DualParameterInstruction AdditionInstruction {
	assigns: bool

	init(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_ADDITION)
		this.assigns = assigns
		this.description = "Add operands"
	}

	override on_build() {
		if settings.is_x64 { on_build_x64() }
		else { on_build_arm64() }
	}

	on_build_x64() {
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			if assigns and first.is_memory_address unit.add(MoveInstruction(unit, first, result), true)

			operand = memory.load_operand(unit, first, true, assigns)

			types = HANDLE_MEDIA_REGISTER
			if second.format == FORMAT_DECIMAL { types = HANDLE_MEDIA_REGISTER | HANDLE_MEMORY }

			# NOTE: Changed the parameter flag to none because any attachment could override the contents of the destination register and the variable should move to an appropriate register attaching the variable there
			flags = FLAG_NONE
			if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

			build(platform.x64.DOUBLE_PRECISION_ADD, 0, InstructionParameter(operand, FLAG_DESTINATION | FLAG_READS | flags, HANDLE_MEDIA_REGISTER), InstructionParameter(second, FLAG_NONE, types))
			return
		}

		if assigns {
			# Example: add r/[...], c/r
			return build(platform.all.ADD, first.size, InstructionParameter(first, FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH | FLAG_READS, HANDLE_REGISTER | HANDLE_MEMORY), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER))
		}

		if first.is_deactivating() {
			# Example: add r, c/r/m
			return build(platform.all.ADD, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
		}

		# Example: lea r, [...]
		calculation = ExpressionHandle.create_addition(first, second)

		build(platform.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(result, FLAG_DESTINATION, HANDLE_REGISTER), InstructionParameter(Result(calculation, SYSTEM_FORMAT), FLAG_NONE, HANDLE_EXPRESSION))
	}

	on_build_arm64(): _ {
		
	}
}

DualParameterInstruction SubtractionInstruction {
	assigns: bool

	init(unit: Unit, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_SUBTRACT)
		this.assigns = assigns
	}

	on_build_x64(): _ {
		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			if assigns and first.is_memory_address unit.add(MoveInstruction(unit, first, result), true)

			operand = memory.load_operand(unit, first, true, assigns)

			types = HANDLE_MEDIA_REGISTER
			if second.format == FORMAT_DECIMAL { types = HANDLE_MEDIA_REGISTER | HANDLE_MEMORY }

			build(platform.x64.DOUBLE_PRECISION_SUBTRACT, 0, InstructionParameter(operand, FLAG_READS | flags, HANDLE_MEDIA_REGISTER), InstructionParameter(second, FLAG_NONE, types))
			return
		}

		if assigns {
			# Example: sub r/[...], c/r
			return build(platform.all.SUBTRACT, first.size, InstructionParameter(first, FLAG_READS | flags, HANDLE_REGISTER | HANDLE_MEMORY), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER))
		}

		# Example: sub r, c/r/[...]
		build(platform.all.SUBTRACT, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	on_build_arm64(): _ {

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

	try_get_constant_multiplication(): ConstantMultiplication {
		if first.value.type == HANDLE_CONSTANT and first.format != FORMAT_DECIMAL return ConstantMultiplication(second, first)
		if second.value.type == HANDLE_CONSTANT and second.format != FORMAT_DECIMAL return ConstantMultiplication(first, second)
		return none as ConstantMultiplication
	}

	on_build_x64(): _ {
		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		operand = none as Result

		# Handle decimal multiplication separately
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			types = HANDLE_MEDIA_REGISTER
			if second.format == FORMAT_DECIMAL { types = HANDLE_MEDIA_REGISTER | HANDLE_MEMORY }

			operand = memory.load_operand(unit, first, true, assigns)

			build(platform.x64.DOUBLE_PRECISION_MULTIPLY, 0, InstructionParameter(operand, FLAG_READS | flags, HANDLE_MEDIA_REGISTER), InstructionParameter(second, FLAG_NONE, types))
			return
		}

		multiplication = try_get_constant_multiplication()

		if multiplication != none and multiplication.multiplier > 0 {
			if not assigns and common.is_power_of_two(multiplication.multiplier) and multiplication.multiplier <= platform.x64.EVALUATE_MAX_MULTIPLIER and not first.is_deactivating {
				memory.get_result_register_for(unit, result, unsigned, false)

				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				# Example:
				# mov rax, rcx
				# imul rax, 4
				# =>
				# lea rax, [rcx*4]

				calculation = ExpressionHandle(operand, multiplication.multiplier, none as Result, 0)
				return build(platform.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(result, FLAG_DESTINATION, HANDLE_REGISTER), InstructionParameter(Result(calculation, get_system_format(unsigned)), FLAG_NONE, HANDLE_EXPRESSION))
			}

			if common.is_power_of_two(multiplication.multiplier) {
				handle = ConstantHandle(common.integer_log2(multiplication.multiplier))

				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				# Example: sal r, c
				return build(platform.x64.SHIFT_LEFT, SYSTEM_BYTES, InstructionParameter(operand, FLAG_READS | flags, HANDLE_REGISTER), InstructionParameter(Result(handle, SYSTEM_FORMAT), FLAG_NONE, HANDLE_CONSTANT))
			}

			if common.is_power_of_two(multiplication.multiplier - 1) and multiplication.multiplier - 1 <= platform.x64.EVALUATE_MAX_MULTIPLIER {
				operand = memory.load_operand(unit, multiplication.multiplicand, false, assigns)

				destination: Result = none as Result

				if assigns { destination = operand }
				else {
					memory.get_result_register_for(unit, result, unsigned, false)
					destination = result
				}

				# Example: imul rax, 3 => lea r, [rax*2+rax]
				expression = ExpressionHandle(operand, multiplication.multiplier - 1, operand, 0)
				flags_first = FLAG_DESTINATION | FLAG_WRITE_ACCESS

				if assigns { flags_first = flags_first | FLAG_NO_ATTACH }

				return build(platform.x64.EVALUATE, SYSTEM_BYTES, InstructionParameter(destination, flags_first, HANDLE_REGISTER), InstructionParameter(Result(expression, get_system_format(unsigned)), FLAG_NONE, HANDLE_EXPRESSION))
			}
		}

		operand = memory.load_operand(unit, first, false, assigns)

		# Example: imul r, c/r/[...]
		build(platform.x64.SIGNED_MULTIPLY, SYSTEM_BYTES, InstructionParameter(operand, FLAG_READS | flags, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	on_build_arm64(): _ {

	}

	override on_build() {
		if assigns and first.is_memory_address unit.add(MoveInstruction(unit, first, result), true)

		if settings.is_x64 return on_build_x64()
		return on_build_arm64()
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
	is_inputter: bool

	init(unit: Unit, is_inputter: bool) {
		Instruction.init(unit, INSTRUCTION_REQUIRE_VARIABLES)
		this.dependencies = List<Result>()
		this.is_inputter = is_inputter
		this.is_abstract = true

		if is_inputter { this.description = "Inputs variables to the scope" }
		else { this.description = "Outputs variables to the scope" }
	}
}

Instruction ReturnInstruction {
	object: Result
	return_type: Type

	return_register(): Register {
		if return_type != none and return_type.format == FORMAT_DECIMAL return unit.get_decimal_return_register()
		return unit.get_standard_return_register()
	}

	return_register_handle(): RegisterHandle {
		return RegisterHandle(return_register)
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
	is_value_in_return_register(): bool {
		return object.value.instance == INSTANCE_REGISTER and object.value.(RegisterHandle).register == return_register
	}

	override on_build() {
		# 1. Skip if there is no return value
		# 2. Packs are handled separately
		# 3. Ensure the return value is in the correct register
		if object == none or (return_type != none and return_type.is_pack) or is_value_in_return_register() return

		instruction = MoveInstruction(unit, Result(return_register_handle, return_type.get_register_format()), object)
		instruction.type = MOVE_RELOCATE
		unit.add(instruction)
	}

	restore_registers_x64(builder: StringBuilder, registers: List<Register>): _ {
		# Save all used non-volatile registers
		loop register in registers {
			builder.append(platform.x64.POP)
			builder.append(` `)
			builder.append_line(register[SYSTEM_BYTES])
		}
	}

	restore_registers_arm64(builder: StringBuilder, registers: List<Register>) {}

	build(recover_registers: List<Register>, local_memory_top: large): _ {
		builder = StringBuilder()
		allocated_local_memory = unit.stack_offset - local_memory_top

		if allocated_local_memory > 0 {
			stack_pointer = unit.get_stack_pointer()

			if settings.is_x64 {
				builder.append(platform.all.ADD)
				builder.append(` `)
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', ')
				builder.append_line(allocated_local_memory)
			}
			else {
				builder.append(platform.all.ADD)
				builder.append(` `)
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', ')
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', #')
				builder.append_line(allocated_local_memory)
			}
		}

		# Restore all used non-volatile registers
		if settings.is_x64 { restore_registers_x64(builder, recover_registers) }
		else { restore_registers_arm64(builder, recover_registers) }

		builder.append(platform.all.RETURN)
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

	# Summary:
	# Stores whether the destination operand is protected from modification.
	# If set to true and the destination contains an active value, the destination will be cleared before modification.
	is_destination_protected: bool = false

	init(unit: Unit, first: Result, second: Result) {
		DualParameterInstruction.init(unit, first, second, SYSTEM_FORMAT, INSTRUCTION_MOVE)
		this.description = "Assign source operand to destination operand"
		this.is_usage_analyzed = false
	}

	# Summary:
	# Determines whether the move is considered to be redundant.
	# If the destination and source operands are the same, the move is considered redundant.
	is_redundant(): bool {
		if not first.value.equals(second.value) return false
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL return first.format == second.format
		return first.size == second.size 
	}

	build_decimal_constant_move_x64(flags_first, flags_second) {
		instruction = platform.x64.RAW_MEDIA_REGISTER_MOVE
		if first.is_memory_address { instruction = platform.all.MOVE }

		if type == MOVE_RELOCATE {
			handle = second.value as ConstantHandle

			if second.format == FORMAT_DECIMAL {
				handle.format = SYSTEM_FORMAT
			}
			else {
				handle.value = decimal_to_bits(handle.value as decimal)
				handle.format = SYSTEM_FORMAT
			}

			second.format = SYSTEM_FORMAT
			memory.move_to_register(unit, second, SYSTEM_BYTES, false, trace.for(unit, second))

			# Example:
			# mov r, c
			# movq x, r
			#
			# mov r, c
			# mov [...], r
			return build(instruction, 0,
				InstructionParameter(first, flags_first, HANDLE_MEDIA_REGISTER | HANDLE_MEMORY),
				InstructionParameter(second, flags_second | FLAG_BIT_LIMIT_64, HANDLE_REGISTER)
			)
		}

		handle = second.value.finalize() as ConstantHandle

		if second.format == FORMAT_DECIMAL {
			handle.format = SYSTEM_FORMAT
		}
		else {
			handle.value = decimal_to_bits(handle.value as decimal)
			handle.format = SYSTEM_FORMAT
		}

		# Example:
		# mov r, c
		# movq x, r
		#
		# mov r, c
		# mov [...], r
		return build(instruction, 0,
			InstructionParameter(first, flags_first, HANDLE_MEDIA_REGISTER | HANDLE_MEMORY),
			InstructionParameter(Result(handle, SYSTEM_FORMAT), flags_second | FLAG_BIT_LIMIT_64, HANDLE_REGISTER)
		)
	}

	on_build_decimal_zero_move(flags_first, flags_second) {
		# Example: pxor x, x
		return build(platform.x64.MEDIA_REGISTER_BITWISE_XOR, 0,
			InstructionParameter(first, flags_first, HANDLE_MEDIA_REGISTER),
			InstructionParameter(first, FLAG_NONE, HANDLE_MEDIA_REGISTER),
			InstructionParameter(second, flags_second | FLAG_HIDDEN | FLAG_BIT_LIMIT_64, HANDLE_CONSTANT)
		)
	}

	on_build_constant_to_decimal_move(flags_first, flags_second, first_parameter_type) {
		if type == MOVE_RELOCATE {
			# Convert the source value to match the destination format
			second.value.(ConstantHandle).convert(first.format)
			second.format = SYSTEM_SIGNED

			# Example: mov r/[...], r/c
			return build(platform.all.MOVE, 0,
				InstructionParameter(first, flags_first, first_parameter_type),
				InstructionParameter(second, flags_second, HANDLE_REGISTER | HANDLE_CONSTANT)
			)
		}

		# Clone the source value, because it must not be affected by this move
		second_value = second.value.finalize() as ConstantHandle
		second_value.convert(first.format)
		second_value.format = SYSTEM_SIGNED

		second_parameter = Result(second_value, SYSTEM_SIGNED)

		# Example: mov r/[...], r/c
		build(platform.all.MOVE, 0,
			InstructionParameter(first, flags_first, first_parameter_type),
			InstructionParameter(second_parameter, flags_second, HANDLE_REGISTER | HANDLE_CONSTANT)
		)
	}

	on_build_decimal_conversion(flags_first, flags_second) {
		is_destination_media_register = first.is_media_register or (first.is_empty and first.format == FORMAT_DECIMAL)
		is_destination_register = first.is_standard_register or (first.is_empty and first.format != FORMAT_DECIMAL)
		is_destination_memory_address = first.is_memory_address
		is_source_constant = second.is_constant

		if is_destination_media_register {
			if is_source_constant {
				if second.value.(ConstantHandle).value == 0 return on_build_decimal_zero_move(flags_first, flags_second)

				build_decimal_constant_move_x64(flags_first, flags_second)
				return
			}

			# Examples: cvtsi2sd r, [...]
			build(platform.x64.CONVERT_INTEGER_TO_DOUBLE_PRECISION, SYSTEM_BYTES,
				InstructionParameter(first, flags_first, HANDLE_MEDIA_REGISTER),
				InstructionParameter(second, flags_second, HANDLE_REGISTER | HANDLE_MEMORY)
			)
		}
		else is_destination_register {
			if is_source_constant return on_build_constant_to_decimal_move(flags_first, flags_second, HANDLE_REGISTER)

			# Examples: cvttsd2si r, x/[...]
			build(platform.x64.CONVERT_DOUBLE_PRECISION_TO_INTEGER, SYSTEM_BYTES,
				InstructionParameter(first, flags_first, HANDLE_REGISTER),
				InstructionParameter(second, flags_second, HANDLE_MEDIA_REGISTER | HANDLE_MEMORY)
			)
		}
		else is_destination_memory_address {
			if is_source_constant return on_build_constant_to_decimal_move(flags_first, flags_second, HANDLE_MEMORY)

			if first.format != FORMAT_DECIMAL {
				# Load the value from memory into a register and use the system size, because if it is smaller than the destination value size, it might not be sign extended
				if second.is_memory_address memory.move_to_register(unit, second, SYSTEM_BYTES, false, trace.for(unit, second))

				# Example: mov [...], r
				return build(platform.all.MOVE, 0,
					InstructionParameter(first, flags_first, HANDLE_MEMORY),
					InstructionParameter(second, flags_second, HANDLE_REGISTER)
				)
			}

			# Example: movsd [...], x
			build(platform.x64.DOUBLE_PRECISION_MOVE, 0,
				InstructionParameter(first, flags_first, HANDLE_MEMORY),
				InstructionParameter(second, flags_second, HANDLE_MEDIA_REGISTER)
			)
		}
	}

	on_build_decimal_moves(flags_first, flags_second) {
		if first.format != second.format return on_build_decimal_conversion(flags_first, flags_second)

		# If the first operand can be a media register and the second is zero, special instructions can be used
		if (first.is_media_register or first.is_empty) and second.is_constant and second.value.(ConstantHandle).value == 0 {
			return on_build_decimal_zero_move(flags_first, flags_second)
		}

		if second.is_constant {
			if settings.is_x64 return build_decimal_constant_move_x64(flags_first, flags_second)

			# Move the source value into the data section so that it can be loaded into a media register
			second.value = NumberDataSectionHandle(second.value as ConstantHandle)
		}

		if first.is_memory_address {
			# Examples: movsd [...], x
			return build(platform.x64.DOUBLE_PRECISION_MOVE, 0,
				InstructionParameter(first, flags_first, HANDLE_MEMORY),
				InstructionParameter(second, flags_second, HANDLE_MEDIA_REGISTER)
			)
		}

		types = HANDLE_CONSTANT | HANDLE_MEDIA_REGISTER | HANDLE_MEMORY

		# Example: movsd x, x/[...]
		build(
			platform.x64.DOUBLE_PRECISION_MOVE, 0,
			InstructionParameter(first, flags_first, HANDLE_MEDIA_REGISTER),
			InstructionParameter(second, flags_second, types)
		)
	}

	on_build_x64(flags_first: large, flags_second: large): _ {
		if first.is_standard_register and second.is_constant and second.value.(ConstantHandle).value == 0 {
			# Example: xor r, r
			build(platform.x64.XOR, SYSTEM_BYTES, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(second, flags_second | FLAG_HIDDEN, HANDLE_CONSTANT))
		}
		else first.is_memory_address and not (first.is_data_section_handle and first.value.(DataSectionHandle).address) {
			if first.is_data_section_handle and first.value.(DataSectionHandle).address abort('Destination can not be an address value')

			# Prepare the destination handle, if it has a modifier
			if first.is_data_section_handle and first.value.(DataSectionHandle).modifier != DATA_SECTION_MODIFIER_NONE {
				# Save the data section handle offset
				offset = first.value.(DataSectionHandle).offset

				address = Result()
				memory.get_register_for(unit, address, true, false)

				# Example:
				# mov rax, [rip+x@GOTPCREL]
				# mov qword ptr [rax+8], 1
				build(
					platform.all.MOVE, 0,
					InstructionParameter(address, FLAG_DESTINATION | FLAG_RELOCATE_TO_DESTINATION | FLAG_WRITE_ACCESS, HANDLE_REGISTER),
					InstructionParameter(first, FLAG_NONE, HANDLE_MEMORY)
				)

				first.value = MemoryHandle(unit, address, offset)

				instruction = MoveInstruction(unit, first, second)
				instruction.type = type
				unit.add(instruction, true)
				return
			}
			
			# Load the value from memory into a register and use the system size, because if it is smaller than the destination value size, it might not be sign extended
			if second.is_memory_address memory.move_to_register(unit, second, SYSTEM_BYTES, false, trace.for(unit, second))

			# Examples: mov [...], c / mov [...], r
			build(platform.all.MOVE, first.size, InstructionParameter(first, flags_first, HANDLE_MEMORY), InstructionParameter(second, flags_second, HANDLE_CONSTANT | HANDLE_REGISTER))
		}
		else second.is_data_section_handle and second.value.(DataSectionHandle).address {
			# Disable the address flag while building
			second.value.(DataSectionHandle).address = false
			# Example: lea r, [...]
			build(platform.x64.EVALUATE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_MEMORY))
			second.value.(DataSectionHandle).address = true
			return
		}
		else second.is_expression {
			# Examples: lea r, [...]
			build(platform.x64.EVALUATE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_EXPRESSION))
		}
		else second.is_memory_address {
			# Examples: mov r, c / mov r, r / mov r, [...]
			build(platform.all.MOVE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
		}
		else {
			# Examples: mov r, c / mov r, r
			build(platform.all.MOVE, 0, InstructionParameter(first, flags_first, HANDLE_REGISTER), InstructionParameter(second, flags_second | FLAG_BIT_LIMIT_64, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
		}
	}

	override on_build() {
		result.format = first.format
		if is_redundant return

		# Ensure the destination is available, if it is a register and the safe flag is enabled
		if is_destination_protected and first.is_any_register memory.clear_register(unit, first.register)

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

		if not is_destination_protected { flags_first = flags_first | FLAG_WRITE_ACCESS }

		if type == MOVE_LOAD { flags_first = flags_first | FLAG_ATTACH_TO_DESTINATION }
		else type == MOVE_RELOCATE { flags_second = flags_second | FLAG_ATTACH_TO_DESTINATION | FLAG_RELOCATE_TO_DESTINATION }

		# Handle decimal moves separately
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL return on_build_decimal_moves(flags_first, flags_second)

		on_build_x64(flags_first, flags_second)
	}

	is_move_instruction_x64(): bool {
		if operation === none return false
		return operation == platform.all.MOVE or operation == platform.x64.UNSIGNED_CONVERSION_MOVE or operation == platform.x64.SIGNED_CONVERSION_MOVE or operation == platform.x64.SIGNED_DWORD_CONVERSION_MOVE
	}

	on_post_build_x64(): _ {
		# Skip decimal formats, since they are correct by default
		if destination.value.format == FORMAT_DECIMAL or source.value.format == FORMAT_DECIMAL or not is_move_instruction_x64() return

		is_source_memory_address = source.value != none and source.value.type == HANDLE_MEMORY
		is_destination_memory_address = destination.value != none and destination.value.type == HANDLE_MEMORY

		if is_destination_memory_address and not is_source_memory_address {
			source.value.format = destination.value.format
			return
		}

		# Return if no conversion is needed
		if source.value.size == destination.value.size or source.value.type == HANDLE_CONSTANT {
			operation = String(platform.all.MOVE)
			return
		}

		# NOTE: Now the destination parameter must be a register
		if source.value.size > destination.value.size {
			source.value.format = destination.value.format
			return
		}

		# NOTE: Now the size of source operand must be less than the size of destination operand
		if destination.value.unsigned {
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
			operation = String(platform.x64.UNSIGNED_CONVERSION_MOVE)
			return
		}

		if destination.value.size == 8 and source.value.size == 4 {
			# movsxd rax, ebx (64 <- 32)
			operation = String(platform.x64.SIGNED_DWORD_CONVERSION_MOVE)
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
		operation = String(platform.x64.SIGNED_CONVERSION_MOVE)
	}

	override on_post_build() {
		if settings.is_x64 on_post_build_x64()
	}
}

Instruction GetConstantInstruction {
	value: large
	format: large

	init(unit: Unit, value: large, unsigned: bool, is_decimal: bool) {
		Instruction.init(unit, INSTRUCTION_GET_CONSTANT)
		
		this.value = value
		this.is_abstract = true

		if is_decimal {
			this.format = FORMAT_DECIMAL
			this.description = "Load constant " + to_string(bits_to_decimal(value))
		}
		else {
			this.format = get_system_format(unsigned)
			this.description = "Load constant " + to_string(value)
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
		this.description = "Load variable " + variable.name

		result.value = references.create_variable_handle(unit, variable, mode)
		result.format = variable.type.format
	}

	override on_build() {
		# TODO: Add trace check?
		# If the result represents a static variable, it might be needed to load it into a register
		if variable.is_static and mode == ACCESS_READ {
			memory.move_to_register(unit, result, SYSTEM_BYTES, result.format == FORMAT_DECIMAL, trace.for(unit, result))
		}
	}
}

# Summary:
# Initializes the functions by handling the stack properly
# This instruction works on all architectures
Instruction InitializeInstruction {
	local_memory_top: large

	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_INITIALIZE)
	}

	get_required_call_memory(call_instructions: List<CallInstruction>): large {
		if call_instructions.size == 0 return 0

		# Find all parameter move instructions which move the source value into memory and determine the maximum offset used in them
		max_parameter_memory_offset = -1

		loop call in call_instructions {
			loop destination in call.destinations {
				if destination.type != HANDLE_MEMORY continue
				
				offset = destination.(MemoryHandle).offset
				if offset > max_parameter_memory_offset { max_parameter_memory_offset = offset }
			}
		}

		# Call parameter offsets are always positive, so if the maximum offset is negative, it means that there are no parameters
		if max_parameter_memory_offset < 0 {
			# Even though no instruction writes to memory, on Windows there is a requirement to allocate so called 'shadow space' for the first four parameters
			if settings.is_target_windows return calls.SHADOW_SPACE_SIZE
			return 0
		}

		return max_parameter_memory_offset + SYSTEM_BYTES
	}

	save_registers_x64(builder: StringBuilder, registers: List<Register>): _ {
		# Save all used non-volatile registers
		loop register in registers {
			builder.append(platform.x64.PUSH)
			builder.append(` `)
			builder.append_line(register[SYSTEM_BYTES])
			unit.stack_offset += SYSTEM_BYTES
		}
	}

	save_registers_arm64(builder: StringBuilder, registers: List<Register>) {}

	build(save_registers: List<Register>, required_local_memory: large): _ {
		# Collect all normal call instructions
		call_instructions = List<CallInstruction>()

		loop instruction in unit.instructions {
			if instruction.type != INSTRUCTION_CALL or instruction.(CallInstruction).is_tail_call continue
			call_instructions.add(instruction as CallInstruction)
		}

		builder = StringBuilder()

		if settings.is_debugging_enabled {
			builder.append(`.`)
			builder.append(AssemblyParser.DEBUG_START_DIRECTIVE)
			builder.append(` `)
			builder.append_line(unit.function.get_fullname())
			builder.append_line(DebugBreakInstruction.get_position_instruction(unit.function.metadata.start))
		}

		if not settings.is_x64 and call_instructions.size > 0 save_registers.add(unit.get_return_address_register())

		# Save all used non-volatile registers
		if settings.is_x64 { save_registers_x64(builder, save_registers) }
		else { save_registers_arm64(builder, save_registers) }

		# Local variables in memory start now
		local_memory_top = unit.stack_offset

		# Apply the required memory for local variables
		additional_memory = required_local_memory

		# Allocate memory for calls
		additional_memory += get_required_call_memory(call_instructions)

		# Apply the additional memory to the stack and calculate the change from the start
		unit.stack_offset += additional_memory

		# Align the stack:

		# If there are calls, it means they will also push the return address to the stack, which must be taken into account when aligning the stack
		total = unit.stack_offset
		if settings.is_x64 and call_instructions.size > 0 { total += SYSTEM_BYTES }

		if total != 0 and total % calls.STACK_ALIGNMENT != 0 {
			# Apply padding to the memory to make it aligned
			padding = calls.STACK_ALIGNMENT - (total % calls.STACK_ALIGNMENT)

			unit.stack_offset += padding
			additional_memory += padding
		}

		# Verify the size of the allocated stack memory does not exceed the maximum signed 32-bit integer
		require(additional_memory <= NORMAL_MAX, "Function allocates too much stack memory at " + unit.function.metadata.start.string())

		if additional_memory > 0 {
			stack_pointer = unit.get_stack_pointer()

			if settings.is_x64 {
				builder.append(platform.all.SUBTRACT)
				builder.append(` `)
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', ')
				builder.append_line(additional_memory)
			}
			else {
				builder.append(platform.all.SUBTRACT)
				builder.append(` `)
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', ')
				builder.append(stack_pointer[SYSTEM_BYTES])
				builder.append(', #')
				builder.append_line(additional_memory)
			}
		}

		# When debugging mode is enabled, the current stack pointer should be saved to the base pointer
		if settings.is_debugging_enabled {
			builder.append(`.`)
			builder.append(AssemblyParser.DEBUG_FRAME_OFFSET_DIRECTIVE)
			builder.append(` `)
			builder.append_line(unit.stack_offset + SYSTEM_BYTES)
		}

		# If the builder ends with a line ending, remove it
		if builder.length > 0 and builder[builder.length - 1] == `\n` {
			builder.remove(builder.length - 1, builder.length)
		}

		Instruction.build(builder.string())
	}
}

Instruction SetVariableInstruction {
	variable: Variable
	value: Result
	is_copied: bool

	init(unit: Unit, variable: Variable, value: Result) {
		Instruction.init(unit, INSTRUCTION_SET_VARIABLE)
		require(variable.is_predictable, 'Setting value for unpredictable variables is not allowed')

		this.variable = variable
		this.value = value
		this.dependencies.add(value)
		this.description = "Updates the value of the variable " + variable.name
		this.is_abstract = true
		this.result.format = variable.type.get_register_format()

		# If the value represents another variable or is a constant, it must be copied
		this.is_copied = unit.is_variable_value(value) or value.is_constant

		if is_copied {
			unit.set_variable_value(variable, result)
			return
		}

		unit.set_variable_value(variable, value)
	}

	copy_value(): _ {
		format = variable.type.get_register_format()
		register = memory.get_next_register_without_releasing(unit, format == FORMAT_DECIMAL, trace.for(unit, result))

		if register !== none {
			result.value = RegisterHandle(register)
			result.format = format

			# Attach the result to the register
			register.value = result
		}
		else {
			result.value = references.create_variable_handle(unit, variable, ACCESS_WRITE)
			result.format = variable.type.format
		}

		# Copy the value to the result of this instruction
		instruction = MoveInstruction(unit, result, value)
		instruction.type = MOVE_LOAD
		unit.add(instruction)
	}

	override on_build() {
		# If the value represents another variable or is a constant, it must be copied
		if is_copied {
			copy_value()

			unit.set_variable_value(variable, result)
			return
		}

		unit.set_variable_value(variable, value)
	}
}

# Summary:
# The instruction calls the specified value (for example function label or a register).
# This instruction works on all architectures
Instruction CallInstruction {
	function: Result
	return_type: Type
	return_pack: DisposablePackHandle = none

	# Represents the destination handles where the required parameters are passed to
	destinations: List<Handle> = List<Handle>()

	# This call is a tail call if it uses a jump instruction
	is_tail_call => operation == platform.x64.JUMP or operation == platform.arm64.JUMP_LABEL or operation == platform.arm64.JUMP_REGISTER

	init(unit: Unit, function: String, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_CALL)
		
		# Support position independent code
		handle = DataSectionHandle(function, true)
		if settings.use_indirect_access_tables { handle.modifier = DATA_SECTION_MODIFIER_PROCEDURE_LINKAGE_TABLE }

		this.function = Result(handle, SYSTEM_FORMAT)
		this.return_type = return_type
		this.dependencies.add(this.function)
		this.description = "Calls function " + function
		this.is_usage_analyzed = false # NOTE: Fixes an issue where the build system moves the function handle to volatile register even though it is needed later

		if return_type != none {
			this.result.format = return_type.format
		}
		else {
			this.result.format = SYSTEM_FORMAT
		}

		# Initialize the return pack, if the return type is a pack
		if return_type != none and return_type.is_pack {
			this.return_pack = DisposablePackHandle(unit, return_type)
			this.result.value = return_pack
		}
	}

	init(unit: Unit, function: Result, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_CALL)

		this.function = function
		this.return_type = return_type
		this.dependencies.add(this.function)
		this.description = "Calls the function handle"
		this.is_usage_analyzed = false # NOTE: Fixes an issue where the build system moves the function handle to volatile register even though it is needed later

		if return_type != none {
			this.result.format = return_type.format
		}
		else {
			this.result.format = SYSTEM_FORMAT
		}

		# Initialize the return pack, if the return type is a pack
		if return_type != none and return_type.is_pack {
			this.return_pack = DisposablePackHandle(unit, return_type)
			this.result.value = return_pack
		}
	}

	# Summary: Iterates through the volatile registers and ensures that they do not contain any important values which are needed later
	validate_evacuation(): _ {
		loop register in unit.volatile_registers {
			# NOTE: The availability of the register is not checked the standard way since they are usually locked at this stage
			if register.value == none or not register.value.is_active or register.value.is_deactivating() or register.is_value_copy() continue
			abort('Register evacuation failed')
		}
	}

	# Summary: Prepares the memory handle for use by relocating its inner handles into registers, therefore its use does not require additional steps, except if it is in invalid format
	# Returns: Returns a list of register locks which must be active while the handle is in use
	validate_memory_handle(handle: Handle): List<Register> {
		results = handle.get_register_dependent_results()
		locked = List<Register>()

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
			instruction.description = "Validates a call memory handle"
			instruction.type = MOVE_RELOCATE

			unit.add(instruction)
			locked.add(iterator.register)
		}

		return locked
	}

	output_pack(standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, position: StackMemoryHandle, disposable_pack: DisposablePackHandle): _ {
		loop iterator in disposable_pack.members {
			member = iterator.value.member
			value = iterator.value.value

			if member.type.is_pack {
				output_pack(standard_parameter_registers, decimal_parameter_registers, position, value.value as DisposablePackHandle)
				continue
			}

			register = none as Register

			if member.type.format == FORMAT_DECIMAL {
				register = decimal_parameter_registers.pop_or(none as Register)
			}
			else {
				register = standard_parameter_registers.pop_or(none as Register)
			}

			if register != none {
				value.value = RegisterHandle(register)
				value.format = member.type.get_register_format()
				register.value = value
			}
			else {
				value.value = position.finalize()
				value.format = member.type.get_register_format()
				position.offset += SYSTEM_BYTES
			}
		}
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
			if function.size != SYSTEM_BYTES {
				loop register in locked { register.unlock() }

				memory.move_to_register(unit, function, SYSTEM_BYTES, false, trace.for(unit, function))
				locked.add(function.register)
			}

			# Now evacuate all the volatile registers before the call
			unit.add(EvacuateInstruction(unit))

			# If the format of the function handle changes, it means its format is registered incorrectly somewhere
			if function.size != SYSTEM_BYTES abort('Invalid function handle format')

			build(platform.x64.CALL, 0, InstructionParameter(function, FLAG_BIT_LIMIT_64 | FLAG_ALLOW_ADDRESS, HANDLE_REGISTER | HANDLE_MEMORY))
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

		if return_pack != none {
			result.value = return_pack

			decimal_parameter_registers = calls.get_decimal_parameter_registers(unit)
			standard_parameter_registers = calls.get_standard_parameter_registers(unit)

			position = StackMemoryHandle(unit, 0, false)
			output_pack(standard_parameter_registers, decimal_parameter_registers, position, return_pack)
			return
		}

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
	return_type: Type
	extracted: bool = false

	init(unit: Unit, destinations: List<Handle>, sources: List<Result>, return_type: Type) {
		Instruction.init(unit, INSTRUCTION_REORDER)
		this.dependencies = none
		this.destinations = destinations
		this.formats = List<large>(destinations.size, false)
		this.return_type = return_type
		this.sources = sources

		loop iterator in destinations { formats.add(iterator.format) }
	}

	# Summary: Returns how many bytes of the specified type are returned using the stack
	compute_return_overflow(type: Type, overflow: large, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>): large {
		loop iterator in type.variables {
			member = iterator.value

			if member.type.is_pack {
				overflow = compute_return_overflow(member.type, overflow, standard_parameter_registers, decimal_parameter_registers)
				continue
			}

			# First, drain out the registers
			register = none as Register

			if member.type.format == FORMAT_DECIMAL {
				register = decimal_parameter_registers.pop_or(none as Register)
			}
			else {
				register = standard_parameter_registers.pop_or(none as Register)
			}

			if register != none continue
			overflow += SYSTEM_BYTES
		}

		return overflow
	}

	# Summary: Returns how many bytes of the specified type are returned using the stack
	compute_return_overflow(type: Type): large {
		decimal_parameter_registers = calls.get_decimal_parameter_registers(unit)
		standard_parameter_registers = calls.get_standard_parameter_registers(unit)

		return compute_return_overflow(type, 0, decimal_parameter_registers, standard_parameter_registers)
	}

	# Summary: Evacuates variables that are located at the overflow zone of the stack
	evacuate_overflow_zone(type: Type): _ {
		shadow_space_size = 0
		if settings.is_target_windows { shadow_space_size = calls.SHADOW_SPACE_SIZE }
		overflow = max(compute_return_overflow(type), shadow_space_size)

		loop iterator in unit.scope.variables {
			# Find all memory handles
			value = iterator.value
			instance: large = value.value.instance
			if instance != INSTANCE_STACK_MEMORY and instance != INSTANCE_TEMPORARY_MEMORY and instance != INSTANCE_MEMORY continue

			memory_handle = value.value as MemoryHandle

			# Ensure the memory address represents a stack address
			start = memory_handle.get_start()
			if start == none or start != unit.get_stack_pointer() continue

			# Ensure the memory address overlaps with the overflow
			offset = memory_handle.get_absolute_offset()
			if offset < 0 or offset >= overflow continue

			variable = iterator.key

			# Try to get an available non-volatile register
			destination = none as Handle
			destination_format = 0
			register = memory.get_next_register_without_releasing(unit, variable.type.format == FORMAT_DECIMAL, trace.for(unit, value))

			# Use the non-volatile register, if one was found
			if register != none {
				destination = RegisterHandle(register)
				destination_format = variable.type.get_register_format()
			}
			else {
				# Since there are no non-volatile registers available, the value must be relocated to safe stack location
				destination = references.create_variable_handle(unit, variable, ACCESS_WRITE)
				destination_format = variable.type.format
			}

			instruction = MoveInstruction(unit, Result(destination, destination_format), value)
			instruction.description = "Evacuate overflow"
			instruction.type = MOVE_RELOCATE
			unit.add(instruction)
		}
	}

	override on_build() {
		if return_type != none evacuate_overflow_zone(return_type)

		instructions = List<MoveInstruction>()

		loop (i = 0, i < destinations.size, i++) {
			source = sources[i]
			destination = Result(destinations[i], formats[i])

			instruction = MoveInstruction(unit, destination, source)
			instruction.is_destination_protected = true
			instructions.add(instruction)
		}

		memory.align(unit, instructions)
		extracted = true
	}

	override get_dependencies() {
		if extracted return List<Result>()
		return sources
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
		build(platform.x64.EXCHANGE, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_RELOCATE_TO_SOURCE | FLAG_READS | FLAG_WRITE_ACCESS, HANDLE_REGISTER), InstructionParameter(second, FLAG_SOURCE | FLAG_RELOCATE_TO_DESTINATION | FLAG_WRITES | FLAG_READS, HANDLE_REGISTER))
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
		
		if is_locked { description = "Locks a register" }
		else { description = "Unlocks a register" }

		register.is_locked = is_locked
	}

	override on_build() {
		register.is_locked = is_locked
	}
}

# Summary:
# Ensures that variables and values which are required later are moved to locations which are not affected by call instructions for example
# This instruction works on all architectures
Instruction EvacuateInstruction {
	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_EVACUATE)
		this.is_abstract = true
	}

	override on_build() {
		loop {
			evacuated = false

			# Save all important values in the standard volatile registers
			loop register in unit.volatile_registers {
				# Skip values which are not needed after the call instruction
				# NOTE: The availability of the register is not checked the standard way since they are usually locked at this stage
				if register.value == none or not register.value.is_active or register.value.is_deactivating or register.is_value_copy continue

				evacuated = true

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

				instruction = MoveInstruction(unit, Result(destination, register.value.format), register.value)
				instruction.description = "Evacuates a value"
				instruction.type = MOVE_RELOCATE

				unit.add(instruction)
			}

			if not evacuated stop
		}
	}
}

Instruction GetObjectPointerInstruction {
	variable: Variable
	start: Result
	offset: large
	mode: large
	return_pack: DisposablePackHandle = none

	init(unit: Unit, variable: Variable, start: Result, offset: large, mode: large) {
		Instruction.init(unit, INSTRUCTION_GET_OBJECT_POINTER)
		this.variable = variable
		this.start = start
		this.offset = offset
		this.mode = mode
		this.is_abstract = true
		this.dependencies.add(start)
		this.result.format = variable.type.format

		if variable.type.is_pack {
			return_pack = DisposablePackHandle(unit, variable.type)

			output_pack(return_pack, 0)

			result.value = return_pack
			result.format = SYSTEM_FORMAT
			return
		}
	}

	output_pack(disposable_pack: DisposablePackHandle, position: large): large {
		loop iterator in disposable_pack.members {
			member = iterator.value.member
			value = iterator.value.value

			if member.type.is_pack {
				# Output the members of the nested pack using this function recursively
				position = output_pack(value.value as DisposablePackHandle, position)
				continue
			}

			# Update the format of the pack member
			value.format = member.type.format

			if mode == ACCESS_WRITE {
				# Since we are in write mode, we need to output a memory address for the pack member
				value.value = MemoryHandle(unit, start, offset + position)
			}
			else {
				# 1. Ensure we are in build mode, so we can use registers
				# 2. Ensure the pack member is used, so we do not move it to a register unnecessarily
				if unit.mode == UNIT_MODE_BUILD and not value.is_deactivating {
					if member.is_inlined() {
						value.value = ExpressionHandle.create_memory_address(start, offset + position)
					}
					else {
						# Since we are in build mode and the member is required, we need to output a register value
						value.value = MemoryHandle(unit, start, offset + position)
						memory.move_to_register(unit, value, to_bytes(value.format), value.format == FORMAT_DECIMAL, trace.for(unit, value))
					}
				}
				else {
					value.value = Handle()
				}
			}

			position += member.type.allocation_size
		}

		return position
	}

	validate_handle(): _ {
		# Ensure the start value is a constant or in a register
		if not start.is_constant and not start.is_stack_allocation and not start.is_standard_register {
			memory.move_to_register(unit, start, SYSTEM_BYTES, false, trace.for(unit, start))
		}
	}

	override on_build() {
		validate_handle()

		if return_pack != none {
			output_pack(return_pack, 0)
			result.value = return_pack
			result.format = SYSTEM_FORMAT
			return
		}

		if variable.is_inlined() {
			result.value = ExpressionHandle.create_memory_address(start, offset)
			result.format = variable.type.format
			return
		}

		if mode != ACCESS_READ and not trace.is_loading_required(unit, result) {
			result.value = MemoryHandle(unit, start, offset)
			result.format = variable.type.format
			return
		}

		if mode == ACCESS_READ {
			result.value = MemoryHandle(unit, start, offset)
			result.format = variable.type.format

			memory.move_to_register(unit, result, SYSTEM_BYTES, variable.type.get_register_format() == FORMAT_DECIMAL, trace.for(unit, result))
		}
		else {
			address = Result(ExpressionHandle.create_memory_address(start, offset), SYSTEM_FORMAT)
			memory.move_to_register(unit, address, SYSTEM_BYTES, false, trace.for(unit, result))

			result.value = MemoryHandle(unit, address, 0)
			result.format = variable.type.format
		}
	}
}

Instruction GetMemoryAddressInstruction {
	format: large
	start: Result
	offset: Result
	stride: large
	mode: large
	return_pack: DisposablePackHandle = none

	init(unit: Unit, type: Type, format: large, start: Result, offset: Result, stride: large, mode: large) {
		Instruction.init(unit, INSTRUCTION_GET_MEMORY_ADDRESS)
		this.start = start
		this.offset = offset
		this.stride = stride
		this.format = format
		this.mode = mode
		this.is_abstract = true
		this.dependencies.add(start)
		this.dependencies.add(offset)

		if type.is_pack {
			return_pack = DisposablePackHandle(unit, type)

			output_pack(return_pack, 0)

			result.value = return_pack
			result.format = SYSTEM_FORMAT
			return
		}
	}

	output_pack(disposable_pack: DisposablePackHandle, position: large): large {
		loop iterator in disposable_pack.members {
			member = iterator.value.member
			value = iterator.value.value

			if member.type.is_pack {
				# Output the members of the nested pack using this function recursively
				position = output_pack(value.value as DisposablePackHandle, position)
				continue
			}

			# Update the format of the pack member
			value.format = member.type.format

			if mode == ACCESS_WRITE {
				# Since we are in write mode, we need to output a memory address for the pack member
				value.value = ComplexMemoryHandle(start, offset, stride, position)
			}
			else {
				# 1. Ensure we are in build mode, so we can use registers
				# 2. Ensure the pack member is used, so we do not move it to a register unnecessarily
				if unit.mode == UNIT_MODE_BUILD and not value.is_deactivating {
					if member.is_inlined() {
						value.value = ExpressionHandle(offset, stride, start, position)
					}
					else {
						# Since we are in build mode and the member is required, we need to output a register value
						value.value = ComplexMemoryHandle(start, offset, stride, position)
						memory.move_to_register(unit, value, to_bytes(value.format), value.format == FORMAT_DECIMAL, trace.for(unit, value))
					}
				}
				else {
					value.value = Handle()
				}
			}

			position += member.type.allocation_size
		}

		return position
	}

	validate_handle(): _ {
		# Ensure the start value is a constant or in a register
		if start.is_constant or start.is_stack_allocation or start.is_standard_register return
		memory.move_to_register(unit, start, SYSTEM_BYTES, false, trace.for(unit, start))
	}

	override on_build() {
		validate_handle()

		if return_pack != none {
			output_pack(return_pack, 0)
			result.value = return_pack
			result.format = SYSTEM_FORMAT
			return
		}

		#warning Improve this
		if mode != ACCESS_READ and not trace.is_loading_required(unit, result) {
			result.value = ComplexMemoryHandle(start, offset, stride, 0)
			result.format = format
			return
		}

		if mode == ACCESS_READ {
			result.value = ComplexMemoryHandle(start, offset, stride, 0)
			result.format = format

			memory.move_to_register(unit, result, SYSTEM_BYTES, format == FORMAT_DECIMAL, trace.for(unit, result))
		}
		else {
			address = Result(ExpressionHandle.create_memory_address(start, offset, stride), SYSTEM_FORMAT)
			memory.move_to_register(unit, address, SYSTEM_BYTES, false, trace.for(unit, result))

			result.value = MemoryHandle(unit, address, 0)
			result.format = format
		}
	}
}

Instruction TemporaryInstruction {
	init(unit: Unit, type: large) {
		Instruction.init(unit, type)
	}

	override on_build() { abort('Tried to build a temporary instruction') }
	override on_post_build() { abort('Tried to build a temporary instruction') }
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
	shared jumps: Map<ComparisonOperator, JumpOperatorBinding>

	shared initialize(): _ {
		jumps = Map<ComparisonOperator, JumpOperatorBinding>()

		if settings.is_x64 {
			jumps.add(Operators.GREATER_THAN,        JumpOperatorBinding(platform.x64.JUMP_GREATER_THAN,           platform.x64.JUMP_ABOVE))
			jumps.add(Operators.GREATER_OR_EQUAL,    JumpOperatorBinding(platform.x64.JUMP_GREATER_THAN_OR_EQUALS, platform.x64.JUMP_ABOVE_OR_EQUALS))
			jumps.add(Operators.LESS_THAN,           JumpOperatorBinding(platform.x64.JUMP_LESS_THAN,              platform.x64.JUMP_BELOW))
			jumps.add(Operators.LESS_OR_EQUAL,       JumpOperatorBinding(platform.x64.JUMP_LESS_THAN_OR_EQUALS,    platform.x64.JUMP_BELOW_OR_EQUALS))
			jumps.add(Operators.EQUALS,              JumpOperatorBinding(platform.x64.JUMP_EQUALS,                 platform.x64.JUMP_ZERO))
			jumps.add(Operators.NOT_EQUALS,          JumpOperatorBinding(platform.x64.JUMP_NOT_EQUALS,             platform.x64.JUMP_NOT_ZERO))
			jumps.add(Operators.ABSOLUTE_EQUALS,     JumpOperatorBinding(platform.x64.JUMP_EQUALS,                 platform.x64.JUMP_ZERO))
			jumps.add(Operators.ABSOLUTE_NOT_EQUALS, JumpOperatorBinding(platform.x64.JUMP_NOT_EQUALS,             platform.x64.JUMP_NOT_ZERO))
			return
		}

		#jumps.add(Operators.GREATER_THAN,        JumpOperatorBinding(platform.arm64.JUMP_GREATER_THAN,           platform.arm64.JUMP_GREATER_THAN))
		#jumps.add(Operators.GREATER_OR_EQUAL,    JumpOperatorBinding(platform.arm64.JUMP_GREATER_THAN_OR_EQUALS, platform.arm64.JUMP_GREATER_THAN_OR_EQUALS))
		#jumps.add(Operators.LESS_THAN,           JumpOperatorBinding(platform.arm64.JUMP_LESS_THAN,              platform.arm64.JUMP_LESS_THAN))
		#jumps.add(Operators.LESS_OR_EQUAL,       JumpOperatorBinding(platform.arm64.JUMP_LESS_THAN_OR_EQUALS,    platform.arm64.JUMP_LESS_THAN_OR_EQUALS))
		#jumps.add(Operators.EQUALS,              JumpOperatorBinding(platform.arm64.JUMP_EQUALS,                 platform.arm64.JUMP_EQUALS))
		#jumps.add(Operators.NOT_EQUALS,          JumpOperatorBinding(platform.arm64.JUMP_NOT_EQUALS,             platform.arm64.JUMP_NOT_EQUALS))
		#jumps.add(Operators.ABSOLUTE_EQUALS,     JumpOperatorBinding(platform.arm64.JUMP_EQUALS,                 platform.arm64.JUMP_EQUALS))
		#jumps.add(Operators.ABSOLUTE_NOT_EQUALS, JumpOperatorBinding(platform.arm64.JUMP_NOT_EQUALS,             platform.arm64.JUMP_NOT_EQUALS))
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

	invert(): _ {
		this.comparator = comparator.counterpart
	}

	override on_build() {
		instruction = none as link

		if comparator == none {
			if settings.is_x64 { instruction = platform.x64.JUMP }
		}
		else is_signed {
			instruction = jumps[comparator].signed
		}
		else not is_signed {
			instruction = jumps[comparator].unsigned
		}

		result.value = DataSectionHandle(label.name, true)
		result.format = SYSTEM_FORMAT

		build(instruction, 0, InstructionParameter(result, FLAG_BIT_LIMIT_64 | FLAG_ALLOW_ADDRESS, HANDLE_MEMORY))
	}
}

# Summary:
# This instruction compares the two specified values together and alters the CPU flags based on the comparison
# This instruction works on all architectures
DualParameterInstruction CompareInstruction {
	init(unit: Unit, first: Result, second: Result) {
		DualParameterInstruction.init(unit, first, second, SYSTEM_FORMAT, INSTRUCTION_COMPARE)
		this.description = "Compares two operands"
	}

	on_build_x64(): _ {
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			return build(platform.x64.DOUBLE_PRECISION_COMPARE, 0,
				InstructionParameter(first, FLAG_NONE, HANDLE_MEDIA_REGISTER),
				InstructionParameter(second, FLAG_NONE, HANDLE_MEDIA_REGISTER)
			)
		}

		if second.is_constant and second.value.(ConstantHandle).value == 0 {
			# Example: test r, r
			return build(platform.x64.TEST, first.size, InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER))
		}

		# Example: cmp r, c/r/[...]
		build(platform.all.COMPARE, min(first.size, second.size), InstructionParameter(first, FLAG_NONE, HANDLE_REGISTER), InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY))
	}

	override on_build() {
		if settings.is_x64 return on_build_x64()
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
# This instruction works on all architectures
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
	correct_numerator_location(): Result {
		numerator = unit.get_numerator_register()
		remainder = unit.get_remainder_register()

		destination = RegisterHandle(numerator)

		if not first.value.equals(destination) {
			remainder.lock()
			memory.clear_register(unit, destination.register)
			remainder.unlock()

			if assigns and not first.is_memory_address {
				instruction = MoveInstruction(unit, Result(destination, get_system_format(unsigned)), first)
				instruction.type = MOVE_RELOCATE
				unit.add(instruction)
				return first
			}

			instruction = MoveInstruction(unit, Result(destination, get_system_format(unsigned)), first)
			instruction.type = MOVE_COPY
			return instruction.add()
		}
		else not assigns {
			if not first.is_deactivating memory.clear_register(unit, destination.register)
			return Result(destination, get_system_format(unsigned))
		}

		return first
	}

	# Summary: Ensures the remainder register is ready for division or modulus operation
	prepare_remainder_register(): _ {
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
	build_modulus(numerator: Result): _ {
		remainder = RegisterHandle(unit.get_remainder_register())

		flags = FLAG_WRITE_ACCESS | FLAG_HIDDEN | FLAG_WRITES | FLAG_READS | FLAG_LOCKED
		if assigns { flags = flags | FLAG_RELOCATE_TO_DESTINATION }

		instruction = platform.x64.SIGNED_DIVIDE
		if unsigned { instruction = platform.x64.UNSIGNED_DIVIDE }

		# Example: idiv/div r, r/[...]
		build(
			instruction, SYSTEM_BYTES,
			InstructionParameter(numerator, flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_REGISTER | HANDLE_MEMORY),
			InstructionParameter(Result(remainder, get_system_format(unsigned)), flags | FLAG_DESTINATION, HANDLE_REGISTER)
		)
	}

	# Summary: Builds a division operation
	build_division(numerator: Result): _ {
		remainder = RegisterHandle(unit.get_remainder_register())
		flags = FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_HIDDEN | FLAG_READS | FLAG_LOCKED
		if assigns { flags = flags | FLAG_NO_ATTACH }

		instruction = platform.x64.SIGNED_DIVIDE
		if unsigned { instruction = platform.x64.UNSIGNED_DIVIDE }

		# Example: idiv/div r, r/[...]
		build(instruction, SYSTEM_BYTES,
			InstructionParameter(numerator, flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_REGISTER | HANDLE_MEMORY),
			InstructionParameter(Result(remainder, get_system_format(unsigned)), FLAG_HIDDEN | FLAG_LOCKED | FLAG_WRITES, HANDLE_REGISTER)
		)
	}

	# Summary: Tries to express the current instructions as a division instruction where the divisor is a constant
	try_get_constant_division(): ConstantDivision {
		if second.is_constant and second.format != FORMAT_DECIMAL return ConstantDivision(first, second)
		return none as ConstantDivision
	}

	on_build_x64(): _ {
		# Handle decimal division separately
		if first.format == FORMAT_DECIMAL or second.format == FORMAT_DECIMAL {
			flags = FLAG_NONE
			if unsigned { flags = FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

			operand = memory.load_operand(unit, first, true, assigns)

			types = HANDLE_MEDIA_REGISTER
			if second.format == FORMAT_DECIMAL { types = HANDLE_MEDIA_REGISTER | HANDLE_MEMORY }

			build(platform.x64.DOUBLE_PRECISION_DIVIDE, 0, InstructionParameter(operand, FLAG_DESTINATION | FLAG_READS | flags, HANDLE_MEDIA_REGISTER), InstructionParameter(second, FLAG_NONE, types))
			return
		}

		if not modulus {
			division = try_get_constant_division()

			if division != none and common.is_power_of_two(division.number) and division.number != 0 {
				count = ConstantHandle(common.integer_log2(division.number))

				flags = FLAG_NONE
				if assigns { flags = FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

				instruction = platform.x64.SHIFT_RIGHT
				if unsigned { instruction = platform.x64.SHIFT_RIGHT_UNSIGNED }

				operand = memory.load_operand(unit, division.dividend, false, assigns)

				# Example: sar r, c
				return build(instruction, SYSTEM_BYTES,
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
		# Assign the result after this instruction, if the destination is a memory address
		if assigns and first.is_memory_address {
			unit.add(MoveInstruction(unit, first, result), true)
		}

		if settings.is_x64 return on_build_x64()
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
			platform.x64.EXTEND_QWORD,
			0,
			InstructionParameter(Result(remainder, SYSTEM_FORMAT), FLAG_DESTINATION | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH | FLAG_HIDDEN | FLAG_LOCKED, HANDLE_REGISTER),
			InstructionParameter(Result(numerator, SYSTEM_FORMAT), FLAG_HIDDEN | FLAG_LOCKED, HANDLE_REGISTER)
		)
	}
}

DualParameterInstruction BitwiseInstruction {
	instruction: String
	assigns: bool

	shared create_and(unit: Unit, first: Result, second: Result, format: large, assigns: bool): BitwiseInstruction {
		return BitwiseInstruction(unit, platform.all.AND, first, second, format, assigns)
	}

	shared create_xor(unit: Unit, first: Result, second: Result, format: large, assigns: bool): BitwiseInstruction {
		if settings.is_x64 {
			if format == FORMAT_DECIMAL return BitwiseInstruction(unit, platform.x64.DOUBLE_PRECISION_XOR, first, second, format, assigns)
			return BitwiseInstruction(unit, platform.x64.XOR, first, second, format, assigns)
		}
	}

	shared create_or(unit: Unit, first: Result, second: Result, format: large, assigns: bool): BitwiseInstruction {
		if settings.is_x64 return BitwiseInstruction(unit, platform.x64.OR, first, second, format, assigns)
	}

	shared create_shift_left(unit: Unit, first: Result, second: Result, format: large): BitwiseInstruction {
		if settings.is_x64 return BitwiseInstruction(unit, platform.x64.SHIFT_LEFT, first, second, format, false)
	}

	shared create_shift_right(unit: Unit, first: Result, second: Result, format: large, unsigned: bool): BitwiseInstruction {
		if settings.is_x64 {
			instruction: link = platform.x64.SHIFT_RIGHT
			if unsigned { instruction = platform.x64.SHIFT_RIGHT_UNSIGNED }

			return BitwiseInstruction(unit, instruction, first, second, format, false)
		}
	}

	init(unit: Unit, instruction: link, first: Result, second: Result, format: large, assigns: bool) {
		DualParameterInstruction.init(unit, first, second, format, INSTRUCTION_BITWISE)
		this.instruction = String(instruction)
		this.description = "Executes a bitwise operation between the operands"
		this.assigns = assigns
	}

	build_shift_x64(): _ {
		locked = none as Register
		shifter = Result(second.value, FORMAT_INT8)

		if not second.is_constant {
			# Relocate the second operand to the shift register
			register = unit.get_shift_register()
			memory.clear_register(unit, register)

			move = MoveInstruction(unit, Result(RegisterHandle(register), FORMAT_INT8), second)
			move.type = MOVE_COPY
			if assigns { move.type = MOVE_RELOCATE }

			shifter = move.add()

			# Lock the shift register since it is very important it does not get relocated
			register.lock()
			locked = register
		}

		flags = FLAG_NONE
		if assigns { flags = FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		if first.is_memory_address and assigns {
			# Example: sal/sar [...], rcx
			build(instruction.data, 0,
				InstructionParameter(first, FLAG_DESTINATION | FLAG_READS | flags, HANDLE_MEMORY),
				InstructionParameter(shifter, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER)
			)

			# Finally, if a register was locked, unlock it now
			if locked != none locked.unlock()
			return
		}

		# Example: sal/sar r, c/rcx
		build(instruction.data, 0,
			InstructionParameter(first, FLAG_DESTINATION | FLAG_READS | flags, HANDLE_REGISTER),
			InstructionParameter(shifter, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER)
		)

		# Finally, if a register was locked, unlock it now
		if locked != none locked.unlock()
	}

	on_build_x64(): _ {
		if instruction == platform.x64.DOUBLE_PRECISION_XOR {
			if assigns abort('Assigning bitwise XOR-operation on media registers is not allowed')

			return build(instruction.data, 0,
				InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_MEDIA_REGISTER),
				InstructionParameter(second, FLAG_NONE, HANDLE_MEDIA_REGISTER | HANDLE_MEMORY)
			)
		}

		if instruction == platform.x64.SHIFT_LEFT or instruction == platform.x64.SHIFT_RIGHT or instruction == platform.x64.SHIFT_RIGHT_UNSIGNED return build_shift_x64()

		flags = FLAG_DESTINATION
		if assigns { flags = flags | FLAG_WRITE_ACCESS | FLAG_NO_ATTACH }

		if first.is_memory_address and assigns {
			# Example: ... [...], c/r
			return build(instruction.data, first.size,
				InstructionParameter(first, FLAG_READS | flags, HANDLE_MEMORY),
				InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER)
			)
		}

		# Example: ... r, c/r/[...]
		build(instruction.data, SYSTEM_BYTES,
			InstructionParameter(first, FLAG_READS | flags, HANDLE_REGISTER),
			InstructionParameter(second, FLAG_NONE, HANDLE_CONSTANT | HANDLE_REGISTER | HANDLE_MEMORY)
		)
	}

	override on_build() {
		if settings.is_x64 return on_build_x64()
	}
}

Instruction SingleParameterInstruction {
	instruction: link
	first: Result

	shared create_not(unit: Unit, first: Result): Instruction {
		instruction: Instruction = none as Instruction

		if settings.is_x64 { instruction = SingleParameterInstruction(unit, platform.x64.NOT, first) }
		else { instruction = SingleParameterInstruction(unit, platform.arm64.NOT, first) }

		instruction.description = "Executes bitwise NOT-operation to the operand"
		return instruction
	}

	shared create_negate(unit: Unit, first: Result, is_decimal: bool): Instruction {
		if is_decimal and settings.is_x64 abort('Negating decimal value using single parameter instruction on architecture x64 is not allowed')

		instruction: Instruction = none as Instruction

		if is_decimal { instruction = SingleParameterInstruction(unit, platform.arm64.DECIMAL_NEGATE, first) }
		else { instruction = SingleParameterInstruction(unit, platform.all.NEGATE, first) }

		instruction.description = "Negates the operand"
		return instruction
	}

	init(unit: Unit, instruction: link, first: Result) {
		Instruction.init(unit, INSTRUCTION_SINGLE_PARAMETER)

		this.instruction = instruction
		this.first = first
		this.dependencies.add(first)
		this.result.format = first.format
	}

	on_build_x64(): _ {
		result.format = first.format
		build(instruction, SYSTEM_BYTES, InstructionParameter(first, FLAG_DESTINATION | FLAG_READS, HANDLE_REGISTER))
	}

	override on_build() {
		if settings.is_x64 return on_build_x64()
	}
}

Instruction DebugBreakInstruction {
	constant INSTRUCTION = '.loc'

	position: Position

	shared get_position_instruction(position: Position): String {
		return String(INSTRUCTION) + ' 1 ' + to_string(position.friendly_line) + ' ' + to_string(position.friendly_character)
	}

	init(unit: Unit, position: Position) {
		Instruction.init(unit, INSTRUCTION_DEBUG_BREAK)
		this.position = position
		this.operation = get_position_instruction(position)
		this.state = INSTRUCTION_STATE_BUILT
		this.description = "Line: " + to_string(position.friendly_line) + ", Character: " + to_string(position.friendly_character)
	}
}

# Summary:
# Converts the specified number into the specified format
# This instruction works on all architectures
Instruction ConvertInstruction {
	number: Result
	format: large

	init(unit: Unit, number: Result, format: large) {
		Instruction.init(unit, INSTRUCTION_CONVERT)
		this.number = number
		this.format = format
		this.dependencies.add(number)
		this.is_abstract = true
		this.description = "Converts the specified number into the specified format"

		if format == FORMAT_DECIMAL { this.result.format = FORMAT_DECIMAL }
		else { this.result.format = get_system_format(format) }
	}

	override on_build() {
		memory.get_result_register_for(unit, result, is_unsigned(format), format == FORMAT_DECIMAL)

		instruction = MoveInstruction(unit, result, number)
		instruction.type = MOVE_LOAD
		instruction.description = "Loads the specified number into the specified register"
		unit.add(instruction)
	}
}

# Summary:
# This instruction requests a block of memory from the stack and returns a handle to it.
# This instruction works on all architectures
Instruction AllocateStackInstruction {
	identity: String
	bytes: large

	init(unit: Unit, node: StackAddressNode) {
		Instruction.init(unit, INSTRUCTION_ALLOCATE_STACK)
		this.identity = node.identity
		this.bytes = node.bytes
		this.is_abstract = true
	}

	override on_build() {
		result.value = StackAllocationHandle(unit, bytes, identity)
		result.format = SYSTEM_FORMAT
	}
}

# Summary:
# This instruction does nothing. However, this instruction is used for stopping the debugger.
# This instruction works on all architectures
Instruction NoOperationInstruction {
	init(unit: Unit) {
		Instruction.init(unit, INSTRUCTION_NO_OPERATION)
		this.operation = String(platform.all.NOP)
		this.description = "No operation"
	}
}

# Summary:
# This instruction allocates a new register for the result of this instruction.
# This instruction works on all architectures
Instruction AllocateRegisterInstruction {
	format: large

	init(unit: Unit, format: large) {
		Instruction.init(unit, INSTRUCTION_ALLOCATE_REGISTER)
		this.format = format
	}

	override on_build() {
		register = memory.get_next_register(unit, format == FORMAT_DECIMAL, trace.for(unit, result), true)
		result.value = RegisterHandle(register)
		result.format = format
		register.value = result
	}
}

Instruction CreatePackInstruction {
	values: List<Result>
	type: Type
	value: DisposablePackHandle

	init(unit: Unit, type: Type, values: List<Result>) {
		Instruction.init(unit, INSTRUCTION_CREATE_PACK)

		this.values = values
		this.type = type

		dependencies = List<Result>()
		dependencies.add(result)
		dependencies.add_all(values)

		value = DisposablePackHandle(unit, type)
		on_build()
	}

	register_member_values(disposable_pack: DisposablePackHandle, type: Type, position: large): large {
		loop iterator in type.variables {
			member = iterator.value

			if member.type.is_pack {
				member_value = disposable_pack.members[member.name].value
				position = register_member_values(member_value.value as DisposablePackHandle, member.type, position)
				continue
			}

			disposable_pack.members[member.name] = pack { member: member, value: values[position] } as DisposablePackMember
			position++
		}

		return position
	}

	override on_build() {
		register_member_values(value, type, 0)

		result.value = value
		result.format = SYSTEM_FORMAT
	}
}

Instruction LabelMergeInstruction {
	primary: String
	secondary: String

	init(unit: Unit, primary: String) {
		Instruction.init(unit, INSTRUCTION_LABEL_MERGE)
		this.primary = primary
		this.secondary = none as String
		this.is_abstract = true
	}

	init(unit: Unit, primary: String, secondary: String) {
		Instruction.init(unit, INSTRUCTION_LABEL_MERGE)
		this.primary = primary
		this.secondary = secondary
		this.is_abstract = true
	}

	prepare_for(id: String): _ {
		if id === none return

		variables = unit.scopes[id].inputs.get_keys()

		loop variable in variables {
			# Packs variables are not merged, their members are instead
			if variable.type.is_pack continue

			# Get the current value of the variable
			result: Result = unit.get_variable_value(variable)

			require(result.is_active, 'Output variable was not active')
			require(not result.is_any_register or result.value.(RegisterHandle).register.value === result, 'Output variable did not own the register')

			# Load complex values into registers
			instance = result.value.instance
			allowed = INSTANCE_REGISTER | INSTANCE_STACK_MEMORY | INSTANCE_STACK_VARIABLE | INSTANCE_TEMPORARY_MEMORY

			if (instance & allowed) == 0 {
				memory.move_to_register(unit, result, SYSTEM_BYTES, result.format == FORMAT_DECIMAL, trace.for(unit, result))
			}
		}
	}

	register_state(id: String): _ {
		if id === none return

		variables = unit.scopes[id].inputs.get_keys()

		# Save the locations of the processed variables as a state
		state: List<VariableState> = List<VariableState>()

		loop variable in variables {
			# Packs variables are not merged, their members are instead
			if variable.type.is_pack continue

			state.add(VariableState.create(variable, unit.get_variable_value(variable)))
		}

		unit.states[id] = state
	}

	merge_with_state(state: List<VariableState>): _ {
		# Collect the destination handles and the current values of the corresponding variables
		destinations = List<Handle>()
		sources = List<Result>()

		loop descriptor in state {
			source = unit.get_variable_value(descriptor.variable)
			if source === none continue

			destinations.add(descriptor.handle)
			sources.add(source)
		}

		# Relocate the sources so that they match the destinations
		unit.add(ReorderInstruction(unit, destinations, sources, none as Type))

		# Update the sources manually
		loop (i = 0, i < destinations.size, i++) {
			destination = destinations[i]
			source = sources[i]

			source.value = destination
			source.format = destination.format

			# If the destination is a register, attach the source to it
			if destination.instance == INSTANCE_REGISTER { destination.(RegisterHandle).register.value = source }
		}
	}

	override on_build() {
		# If the unit does not have a registered state for the label, then we must make one
		if not unit.states.contains_key(primary) {
			prepare_for(primary)
			prepare_for(secondary)

			register_state(primary)
			register_state(secondary)
			return
		}

		prepare_for(secondary)
		merge_with_state(unit.states[primary])
		register_state(secondary)
	}
}

Instruction EnterScopeInstruction {
	id: String

	init(unit: Unit, id: String) {
		Instruction.init(unit, INSTRUCTION_ENTER_SCOPE)
		this.id = id
	}

	override on_build() {
		if not unit.states.contains_key(id) return

		# Load the state
		state: List<VariableState> = unit.states[id]

		loop descriptor in state {
			scope.set_or_create_input(descriptor.variable, descriptor.handle, descriptor.handle.format)
		}
	}
}