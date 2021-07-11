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

ConstantMultiplication {
	multiplicand: Result
	multiplier: large

	init(multiplicand: Result, multiplier: Result) {
		this.multiplicand = multiplicand
		this.multiplier = multiplier.value.(ConstantHandle).value
	}
}

DualParameterInstruction MultiplicationInstruction {
	assigns: bool

	init(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_MULTIPLICATION)
		this.assigns = assigns
	}

	try_get_constant_multiplication() {
		if first.value.type == HANDLE_CONSTANT and first.format != FORMAT_DECIMAL => ConstantMultiplication(second, first)
		if second.value.type == HANDLE_CONSTANT and second.format != FORMAT_DECIMAL => ConstantMultiplication(first, second)
		=> none as ConstantMultiplication
	}

	on_build_x64() {
		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		operand = none as Result

		# Handle decimal multiplication separately
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			return
		}

		multiplication = try_get_constant_multiplication()

		if multiplication != none and multiplication.multiplier > 0 {
			if not assigns and common.is_power_of_two(multiplication.multiplier) and multiplication.multiplier <= instructions.x64.EVALUATE_MAX_MULTIPLIER and not first.is_deactivating {
				memory.get_result_register_for(unit, result, false)

				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				# Example:
				# mov rax, rcx
				# imul rax, 4
				# =>
				# lea rax, [rcx*4]

				calculation = ExpressionHandle(operand, multiplication.multiplier, none as Result, 0)
				=> build(instructions.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(result, FLAG_DESTINATION, HANDLE_REGISTER), InstructionParameter(Result(calculation, SYSTEM_FORMAT), FLAG_NONE, HANDLE_EXPRESSION))
			}

			if common.is_power_of_two(multiplication.multiplier) {
				handle = ConstantHandle(common.integer_log2(multiplication.multiplier))

				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				# Example: sal r, c
				=> build(instructions.x64.SHIFT_LEFT, SYSTEM_BYTES, InstructionParameter(operand, FLAG_READS | flags, HANDLE_REGISTER), InstructionParameter(Result(handle, SYSTEM_FORMAT), FLAG_NONE, HANDLE_CONSTANT))
			}

			if common.is_power_of_two(multiplication.multiplier - 1) and multiplication.multiplier - 1 <= instructions.x64.EVALUATE_MAX_MULTIPLIER {
				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				destination: Result = none as Result

				if assigns { destination = operand }
				else {
					memory.get_result_register_for(unit, result, false)
					destination = result
				}

				# Example: imul rax, 3 => lea r, [rax*2+rax]
				expression = ExpressionHandle(operand, multiplication.multiplier - 1, operand, 0)
				flags_first = FLAG_DESTINATION | FLAG_WRITE_ACCESS

				if assigns { flags_first = flags_first | FLAG_NO_ATTACH }

				=> build(instructions.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(destination, flags_first, HANDLE_REGISTER), InstructionParameter(Result(expression, SYSTEM_FORMAT), FLAG_NONE, HANDLE_EXPRESSION))
			}
		}

		operand = memory.load_operand(unit, first, false, assigns)

		# Example: imul r, c/r/[...]
		build(instructions.x64.SIGNED_MULTIPLY, SYSTEM_BYTES, InstructionParameter(operand, FLAG_READS | flags, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	on_build_arm64() {

	}

	override on_build() {
		if assigns and first.is_memory_address unit.add(MoveInstruction(unit, first, result), true)

		if settings.is_x64 => on_build_x64()
		=> on_build_arm64()
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

# Summary:
# The instruction calls the specified value (for example function label or a register).
# This instruction is works on all architectures
Instruction CallInstruction {
	function: Result
	return_type: Type

	# Represents the destination handles where the required parameters are passed to
	destinations: List<Handle> = List<Handle>()

	# This call is a tail call if it uses a jump instruction
	is_tail_call => operation == instructions.x64.JUMP or operation == instructions.arm64.JUMP_LABEL or operation == instructions.arm64.JUMP_REGISTER

	init(unit: Unit, function: String, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_CALL)

		this.function = Result(DataSectionHandle(function, true), SYSTEM_FORMAT)
		this.return_type = return_type
		this.dependencies.add(this.function)
		this.description = String('Calls function ') + function
		this.is_usage_analyzed = false # NOTE: Fixes an issue where the build system moves the function handle to volatile register even though it is needed later

		if return_type != none {
			this.result.format = return_type.get_register_format()
			return
		}

		this.result.format = SYSTEM_FORMAT
	}

	init(unit: Unit, function: Result, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_CALL)

		this.function = function
		this.return_type = return_type
		this.dependencies.add(this.function)
		this.description = String('Calls the function handle')
		this.is_usage_analyzed = false # NOTE: Fixes an issue where the build system moves the function handle to volatile register even though it is needed later

		if return_type != none {
			this.result.format = return_type.get_register_format()
			return
		}

		this.result.format = SYSTEM_FORMAT
	}

	# Summary: Iterates through the volatile registers and ensures that they do not contain any important values which are needed later
	validate_evacuation() {
		loop register in unit.volatile_registers {
			# NOTE: The availability of the register is not checked the standard way since they are usually locked at this stage
			if register.value == none or not register.value.is_active or register.value.is_deactivating() or register.is_value_copy() continue
			abort('Register evacuation failed')
		}
	}

	# Summary: Prepares the memory handle for use by relocating its inner handles into registers, therefore its use does not require additional steps, except if it is in invalid format
	# Returns: Returns a list of register locks which must be active while the handle is in use
	validate_memory_handle(handle: Handle) {
		results = handle.get_register_dependent_results()
		locks = List<Register>()

		loop iterator in results {
			# 1. If the function handle lifetime extends over this instruction, all the inner handles must extend over this instruction as well, therefore a non-volatile register is needed
			# 2. If lifetime of a inner handle extends over this instruction, it needs a non-volatile register
			non_volatile = (function.is_active and not function.is_deactivating) or (iterator.is_active and not iterator.is_deactivating)
			
			if iterator.is_standard_register and not (non_volatile and iterator.register.is_volatile) continue

			# Request an available register, which is volatile based on the lifetime of the function handle and its inner handles
			register = none as Register

			if non_volatile { register = unit.get_next_non_volatile_register(false, true) }
			else { register = unit.get_next_register() }

			# There should always be a register available, since the function call above can release values into memory
			if register == none abort('Could not validate call memory handle')

			instruction = MoveInstruction(unit, Result(RegisterHandle(register), SYSTEM_FORMAT), iterator)
			instruction.description = String('Validates a call memory handle')
			instruction.type = MOVE_RELOCATE

			unit.add(instruction)
			locks.add(iterator.register)
		}

		=> locks
	}

	override on_build() {
		# Lock all destination registers
		registers = List<Register>()

		loop iterator in destinations {
			if iterator.type != HANDLE_REGISTER continue
			iterator.(RegisterHandle).register.lock()
			registers.add(iterator.(RegisterHandle).register)
		}

		locked = List<Register>()

		if settings.is_x64 {
			if function.is_memory_address {
				locked = validate_memory_handle(function.value)
			}
			else {
				memory.move_to_register(unit, function, SYSTEM_BYTES, false, trace.for(unit, function))
				locked.add(function.register)
			}

			# Ensure the function handle is in the correct format
			if function.format != SYSTEM_FORMAT {
				loop register in locked { register.unlock() }

				memory.move_to_register(unit, function, SYSTEM_BYTES, false, trace.for(unit, function))
				locked.add(function.register)
			}

			# Now evacuate all the volatile registers before the call
			unit.add(EvacuateInstruction(unit))

			# If the format of the function handle changes, it means its format is registered incorrectly somewhere
			if function.format != SYSTEM_FORMAT abort('Invalid function handle format')

			build(instructions.x64.CALL, 0, InstructionParameter(function, FLAG_BIT_LIMIT_64 | FLAG_ALLOW_ADDRESS, HANDLE_REGISTER | HANDLE_MEMORY))
		}
		else {
			
		}

		loop register in locked { register.unlock() }

		# Validate evacuation since it is very important to be correct
		validate_evacuation()

		# Now that the call is over, the registers can be unlocked
		loop register in registers { register.unlock() }

		# After a call all volatile registers might be changed
		loop register in unit.volatile_registers { register.reset() }

		# Returns value is always in the following handle
		register = none as Register

		if result.format == FORMAT_DECIMAL { register = unit.get_decimal_return_register() }
		else { register = unit.get_standard_return_register() }

		result.value = RegisterHandle(register)
		register.value = result
	}
}

Instruction ReorderInstruction {
	destinations: List<Handle>
	formats: List<large>
	sources: List<Result>
	extracted: bool = false

	init(unit: Unit, destinations: List<Handle>, sources: List<Result>) {
		Instruction.init(unit, INSTRUCTION_REORDER)
		this.dependencies = none
		this.destinations = destinations
		this.formats = List<large>(destinations.size, false)
		this.sources = sources

		loop iterator in destinations { formats.add(iterator.format) }
	}

	override on_build() {
		instructions = List<MoveInstruction>()

		loop (i = 0, i < destinations.size, i++) {
			source = sources[i]
			destination = Result(destinations[i], formats[i])

			instruction = MoveInstruction(unit, destination, source)
			instruction.is_safe = true
			instructions.add(instruction)
		}

		instructions = memory.align(unit, instructions)

		extracted = true
		loop instruction in instructions { unit.add(instruction) }
	}

	override get_dependencies() {
		if extracted => List<Result>()
		=> sources
	}
}

# Summary:
# Exchanges the locations of the specified values.
# This instruction works only on architecture x86-64.
DualParameterInstruction ExchangeInstruction {
	init(unit: Unit, first: Result, second: Result) {
		DualParameterInstruction.init(unit, first, second, first.format, INSTRUCTION_EXCHANGE)
		this.is_usage_analyzed = false
	}

	override on_build() {
		# Example: xchg r, r
		build(instructions.x64.EXCHANGE, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_RELOCATE_TO_SOURCE | FLAG_READS | FLAG_WRITE_ACCESS, HANDLE_REGISTER), InstructionParameter(second, FLAG_SOURCE | FLAG_RELOCATE_TO_DESTINATION | FLAG_WRITES | FLAG_READS, HANDLE_REGISTER))
	}
}

# Summary:
# Sets the lock state of the specified variable
# This instruction works on all architectures
Instruction LockStateInstruction {
	register: Register
	is_locked: bool

	init(unit: Unit, register: Register, locked: bool) {
		Instruction.init(unit, INSTRUCTION_LOCK_STATE)
		this.register = register
		this.is_locked = locked
		this.is_abstract = true
		
		if is_locked { description = String('Locks a register') }
		else { description = String('Unlocks a register') }
	}

	override on_simulate() {
		register.is_locked = is_locked
	}

	override on_build() {
		register.is_locked = is_locked
	}
}

# Summary:
# Ensures that variables and values which are required later are moved to locations which are not affected by call instructions for example
# This instruction is works on all architectures
Instruction EvacuateInstruction {
	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_EVACUATE)
		this.is_abstract = true
	}

	override on_build() {
		# Save all important values in the standard volatile registers
		loop register in unit.volatile_registers {
			register.lock()

			# Skip values which are not needed after the call instruction
			# NOTE: The availability of the register is not checked the standard way since they are usually locked at this stage
			if register.value == none or not register.value.is_active or register.value.is_deactivating or register.is_value_copy continue

			# Try to get an available non-volatile register
			destination = none as Handle
			non_volatile_register = unit.get_next_non_volatile_register(register.is_media_register, false)

			# Use the non-volatile register, if one was found
			if non_volatile_register != none {
				destination = RegisterHandle(non_volatile_register)
			}
			else {
				# Since there are no non-volatile registers available, the value must be relocated to stack memory
				unit.release(register)
				continue
			}

			instruction = MoveInstruction(unit, Result(destination, register.format), register.value)
			instruction.description = String('Evacuates a value')
			instruction.type = MOVE_RELOCATE

			unit.add(instruction)
		}

		# Unlock all the volatile registers
		loop register in unit.volatile_registers { register.unlock() }
	}
}

Instruction GetObjectPointerInstruction {
	variable: Variable
	start: Result
	offset: large
	mode: large

	init(unit: Unit, variable: Variable, start: Result, offset: large, mode: large) {
		Instruction.init(unit, INSTRUCTION_GET_OBJECT_POINTER)
		this.variable = variable
		this.start = start
		this.offset = offset
		this.mode = mode
		this.is_abstract = true
		this.dependencies.add(start)
		this.result.format = variable.type.format
	}

	validate_handle() {
		# Ensure the start value is a constant or in a register
		if not start.is_constant and not start.is_inline and not start.is_standard_register {
			memory.move_to_register(unit, start, SYSTEM_BYTES, false, trace.for(unit, start))
		}
	}

	override on_build() {
		validate_handle()

		if variable.is_inlined() {
			result.value = ExpressionHandle.create_memory_address(start, offset)
			result.format = variable.type.format
			return
		}

		result.value = MemoryHandle(unit, start, offset)
		result.format = variable.type.format
	}
}

Instruction GetMemoryAddressInstruction {
	format: large
	start: Result
	offset: Result
	stride: large

	init(unit: Unit, format: large, start: Result, offset: Result, stride: large) {
		Instruction.init(unit, INSTRUCTION_GET_MEMORY_ADDRESS)
		this.start = start
		this.offset = offset
		this.stride = stride
		this.format = format
		this.is_abstract = true
		this.dependencies.add(start)
		this.dependencies.add(offset)

		result.value = ComplexMemoryHandle(start, offset, stride, 0)
		result.format = format
	}

	validate_handle() {
		# Ensure the start value is a constant or in a register
		if start.is_constant or start.is_inline or start.is_standard_register return
		memory.move_to_register(unit, start, SYSTEM_BYTES, false, trace.for(unit, start))
	}

	override on_build() {
		validate_handle()

		result.value = ComplexMemoryHandle(start, offset, stride, 0)
		result.format = format
	}
}

Instruction TemporaryInstruction {
	init(unit: Unit, type: large) {
		Instruction.init(unit, type)
	}

	override on_build() { abort('Tried to build a temporary instruction') }
	override on_post_build() { abort('Tried to build a temporary instruction') }
	override on_simulate() { abort('Tried to build a temporary instruction') }
}

JumpOperatorBinding {
	signed: link
	unsigned: link

	init(signed: link, unsigned: link) {
		this.signed = signed
		this.unsigned = unsigned
	}
}

# Summary:
# Jumps to the specified label and optionally checks a condition
# This instruction works on all architectures
Instruction JumpInstruction {
	static jumps: Map<ComparisonOperator, JumpOperatorBinding>

	static initialize() {
		jumps = Map<ComparisonOperator, JumpOperatorBinding>()

		if settings.is_x64 {
			jumps.add(Operators.GREATER_THAN,     JumpOperatorBinding(instructions.x64.JUMP_GREATER_THAN,           instructions.x64.JUMP_ABOVE))
			jumps.add(Operators.GREATER_OR_EQUAL, JumpOperatorBinding(instructions.x64.JUMP_GREATER_THAN_OR_EQUALS, instructions.x64.JUMP_ABOVE_OR_EQUALS))
			jumps.add(Operators.LESS_THAN,        JumpOperatorBinding(instructions.x64.JUMP_LESS_THAN,              instructions.x64.JUMP_BELOW))
			jumps.add(Operators.LESS_OR_EQUAL,    JumpOperatorBinding(instructions.x64.JUMP_LESS_THAN_OR_EQUALS,    instructions.x64.JUMP_BELOW_OR_EQUALS))
			jumps.add(Operators.EQUALS,           JumpOperatorBinding(instructions.x64.JUMP_EQUALS,                 instructions.x64.JUMP_ZERO))
			jumps.add(Operators.NOT_EQUALS,       JumpOperatorBinding(instructions.x64.JUMP_NOT_EQUALS,             instructions.x64.JUMP_NOT_ZERO))
			return
		}

		#jumps.add(Operators.GREATER_THAN,     JumpOperatorBinding(instructions.arm64.JUMP_GREATER_THAN,           instructions.arm64.JUMP_GREATER_THAN))
		#jumps.add(Operators.GREATER_OR_EQUAL, JumpOperatorBinding(instructions.arm64.JUMP_GREATER_THAN_OR_EQUALS, instructions.arm64.JUMP_GREATER_THAN_OR_EQUALS))
		#jumps.add(Operators.LESS_THAN,        JumpOperatorBinding(instructions.arm64.JUMP_LESS_THAN,              instructions.arm64.JUMP_LESS_THAN))
		#jumps.add(Operators.LESS_OR_EQUAL,    JumpOperatorBinding(instructions.arm64.JUMP_LESS_THAN_OR_EQUALS,    instructions.arm64.JUMP_LESS_THAN_OR_EQUALS))
		#jumps.add(Operators.EQUALS,           JumpOperatorBinding(instructions.arm64.JUMP_EQUALS,                 instructions.arm64.JUMP_EQUALS))
		#jumps.add(Operators.NOT_EQUALS,       JumpOperatorBinding(instructions.arm64.JUMP_NOT_EQUALS,             instructions.arm64.JUMP_NOT_EQUALS))
	}

	label: Label
	comparator: ComparisonOperator
	is_conditional => comparator != none
	is_signed: bool = true

	init(unit: Unit, label: Label) {
		Instruction.init(unit, INSTRUCTION_JUMP)
		this.label = label
		this.comparator = none
	}

	init(unit: Unit, comparator: ComparisonOperator, invert: bool, signed: bool, label: Label) {
		Instruction.init(unit, INSTRUCTION_JUMP)
		this.label = label
		this.is_signed = signed

		if invert { this.comparator = comparator.counterpart }
		else { this.comparator = comparator }
	}

	invert() {
		this.comparator = comparator.counterpart
	}

	override on_build() {
		instruction = none as link

		if comparator == none {
			if settings.is_x64 { instruction = instructions.x64.JUMP }
		}
		else is_signed {
			instruction = jumps[comparator].signed
		}
		else not is_signed {
			instruction = jumps[comparator].unsigned
		}

		build(String(instruction) + ' ' + label.name)
	}
}

# Summary:
# Relocates variables so that their locations match the state of the outer scope
# This instruction works on all architectures
Instruction MergeScopeInstruction {
	container: Scope

	init(unit: Unit, container: Scope) {
		Instruction.init(unit, INSTRUCTION_MERGE_SCOPE)
		this.container = container
		this.description = String('Relocates values so that their locations match the state of the outer scope')
		this.is_abstract = true
	}

	get_variable_stack_handle(variable: Variable) {
		=> Result(references.create_variable_handle(unit, variable), variable.type.format)
	}

	get_destination_handle(variable: Variable) {
		if container.outer == none => get_variable_stack_handle(variable)
		=> container.outer.get_variable_value(variable, true)
	}

	override on_build() {
		moves = List<MoveInstruction>()

		loop variable in container.actives {
			source = unit.get_variable_value(variable, true)
			if source == none { source = get_variable_stack_handle(variable) }

			# Copy the destination value to prevent any relocation leaks
			handle = get_destination_handle(variable)
			destination = Result(handle.value, handle.format)

			if destination.is_constant continue

			# If the only difference between the source and destination, is the size, and the source size is larger than the destination size, no conversion is needed
			# NOTE: Move instruction should still be created, so that the destination is locked
			if destination.value.equals(source.value) and to_bytes(destination.format) <= to_bytes(source.format) { source = destination }

			instruction = MoveInstruction(unit, destination, source)
			instruction.is_safe = true
			instruction.description = String('Relocates the source value to merge the current scope with the outer scope')
			instruction.type = MOVE_RELOCATE

			moves.add(instruction)
		}

		instructions = memory.align(unit, moves)

		loop (i = instructions.size - 1, i >= 0, i--) {
			unit.add(instructions[i], true)
		}
	}
}

# Summary:
# This instruction compares the two specified values together and alters the CPU flags based on the comparison
# This instruction is works on all architectures
DualParameterInstruction CompareInstruction {
	init(unit: Unit, first: Result, second: Result) {
		DualParameterInstruction.init(unit, first, second, SYSTEM_FORMAT, INSTRUCTION_COMPARE)
		this.description = String('Compares two operands')
	}

	on_build_x64() {
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			return
		}

		if settings.is_x64 and second.is_constant and second.value.(ConstantHandle).value == 0 {
			# Example: test r, r
			=> build(instructions.x64.TEST, first.size, InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_REGISTER))
		}

		# Example: cmp r, c/r/[...]
		build(instructions.shared.COMPARE, min(first.size, second.size), InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	override on_build() {
		if settings.is_x64 => on_build_x64()
	}
}

# Summary:
# Loads the specified variable into a modifiable location if it is constant
# This instruction works on all architectures
Instruction SetModifiableInstruction {
	variable: Variable

	init(unit: Unit, variable: Variable) {
		Instruction.init(unit, INSTRUCTION_SET_MODIFIABLE)
		this.variable = variable
		this.description = String('Ensures the variable is in a modifiable location')
		this.is_abstract = true

		this.result.format = variable.type.get_register_format()
	}

	override on_build() {
		handle = unit.get_variable_value(variable)
		if handle == none or not handle.is_constant return

		directives = trace.for(unit, handle)
		is_media_register = handle.format == FORMAT_DECIMAL

		# Try to use the directives to decide the destination register for the variable
		register = memory.consider(unit, directives, is_media_register)

		# If the directives did not determine the register, try to determine the register manually
		if register == none {
			if is_media_register { register = unit.get_next_media_register_without_releasing() }
			else { register = unit.get_next_register_without_releasing() }
		}

		# If register could not be determined, the variable must be moved into memory
		if register == none { result.value = references.create_variable_handle(unit, variable) }
		else { result.value = RegisterHandle(register) }

		instruction = MoveInstruction(unit, result, handle)
		instruction.type = MOVE_RELOCATE
		unit.add(instruction)
	}
}

ConstantDivision {
	dividend: Result
	number: large

	init(dividend: Result, number: Result) {
		this.dividend = dividend
		this.number = number.value.(ConstantHandle).value
	}
}

# Summary:
# This instruction divides the two specified operand together and outputs a result.
# This instruction can act as a remainder operation.
# This instruction is works on all architectures
DualParameterInstruction DivisionInstruction {
	modulus: bool
	assigns: bool
	unsigned: bool

	init(unit: Unit, modulus: bool, first: Result, second: Result, format: large, assigns: bool, unsigned: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_DIVISION)
		this.modulus = modulus
		this.unsigned = unsigned
		this.assigns = assigns
	}

	# Summary: Ensures the numerator value is in the right register
	correct_numerator_location() {
		numerator = unit.get_numerator_register()
		remainder = unit.get_remainder_register()

		destination = RegisterHandle(numerator)

		if not first.value.equals(destination) {
			remainder.lock()
			memory.clear_register(Unit, destination.register)
			remainder.unlock()

			if assigns and not first.is_memory_address {
				instruction = MoveInstruction(unit, Result(destination, SYSTEM_FORMAT), first)
				instruction.type = MOVE_RELOCATE
				unit.add(instruction)
				=> first
			}

			instruction = MoveInstruction(unit, Result(destination, SYSTEM_FORMAT), first)
			instruction.type = MOVE_COPY
			=> instruction.add()
		}
		else not assigns {
			if not first.is_deactivating memory.clear_register(unit, destination.register)
			=> Result(destination, SYSTEM_FORMAT)
		}

		=> first
	}

	# Summary: Ensures the remainder register is ready for division or modulus operation
	prepare_remainder_register() {
		numerator_register = unit.get_numerator_register()
		remainder_register = unit.get_remainder_register()

		numerator_register.lock()
		remainder_register.lock()

		if unsigned {
			# Clear the remainder register
			memory.zero(unit, remainder_register)
		}
		else {
			memory.clear_register(unit, remainder_register)
			unit.add(ExtendNumeratorInstruction(unit))
		}

		numerator_register.unlock()
		remainder_register.unlock()
	}

	# Summary: Builds a modulus operation
	build_modulus(numerator: Result) {
		remainder = RegisterHandle(unit.get_remainder_register())

		flags = FLAG_WRITE_ACCESS | FLAG_HIDDEN | FLAG_WRITES | FLAG_READS | FLAG_LOCKED
		if assigns { flags = flags | FLAG_RELOCATE_TO_DESTINATION }

		# Example: idiv r, r/[...]
		build(
			instructions.x64.SIGNED_DIVIDE, SYSTEM_BYTES,
			InstructionParameter(numerator, flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_REGISTER | HANDLE_MEMORY),
			InstructionParameter(Result(remainder, SYSTEM_FORMAT), flags | FLAG_DESTINATION, HANDLE_REGISTER)
		)
	}

	# Summary: Builds a division operation
	build_division(numerator: Result) {
		remainder = RegisterHandle(unit.get_remainder_register())
		flags = FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_HIDDEN | FLAG_READS | FLAG_LOCKED
		if assigns { flags = flags | FLAG_NO_ATTACH }

		# Example: idiv r, r/[...]
		build(instructions.x64.SIGNED_DIVIDE, SYSTEM_BYTES,
			InstructionParameter(numerator, flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_REGISTER | HANDLE_MEMORY),
			InstructionParameter(Result(remainder, SYSTEM_FORMAT), FLAG_HIDDEN | FLAG_LOCKED | FLAG_WRITES, HANDLE_REGISTER)
		)
	}

	# Summary: Tries to express the current instructions as a division instruction where the divisor is a constant
	try_get_constant_division() {
		if second.is_constant and second.format != FORMAT_DECIMAL => ConstantDivision(first, second)
		=> none as ConstantDivision
	}

	on_build_x64() {
		# Handle decimal division separately
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			# TODO: Support decimals
			return
		}

		if not modulus {
			division = try_get_constant_division()

			if division != none and common.is_power_of_two(division.number) and division.number != 0 {
				count = ConstantHandle(common.integer_log2(division.number))

				flags = FLAG_NONE
				if assigns { flags = FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

				operand = memory.load_operand(unit, division.dividend, false, assigns)

				# Example: sar r, c
				=> build(instructions.x64.SHIFT_RIGHT, SYSTEM_BYTES,
					InstructionParameter(operand, FLAG_DESTINATION | FLAG_READS | flags, HANDLE_REGISTER),
					InstructionParameter(Result(count, SYSTEM_FORMAT), FLAG_NONE, HANDLE_CONSTANT)
				)
			}
		}

		numerator_register = unit.get_numerator_register()
		remainder_register = unit.get_remainder_register()

		numerator = correct_numerator_location()

		prepare_remainder_register()

		numerator_register.lock()
		remainder_register.lock()

		if modulus { build_modulus(numerator) }
		else { build_division(numerator) }

		numerator_register.unlock()
		remainder_register.unlock()
	}

	override on_build() {
		if settings.is_x64 => on_build_x64()
	}
}

# Summary:
# Extends the sign of the quotient register
# This instruction works only on architecture x86-64
Instruction ExtendNumeratorInstruction {
	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_EXTEND_NUMERATOR)
	}

	override on_build() {
		numerator = RegisterHandle(unit.get_numerator_register())
		remainder = RegisterHandle(unit.get_remainder_register())

		# Example: cqo
		build(
			instructions.x64.EXTEND_QWORD,
			0,
			InstructionParameter(Result(remainder, SYSTEM_FORMAT), FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH | FLAG_HIDDEN | FLAG_LOCKED, HANDLE_REGISTER),
			InstructionParameter(Result(numerator, SYSTEM_FORMAT), FLAG_HIDDEN | FLAG_LOCKED, HANDLE_REGISTER)
		)
	}
}

DualParameterInstruction BitwiseInstruction {
	instruction: String
	assigns: bool

	static create_xor(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		if settings.is_x64 {
			if format == FORMAT_DECIMAL => none as Instruction
			=> BitwiseInstruction(unit, instructions.x64.XOR, first, second, format, assigns)
		}
	}

	init(unit: Unit, instruction: link, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_BITWISE)
		this.instruction = String(instruction)
		this.description = String('Executes a bitwise operation between the operands')
		this.assigns = assigns
	}

	on_build_x64() {
		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		if first.is_memory_address and assigns {
			# Example: ... [...], c/r
			=> build(instruction.text, first.size,
				InstructionParameter(first, FLAG_READS | flags, HANDLE_MEMORY),
				InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER)
			)
		}

		# Example: ... r, c/r/[...]
		build(instruction.text, SYSTEM_BYTES,
			InstructionParameter(first, FLAG_READS | flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY)
		)
	}

	override on_build() {
		if settings.is_x64 => on_build_x64()
	}
}