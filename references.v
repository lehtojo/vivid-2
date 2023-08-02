ACCESS_READ = 1
ACCESS_WRITE = 2

namespace references

create_constant_number(value: large, format: large): Handle {
	return ConstantHandle(value, format)
}

create_variable_handle(unit: Unit, variable: Variable, mode: large): Handle {
	category = variable.category

	if category == VARIABLE_CATEGORY_PARAMETER return StackVariableHandle(unit, variable)
	else category == VARIABLE_CATEGORY_LOCAL {
		if variable.is_inlined {
			return StackAllocationHandle(unit, variable.type.allocation_size, variable.parent.identity + `.` + variable.name)
		}

		return StackVariableHandle(unit, variable)
	}
	else category == VARIABLE_CATEGORY_MEMBER {
		abort('Can not access member variables here')
	}
	else category == VARIABLE_CATEGORY_GLOBAL {
		if variable.type.is_pack {
			abort('Global packs are not supported yet')
		}

		address = variable.is_inlined or variable.type.is_array_type
		handle = DataSectionHandle(variable.get_static_name(), address)

		if settings.use_indirect_access_tables { handle.modifier = DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE }

		return handle
	}

	abort('Unsupported variable category')
}

get_variable_debug(unit: Unit, variable: Variable, mode: large): Result {
	if variable.type.is_pack return unit.get_variable_value(variable)

	return GetVariableInstruction(unit, variable, mode).add()
}

get_variable(unit: Unit, variable: Variable, mode: large): Result {
	if settings.is_debugging_enabled return get_variable_debug(unit, variable, mode)

	if variable.is_static or variable.is_inlined {
		return GetVariableInstruction(unit, variable, mode).add()
	}

	return unit.get_variable_value(variable)
}

get_variable(unit: Unit, node: VariableNode, mode: large): Result {
	if node.variable.is_member and not node.variable.is_static {
		if unit.self == none abort('Missing self pointer')

		self = VariableNode(unit.self, node.start)
		member = VariableNode(node.variable, node.start)
		return builders.build_link(unit, LinkNode(self, member, node.start), mode)
	}

	return get_variable(unit, node.variable, mode)
}

get_constant(unit: Unit, node: NumberNode): Result {
	return GetConstantInstruction(unit, node.value, is_unsigned(node.format), node.format == FORMAT_DECIMAL).add()
}

get(unit: Unit, node: Node, mode: large): Result {
	instance = node.instance

	if instance == NODE_VARIABLE return get_variable(unit, node as VariableNode, mode)
	else instance == NODE_NUMBER return get_constant(unit, node as NumberNode)
	else instance == NODE_LINK return builders.build_link(unit, node, mode)
	else instance == NODE_ACCESSOR return builders.build_accessor(unit, node, mode)
	return builders.build(unit, node) as Result
}