namespace calls

constant SHADOW_SPACE_SIZE = 32
constant STACK_ALIGNMENT = 16

get_standard_parameter_register_names(unit: Unit) {
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

	=> result
}

get_decimal_parameter_register_count(unit: Unit) {
	if settings.is_x64 {
		if settings.is_target_windows => 4
		=> 7
	}

	=> 8
}

get_standard_parameter_registers(unit: Unit) {
	registers = List<Register>()

	loop name in get_standard_parameter_register_names(unit) {
		loop register in unit.standard_registers {
			if not (register[8] == name) continue
			registers.add(register)
		}
	}

	=> registers
}

get_decimal_parameter_registers(unit: Unit) {
	registers = List<Register>()
	count = get_decimal_parameter_register_count(unit)

	loop (i = 0, i < count, i++) {
		registers.add(unit.media_registers[i])
	}

	=> registers
}

is_self_pointer_required(current: FunctionImplementation, other: FunctionImplementation) {
	if other.is_static or other.is_constructor or not current.is_member or current.is_static or not other.is_member or other.is_static => false

	x = current.find_type_parent()
	y = other.find_type_parent()

	=> x == y or x.is_supertype_declared(y)
}

# Summary: Passes the specified argument using a register or the specified stack position depending on the situation
pass_argument(destinations: List<Handle>, sources: List<Result>, standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, position: StackMemoryHandle, value: Result, format: large) {
	# Determine the parameter register
	is_decimal = format == FORMAT_DECIMAL
	register = none as Register

	if is_decimal {
		if decimal_parameter_registers.size > 0 { register = decimal_parameter_registers.take_first() }
	}
	else {
		if standard_parameter_registers.size > 0 { register = standard_parameter_registers.take_first() }
	}

	if register != none {
		# Even though the destination should be the same size as the parameter, an exception should be made in case of registers since it is easier to manage when all register values can support every format
		destination = RegisterHandle(register)
		destination.format = FORMAT_DECIMAL

		if not is_decimal { destination.format = to_format(SYSTEM_BYTES, is_unsigned(value.format)) }

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
	if settings.is_x64 { offset = SHADOW_SPACE_SIZE }

	position = StackMemoryHandle(unit, offset, false)

	if self_pointer != none {
		if self_type == none abort('Missing self pointer type')
		pass_argument(destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, self_pointer, SYSTEM_FORMAT)
	}

	loop (i = 0, i < parameters.size, i++) {
		parameter = parameters[i]
		value = references.get(unit, parameters[i], ACCESS_READ)
		type = parameter_types[i]

		value = casts.cast(unit, value, parameter.get_type(), type)
		pass_argument(destinations, sources, standard_parameter_registers, decimal_parameter_registers, position, value, type.get_register_format())
	}

	call.destinations.add_range(destinations)
	unit.add(ReorderInstruction(unit, destinations, sources))
}

# Summary: Collects all parameters from the specified node tree into an array
collect_parameters(parameters: Node) {
	result = List<Node>()
	if parameters == none => result
	loop parameter in parameters { result.add(parameter) }
	=> result
}

build(unit: Unit, self: Result, parameters: Node, implementation: FunctionImplementation) {
	if self == none and is_self_pointer_required(unit.function, implementation) abort('Missing self pointer')

	call = CallInstruction(unit, implementation.get_fullname(), implementation.return_type)

	self_type = none as Type
	if self != none { self_type = implementation.find_type_parent() }

	# Pass the parameters to the function and then execute it
	pass_arguments(unit, call, self, self_type, false, collect_parameters(parameters), implementation.parameter_types)

	=> call.add()
}

build(unit: Unit, self: Result, self_type: Type, function: Result, return_type: Type, parameters: Node, parameter_types: List<Type>) {
	call = CallInstruction(unit, function, return_type)

	# Pass the parameters to the function and then execute it
	pass_arguments(unit, call, self, self_type, true, collect_parameters(parameters), parameter_types)

	=> call.add()
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

	=> build(unit, self, node.parameters, node.function)
}

build(unit: Unit, self: Result, node: FunctionNode) {
	unit.add_debug_position(node)
	=> build(unit, self, node.parameters, node.function)
}