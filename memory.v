namespace memory

# Summary: Moves the value inside the given register to other register or releases it memory
clear_register(unit: Unit, target: Register) {
	if target.is_available() return

	register = none as Register

	target.lock()

	directives = none as List<Directive>
	if target.value != none { directives = trace.for(unit, target.value) }

	register = get_next_register_without_releasing(unit, target.is_media_register, directives, false)

	target.unlock()

	if register == none {
		unit.release(target)
		return
	}

	if target.value == none return

	destination = RegisterHandle(register)

	instruction = MoveInstruction(unit, Result(destination, register.format), target.value)
	instruction.type = MOVE_RELOCATE
	instruction.description = String('Relocates the source value so that the register is cleared for another purpose')

	unit.add(instruction)

	target.reset()
}

# Summary: Copies the specified result to a register
copy_to_register(unit: Unit, result: Result, size: large, media_register: bool, directives: List<Directive>) {
	format = FORMAT_DECIMAL
	if not media_register { format = to_format(size) }

	if result.is_any_register {
		source = result.register

		source.lock()
		destination = Result(RegisterHandle(get_next_register(unit, media_register, directives, false)), format)
		result = MoveInstruction(unit, destination, result).add()
		source.unlock()

		=> result
	}
	else {
		register = get_next_register(unit, media_register, directives, false)
		destination = Result(RegisterHandle(register), format)

		=> MoveInstruction(unit, destination, result).add()
	}
}

# Summary: Moves the specified result to a register considering the specified hints
move_to_register(unit: Unit, result: Result, size: large, media_register: bool, directives: List<Directive>) {
	# Prevents redundant moving to registers
	if result.value.instance == INSTANCE_REGISTER => result

	format = FORMAT_DECIMAL
	if not media_register { format = to_format(size) }

	register = get_next_register(unit, media_register, directives, false)
	destination = Result(RegisterHandle(register), format)

	instruction = MoveInstruction(unit, destination, result)
	instruction.description = String('Move source to a register')
	instruction.type = MOVE_RELOCATE

	=> instruction.add()
}

# Summary: Tries to apply the most important directive
consider(unit: Unit, directive: Directive, media_register: bool) {
	# TODO: Support directives
	=> none as Register
}

# Summary: Determines the next register to use
get_next_register(unit: Unit, media_register: bool, directives: List<Directive>, is_result: bool) {
	register = none as Register

	if directives != none {
		loop directive in directives {
			result = consider(unit, directive, media_register)

			if result == none or media_register != result.is_media_register continue

			if [is_result and (result.is_available() or result.is_deactivating())] or [not is_result and result.is_available()] {
				register = result
				stop
			}
		}
	}

	if register == none {
		if media_register => unit.get_next_media_register()
		=> unit.get_next_register()
	}

	=> register
}

# Summary: Tries to get a register without releasing based on the specified directives
get_next_register_without_releasing(unit: Unit, media_register: bool, directives: List<Directive>, is_result: bool) {
	register = none as Register

	if directives != none {
		loop directive in directives {
			result = consider(unit, directive, media_register)

			if result == none or media_register != result.is_media_register or not result.is_available() continue

			register = result
			stop
		}
	}

	if register == none {
		if media_register => unit.get_next_media_register_without_releasing()
		=> unit.get_next_register_without_releasing()
	}

	=> register
}

# Summary: Moves the specified result to an available register
get_register_for(unit: Unit, result: Result, media_register: bool) {
	register = get_next_register(unit, media_register, trace.for(unit, result), false)

	register.value = result

	result.value = RegisterHandle(register)
	
	if media_register { result.format = FORMAT_DECIMAL }
	else { result.format = SYSTEM_FORMAT }
}

# Summary: Moves the specified result to an available register
get_result_register_for(unit: Unit, result: Result, media_register: bool) {
	register = get_next_register(unit, media_register, trace.for(unit, result), true)

	register.value = result

	result.value = RegisterHandle(register)
	
	if media_register { result.format = FORMAT_DECIMAL }
	else { result.format = SYSTEM_FORMAT }
}

try_convert(unit: Unit, result: Result, size: large, type: large, protect: bool, directives: List<Directive>) {
	if type == HANDLE_REGISTER or type == HANDLE_MEDIA_REGISTER {
		is_media_register = type == HANDLE_MEDIA_REGISTER

		# If the result is empty, a new available register can be assigned to it
		if result.is_empty {
			get_register_for(unit, result, is_media_register)
			=> result
		}

		# If the format does not match the required register type, only copy it since the conversion may be lossy
		if (result.format == FORMAT_DECIMAL) != is_media_register => copy_to_register(unit, result, size, is_media_register, directives)

		expiring = result.is_deactivating()

		# The result must be loaded into a register
		if protect and not expiring {
			# Do not use the directives here, because it would conflict with the upcoming copy
			result = move_to_register(unit, result, size, is_media_register, none as List<Directive>)
			register = result.register

			# Now copy the registered value into another register using the directives
			register.lock()
			result = copy_to_register(unit, result, size, is_media_register, directives)
			register.unlock()

			=> result
		}

		=> move_to_register(unit, result, size, is_media_register, directives)
	}
	else type == HANDLE_MEMORY {
		if settings.is_x64 and not result.is_data_section_handle => none as Result

		# TODO: Support data section handles on arm64
		=> none as Result
	}
	else type == HANDLE_NONE {
		abort('Tried to convert into an empty result')
	}

	=> none as Result
}

convert(unit: Unit, result: Result, size: large, types: large, protect: bool, directives: List<Directive>) {
	loop (i = 0, types != 0 and i < 64, i++) {
		type = 1 <| i

		# Continue if the types do not contain the current type
		if (types & type) == 0 continue

		converted = try_convert(unit, result, size, type, protect, directives)
		if converted != none => converted

		# Remove the current type from the flags
		types = types & (!type)
	}

	abort('Could not convert the specified result into the specified format')
}

# Summary: Moves the specified result to a register considering the specified directives
convert(unit: Unit, result: Result, size: large, directives: List<Directive>) {
	register = none as Register
	destination = none as Result
	format = FORMAT_DECIMAL

	if result.format != FORMAT_DECIMAL { format = to_format(size) }

	if result.is_media_register => result
	else result.is_constant {
		result.format = format
		=> result
	}
	else result.is_standard_register {
		if result.size >= size => result
	}
	else result.is_memory_address {
		register = get_next_register(unit, format == FORMAT_DECIMAL, directives, false)
		destination = Result(RegisterHandle(register), format)

		instruction = MoveInstruction(unit, destination, result)
		instruction.description = String('Converts the format of the source operand')
		instruction.type = MOVE_RELOCATE
		=> instruction.add()
	}
	else {
		abort('Unsupported conversion requested')
	}

	# Use the register of the result to extend the value
	# NOTE: This will always extend the value, so there will be no loss of information
	register = result.register
	destination = Result(RegisterHandle(register), format)

	instruction = MoveInstruction(unit, destination, result)
	instruction.description = String('Converts the format of the source operand')
	instruction.type = MOVE_RELOCATE
	=> instruction.add()
}