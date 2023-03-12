DIRECTIVE_NON_VOLATILITY = 1
DIRECTIVE_SPECIFIC_REGISTER = 2
DIRECTIVE_AVOID_REGISTERS = 3

Directive {
	type: tiny
	init(type: tiny) { this.type = type }
}

Directive NonVolatilityDirective {
	init() { Directive.init(DIRECTIVE_NON_VOLATILITY) }
}

Directive SpecificRegisterDirective {
	register: Register

	init(register: Register) {
		Directive.init(DIRECTIVE_SPECIFIC_REGISTER)
		this.register = register
	}
}

Directive AvoidRegistersDirective {
	registers: List<Register>

	init(registers: List<Register>) {
		Directive.init(DIRECTIVE_AVOID_REGISTERS)
		this.registers = registers
	}
}

namespace trace

for(unit: Unit, result: Result) {
	directives = List<Directive>()
	reorders = List<ReorderInstruction>()

	usages = result.lifetime.usages
	instructions = unit.instructions

	start = usages.size
	end = -1

	# Find the last usage
	loop usage in usages {
		position = unit.instructions.index_of(usage)
		if position > end { end = position }
		if position < start { start = position }
	}

	if unit.position > start { start = unit.position }

	# Do not process results, which have already expired
	if start > end return List<Directive>()

	loop (i = start, i <= end, i++) {
		instruction = instructions[i]

		# If the value is used after a call, add non-volatility directive
		if instruction.type == INSTRUCTION_CALL and i < end {
			directives.add(NonVolatilityDirective())
			continue
		}

		if instruction.type == INSTRUCTION_REORDER {
			reorders.add(instruction as ReorderInstruction)
		}
	}

	avoid = List<Register>()

	# Look for return instructions, which have return values, if the current function has a return type
	if not primitives.is_primitive(unit.function.return_type, primitives.UNIT) {
		loop (i = start, i <= end, i++) {
			instruction = instructions[i]

			# Look for return instructions, which have return values
			if instruction.type != INSTRUCTION_RETURN continue
			if instruction.(ReturnInstruction).object == none continue

			# If the returned object is the specified result, it should try to use the return register, otherwise it should avoid it
			register = instruction.(ReturnInstruction).return_register

			if instruction.(ReturnInstruction).object != result {
				avoid.add(register)
			}
			else {
				directives.add(SpecificRegisterDirective(register))
			}

			stop
		}
	}

	if settings.is_x64 {
		loop (i = start, i <= end, i++) {
			instruction = instructions[i]

			# Look for division instructions
			if instruction.type != INSTRUCTION_DIVISION continue

			# If the first operand of the division is the specified result, it should try to use the numerator register, otherwise it should avoid it
			register = unit.get_numerator_register()

			if instruction.(DivisionInstruction).first != result {
				avoid.add(register)
			}
			else {
				directives.add(SpecificRegisterDirective(register))
			}

			# All results should avoid the remainder register
			avoid.add(unit.get_remainder_register())
			stop
		}
	}

	loop reorder in reorders {
		# Check if the specified result is relocated to any register
		loop (i = 0, i < reorder.destinations.size, i++) {
			destination = reorder.destinations[i]
			if destination.instance != INSTANCE_REGISTER continue

			register = destination.(RegisterHandle).register

			if reorder.sources[i] != result {
				avoid.add(register)
				continue
			}

			directives.add(SpecificRegisterDirective(register))
			stop
		}
	}

	directives.add(AvoidRegistersDirective(avoid))
	return directives
}

# Summary: Returns whether the specified result lives through at least one call
is_used_after_call(unit: Unit, result: Result) {
	usages = result.lifetime.usages
	instructions = unit.instructions

	start = usages.size
	end = -1

	# Find the last usage
	loop usage in usages {
		position = instructions.index_of(usage)
		if position > end { end = position }
		if position < start { start = position }
	}

	if unit.position > start { start = unit.position }

	# Do not process results, which have already expired
	if start > end return false

	loop (i = start, i < end, i++) {
		if instructions[i].type == INSTRUCTION_CALL return true
	}

	return false
}

# Summary: Returns whether the specified result stays constant during the lifetime of the specified parent
is_loading_required(unit: Unit, result: Result): bool {
	usages = result.lifetime.usages
	instructions = unit.instructions

	start = usages.size
	end = -1

	# Find the last usage
	loop usage in usages {
		position = instructions.index_of(usage)
		if position > end { end = position }
		if position < start { start = position }
	}

	if unit.position > start { start = unit.position + 1 }

	# Do not process results, which have already expired
	if start > end return false

	loop (i = start, i < end, i++) {
		instruction = instructions[i]
		type = instruction.type

		if type == INSTRUCTION_CALL return true
		if type == INSTRUCTION_GET_OBJECT_POINTER and instruction.(GetObjectPointerInstruction).mode == ACCESS_WRITE return true
		if type == INSTRUCTION_GET_MEMORY_ADDRESS and instruction.(GetMemoryAddressInstruction).mode == ACCESS_WRITE return true
	}

	return false
}