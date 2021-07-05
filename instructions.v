DualParameterInstruction AdditionInstruction {
	assigns: bool

	init(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_ADDITION)
		this.assigns = assigns
		this.description = String('Add operands')
	}

	override on_build() {
		if settings.is_x64 { on_build_x64() }
		else { on_build_arm64() }
	}

	on_build_x64() {
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			return
		}

		if assigns {
			# Example: add r/[...], c/r
			=> build(instructions.shared.ADD, first.size, InstructionParameter(first, FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH | FLAG_READS, HANDLE_REGISTER | HANDLE_MEMORY), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER))
		}

		if first.is_deactivating() {
			# Example: add r, c/r/m
			=> build(instructions.shared.ADD, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
		}

		# Example: lea r, [...]
		calculation = ExpressionHandle.create_addition(first, second)

		build(instructions.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(result, FLAG_DESTINATION, HANDLE_REGISTER), InstructionParameter(Result(calculation, SYSTEM_FORMAT), FLAG_NONE, HANDLE_EXPRESSION))
	}

	on_build_arm64() {
		
	}
}

DualParameterInstruction SubtractionInstruction {
	assigns: bool

	init(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_SUBTRACT)
		this.assigns = assigns
	}

	on_build_x64() {
		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			return
		}

		if assigns {
			# Example: sub r/[...], c/r
			=> build(instructions.shared.SUBTRACT, first.size, InstructionParameter(first, FLAG_READS | flags, HANDLE_REGISTER | HANDLE_MEMORY), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER))
		}

		# Example: sub r, c/r/[...]
		build(instructions.shared.SUBTRACT, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	on_build_arm64() {

	}

	override on_build() {
		if settings.is_x64 on_build_x64()
		on_build_arm64()
	}
}

Instruction LabelInstruction {
	label: Label

	init(unit: Unit, label: Label) {
		Instruction.init(unit, INSTRUCTION_LABEL)
		this.label = label
		this.description = label.name + ':'
	}

	override on_build() {
		build(label.name + ':')
	}
}

# Summary:
# Ensures that the lifetimes of the specified variables begin at least at this instruction
# This instruction works on all architectures
Instruction RequireVariablesInstruction {
	variables: List<Variable>

	init(unit: Unit, variables: List<Variable>) {
		Instruction.init(unit, INSTRUCTION_REQUIRE_VARIABLES)
		this.variables = variables
		this.dependencies = List<Result>(variables.size, false)
		this.description = String('Activates variables')
		this.is_abstract = true

		loop variable in variables {
			dependencies.add(references.get_variable(unit, variable, ACCESS_READ))
		}
	}
}

Instruction ReturnInstruction {
	object: Result
	return_type: Type

	return_register() {
		if return_type != none and return_type.format == FORMAT_DECIMAL => unit.get_decimal_return_register()
		=> unit.get_standard_return_register()
	}

	return_register_handle() {
		=> RegisterHandle(return_register)
	}

	init(unit: Unit, object: Result, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_RETURN)

		this.object = object
		this.return_type = return_type
		
		if object != none dependencies.add(object)

		if return_type == none {
			this.result.format = SYSTEM_FORMAT
			return
		}

		this.result.format = return_type.get_register_format()
	}

	# Summary: Returns whether the return value is in the wanted return register
	is_value_in_return_register() {
		=> object.value.instance == INSTANCE_REGISTER and object.value.(RegisterHandle).register == return_register
	}

	override on_build() {
		# 1. Skip if there is no return value
		# 2. Ensure the return value is in the correct register
		if object == none or is_value_in_return_register() return

		instruction = MoveInstruction(unit, Result(return_register_handle, return_type.get_register_format()), object)
		instruction.type = MOVE_RELOCATE
		unit.add(instruction)
	}

	build(recover_registers: List<Register>, local_variables_top: large) {
		builder = StringBuilder()
		builder.append(instructions.shared.RETURN)
		Instruction.build(builder.string())
	}
}

MoveInstructionVariant {
	input_destination_format: large
	input_source_format: large
	match_destination_sign: bool
	match_source_sign: bool
	input_destination_instances: large
	input_source_instances: large
	operation: link
	output_destination_size: large
	output_source_size: large

	init(input_destination_format: large, input_source_format: large, match_destination_sign: bool, match_source_sign: bool, input_destination_instances: large, input_source_instances: large, operation: link, output_destination_size: large, output_source_size: large) {
		this.input_destination_format = input_destination_format
		this.input_source_format = input_source_format
		this.match_destination_sign = match_destination_sign
		this.match_source_sign = match_source_sign
		this.input_destination_instances = input_destination_instances
		this.input_source_instances = input_source_instances
		this.operation = operation
		this.output_destination_size = output_destination_size
		this.output_source_size = output_source_size
	}
}

MOVE_COPY = 1 # Summary: The source value is loaded to the destination attaching the source value to the destination and leaving the source untouched
MOVE_LOAD = 2 # Summary: The source value is loaded to destination attaching the destination value to the destination
MOVE_RELOCATE = 3 # Summary: The source value is loaded to the destination attaching the source value to the destination and updating the source to be equal to the destination

DualParameterInstruction MoveInstruction {
	type: large
	is_safe: bool = false

	init(unit: Unit, first: Result, second: Result) {
		DualParameterInstruction.init(unit, first, second, SYSTEM_FORMAT, INSTRUCTION_MOVE)
		this.description = String('Assign source operand to destination operand')
		this.is_usage_analyzed = false
	}

	is_redundant() {
		if not first.value.equals(second.value) => false
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL => first.format == second.format
		=> first.size == second.size 
	}

	on_build_x64(flags_first: large, flags_second: large) {
		if first.is_standard_register and second.is_constant and second.value.(ConstantHandle).value == 0 {
			# Example: xor r, r
			build(instructions.x64.XOR, SYSTEM_BYTES, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(second, flags_second | FLAG_HIDDEN, HANDLE_CONSTANT))
		}
		else first.is_memory_address and not (first.is_data_section_handle and first.value.(DataSectionHandle).address) {
			# Examples: mov [...], c / mov [...], r
			build(instructions.shared.MOVE, 0, InstructionParameter(first, flags_first, HANDLE_MEMORY), InstructionParameter(second, flags_second, HANDLE_CONSTANT | HANDLE_REGISTER))
		}
		else second.is_data_section_handle and second.value.(DataSectionHandle).address {
			# Disable the address flag while building
			second.value.(DataSectionHandle).address = false
			# Example: lea r, [...]
			build(instructions.x64.EVALUATE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_MEMORY))
			second.value.(DataSectionHandle).address = true
			return
		}
		else second.is_expression {
			# Examples: lea r, [...]
			build(instructions.x64.EVALUATE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_EXPRESSION))
		}
		else second.is_memory_address {
			# Examples: mov r, c / mov r, r / mov r, [...]
			build(instructions.shared.MOVE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
		}
		else {
			# Examples: mov r, c / mov r, r
			build(instructions.shared.MOVE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_CONSTANT | HANDLE_REGISTER))
		}
	}

	override on_build() {
		result.format = first.format
		if is_redundant return

		# Ensure the destination is available, if it is a register and the safe flag is enabled
		if is_safe and first.is_any_register memory.clear_register(unit, first.register)

		# If the source is empty, no actual instruction is needed, but relocating the source might be needed
		if second.is_empty {
			if type != MOVE_RELOCATE return

			# Relocate the source to the destination
			second.value = first.value

			# Attach the source value to the destination, if it is a register
			if second.is_any_register { second.value.(RegisterHandle).register.value = second }

			return
		}

		# Determine the flags of the first and the second operand
		flags_first = FLAG_DESTINATION
		flags_second = FLAG_NONE

		if is_safe { flags_first = flags_first | FLAG_WRITE_ACCESS }

		if type == MOVE_LOAD { flags_first = flags_first | FLAG_ATTACH_TO_DESTINATION }
		else type == MOVE_RELOCATE { flags_second = flags_second | FLAG_ATTACH_TO_DESTINATION | FLAG_RELOCATE_TO_DESTINATION }

		on_build_x64(flags_first, flags_second)
	}

	is_move_instruction_x64() {
		if operation as link == none => false
		=> operation == instructions.shared.MOVE or operation == instructions.x64.UNSIGNED_CONVERSION_MOVE or operation == instructions.x64.SIGNED_CONVERSION_MOVE or operation == instructions.x64.SIGNED_DWORD_CONVERSION_MOVE
	}

	on_post_build_x64() {
		# Skip decimal formats, since they are correct by default
		if destination.value.format == FORMAT_DECIMAL or source.value.format == FORMAT_DECIMAL or not is_move_instruction_x64() return

		is_source_memory_address = source.value != none and source.value.type == HANDLE_MEMORY
		is_destination_memory_address = destination.value != none and destination.value.type == HANDLE_MEMORY

		if is_destination_memory_address and not is_source_memory_address {
			second.value.format = destination.value.format
			return
		}

		# Return if no conversion is needed
		if source.value.size == destination.value.size or second.value.type == HANDLE_CONSTANT {
			operation = String(instructions.shared.MOVE)
			return
		}

		# NOTE: Now the destination parameter must be a register
		if source.value.size > destination.value.size {
			source.value.format = destination.value.format
			return
		}

		# NOTE: Now the size of source operand must be less than the size of destination operand
		if source.value.unsigned {
			if destination.value.size == 8 and source.value.size == 4 {
				# Example: mov eax, ebx (64 <- 32)
				# In 64-bit mode if you move data from 32-bit register to another 32-bit register it zeroes out the high half of the destination 64-bit register
				destination.value.format = FORMAT_UINT32
				return
			}

			# Examples:
			# movzx rax, cx (64 <- 16)
			# movzx rax, cl (64 <- 8)
			# 
			# movzx eax, cx (32 <- 16)
			# movzx eax, cl (32 <- 8)
			#
			# movzx ax, cl (16 <- 8)
			operation = String(instructions.x64.UNSIGNED_CONVERSION_MOVE)
			return
		}

		if destination.value.size == 8 and source.value.size == 4 {
			# movsxd rax, ebx (64 <- 32)
			operation = String(instructions.x64.SIGNED_DWORD_CONVERSION_MOVE)
			return
		}

		# Examples:
		# movsx rax, cx (64 <- 16)
		# movsx rax, cl (64 <- 8)
		#
		# movsx eax, cx (32 <- 16)
		# movsx eax, cl (32 <- 8)
		#
		# movsx ax, cl (16 <- 8)
		operation = String(instructions.x64.SIGNED_CONVERSION_MOVE)
	}

	override on_post_build() {
		if settings.is_x64 on_post_build_x64()
	}
}

Instruction GetConstantInstruction {
	value: large
	format: large

	init(unit: Unit, value: large, is_decimal: large) {
		Instruction.init(unit, INSTRUCTION_GET_CONSTANT)
		
		this.value = value
		this.format = SYSTEM_FORMAT
		this.is_abstract = true

		if is_decimal {
			this.format = FORMAT_DECIMAL
			this.description = String('Load constant ') + to_string(bits_to_decimal(value))
		}
		else {
			this.description = String('Load constant ') + to_string(value)
		}

		this.result.value = references.create_constant_number(value, format)
		this.result.format = format
	}

	override on_build() {
		this.result.value = references.create_constant_number(value, format)
		this.result.format = format
	}
}

Instruction GetVariableInstruction {
	variable: Variable
	mode: large

	init(unit: Unit, variable: Variable, mode: large) {
		Instruction.init(unit, INSTRUCTION_GET_VARIABLE)

		this.variable = variable
		this.mode = mode
		this.is_abstract = true
		this.description = String('Load variable ') + variable.name

		result.value = references.create_variable_handle(unit, variable)
		result.format = variable.type.format
	}

	override on_build() {
		# TODO: Add trace check
		# If the result represents a static variable, it might be needed to load it into a register
		if variable.is_static and mode == ACCESS_READ {
			memory.move_to_register(unit, result, SYSTEM_BYTES, result.format == FORMAT_DECIMAL, trace.for(unit, result))
		}
	}
}

Instruction InitializeInstruction {
	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_INITIALIZE)
	}
}

Instruction SetVariableInstruction {
	variable: Variable
	value: Result

	init(unit: Unit, variable: Variable, value: Result) {
		Instruction.init(unit, INSTRUCTION_SET_VARIABLE)

		if not variable.is_predictable abort('Setting value for unpredictable variables is not allowed')

		this.variable = variable
		this.value = value
		this.dependencies.add(value)

		# If the variable has a previous value, hold it until this instruction is executed
		previous = unit.get_variable_value(variable, false)

		if previous != none { this.dependencies.add(previous) }

		this.description = String('Updates the value of the variable ') + variable.name
		this.is_abstract = true

		result.format = variable.type.get_register_format()
		on_simulate()
	}

	override on_simulate() {
		# If the value does not represent another variable, it does not need to be copied
		if not unit.is_variable_value(value) {
			unit.set_variable_value(variable, value)
			return
		}

		# Since the value represents another variable, the value has been copied to the result of this instruction
		unit.set_variable_value(variable, result)
	}

	override on_build() {
		# Do not copy the value if it does not represent another variable
		if not unit.is_variable_value(value) return

		# Try to get the current location of the variable to be updated
		current = unit.get_variable_value(variable)

		# Use the location if it is available
		if current != none {
			result.value = current.value
			result.format = current.format
		}
		else {
			# Set the default values since the location is not available
			result.value = Handle()
			result.format = variable.type.get_register_format()
		}

		# Copy the value to the result of this instruction
		# NOTE: If the result is empty, the system will reserve a register
		instruction = MoveInstruction(unit, result, value)
		instruction.type = MOVE_LOAD
		unit.add(instruction)
	}
}