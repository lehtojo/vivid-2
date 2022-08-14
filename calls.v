namespace calls

constant SHADOW_SPACE_SIZE = 32
constant STACK_ALIGNMENT = 16

get_standard_parameter_register_names() {
	result = List<link>(8, false)

	if settings.is_x64 {
		if settings.is_target_windows {
			result.add('rcx')
			result.add('rdx')
			result.add('r8')
			result.add('r9')
		}
		else {
			result.add('rdi')
			result.add('rsi')
			result.add('rdx')
			result.add('rcx')
			result.add('r8')
			result.add('r9')
		}
	}
	else {
		result.add('x0')
		result.add('x1')
		result.add('x2')
		result.add('x3')
		result.add('x4')
		result.add('x5')
		result.add('x6')
		result.add('x7')
	}

	return result
}

get_standard_parameter_register_count() {
	if settings.is_x64 {
		if settings.is_target_windows return 4
		return 6
	}

	return 8
}

get_decimal_parameter_register_count() {
	if settings.is_x64 {
		if settings.is_target_windows return 4
		return 7
	}

	return 8
}

get_standard_parameter_registers(unit: Unit) {
	registers = List<Register>()

	loop name in get_standard_parameter_register_names() {
		loop register in unit.standard_registers {
			if not (register[8] == name) continue
			registers.add(register)
		}
	}

	return registers
}

get_decimal_parameter_registers(unit: Unit) {
	registers = List<Register>()
	count = get_decimal_parameter_register_count()

	loop (i = 0, i < count, i++) {
		registers.add(unit.media_registers[i])
	}

	return registers
}

is_self_pointer_required(current: FunctionImplementation, other: FunctionImplementation) {
	if other.is_static or other.is_constructor or not current.is_member or current.is_static or not other.is_member or other.is_static return false

	x = current.find_type_parent()
	y = other.find_type_parent()

	return x == y or x.is_supertype_declared(y)
}

# Summary: Passes the specified disposable pack by passing its member one by one
pass_pack(unit: Unit, destinations: List<Handle>, sources: List<Result>, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, position: StackMemoryHandle, disposable_pack: DisposablePackHandle) {
	loop iterator in disposable_pack.members {
		member = iterator.value.member
		value = iterator.value.value

		if member.type.is_pack {
			pass_pack(unit, destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, value.value as DisposablePackHandle)
		}
		else {
			pass_argument(unit, destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, value, member.type, member.type.get_register_format())
		}
	}
}

# Summary: Passes the specified argument using a register or the specified stack position depending on the situation
pass_argument(unit: Unit, destinations: List<Handle>, sources: List<Result>, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, position: StackMemoryHandle, value: Result, type: Type, format: large) {
	if value.value.instance == INSTANCE_DISPOSABLE_PACK {
		pass_pack(unit, destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, value.value as DisposablePackHandle)
		return
	}

	# Determine the parameter register
	is_decimal = format == FORMAT_DECIMAL
	register = none as Register

	if is_decimal {
		if decimal_parameter_registers.size > 0 { register = decimal_parameter_registers.pop_or(none as Register) }
	}
	else {
		if standard_parameter_registers.size > 0 { register = standard_parameter_registers.pop_or(none as Register) }
	}

	if register != none {
		# Even though the destination should be the same size as the parameter, an exception should be made in case of registers since it is easier to manage when all register values can support every format
		destination = RegisterHandle(register)
		destination.format = FORMAT_DECIMAL

		if not is_decimal { destination.format = get_system_format(type.format) }

		destinations.add(destination)
	}
	else {
		# Since there is no more room for parameters in registers, this parameter must be pushed to stack
		position.format = format
		destinations.add(position.finalize())

		position.offset += SYSTEM_BYTES
	}

	sources.add(value)
}

# Summary: Passes the specified parameters to the function using the specified calling convention
# Returns: Returns the amount of parameters moved to stack
pass_arguments(unit: Unit, call: CallInstruction, self_pointer: Result, self_type: Type, is_self_pointer_required: bool, parameters: List<Node>, parameter_types: List<Type>) {
	standard_parameter_registers = get_standard_parameter_registers(unit)
	decimal_parameter_registers = get_decimal_parameter_registers(unit)

	# Retrieve the this pointer if it is required and it is not loaded
	if self_pointer == none and is_self_pointer_required {
		self_pointer = references.get_variable(unit, unit.self, ACCESS_READ)
	}

	destinations = List<Handle>()
	sources = List<Result>()

	# On Windows x64 a 'shadow space' is allocated for the first four parameters
	offset = 0
	if settings.is_target_windows { offset = SHADOW_SPACE_SIZE }

	position = StackMemoryHandle(unit, offset, false)

	if self_pointer != none {
		if self_type == none abort('Missing self pointer type')
		pass_argument(unit, destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, self_pointer, self_type, SYSTEM_FORMAT)
	}

	loop (i = 0, i < parameters.size, i++) {
		parameter = parameters[i]
		value = references.get(unit, parameters[i], ACCESS_READ)
		type = parameter_types[i]

		value = casts.cast(unit, value, parameter.get_type(), type)
		pass_argument(unit, destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, value, type, type.get_register_format())
	}

	call.destinations.add_all(destinations)
	unit.add(ReorderInstruction(unit, destinations, sources, call.return_type))
}

# Summary: Collects all parameters from the specified node tree into an array
collect_parameters(parameters: Node) {
	result = List<Node>()
	if parameters == none return result
	loop parameter in parameters { result.add(parameter) }
	return result
}

build(unit: Unit, self: Result, parameters: Node, implementation: FunctionImplementation) {
	if self == none and is_self_pointer_required(unit.function, implementation) abort('Missing self pointer')

	call = CallInstruction(unit, implementation.get_fullname(), implementation.return_type)

	self_type = none as Type
	if self != none { self_type = implementation.find_type_parent() }

	# Pass the parameters to the function and then execute it
	pass_arguments(unit, call, self, self_type, false, collect_parameters(parameters), implementation.parameter_types)

	return call.add()
}

build(unit: Unit, self: Result, self_type: Type, function: Result, return_type: Type, parameters: Node, parameter_types: List<Type>) {
	call = CallInstruction(unit, function, return_type)

	# Pass the parameters to the function and then execute it
	pass_arguments(unit, call, self, self_type, true, collect_parameters(parameters), parameter_types)

	return call.add()
}

build(unit: Unit, node: FunctionNode) {
	unit.add_debug_position(node)

	self = none as Result

	if is_self_pointer_required(unit.function, node.function) {
		local_self_type = unit.function.find_type_parent()
		function_self_type = node.function.find_type_parent()

		self = references.get_variable(unit, unit.self, ACCESS_READ)

		# If the function is not defined inside the type of the self pointer, it means it must have been defined in its supertypes, therefore casting is needed
		if local_self_type != function_self_type { self = casts.cast(unit, self, local_self_type, function_self_type) }
	}

	return build(unit, self, node.parameters, node.function)
}

build(unit: Unit, self: Result, node: FunctionNode) {
	unit.add_debug_position(node)
	return build(unit, self, node.parameters, node.function)
}

move_pack_to_stack(unit: Unit, parameter: Variable, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, stack_position: StackMemoryHandle) {
	proxies = common.get_pack_proxies(parameter)

	loop proxy in proxies {
		# Do not use the default parameter alignment, use local stack memory, because we want the pack members to be sequentially
		proxy.alignment = 0
		proxy.is_aligned = false

		register = none as Register
		source = none as Result

		if proxy.type.format == FORMAT_DECIMAL {
			register = decimal_parameter_registers.pop_or(none as Register)
		}
		else {
			register = standard_parameter_registers.pop_or(none as Register)
		}

		if register !== none {
			source = Result(RegisterHandle(register), proxy.type.get_register_format())
		}
		else {
			source = Result(stack_position.finalize(), proxy.type.get_register_format())
		}

		destination = Result(references.create_variable_handle(unit, proxy, ACCESS_TYPE_WRITE), proxy.type.format)

		instruction = MoveInstruction(unit, destination, source)
		instruction.type = MOVE_RELOCATE
		unit.add(instruction)

		# Windows: Even though the first parameters are passed in registers, they still require their own stack memory (shadow space)
		if register !== none and not settings.is_target_windows continue

		# Normal parameters consume one stack unit
		stack_position.offset += SYSTEM_BYTES
	}
}

# Summary:
# Moves the specified parameter or its proxies to their own stack locations, if they are not already in the stack.
# The location of the parameter is determined by using the specified registers.
# This is used for debugging purposes.
move_parameters_to_stack(unit: Unit, parameter: Variable, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, stack_position: StackMemoryHandle) {
	if parameter.type.is_pack {
		move_pack_to_stack(unit, parameter, standard_parameter_registers, decimal_parameter_registers, stack_position)
		return
	}

	register = none as Register

	if parameter.type.format == FORMAT_DECIMAL {
		register = decimal_parameter_registers.pop_or(none as Register)
	}
	else {
		register = standard_parameter_registers.pop_or(none as Register)
	}

	if register != none {
		destination = Result(references.create_variable_handle(unit, parameter, ACCESS_READ), parameter.type.format)
		source = Result(RegisterHandle(register), parameter.type.get_register_format())

		instruction = MoveInstruction(unit, destination, source)
		instruction.type = MOVE_RELOCATE
		unit.add(instruction)

		# Windows: Even though the first parameters are passed in registers, they still require their own stack memory (shadow space)
		if not settings.is_target_windows return
	}

	# Normal parameters consume one stack unit
	stack_position.offset += SYSTEM_BYTES
}

# Summary:
# Moves the specified parameters or their proxies to their own stack locations, if they are not already in the stack.
# This is used for debugging purposes.
move_parameters_to_stack(unit: Unit) {
	stack_offset = 0
	if settings.is_x64 { stack_offset = SYSTEM_BYTES }

	decimal_parameter_registers = calls.get_decimal_parameter_registers(unit)
	standard_parameter_registers = calls.get_standard_parameter_registers(unit)
	stack_position = StackMemoryHandle(unit, stack_offset, true)

	if (unit.function.is_member and not unit.function.is_static) or unit.function.is_lambda_implementation {
		self = unit.self
		if self == none abort('Missing self pointer')
		move_parameters_to_stack(unit, self, standard_parameter_registers, decimal_parameter_registers, stack_position)
	}

	loop parameter in unit.function.parameters {
		move_parameters_to_stack(unit, parameter, standard_parameter_registers, decimal_parameter_registers, stack_position)
	}
}