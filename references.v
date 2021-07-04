ACCESS_READ = 1
ACCESS_WRITE = 2

namespace references

create_constant_number(value: large, format: large) {
	=> ConstantHandle(value, format)
}

create_variable_handle(unit: Unit, variable: Variable) {
	handle = none as Handle
	category = variable.category

	if category == VARIABLE_CATEGORY_PARAMETER => StackVariableHandle(unit, variable)
	else category == VARIABLE_CATEGORY_LOCAL {
		# TODO: Support inline handles
		=> StackVariableHandle(unit, variable)
	}
	else category == VARIABLE_CATEGORY_MEMBER {
		abort('Can not create member variables here')
		=> none as Handle
	}
	else category == VARIABLE_CATEGORY_GLOBAL {
		# TODO: Support global variables
		=> none as Handle
	}

	abort('Unsupported variable category')
}

get_variable(unit: Unit, variable: Variable, mode: large) {
	if not settings.is_debugging_enabled and unit.is_initialized(variable) => unit.get_variable_value(variable)
	=> GetVariableInstruction(unit, variable, mode).add()
}

get_variable(unit: Unit, node: VariableNode, mode: large) {
	=> get_variable(unit, node.variable, mode)
}

get_constant(unit: Unit, node: NumberNode) {
	=> GetConstantInstruction(unit, node.value, node.type == FORMAT_DECIMAL).add()
}

get(unit: Unit, node: Node, mode: large) {
	instance = node.instance

	if instance == NODE_VARIABLE => get_variable(unit, node as VariableNode, mode)
	else instance == NODE_NUMBER => get_constant(unit, node as NumberNode)
	=> builders.build(unit, node) as Result
}