INSTRUCTION_ADDITION = 1
INSTRUCTION_ALLOCATE_STACK = 2
INSTRUCTION_ENTER_SCOPE = 3
INSTRUCTION_ATOMIC_EXCHANGE_ADDITION = 4
INSTRUCTION_BITWISE = 5
INSTRUCTION_CACHE_VARIABLES = 6
INSTRUCTION_CALL = 7
INSTRUCTION_COMPARE = 8
INSTRUCTION_CONVERT = 9
# Free: 10
INSTRUCTION_DIVISION = 11
INSTRUCTION_DUPLICATE = 12
INSTRUCTION_EVACUATE = 13
INSTRUCTION_EXCHANGE = 14
INSTRUCTION_EXTEND_NUMERATOR = 15
INSTRUCTION_GET_CONSTANT = 16
INSTRUCTION_GET_MEMORY_ADDRESS = 17
INSTRUCTION_GET_OBJECT_POINTER = 18
INSTRUCTION_GET_RELATIVE_ADDRESS = 19
INSTRUCTION_GET_VARIABLE = 20
INSTRUCTION_INITIALIZE = 21
INSTRUCTION_JUMP = 22
INSTRUCTION_LABEL = 23
INSTRUCTION_LABEL_MERGE = 24
INSTRUCTION_LOAD_SHIFTED_CONSTANT = 25
# Free: 26
INSTRUCTION_LONG_MULTIPLICATION = 27
INSTRUCTION_MERGE_SCOPE = 28
INSTRUCTION_MOVE = 29
INSTRUCTION_MULTIPLICATION = 30
INSTRUCTION_MULTIPLICATION_SUBTRACTION = 31
INSTRUCTION_DEBUG_BREAK = 32
INSTRUCTION_NORMAL = 33
INSTRUCTION_TEMPORARY_COMPARE = 34
INSTRUCTION_REORDER = 35
INSTRUCTION_REQUIRE_VARIABLES = 36
INSTRUCTION_RETURN = 37
INSTRUCTION_LOCK_STATE = 38
INSTRUCTION_SET_VARIABLE = 39
INSTRUCTION_NO_OPERATION = 40
INSTRUCTION_SUBTRACT = 41
INSTRUCTION_SINGLE_PARAMETER = 42
INSTRUCTION_DEBUG_START = 43
INSTRUCTION_DEBUG_FRAME_OFFSET = 44
INSTRUCTION_DEBUG_END = 45
INSTRUCTION_ALLOCATE_REGISTER = 46
INSTRUCTION_CREATE_PACK = 47

FLAG_NONE = 0
FLAG_DESTINATION = FLAG_WRITES | 1
FLAG_SOURCE = 1 <| 1
FLAG_WRITE_ACCESS = 1 <| 2
FLAG_ATTACH_TO_DESTINATION = 1 <| 3
FLAG_ATTACH_TO_SOURCE = 1 <| 4
FLAG_RELOCATE_TO_DESTINATION = 1 <| 5
FLAG_RELOCATE_TO_SOURCE = 1 <| 6
FLAG_HIDDEN = 1 <| 7
FLAG_BIT_LIMIT = 1 <| 8
FLAG_BIT_LIMIT_64 = FLAG_BIT_LIMIT | (64 <| 24)
FLAG_NO_ATTACH = 1 <| 9
FLAG_WRITES = 1 <| 10
FLAG_READS = 1 <| 11
FLAG_ALLOW_ADDRESS = 1 <| 12
FLAG_LOCKED = 1 <| 13

# Summary: Returns the largest format with the specified sign
get_system_format(unsigned: bool): large {
	if unsigned return SYSTEM_FORMAT
	return SYSTEM_SIGNED
}

# Summary: Returns the largest format with the specified sign
get_system_format(format: large): large {
	if (format & 1) != 0 return SYSTEM_FORMAT
	return SYSTEM_SIGNED
}

create_bit_limit_flag(bits) {
	return FLAG_BIT_LIMIT | (bits <| 24)
}

get_bit_limit_from_flags(bits) {
	return bits |> 24
}

InstructionParameter {
	result: Result
	value: Handle
	size: large
	types: large
	flags: large

	writes => has_flag(flags, FLAG_WRITES)

	is_hidden => has_flag(flags, FLAG_HIDDEN)
	is_destination => has_flag(flags, FLAG_DESTINATION)
	is_source => has_flag(flags, FLAG_SOURCE)
	is_protected => not has_flag(flags, FLAG_WRITE_ACCESS)
	is_attachable => not has_flag(flags, FLAG_NO_ATTACH)

	is_any_register => value != none and (value.type == HANDLE_REGISTER or value.type == HANDLE_MEDIA_REGISTER)
	is_standard_register => value != none and value.type == HANDLE_REGISTER
	is_media_register => value != none and value.type == HANDLE_MEDIA_REGISTER
	is_memory_address => value != none and value.type == HANDLE_MEMORY
	is_constant => value != none and value.type == HANDLE_CONSTANT

	is_value_valid => value != none and has_flag(types, value.type)

	init(result: Result, flags: large, types: large) {
		this.flags = flags
		this.result = result
		this.types = types
	}

	init(value: Handle, flags: large) {
		this.flags = flags
		this.result = Result(value, SYSTEM_FORMAT)
		this.value = value
		this.types = value.type
	}

	# Summary: Returns all valid handle options that are lower in cost than the current one
	get_lower_cost_handle_options(type: large): large {
		mask = -1

		loop (type != 0) {
			type = type |> 1
			mask = mask <| 1
		}

		return types & mask
	}

	is_valid(): bool {
		if not has_flag(types, result.value.type) return false

		# Watch out for bit limit
		if result.is_constant {
			bits = result.value.(ConstantHandle).bits

			# If the flags do not contain the bit limit flag, use the default bit limit (32-bits)
			if not has_flag(flags, FLAG_BIT_LIMIT) return bits <= 32

			return bits <= get_bit_limit_from_flags(flags)
		}

		# Data section handles should be moved into a register
		if result.value.instance == INSTANCE_DATA_SECTION or result.value.instance == INSTANCE_CONSTANT_DATA_SECTION {
			handle = result.value as DataSectionHandle

			if settings.is_x64 return has_flag(flags, FLAG_BIT_LIMIT_64) or not handle.address

			return has_flag(flags, FLAG_ALLOW_ADDRESS) and handle.address
		}

		return true
	}
}

INSTRUCTION_STATE_NOT_BUILT = 1
INSTRUCTION_STATE_BUILDING = 1 <| 1
INSTRUCTION_STATE_BUILT = 1 <| 2

Instruction {
	unit: Unit
	scope: Scope
	result: Result
	type: large
	description: String
	operation: String
	parameters: List<InstructionParameter> = List<InstructionParameter>()
	dependencies: List<Result>
	state: large = INSTRUCTION_STATE_NOT_BUILT

	# Controls whether the unit is allowed to load operands into registers while respecting the constraints
	is_usage_analyzed: bool = true
	# Tells whether this instruction is built
	is_built: bool = false
	# Tells whether the instruction is abstract. Abstract instructions will not translate into real assembly instructions
	is_abstract: bool = false
	# Tells whether the instruction is built manually using textual assembly. This helps the assembler by telling it to use the assembly code parser.
	is_manual: bool = false

	destination(): InstructionParameter {
		loop parameter in parameters {
			if parameter.is_destination return parameter
		}

		return none as InstructionParameter
	}
	
	source(): InstructionParameter {
		loop parameter in parameters {
			if not parameter.is_destination return parameter
		}

		return none as InstructionParameter
	}

	init(unit: Unit, type: large) {
		this.unit = unit
		this.type = type
		this.operation = String.empty
		this.result = Result()
		this.dependencies = List<Result>()
		this.dependencies.add(result)
	}

	init(operation: String, type: large) {
		this.unit = none as Unit
		this.type = type
		this.operation = operation
		this.result = Result()
		this.dependencies = List<Result>()
		this.dependencies.add(result)
	}

	match(type: large): bool {
		return this.type == type
	}

	# Summary: Adds this instruction to the unit and returns the result of this instruction
	add(): Result {
		unit.add(this)
		return result
	}

	private validate_handle(handle: Handle, locked: List<Register>): _ {
		results = handle.get_register_dependent_results()
		
		loop iterator in results {
			if not iterator.is_standard_register {
				memory.move_to_register(unit, iterator, SYSTEM_BYTES, false, trace.for(unit, iterator))
			}

			register = iterator.register
			register.lock()

			locked.add(register)
		}
	}

	# Summary: Simulates the interactions between the instruction parameters such as relocating the source to the destination
	apply_parameter_flags(): _ {
		destination: Handle = none as Handle
		source: Handle = none as Handle

		# Determine the destination and the source
		loop (i = 0, i < parameters.size, i++) {
			parameter = parameters[i]

			if parameter.is_destination and parameter.is_attachable {
				# There should not be multiple destinations
				if destination != none abort('Instruction had multiple destinations')
				destination = parameter.value.finalize()
			}

			if parameter.is_source and parameter.is_attachable {
				if source != none abort('Instruction had multiple sources')
				source = parameter.value.finalize()
			}

			is_relocated = has_flag(parameter.flags, FLAG_RELOCATE_TO_DESTINATION) or has_flag(parameter.flags, FLAG_RELOCATE_TO_SOURCE)
			is_register = parameter.result.is_any_register

			if is_relocated and is_register {
				# Since the parameter is relocated, its current register can be reset
				parameter.result.value.(RegisterHandle).register.reset()
			}
		}

		if destination != none {
			if destination.instance == INSTANCE_REGISTER {
				register = destination.(RegisterHandle).register
				attached = false

				# Search for values to attach to the destination register
				loop parameter in parameters {
					if has_flag(parameter.flags, FLAG_ATTACH_TO_DESTINATION) or has_flag(parameter.flags, FLAG_RELOCATE_TO_DESTINATION) {
						register.value = parameter.result
						parameter.result.format = destination.format
						attached = true
						stop
					}
				}

				# If no result was attached to the destination, the default action should be taken
				if not attached {
					register.value = result
					result.format = destination.format
				}
			}

			# Search for values to relocate to the destination
			loop parameter in parameters {
				if has_flag(parameter.flags, FLAG_RELOCATE_TO_DESTINATION) {
					parameter.result.value = destination
					parameter.result.format = destination.format
				}
			}
		}

		if source != none {
			if source.instance == INSTANCE_REGISTER {
				register = source.(RegisterHandle).register

				# Search for values to attach to the source register
				loop parameter in parameters {
					if has_flag(parameter.flags, FLAG_ATTACH_TO_SOURCE) or has_flag(parameter.flags, FLAG_RELOCATE_TO_SOURCE) {
						register.value = parameter.result
						parameter.result.format = source.format
						stop
					}
				}
			}

			# Search for values to relocate to the source
			loop parameter in parameters {
				if has_flag(parameter.flags, FLAG_RELOCATE_TO_SOURCE) {
					parameter.result.value = source
					parameter.result.format = source.format
				}
			}
		}
	}

	convert(parameter: InstructionParameter): Result {
		protect = parameter.is_destination and parameter.is_protected
		directives = none as List<Directive>

		if parameter.is_destination { directives = trace.for(unit, result) }
		else { directives = trace.for(unit, parameter.result) }

		if parameter.is_valid {
			# Get the more preferred options for this parameter
			options = parameter.get_lower_cost_handle_options(parameter.result.value.type)

			# If the value will be used later in the future and the register situation is good, the value can be moved to a register
			if has_flag(options, HANDLE_REGISTER) {
				if is_usage_analyzed and not parameter.is_destination and not parameter.result.is_deactivating() and unit.get_next_register_without_releasing() != none {
					return memory.move_to_register(unit, parameter.result, parameter.size, false, directives)
				}
			}
			else has_flag(options, HANDLE_MEDIA_REGISTER) {
				if is_usage_analyzed and not parameter.is_destination and not parameter.result.is_deactivating() and unit.get_next_media_register_without_releasing() != none {
					return memory.move_to_register(unit, parameter.result, parameter.size, true, directives)
				}
			}

			# If the parameter size does not match the required size, it can be converted by moving it to register
			if parameter.size != 0 and parameter.result.size != parameter.size {
				if parameter.result.is_memory_address and parameter.is_destination {
					abort('Could not convert memory address to the required size since it was specified as a destination')
				}

				memory.convert(unit, parameter.result, parameter.size, directives)
			}

			# If the current parameter is the destination and it is needed later, then it must me copied to another register
			if protect and parameter.result.is_only_active() {
				return memory.copy_to_register(unit, parameter.result, parameter.size, has_flag(parameter.types, HANDLE_MEDIA_REGISTER), directives)
			}

			return parameter.result
		}

		return memory.convert(unit, parameter.result, parameter.size, parameter.types, protect, directives)
	}

	# Summary: Builds the given operation without any processing
	build(operation: String): _ {
		this.operation = operation
		this.is_manual = true
	}

	build(operation: link, size: large): _ {
		locked = List<Register>()

		loop (i = 0, i < parameters.size, i++) {
			parameter = parameters[i]

			# Apply the specified size to the parameter
			if size == 0 { parameter.size = parameter.result.size }
			else { parameter.size = size }

			# Convert the parameter to a valid format for this instruction
			converted = convert(parameter)

			# Set the result of this instruction to match the parameter, if it is the destination
			if parameter.is_destination {
				result.value = converted.value
				result.format = converted.format
			}

			# Prepare the parameter for use
			validate_handle(converted.value, locked)

			# Prevents other parameters from stealing the register of the current parameter in the middle of this instruction
			if converted.value.instance == INSTANCE_REGISTER {
				register = converted.register
				register.lock()
				locked.add(register)
			}

			format = converted.format

			parameter.result = converted
			parameter.value = converted.value.finalize()
			
			if format == FORMAT_DECIMAL { parameter.value.format = FORMAT_DECIMAL }
			else { parameter.value.format = to_format(parameter.size, is_unsigned(format)) }
		}

		# Simulate the effects of the parameter flags
		apply_parameter_flags()

		# Allow final touches to this instruction
		this.operation = String(operation)
		on_post_build()

		# Unlock the registers since the instruction has been executed
		loop register in locked { register.unlock() }
	}

	build(operation: link, size: large, parameter: InstructionParameter): _ {
		parameters.add(parameter)
		build(operation, size)
	}

	build(operation: link, size: large, first: InstructionParameter, second: InstructionParameter): _ {
		parameters.add(first)
		parameters.add(second)
		build(operation, size)
	}

	build(operation: link, size: large, first: InstructionParameter, second: InstructionParameter, third: InstructionParameter): _ {
		parameters.add(first)
		parameters.add(second)
		parameters.add(third)
		build(operation, size)
	}

	reindex(): _ {
		dependencies: List<Result> = get_all_dependencies()
		loop dependency in dependencies { dependency.use(this) }

		# Use the result at its usages
		result.use(result.lifetime.usages)
	}

	build(): _ {
		if state == INSTRUCTION_STATE_BUILT {
			loop parameter in parameters {
				if not parameter.is_value_valid and parameter.value == none abort('During translation one instruction parameter was in incorrect format')

				if parameter.is_destination {
					# Set the result to be equal to the destination
					result.value = parameter.value
				}
			}

			# Simulate the effects of the parameter flags
			apply_parameter_flags()
		}
		else {
			state = INSTRUCTION_STATE_BUILDING
			reindex()
			on_build()
			reindex()
			state = INSTRUCTION_STATE_BUILT
		}

		# Extend all inner results to last at least as long as their parents
		# NOTE: This fixes the issue where for example a memory address is created but the lifetime of the starting address is not extended so its register could be stolen
		loop iterator in get_all_dependencies() {
			loop inner in iterator.value.get_inner_results() {
				inner.use(iterator.lifetime.usages)
			}
		}
	}

	finish(): _ {
		# Skip empty instructions
		if operation === none or operation.length == 0 return

		builder = StringBuilder()
		builder.append(operation.data)

		added = false

		loop parameter in parameters {
			if parameter.is_hidden continue
			
			value = parameter.value.string()
			if value.length == 0 abort('Instruction parameter could not be converted into assembly')
			
			builder.append(' ')
			builder.append(value)
			builder.append(',')

			added = true
		}

		# If any parameters were added, remove the comma from the end
		if added builder.remove(builder.length - 1, builder.length)

		unit.write(builder.string())
	}

	open on_build() {}
	open on_post_build() {}
	open redirect(handle: Handle) { return false }

	open get_dependencies() {
		all = List<Result>()
		all.add(result)
		return all
	}

	get_all_dependencies(): List<Result> {
		all = List<Result>()
		loop parameter in parameters { all.add(parameter.result) }

		if dependencies == none { all.add_all(get_dependencies()) }
		else { all.add_all(dependencies) }
		
		return all
	}
}

Instruction DualParameterInstruction {
	first: Result
	second: Result
	unsigned: bool

	init(unit: Unit, first: Result, second: Result, format: large, type: large) {
		Instruction.init(unit, type)

		this.first = first
		this.second = second
		this.unsigned = is_unsigned(format)
		this.result.format = format
		this.dependencies = [ result, first, second ]
	}

	override get_dependencies() {
		return [ result, first, second ]
	}
}