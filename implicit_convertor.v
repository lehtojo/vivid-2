namespace implicit_convertor

constant IMPLICIT_CONVERTOR_FUNCTION = 'from'

private has_convertor_function(from: Type, to: Type): bool {
	# Member function is a convertor function when
	# - its name is <IMPLICIT_CONVERTOR_FUNCTION>
	# - accepts exactly one argument of source type
	# - it is shared
	# - returns destination type

	# Attempt to get all convertor functions
	convertor_function_name = String(IMPLICIT_CONVERTOR_FUNCTION)
	if not to.functions.contains_key(convertor_function_name) return false
	convertors = to.functions[convertor_function_name]

	# Attempt to find an overload that accepts the source type as its only argument
	overload = convertors.get_overload([ from ])
	if overload === none return false

	# Ensure the overload is shared
	if not overload.is_static return false

	# Ensure the overload has an explicit return type that matches the destination type
	return overload.return_type === to
}

private try_conversion(node: Node, from: Type, to: Type): _ {
	# If the source type is not compatible with the destination type, we can attempt an implicit conversion
	if common.compatible(from, to) return

	# Attempt to find a convertor function
	if not has_convertor_function(from, to) return

	# Call the shared convertor function with the specified value as its argument
	call = UnresolvedFunction(String(IMPLICIT_CONVERTOR_FUNCTION), node.start)
	conversion = LinkNode(TypeNode(to, node.start), call)

	# Replace the specified value with the conversion
	node.replace(conversion)

	# Pass the value to the call
	call.add(node)
}

process(context: Context, node: ReturnNode): _ {
	if node.first === none return

	# Attempt to get the type of the returned value
	returned_type = node.first.try_get_type()
	if returned_type === none or returned_type.is_unresolved return

	# Find the function we are inside of
	implementation = context.find_implementation_parent()
	if implementation === none return

	# Get the return type of the function
	return_type = implementation.return_type
	if return_type === none or return_type.is_unresolved return

	try_conversion(node.first, returned_type, return_type)
}

private process_assignment_operator(context: Context, node: OperatorNode): _ {
	# Attempt to get the type of the right-hand side
	right_type = node.last.try_get_type()
	if right_type === none or right_type.is_unresolved return

	# Attempt to get the type of the left-hand side
	left_type = node.first.try_get_type()
	if left_type === none or left_type.is_unresolved return

	try_conversion(node.last, right_type, left_type)
}

process(context: Context, node: OperatorNode): _ {
	operator = node.operator

	if operator === Operators.ASSIGN process_assignment_operator(context, node)
}