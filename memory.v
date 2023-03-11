namespace memory

# Summary: Minimizes intersection between the specified move instructions and tries to use exchange instructions
minimize_intersections(unit: Unit, moves: List<DualParameterInstruction>) {
	# Find moves that can be replaced with an exchange instruction
	result = List<DualParameterInstruction>(moves)
	exchanges = List<DualParameterInstruction>()
	exchanged_indices = List<large>()

	if settings.is_x64 {
		loop (i = 0, i < result.size, i++) {
			loop (j = 0, j < result.size, j++) {
				if i == j or exchanged_indices.contains(i) or exchanged_indices.contains(j) continue

				current = result[i]
				other = result[j]

				# Can not exchange non-integer values
				if current.first.value.format == FORMAT_DECIMAL or current.second.value.format == FORMAT_DECIMAL continue

				if current.first.value.equals(other.second.value) and current.second.value.equals(other.first.value) {
					exchanges.add(ExchangeInstruction(unit, current.second, other.second))
					exchanged_indices.add(i)
					exchanged_indices.add(j)
					stop
				}
			}
		}
	}

	# Add the created exchanges and remove the moves which were replaced by the exchanges
	result.add_all(exchanges)
	
	loop (i = result.size - 1, i >= 0, i--) {
		if not exchanged_indices.contains(i) continue
		result.remove_at(i)
	}

	# Order the move instructions so that intersections are minimized
	loop (i = 0, i < result.size, i++) {
		loop (j = i + 1, j < result.size, j++) {
			a = result[i]
			b = result[j]

			if not a.first.value.equals(b.second.value) continue

			# Swap:
			result[i] = b
			result[j] = a
		}
	}

	return result
}

# Summary: Aligns the specified moves so that intersections are minimized
align(unit: Unit, moves: List<MoveInstruction>): _ {
	complex = List<Instruction>()

	# Execute complex moves before anything else, because they might require multiple steps
	loop (i = moves.size - 1, i >= 0, i--) {
		move = moves[i]

		if not move.first.is_any_register or move.second.is_empty {
			complex.add(move)
			moves.remove_at(i)
		}
	}

	locks = List<Instruction>()
	unlocks = List<Instruction>()

	loop move in moves {
		if move.is_redundant and move.first.is_standard_register {
			register = move.first.value.(RegisterHandle).register
			locks.add(LockStateInstruction(unit, register, true))
			unlocks.add(LockStateInstruction(unit, register, false))
		}
	}

	aligned = minimize_intersections(unit, moves as List<DualParameterInstruction>) as List<Instruction>

	loop (i = aligned.size - 1, i >= 0, i--) {
		instruction = aligned[i]

		if instruction.type == INSTRUCTION_EXCHANGE {
			exchange = instruction as ExchangeInstruction

			first = exchange.first.value.(RegisterHandle).register
			second = exchange.second.value.(RegisterHandle).register

			aligned.insert(i + 1, LockStateInstruction(unit, second, true))
			aligned.insert(i + 1, LockStateInstruction(unit, first, true))

			unlocks.add(LockStateInstruction(unit, first, false))
			unlocks.add(LockStateInstruction(unit, second, false))
		}
		else instruction.type == INSTRUCTION_MOVE {
			move = instruction as MoveInstruction

			if move.first.is_any_register {
				register = move.first.value.(RegisterHandle).register

				aligned.insert(i + 1, LockStateInstruction(unit, register, true))
				unlocks.add(LockStateInstruction(unit, register, false))
			}
		}
		else {
			abort('Unsupported instruction type found while aligning move instructions')
		}
	}

	result = List<Instruction>()
	result.add_all(complex)
	result.add_all(locks)
	result.add_all(aligned)
	result.add_all(unlocks)

	loop (i = result.size - 1, i >= 0, i--) {
		unit.add(result[i], true)
	}
}

# Summary: Loads the operand so that it is ready based on the specified settings
load_operand(unit: Unit, operand: Result, media_register: bool, assigns: bool): Result {
	if not assigns return operand
	if operand.is_memory_address return memory.copy_to_register(unit, operand, SYSTEM_BYTES, media_register, trace.for(unit, operand))

	memory.move_to_register(unit, operand, SYSTEM_BYTES, media_register, trace.for(unit, operand))
	return operand
}

# Summary: Moves the value inside the given register to other register or releases it memory
clear_register(unit: Unit, target: Register): _ {
	# 1. If the register is already available, no need to clear it
	# 2. If the value inside the register does not own the register, no need to clear it
	if target.is_available() or target.is_value_copy() return

	register = none as Register

	target.lock()

	directives = none as List<Directive>
	if target.value != none { directives = trace.for(unit, target.value) }

	register = get_next_register_without_releasing(unit, target.is_media_register, directives)

	target.unlock()

	if register == none {
		unit.release(target)
		return
	}

	if target.value == none return

	destination = RegisterHandle(register)

	instruction = MoveInstruction(unit, Result(destination, target.value.format), target.value)
	instruction.type = MOVE_RELOCATE
	instruction.description = "Relocates the source value so that the register is cleared for another purpose"

	unit.add(instruction)

	target.reset()
}

# Summary: Sets the value of the register to zero
zero(unit: Unit, register: Register): _ {
	if not register.is_available() clear_register(unit, register)

	handle = RegisterHandle(register)

	instruction = BitwiseInstruction.create_xor(unit, Result(handle, SYSTEM_FORMAT), Result(handle, SYSTEM_FORMAT), SYSTEM_FORMAT, false)
	instruction.description = "Sets the value of the destination to zero"

	unit.add(instruction)
}

# Summary: Copies the specified result to a register
copy_to_register(unit: Unit, result: Result, size: large, media_register: bool, directives: List<Directive>): Result {
	format = FORMAT_DECIMAL
	if not media_register { format = to_format(size, is_unsigned(result.format)) }

	if result.is_any_register {
		source = result.register

		source.lock()
		destination = Result(RegisterHandle(get_next_register(unit, media_register, directives, false)), format)
		result = MoveInstruction(unit, destination, result).add()
		source.unlock()

		return result
	}
	else {
		register = get_next_register(unit, media_register, directives, false)
		destination = Result(RegisterHandle(register), format)

		return MoveInstruction(unit, destination, result).add()
	}
}

# Summary: Moves the specified result to a register considering the specified hints
move_to_register(unit: Unit, result: Result, size: large, media_register: bool, directives: List<Directive>): Result {
	# Prevents redundant moving to registers
	if media_register {
		if result.value.type == HANDLE_MEDIA_REGISTER return result
	}
	else {
		if result.value.type == HANDLE_REGISTER return result
	}

	format = FORMAT_DECIMAL
	if not media_register { format = to_format(size, is_unsigned(result.format)) }

	register = get_next_register(unit, media_register, directives, false)
	destination = Result(RegisterHandle(register), format)

	instruction = MoveInstruction(unit, destination, result)
	instruction.description = "Move source to a register"
	instruction.type = MOVE_RELOCATE

	return instruction.add()
}

# Summary: Tries to apply the most important directive
consider(unit: Unit, directive: Directive, media_register: bool): Register {
	return when(directive.type) {
		DIRECTIVE_NON_VOLATILITY => unit.get_next_non_volatile_register(media_register, false),
		DIRECTIVE_AVOID_REGISTERS => {
			register = none as Register
			denylist = directive.(AvoidRegistersDirective).registers

			if media_register { register = unit.get_next_media_register_without_releasing(denylist) }
			else { register = unit.get_next_register_without_releasing(denylist) }

			register
		},
		DIRECTIVE_SPECIFIC_REGISTER => directive.(SpecificRegisterDirective).register,
		else => abort('Unknown directive type encountered') as Register
	}
}

# Summary: Determines the next register to use
get_next_register(unit: Unit, media_register: bool, directives: List<Directive>, is_result: bool): Register {
	register = none as Register

	if directives != none {
		loop directive in directives {
			result = consider(unit, directive, media_register)

			if result == none or media_register != result.is_media_register continue

			if (is_result and (result.is_available() or result.is_deactivating())) or (not is_result and result.is_available()) {
				register = result
				stop
			}
		}
	}

	if register == none {
		if media_register return unit.get_next_media_register()
		return unit.get_next_register()
	}

	return register
}

# Summary: Tries to get a register without releasing based on the specified directives
get_next_register_without_releasing(unit: Unit, media_register: bool, directives: List<Directive>): Register {
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
		if media_register return unit.get_next_media_register_without_releasing()
		return unit.get_next_register_without_releasing()
	}

	return register
}

# Summary: Moves the specified result to an available register
get_register_for(unit: Unit, result: Result, unsigned: bool, media_register: bool): _ {
	register = get_next_register(unit, media_register, trace.for(unit, result), false)

	register.value = result

	result.value = RegisterHandle(register)
	
	if media_register { result.format = FORMAT_DECIMAL }
	else { result.format = get_system_format(unsigned) }
}

# Summary: Moves the specified result to an available register
get_result_register_for(unit: Unit, result: Result, unsigned: bool, media_register: bool): _ {
	register = get_next_register(unit, media_register, trace.for(unit, result), true)

	register.value = result

	result.value = RegisterHandle(register)
	
	if media_register { result.format = FORMAT_DECIMAL }
	else { result.format = get_system_format(unsigned) }
}

try_convert(unit: Unit, result: Result, size: large, type: large, protect: bool, directives: List<Directive>): Result {
	if type == HANDLE_REGISTER or type == HANDLE_MEDIA_REGISTER {
		is_media_register = type == HANDLE_MEDIA_REGISTER

		# If the result is empty, a new available register can be assigned to it
		if result.is_empty {
			get_register_for(unit, result, is_unsigned(result.format), is_media_register)
			return result
		}

		# If the format does not match the required register type, only copy it since the conversion may be lossy
		if (result.format == FORMAT_DECIMAL) != is_media_register return copy_to_register(unit, result, size, is_media_register, directives)

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

			return result
		}

		return move_to_register(unit, result, size, is_media_register, directives)
	}
	else type == HANDLE_MEMORY {
		if settings.is_x64 and not result.is_data_section_handle return none as Result

		# TODO: Support data section handles on Arm64
		return none as Result
	}
	else type == HANDLE_NONE {
		abort('Tried to convert into an empty result')
	}

	return none as Result
}

convert(unit: Unit, result: Result, size: large, types: large, protect: bool, directives: List<Directive>): Result {
	loop (i = 0, types != 0 and i < 64, i++) {
		type = 1 <| i

		# Continue if the types do not contain the current type
		if (types & type) == 0 continue

		converted = try_convert(unit, result, size, type, protect, directives)
		if converted != none return converted

		# Remove the current type from the flags
		types = types & (!type)
	}

	abort('Could not convert the specified result into the specified format')
}

# Summary: Moves the specified result to a register considering the specified directives
convert(unit: Unit, result: Result, size: large, directives: List<Directive>): Result {
	register = none as Register
	destination = none as Result
	format = FORMAT_DECIMAL

	if result.format != FORMAT_DECIMAL { format = to_format(size, is_unsigned(result.format)) }

	if result.is_media_register return result
	else result.is_constant {
		result.format = format
		return result
	}
	else result.is_standard_register {
		if result.size >= size return result
	}
	else result.is_memory_address {
		register = get_next_register(unit, format == FORMAT_DECIMAL, directives, false)
		destination = Result(RegisterHandle(register), format)

		instruction = MoveInstruction(unit, destination, result)
		instruction.description = "Converts the format of the source operand"
		instruction.type = MOVE_RELOCATE
		return instruction.add()
	}
	else {
		abort('Unsupported conversion requested')
	}

	# Use the register of the result to extend the value
	# NOTE: This will always extend the value, so there will be no loss of information
	register = result.register
	destination = Result(RegisterHandle(register), format)

	instruction = MoveInstruction(unit, destination, result)
	instruction.description = "Converts the format of the source operand"
	instruction.type = MOVE_RELOCATE
	return instruction.add()
}