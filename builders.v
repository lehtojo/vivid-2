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

	if operator == Operators.ADD => build_addition_operator(unit, node, false)
	if operator == Operators.ASSIGN_ADD => build_addition_operator(unit, node, true)

	if operator == Operators.SUBTRACT => build_subtraction_operator(unit, node, false)
	if operator == Operators.ASSIGN_SUBTRACT => build_subtraction_operator(unit, node, true)
	
	# unit.add_debug_position(node)
	if operator == Operators.ASSIGN => build_assign_operator(unit, node)

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
		NODE_OPERATOR => build_arithmetic(unit, node as OperatorNode)
		NODE_RETURN => build_return(unit, node as ReturnNode)
		else => build_childs(unit, node)
	}
}