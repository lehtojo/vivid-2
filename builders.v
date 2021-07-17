namespace builders

# Summary: Tries to determine the local variable the specified node and its result represent
try_get_local_variable(unit: Unit, node: Node, result: Result) {
	local = unit.get_value_owner(result)
	if local != none => local
	if result.value.instance == INSTANCE_STACK_VARIABLE => result.value.(StackVariableHandle).variable
	if node.match(NODE_VARIABLE) and node.(VariableNode).variable.is_predictable => node.(VariableNode).variable
	=> none as Variable
}

build_addition_operator(unit: Unit, operator: OperatorNode, assigns: bool) {
	access = ACCESS_READ
	if assigns { access = ACCESS_WRITE }

	left = references.get(unit, operator.first, access)
	right = references.get(unit, operator.last, ACCESS_READ)
	type = operator.get_type().(Number).type

	=> AdditionInstruction(unit, left, right, type, assigns).add()
}

build_subtraction_operator(unit: Unit, operator: OperatorNode, assigns: bool) {
	access = ACCESS_READ
	if assigns { access = ACCESS_WRITE }

	left = references.get(unit, operator.first, access)
	right = references.get(unit, operator.last, ACCESS_READ)
	type = operator.get_type().(Number).type

	=> SubtractionInstruction(unit, left, right, type, assigns).add()
}

build_multiplication_operator(unit: Unit, operator: OperatorNode, assigns: bool) {
	access = ACCESS_READ
	if assigns { access = ACCESS_WRITE }

	left = references.get(unit, operator.first, access)
	right = references.get(unit, operator.last, ACCESS_READ)
	type = operator.get_type().(Number).type

	=> MultiplicationInstruction(unit, left, right, type, assigns).add()
}

compute_reciprocal(divider: large) {
	a = 0 as u64
	result = 0 as u64

	loop (i = 0, i < 64, i++) {
		x = a + 1
		y = (2 <| i) as u64
		r = y / x

		if r >= divider {
			a = x
			result = result | (1 <| [63 - i])
		}

		a *= 2
	}

	=> result
}

build_division_operator(unit: Unit, modulus: bool, operator: OperatorNode, assigns: bool) {
	type = operator.get_type().(Number).type

	access = ACCESS_READ
	if assigns { access = ACCESS_WRITE }

	left = references.get(unit, operator.first, access)
	right = references.get(unit, operator.last, ACCESS_READ)
	unsigned = is_unsigned(operator.first.get_type().format)

	=> DivisionInstruction(unit, modulus, left, right, type, assigns, unsigned).add()
}

# Summary:  Builds bitwise operations such as AND, XOR and OR which can assign the result if specified
build_bitwise_operator(unit: Unit, node: OperatorNode, assigns: bool) {
	access = ACCESS_READ
	if assigns { access = ACCESS_WRITE }

	left = references.get(unit, node.first, access)
	right = references.get(unit, node.last, ACCESS_READ)
	type = node.get_type().(Number).type

	operator = node.operator

	if operator == Operators.BITWISE_AND or operator == Operators.ASSIGN_BITWISE_AND => BitwiseInstruction.create_and(unit, left, right, type, assigns).add()
	if operator == Operators.BITWISE_XOR or operator == Operators.ASSIGN_BITWISE_XOR => BitwiseInstruction.create_xor(unit, left, right, type, assigns).add()
	if operator == Operators.BITWISE_OR or operator == Operators.ASSIGN_BITWISE_OR => BitwiseInstruction.create_or(unit, left, right, type, assigns).add()

	abort('Unsupported bitwise operation')
}

# Summary: Builds a left shift operation which can not assign
build_shift_left(unit: Unit, shift: OperatorNode) {
	left = references.get(unit, shift.first, ACCESS_READ)
	right = references.get(unit, shift.first, ACCESS_READ)
	=> BitwiseInstruction.create_shift_left(unit, left, right, SYSTEM_FORMAT).add()
}

# Summary: Builds a right shift operation which can not assign
build_shift_right(unit: Unit, shift: OperatorNode) {
	left = references.get(unit, shift.first, ACCESS_READ)
	right = references.get(unit, shift.first, ACCESS_READ)
	=> BitwiseInstruction.create_shift_right(unit, left, right, SYSTEM_FORMAT).add()
}

# Summary: Builds a not operation which can not assign and work with booleans as well
build_not(unit: Unit, node: NotNode) {
	type = node.first.get_type()

	if primitives.is_primitive(type, primitives.BOOL) {
		value = references.get(unit, node.first, ACCESS_READ)
		=> BitwiseInstruction.create_xor(unit, value, Result(ConstantHandle(1), SYSTEM_FORMAT), value.format, false).add()
	}

	=> SingleParameterInstruction.create_not(unit, references.get(unit, node.first, SYSTEM_FORMAT)).add()
}

# Summary: Builds a negation operation which can not assign
build_negate(unit: Unit, node: NegateNode) {
	is_decimal = node.get_type().format == FORMAT_DECIMAL

	if settings.is_x64 and is_decimal {}

	=> SingleParameterInstruction.create_negate(unit, references.get(unit, node.first, ACCESS_READ), is_decimal).add()
}

build_assign_operator(unit: Unit, node: OperatorNode) {
	left = references.get(unit, node.first, ACCESS_WRITE)
	right = references.get(unit, node.last, ACCESS_READ)

	local = try_get_local_variable(unit, node.first, left)

	# Check if the destination represents a local variable and ensure the assignment is not conditional
	# TODO: Add node.condition == none
	if local != none and not settings.is_debugging_enabled {
		=> SetVariableInstruction(unit, local, right).add()
	}

	# Externally used variables need an immediate update
	# TODO: Conditions
	=> MoveInstruction(unit, left, right).add()
}

build_arithmetic(unit: Unit, node: OperatorNode) {
	operator = node.operator

	if operator == Operators.ASSIGN {
		unit.add_debug_position(node)
		=> build_assign_operator(unit, node)
	}

	if operator == Operators.ADD => build_addition_operator(unit, node, false)
	if operator == Operators.SUBTRACT => build_subtraction_operator(unit, node, false)
	if operator == Operators.MULTIPLY => build_multiplication_operator(unit, node, false)
	if operator == Operators.DIVIDE => build_division_operator(unit, false, node, false)
	if operator == Operators.MODULUS => build_division_operator(unit, true, node, false)
	if operator == Operators.BITWISE_AND or operator == Operators.BITWISE_XOR or operator == Operators.BITWISE_OR => build_bitwise_operator(unit, node, false)
	if operator == Operators.SHIFT_LEFT => build_shift_left(unit, node)
	if operator == Operators.SHIFT_RIGHT => build_shift_right(unit, node)

	unit.add_debug_position(node)
	if operator == Operators.ASSIGN_ADD => build_addition_operator(unit, node, true)
	if operator == Operators.ASSIGN_SUBTRACT => build_subtraction_operator(unit, node, true)
	if operator == Operators.ASSIGN_MULTIPLY => build_multiplication_operator(unit, node, true)
	if operator == Operators.ASSIGN_DIVIDE => build_division_operator(unit, false, node, true)
	if operator == Operators.ASSIGN_MODULUS => build_division_operator(unit, true, node, true)
	if operator == Operators.ASSIGN_BITWISE_AND or operator == Operators.ASSIGN_BITWISE_XOR or operator == Operators.ASSIGN_BITWISE_OR => build_bitwise_operator(unit, node, true)

	abort('Missing operator node implementation')
}

build_return(unit: Unit, node: ReturnNode) {
	if node.value != none {
		from = node.value.get_type()
		to = unit.function.return_type
		# TODO: Support casting
		value = references.get(unit, node.value, ACCESS_READ)

		=> ReturnInstruction(unit, value, unit.function.return_type).add()
	}

	=> ReturnInstruction(unit, none as Result, unit.function.return_type).add()
}

get_member_function_call(unit: Unit, function: FunctionNode, left: Node, type: Type) {
	# Static functions can not access any instance data
	if function.function.is_static => calls.build(unit, function)

	# Retrieve the context where the function is defined
	primary = function.function.metadata.find_type_parent()
	self = references.get(unit, left, ACCESS_READ) as Result

	# If the function is not defined inside the type of the self pointer, it means it must have been defined in its supertypes, therefore casting is needed
	if primary != type { self = casts.cast(unit, self, type, primary) }

	=> calls.build(unit, self, function)
}

build_link(unit: Unit, node: LinkNode, mode: large) {
	type = node.first.get_type()

	if node.last.match(NODE_VARIABLE) {
		member = node.last.(VariableNode).variable

		# Link nodes can also access static variables for example
		if member.is_global => references.get_variable(unit, member, mode)

		left = references.get(unit, node.first, ACCESS_READ) as Result
		alignment = member.get_alignment(type)

		=> GetObjectPointerInstruction(unit, member, left, alignment, mode).add()
	}

	if not node.last.match(NODE_FUNCTION) abort('Unsupported member node')

	=> get_member_function_call(unit, node.last as FunctionNode, node.first, type)
}

build_accessor(unit: Unit, node: AccessorNode, mode: large) {
	start = references.get(unit, node.first, ACCESS_READ) as Result
	offset = references.get(unit, node.last.first, ACCESS_READ) as Result

	=> GetMemoryAddressInstruction(unit, node.format, start, offset, node.stride).add()
}

build_childs(unit: Unit, node: Node) {
	result = none as Result

	loop iterator in node {
		result = references.get(unit, iterator, ACCESS_READ)
	}

	if result != none => result
	=> Result()
}

build(unit: Unit, node: Node) {
	=> when(node.instance) {
		NODE_ACCESSOR => build_accessor(unit, node, ACCESS_READ)
		NODE_CAST => casts.build(unit, node as CastNode, ACCESS_READ)
		NODE_DISABLED => Result()
		NODE_ELSE => Result()
		NODE_ELSE_IF => Result()
		NODE_FUNCTION => calls.build(unit, node as FunctionNode)
		NODE_IF => conditionals.start(unit, node as IfNode) as Result
		NODE_LINK => build_link(unit, node as LinkNode, ACCESS_READ)
		NODE_LOOP => loops.build(unit, node as LoopNode)
		NODE_NOT => build_not(unit, node as NotNode)
		NODE_NEGATE => build_negate(unit, node as NegateNode)
		NODE_OPERATOR => build_arithmetic(unit, node as OperatorNode)
		NODE_RETURN => build_return(unit, node as ReturnNode)
		NODE_STACK_ADDRESS => AllocateStackInstruction(unit, node as StackAddressNode).add()
		else => build_childs(unit, node)
	}
}