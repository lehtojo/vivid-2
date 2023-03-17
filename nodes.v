NODE_FUNCTION_DEFINITION = 1
NODE_LINK = 1 <| 1
NODE_NUMBER = 1 <| 2
NODE_OPERATOR = 1 <| 3
NODE_SCOPE = 1 <| 4
NODE_TYPE = 1 <| 5
NODE_TYPE_DEFINITION = 1 <| 6
NODE_UNRESOLVED_IDENTIFIER = 1 <| 7
NODE_VARIABLE = 1 <| 8
NODE_STRING = 1 <| 9
NODE_LIST = 1 <| 10
NODE_UNRESOLVED_FUNCTION = 1 <| 11
NODE_CONSTRUCTION = 1 <| 12
NODE_FUNCTION = 1 <| 13
NODE_RETURN = 1 <| 14
NODE_PARENTHESIS = 1 <| 15
NODE_IF = 1 <| 16
NODE_ELSE_IF = 1 <| 17
NODE_LOOP = 1 <| 18
NODE_CAST = 1 <| 19
NODE_COMMAND = 1 <| 20
NODE_NEGATE = 1 <| 21
NODE_ELSE = 1 <| 22
NODE_INCREMENT = 1 <| 23
NODE_DECREMENT = 1 <| 24
NODE_NOT = 1 <| 25
NODE_ACCESSOR = 1 <| 26
NODE_INLINE = 1 <| 27
NODE_NORMAL = 1 <| 28
NODE_CALL = 1 <| 29
NODE_DATA_POINTER = 1 <| 30
NODE_STACK_ADDRESS = 1 <| 31
NODE_DISABLED = 1 <| 32
NODE_LABEL = 1 <| 33
NODE_JUMP = 1 <| 34
NODE_SECTION = 1 <| 35
NODE_NAMESPACE = 1 <| 36
NODE_INSPECTION = 1 <| 37
NODE_COMPILES = 1 <| 38
NODE_IS = 1 <| 39
NODE_LAMBDA = 1 <| 40
NODE_HAS = 1 <| 41
NODE_EXTENSION_FUNCTION = 1 <| 42
NODE_WHEN = 1 <| 43
NODE_LIST_CONSTRUCTION = 1 <| 44
NODE_PACK_CONSTRUCTION = 1 <| 45
NODE_PACK = 1 <| 46
NODE_UNDEFINED = 1 <| 47
NODE_OBJECT_LINK = 1 <| 48
NODE_OBJECT_UNLINK = 1 <| 49
NODE_USING = 1 <| 50

Node NumberNode {
	value: large
	format: large
	type: Type

	init(format: large, value: large, start: Position) {
		this.instance = NODE_NUMBER
		this.start = start
		this.format = format
		this.value = value
	}

	negate(): NumberNode {
		if format == FORMAT_DECIMAL {
			value = value ¤ [1 <| 63]
		}
		else {
			value = -value
		}

		return this
	}

	convert(format: large): _ {
		if format == FORMAT_DECIMAL {
			if this.format != FORMAT_DECIMAL { this.value = decimal_to_bits(value as decimal) }
		}
		else {
			if this.format == FORMAT_DECIMAL { this.value = bits_to_decimal(value) }
		}

		this.format = format
	}

	override is_equal(other: Node) {
		return instance == other.instance and value == other.(NumberNode).value and format == other.(NumberNode).format and type == other.(NumberNode).type
	}

	override try_get_type() {
		if type == none { type = numbers.get(format) }
		return type
	}

	override copy() {
		return NumberNode(format, value, start)
	}

	override string() {
		if format == FORMAT_DECIMAL return "Decimal Number " + to_string(bits_to_decimal(value))
		return "Number " + to_string(value)
	}
}

Node OperatorNode {
	operator: Operator

	init(operator: Operator) {
		this.instance = NODE_OPERATOR
		this.operator = operator
		this.is_resolvable = true
	}

	init(operator: Operator, start: Position) {
		this.instance = NODE_OPERATOR
		this.start = start
		this.operator = operator
		this.is_resolvable = true
	}

	set_operands(left: Node, right: Node): OperatorNode {
		add(left)
		add(right)
		return this
	}

	private try_resolve_as_setter_accessor(): Node {
		if operator != Operators.ASSIGN return none as Node

		# Since the left node represents an accessor, its first node must represent the target object
		object = first.first
		type = object.try_get_type()

		if type == none or not type.is_local_function_declared(String(Operators.ACCESSOR_SETTER_FUNCTION_IDENTIFIER)) return none as Node

		# Since the left node represents an accessor, its last node must represent its arguments
		arguments = first.last

		# Since the current node is the assign-operator, the right node must represent the assigned value which should be the last parameter
		arguments.add(last)

		return create_operator_overload_function_call(object, String(Operators.ACCESSOR_SETTER_FUNCTION_IDENTIFIER), arguments)
	}

	private create_operator_overload_function_call(object: Node, function: String, arguments: Node): LinkNode {
		return LinkNode(object, UnresolvedFunction(function, start).set_arguments(arguments), start)
	}

	override resolve(context: Context) {
		# First resolve any problems in the other nodes
		resolver.resolve(context, first)
		resolver.resolve(context, last)

		# Check if the left node represents an accessor and if it is being assigned a value
		if operator.type == OPERATOR_TYPE_ASSIGNMENT and first.match(NODE_ACCESSOR) {
			result = try_resolve_as_setter_accessor()
			if result != none return result
		}

		# Try to resolve this operator node as an operator overload function call
		type = first.try_get_type()
		if type == none return none as Node

		if not type.is_operator_overloaded(operator) return none as Node

		# Retrieve the function name corresponding to the operator of this node
		overload = Operators.overloads[operator]
		arguments = Node()
		arguments.add(last)

		return create_operator_overload_function_call(first, overload, arguments)
	}

	# Summary:
	# Returns whether the user is attempting to modify a memory address
	private is_address_modification(left_type: Type, right_type: Type): bool {
		if left_type === none or right_type === none return false

		# The right operand must be an integer type
		if not right_type.is_number or right_type.format === FORMAT_DECIMAL return false

		# Allow links and array types as left operands
		return primitives.is_primitive(left_type, primitives.LINK) or left_type.is_array_type
	}

	private get_classic_type(): Type {
		left_type = first.try_get_type()
		right_type = last.try_get_type()

		if is_address_modification(left_type, right_type) return left_type

		return resolver.get_shared_type(left_type, right_type)
	}

	override is_equal(other: Node) {
		return instance == other.instance and operator == other.(OperatorNode).operator and is_tree_equal(other)
	}

	override try_get_type() {
		return when(operator.type) {
			OPERATOR_TYPE_CLASSIC => get_classic_type()
			OPERATOR_TYPE_COMPARISON => primitives.create_bool()
			OPERATOR_TYPE_ASSIGNMENT => primitives.create_unit()
			OPERATOR_TYPE_LOGICAL => primitives.create_bool()
			else => {
				abort('Independent operator should not be processed here')
				none as Type
			}
		}
	}

	override copy() {
		return OperatorNode(operator, start)
	}

	override string() {
		return "Operator " + operator.identifier
	}
}

Node ScopeNode {
	context: Context
	is_value_returned: bool = false
	end: Position

	init(context: Context, start: Position, end: Position, is_value_returned: bool) {
		this.instance = NODE_SCOPE
		this.context = context
		this.is_value_returned = is_value_returned
		this.start = start
		this.end = end
	}

	override try_get_type() {
		if last === none return none as Type
		return last.try_get_type()
	}

	override is_equal(other: Node) {
		return instance == other.instance and context.identity == other.(ScopeNode).context.identity and is_tree_equal(other)
	}

	override copy() {
		return ScopeNode(context, start, end, is_value_returned)
	}

	override string() {
		return "Scope " + context.identity
	}
}

Node VariableNode {
	variable: Variable

	init(variable: Variable) {
		this.instance = NODE_VARIABLE
		this.variable = variable

		variable.usages.add(this)
	}

	init(variable: Variable, start: Position) {
		this.instance = NODE_VARIABLE
		this.variable = variable
		this.start = start

		variable.usages.add(this)
	}

	override is_equal(other: Node) {
		return instance == other.instance and variable == other.(VariableNode).variable
	}

	override try_get_type() {
		type = variable.type

		if type !== none and type.is_array_type {
			return type.(ArrayType).usage_type
		}

		return type
	}

	override copy() {
		return VariableNode(variable, start)
	}

	override string() {
		return "Variable " + variable.name
	}
}

OperatorNode LinkNode {
	private init(position: Position) {
		OperatorNode.init(Operators.DOT)
		this.instance = NODE_LINK
		this.start = position
		this.is_resolvable = true
	}

	init(left: Node, right: Node) {
		OperatorNode.init(Operators.DOT)
		add(left)
		add(right)
		this.instance = NODE_LINK
		this.is_resolvable = true
	}

	init(left: Node, right: Node, position: Position) {
		OperatorNode.init(Operators.DOT)
		add(left)
		add(right)
		this.instance = NODE_LINK
		this.start = position
		this.is_resolvable = true
	}

	override resolve(environment: Context) {
		# Try to resolve the left node
		resolver.resolve(environment, first)
		primary = first.try_get_type()

		# Do not try to resolve the right node without the type of the left
		if primary == none return none as Node

		if last.match(NODE_UNRESOLVED_FUNCTION) {
			function = last as UnresolvedFunction

			# First, try to resolve the function normally
			result = function.resolve(environment, primary)

			if result != none {
				last.replace(result)
				return none as Node
			}

			# Try to get the parameter types from the function node
			types = resolver.get_types(function)
			if types == none return none as Node

			# Try to form a virtual function call
			result = common.try_get_virtual_function_call(first, primary, function.name, function, types, start)
			if result == none { result = common.try_get_lambda_call(primary, first, function.name, function, types) }

			if result != none {
				result.start = start
				return result
			}
		}
		else last.match(NODE_UNRESOLVED_IDENTIFIER) {
			resolver.resolve(primary, last)
		}
		else {
			# Consider a situation where the right operand is a function call. The function arguments need the environment context to be resolved.
			resolver.resolve(environment, last)
		}

		return none as Node
	}

	override try_get_type() {
		return last.try_get_type()
	}

	# Summary:
	# Returns whether the accessed object is accessible based in the specified environment
	private is_accessible(environment: FunctionImplementation, reads: bool): bool {
		# Only variables and function calls can be checked
		if not last.match(NODE_VARIABLE | NODE_FUNCTION) return true

		context = none as Context
		if last.instance == NODE_VARIABLE { context = last.(VariableNode).variable.parent }
		else { context = last.(FunctionNode).function.parent }

		if context === none or not context.is_type return true

		# Determine which type owns the accessed object
		owner = context as Type

		# Determine the required access level for accessing the object
		modifiers = 0
		if last.instance == NODE_VARIABLE { modifiers = last.(VariableNode).variable.modifiers }
		else { modifiers = last.(FunctionNode).function.metadata.modifiers }

		required_access_level = modifiers & ACCESS_LEVEL_MASK

		# Determine the access level of the requester
		requester = environment.find_type_parent()
		request_access_level = 0

		if requester === owner {
			request_access_level = MODIFIER_PRIVATE
		}
		else {
			if requester !== none and requester.is_type_inherited(owner) { request_access_level = MODIFIER_PROTECTED }
			else { request_access_level = MODIFIER_PUBLIC }
		}

		# 1. Objects can always be read when the access level of the requester is higher or equal to the required level.
		# 2. If writing is not restricted, the access level of the requester must be higher or equal to the required level.
		if reads or not has_flag(modifiers, MODIFIER_READABLE) return request_access_level >= required_access_level

		# Writing is restricted, so the requester must have higher access level
		return request_access_level > required_access_level
	}

	# Summary:
	# Returns whether this link represents a static access that is not allowed.
	# Unallowed static access can be accessing of a non-static member through type.
	is_illegal_static_access(environment: FunctionImplementation): bool {
		# Require the left operand to be a type node
		if first.instance !== NODE_TYPE return false

		accessed_type = first.(TypeNode).type

		is_inside_static_function = environment.is_static
		is_inside_accessed_type = environment.parent.is_type and (environment.parent === accessed_type or environment.parent.(Type).is_type_inherited(accessed_type))

		is_accessed_object_static =
			(last.instance == NODE_VARIABLE and (last.(VariableNode).variable.is_static or last.(VariableNode).variable.is_constant)) or 
			(last.instance == NODE_FUNCTION and last.(FunctionNode).function.is_static) or 
			(last.match(NODE_TYPE | NODE_CONSTRUCTION))

		# If a non-static member variable or function is accessed in static way, return true.
		# Only exception is if we are "inside" the accessed type and not inside a static function.
		# So in other words, non-static members can be accessed through types in the accessed type or if it is inherited.
		return not is_accessed_object_static and not (is_inside_accessed_type and not is_inside_static_function)
	}

	override get_status() {
		# Find the environment context
		environment = try_get_parent_context()
		if environment === none return none as Status

		# Look for the function we are inside of
		environment = environment.find_implementation_parent()
		if environment === none return none as Status

		reads = not common.is_edited(this)

		if not is_accessible(environment as FunctionImplementation, reads) return Status(last.start, 'Can not access the member here')
		if is_illegal_static_access(environment as FunctionImplementation) return Status(last.start, 'Can not access non-shared member this way')

		return none as Status
	}

	override copy() {
		return LinkNode(start)
	}

	override string() {
		return "Link"
	}
}

Node UnresolvedIdentifier {
	value: String

	init(value: String, position: Position) {
		this.instance = NODE_UNRESOLVED_IDENTIFIER
		this.value = value
		this.start = position
		this.is_resolvable = true
	}

	private try_resolve_as_function_pointer(context: Context): Node {
		# TODO: Function pointers
		return none as Node
	}

	override is_equal(other: Node) {
		return instance == other.instance and value == other.(UnresolvedIdentifier).value
	}

	override resolve(context: Context) {
		linked = parent != none and parent.match(NODE_LINK) and previous != none
		result = parser.parse_identifier(context, IdentifierToken(value, start), linked)

		if result.match(NODE_UNRESOLVED_IDENTIFIER) return try_resolve_as_function_pointer(context)
		return result
	}

	override get_status() {
		return Status(start, "Can not resolve identifier " + value)
	}

	override copy() {
		return UnresolvedIdentifier(value, start)
	}

	override string() {
		return "Unresolved Identifier " + value
	}
}

pack CallArgument {
	type: Type
	value: Node
}

Node UnresolvedFunction {
	name: String
	arguments: List<Type>

	init(name: String, position: Position) {
		this.instance = NODE_UNRESOLVED_FUNCTION
		this.name = name
		this.arguments = List<Type>()
		this.start = position
		this.is_resolvable = true
	}

	init(name: String, arguments: List<Type>, position: Position) {
		this.instance = NODE_UNRESOLVED_FUNCTION
		this.name = name
		this.arguments = arguments
		this.start = position
		this.is_resolvable = true
	}

	set_arguments(arguments: Node): UnresolvedFunction {
		loop argument in arguments { add(argument) }
		return this
	}

	private try_resolve_lambda_parameters(primary: Context, call_arguments: List<CallArgument>): _ {
		# Collect all the parameters which are unresolved
		unresolved = call_arguments.filter(i -> i.type == none or i.type.is_unresolved)

		# Ensure all the unresolved parameter types represent lambda types
		if not unresolved.all(i -> i.value.instance == NODE_LAMBDA) or not primary.is_function_declared(name) return

		# Collect all parameter types leaving all lambda types as nulls
		actual_types = call_arguments.map<Type>((i: CallArgument) -> i.type)

		# Find all the functions overloads with the name of this unresolved function
		functions = primary.get_function(name)

		# Find all the function overloads that could accept the currently resolved parameter types
		candidates = functions.overloads.filter(overload -> {
			# Ensure the number of parameters is the same before continuing
			if actual_types.size != overload.parameters.size return false

			# Collect the expected parameter types
			expected_types = overload.parameters.map<Type>((j: Parameter) -> j.type)

			# Determine the final parameter types as follows:
			# - Prefer the actual parameter types over the expected parameter types
			# - If the actual parameter type is not defined, use the expected parameter type
			types = List<Type>(expected_types.size, false)

			loop (i = 0, i < expected_types.size, i++) {
				actual_type = actual_types[i]
				if actual_type != none { types.add(actual_type) }
				else { types.add(expected_types[i]) }
			}

			# Check if the final parameter types pass
			return types.all(i -> i != none and i.is_resolved) and overload.passes(types, arguments)
		})

		# Collect all parameter types but this time filling the unresolved lambda types with incomplete call descriptor types
		loop (i = 0, i < actual_types.size, i++) {
			actual_type = actual_types[i]
			if actual_type != none continue

			actual_types[i] = call_arguments[i].value.(LambdaNode).get_incomplete_type()
		}

		expected_types = none as List<Type>

		# Filter out all candidates where the type of the parameter matching the unresolved lambda type is not a lambda type
		loop (i = candidates.size - 1, i >= 0, i--) {
			expected_types = candidates[i].parameters.map<Type>((i: Parameter) -> i.type)

			loop (j = 0, j < expected_types.size, j++) {
				expected = expected_types[j]
				actual = actual_types[j]

				# Skip all parameter types which do not represent lambda types
				if expected == none or not actual.is_function_type continue

				if not expected.is_function_type {
					# Since the actual parameter type is lambda type and the expected is not, the current candidate can be removed
					candidates.remove_at(i)
					stop
				}
			}
		}

		# Resolve the lambda type only if there is only one option left since the analysis would go too complex
		if candidates.size != 1 return

		match = candidates[]
		expected_types = match.parameters.map<Type>((i: Parameter) -> i.type)

		loop (i = 0, i < expected_types.size, i++) {
			# Skip all parameter types which do not represent lambda types
			# NOTE: It is ensured that when the expected type is a call descriptor the actual type is as well
			if not expected_types[i].is_function_type continue
			expected = expected_types[i] as FunctionType

			actual = actual_types[i] as FunctionType

			# Ensure the parameter types do not conflict
			if expected.parameters.size != actual.parameters.size return

			loop (j = 0, j < expected.parameters.size, j++) {
				expected_parameter = expected.parameters[j]
				actual_parameter = actual.parameters[j]

				# Ensure the parameter types do not conflict
				if actual_parameter !== none and not (expected_parameter.type == actual_parameter.type) return
			}

			# Since none of the parameters conflicted with the expected parameters types, the expected parameter types can be transferred
			loop (j = 0, j < expected.parameters.size, j++) {
				call_arguments[i].value.(LambdaNode).function.parameters[j].type = expected.parameters[j]
			}
		}
	}

	resolve(environment: Context, primary: Context): Node {
		linked = environment != primary

		# Try to resolve all the arguments
		loop argument in this { resolver.resolve(environment, argument) }

		# Try to resolve all the template arguments
		loop (i = 0, i < arguments.size, i++) {
			result = resolver.resolve(environment, arguments[i])
			if result == none continue
			arguments[i] = result
		}

		# Try to collect all argument types and record whether any of them is unresolved
		call_arguments = List<CallArgument>()
		argument_types = List<Type>()
		unresolved = false

		loop argument in this {
			argument_type = argument.try_get_type()
			call_arguments.add(pack { type: argument_type, value: argument })
			argument_types.add(argument_type)
			if argument_type == none or argument_type.is_unresolved { unresolved = true }
		}

		if unresolved {
			try_resolve_lambda_parameters(primary, call_arguments)
			return none as Node
		}

		is_normal_unlinked_call = not linked and arguments.size == 0

		# First, ensure this function can be a lambda call
		if is_normal_unlinked_call {
			# Try to form a lambda function call
			result = common.try_get_lambda_call(environment, name, this as Node, argument_types)

			if result != none {
				result.start = start
				return result
			}
		}

		# Try to find a suitable function by name and parameter types
		function = parser.get_function_by_name(primary, name, argument_types, arguments, linked)

		# Lastly, try to form a virtual function call if the function could not be found
		if function == none and is_normal_unlinked_call {
			result = common.try_get_virtual_function_call(environment, name, this, argument_types, start)

			if result != none {
				result.start = start
				return result
			}
		}

		if function == none return none as Node

		node = FunctionNode(function, start).set_arguments(this)

		if function.is_constructor {
			type = function.find_type_parent()
			if type == none abort('Missing constructor parent type')

			# If the descriptor name is not the same as the function name, it is a direct call rather than a construction
			if not (type.identifier == name) return node
			return ConstructionNode(node, node.start)
		}

		# When the function is a member function and the this function is not part of a link it means that the function needs the self pointer
		if function.is_member and not function.is_static and not linked {
			self = common.get_self_pointer(environment, start)
			return LinkNode(self, node, start)
		}

		return node
	}

	override is_equal(other: Node) {
		return instance == other.instance and name == other.(UnresolvedFunction).name and is_tree_equal(other)
	}

	override resolve(context: Context) {
		return resolve(context, context)
	}

	override copy() {
		return UnresolvedFunction(name, arguments, start)
	}

	override get_status() {
		types = List<Type>()
		loop iterator in this { types.add(iterator.try_get_type()) }
		return Status(start, "Can not find function " + common.to_string(name, types, arguments))
	}

	override string() {
		return "Unresolved Function " + name
	}
}

Node TypeNode {
	type: Type

	init(type: Type) {
		this.instance = NODE_TYPE
		this.type = type
		this.is_resolvable = true
	}

	init(type: Type, position: Position) {
		this.instance = NODE_TYPE
		this.type = type
		this.start = position
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		if type.is_resolved return none as Node

		replacement = resolver.resolve(context, type)
		if replacement == none return none as Node

		type = replacement
		return none as Node
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(TypeNode).type
	}

	override try_get_type() {
		return type
	}

	override get_status() {
		if parent.match(NODE_COMPILES | NODE_INSPECTION | NODE_LINK) or (parent.instance == NODE_CAST and next === none) {
			return none as Status
		}

		return Status(start, 'Can not understand')
	}

	override copy() {
		return TypeNode(type, start)
	}

	override string() {
		return "Type " + type.name
	}
}

Node TypeDefinitionNode {
	type: Type
	blueprint: List<Token>

	init(type: Type, blueprint: List<Token>, position: Position) {
		this.instance = NODE_TYPE_DEFINITION
		this.type = type
		this.blueprint = blueprint
		this.start = position
	}

	parse(): _ {
		# Static types can not be constructed
		if not type.is_static and not type.is_plain type.add_runtime_configuration()

		# Create the body of the type
		parser.parse(this, type, List<Token>(blueprint))
		blueprint.clear()

		# Add all member initializations
		assignments = find_top(i -> i.match(Operators.ASSIGN))

		# Remove all constant and static variable assignments
		loop (i = assignments.size - 1, i >= 0, i--) {
			assignment = assignments[i]
			destination = assignment.first
			if destination.instance != NODE_VARIABLE continue

			variable = destination.(VariableNode).variable
			if not variable.is_static and not variable.is_constant continue

			assignments.remove_at(i)
		}

		type.initialization = assignments

		# Add member initialization to the constructors that have been created before loading the member initializations
		loop constructor in type.constructors.overloads {
			constructor.(Constructor).add_member_initializations()
		}
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(TypeDefinitionNode).type
	}

	override copy() {
		return TypeDefinitionNode(type, blueprint, start)
	}

	override string() {
		return "Type Definition " + type.name
	}
}

Node FunctionDefinitionNode {
	function: Function

	init(function: Function, position: Position) {
		this.instance = NODE_FUNCTION_DEFINITION
		this.function = function
		this.start = position
	}

	override is_equal(other: Node) {
		return instance == other.instance and function == other.(FunctionDefinitionNode).function
	}

	override copy() {
		return FunctionDefinitionNode(function, start)
	}

	override string() {
		return "Function Definition " + function.name
	}
}

Node StringNode {
	text: String
	identifier: String

	init(text: String, position: Position) {
		this.text = text
		this.start = position
		this.instance = NODE_STRING
	}

	init(text: String, identifier: String, position: Position) {
		this.text = text
		this.identifier = identifier
		this.start = position
		this.instance = NODE_STRING
	}

	override is_equal(other: Node) {
		return instance == other.instance and text == other.(StringNode).text
	}

	override try_get_type() {
		return Link()
	}

	override copy() {
		return StringNode(text, identifier, start)
	}

	override string() {
		return "String " + text
	}
}

Node FunctionNode {
	function: FunctionImplementation
	parameters => this

	init(function: FunctionImplementation, position: Position) {
		this.function = function
		this.start = position
		this.instance = NODE_FUNCTION

		function.usages.add(this)
	}

	set_arguments(arguments: Node): FunctionNode {
		loop argument in arguments { add(argument) }
		return this
	}

	override is_equal(other: Node) {
		return instance == other.instance and function == other.(FunctionNode).function and is_tree_equal(other)
	}

	override try_get_type() {
		return function.return_type
	}

	override copy() {
		return FunctionNode(function, start)
	}

	override string() {
		return "Function Call " + function.name
	}
}

Node ConstructionNode {
	allocator => first
	constructor => last as FunctionNode
	has_allocator => first !== last

	is_stack_allocated: bool = false

	init(constructor: FunctionNode, position: Position) {
		this.start = position
		this.instance = NODE_CONSTRUCTION
		this.is_resolvable = true
		add(constructor)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_CONSTRUCTION
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		return none as Node
	}

	override try_get_type() {
		return constructor.function.find_type_parent()
	}

	override get_status() {
		type: Type = try_get_type()
		if type === none return none as Status

		if type.is_static return Status(start, 'Namespaces can not be created as objects')
		if type.is_template_type and not type.is_template_type_variant return Status(start, 'Can not create template type without template arguments')

		return none as Status
	}

	override copy() {
		return ConstructionNode(start)
	}

	override string() {
		return "Construction " + constructor.function.name
	}
}

Node ParenthesisNode {
	init(position: Position) {
		this.start = position
		this.instance = NODE_PARENTHESIS
	}

	override try_get_type() {
		if last == none return none as Type
		return last.try_get_type()
	}

	override copy() {
		return ParenthesisNode(start)
	}

	override string() {
		return "Parenthesis"
	}
}

Node ReturnNode {
	value => first

	init(node: Node, position: Position) {
		this.instance = NODE_RETURN
		this.start = position
		this.is_resolvable = true

		# Add the return value, if it exists
		if node != none add(node)
	}

	override resolve(context: Context) {
		if first !== none resolver.resolve(context, first)
		return none as Node
	}

	override get_status() {
		# Find the environment context
		environment = try_get_parent_context()
		if environment === none return none as Status

		# Look for the function we are inside of
		environment = environment.find_implementation_parent()
		if environment === none return none as Status

		# If this statement has a return value, try to get its type
		return_value_type = none as Type
		if first !== none { return_value_type = first.try_get_type() }

		# Illegal return statements:
		# - Return statement does not have a return value even though the function has a return type
		# - Return statement does have a return value, but the function does not return a value
		# Unit type represents no return type. Exceptionally allow returning units when the return type is unit.
		has_return_type = not primitives.is_primitive(environment.(FunctionImplementation).return_type, primitives.UNIT)
		has_return_value = first !== none and not primitives.is_primitive(return_value_type, primitives.UNIT)
		if has_return_type == has_return_value return none as Status

		if has_return_type return Status(start, 'Can not return without a value, because the function has a return type')
		return Status(start, 'Can not return with a value, because the function does not return a value')
	}

	override copy() {
		return ReturnNode(none as Node, start)
	}

	override string() {
		return "Return"
	}
}

Node IfNode {
	condition_container => first
	condition => common.find_condition(first)
	body => last as ScopeNode

	successor(): Node {
		if next != none and (next.instance == NODE_ELSE_IF or next.instance == NODE_ELSE) return next
		return none as Node
	}

	predecessor(): Node {
		if instance == NODE_IF return none as Node
		if previous != none and (previous.instance == NODE_IF or previous.instance == NODE_ELSE_IF) return previous
		return none as Node
	}

	init(context: Context, condition: Node, body: Node, start: Position, end: Position) {
		this.start = start
		this.instance = NODE_IF
		this.is_resolvable = true

		# Ensure we have access to the environment context
		environment = context.parent
		if environment == none abort('Missing environment context')

		# Create the condition
		node = ScopeNode(Context(environment, NORMAL_CONTEXT), start, end, true)
		node.add(condition)
		add(node)

		# Create the body
		node = ScopeNode(context, start, end, false)
		loop iterator in body { node.add(iterator) }
		add(node)
	}

	init(start: Position) {
		this.instance = NODE_IF
		this.start = start
		this.is_resolvable = true
	}

	init() {
		this.instance = NODE_IF
		this.is_resolvable = true
	}

	get_successors(): List<Node> {
		successors = List<Node>()
		iterator = successor

		loop (iterator != none) {
			if iterator.instance == NODE_ELSE_IF {
				successors.add(iterator)
				iterator = iterator.(ElseIfNode).successor
			}
			else {
				successors.add(iterator)
				stop
			}
		}

		return successors
	}

	get_branches(): List<Node> {
		branches = List<Node>(1, false)
		branches.add(this)

		if successor == none return branches

		if successor.instance == NODE_ELSE_IF {
			branches.add_all(successor.(ElseIfNode).get_branches())
		}
		else {
			branches.add(successor)
		}

		return branches
	}

	override resolve(context: Context) {
		resolver.resolve(context, condition)
		resolver.resolve(body.context, body)

		if successor != none resolver.resolve(context, successor)

		return none as Node
	}

	override copy() {
		return IfNode(start)
	}

	override string() {
		return "If"
	}
}

IfNode ElseIfNode {
	init(context: Context, condition: Node, body: Node, start: Position, end: Position) {
		IfNode.init(context, condition, body, start, end)
		this.instance = NODE_ELSE_IF
	}

	init(start: Position) {
		IfNode.init(start)
		this.instance = NODE_ELSE_IF
	}

	get_root(): IfNode {
		iterator = predecessor

		loop (iterator.instance != NODE_IF) {
			iterator = iterator.(ElseIfNode).predecessor
		}

		return iterator as IfNode
	}

	override copy() {
		return ElseIfNode(start)
	}

	override string() {
		return "Else If"
	}
}

Node ListNode {
	init(position: Position, left: Node, right: Node) {
		this.start = position
		this.instance = NODE_LIST

		add(left)
		add(right)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_LIST
	}

	override copy() {
		return ListNode(start)
	}

	override string() {
		return "List"
	}
}

Node LoopNode {
	context: Context

	steps => first
	body => last as ScopeNode

	initialization => first.first
	action => first.last

	start_label: Label
	exit_label: Label

	is_forever_loop => first == last

	condition_container => first.first.next
	
	condition(): Node {
		return common.find_condition(first.first.next)
	}

	init(context: Context, steps: Node, body: ScopeNode, position: Position) {
		this.context = context
		this.start = position
		this.instance = NODE_LOOP
		this.is_resolvable = true

		if steps != none add(steps)
		add(body)
	}

	init(context: Context, position: Position, start_label: Label, exit_label: Label) {
		this.context = context
		this.start = position
		this.start_label = start_label
		this.exit_label = exit_label
		this.instance = NODE_LOOP
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		if not is_forever_loop {
			resolver.resolve(this.context, initialization)
			resolver.resolve(this.context, condition)
			resolver.resolve(this.context, action)
		}

		resolver.resolve(body.context, body)
		return none as Node
	}

	override copy() {
		return LoopNode(context, start, start_label, exit_label)
	}

	override string() {
		return "Loop"
	}
}

Node CastNode {
	init(object: Node, type: Node, position: Position) {
		this.start = position
		this.instance = NODE_CAST
		this.is_resolvable = true

		add(object)
		add(type)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_CAST
	}

	is_free(): bool {
		from = first.get_type()
		to = get_type()

		a = from.get_supertype_base_offset(to)
		b = to.get_supertype_base_offset(from)

		# 1. Return true if both of the types have nothing in common: a == none and b == none
		# 2. If either a or b is zero, no offset is required, so the cast is free: a == 0 or b == 0
		# Result: (a == none and b == none) or (a == 0 or b == 0)
		if a.empty return b.empty or b.value == 0
		return a.value == 0 or (not b.empty and b.value == 0)
	}

	override try_get_type() {
		return last.try_get_type()
	}

	override resolve(context: Context) {
		# If the casted object is a pack construction:
		# - Set the target type of the pack construction to the target type of this cast
		# - Replace this cast node with the pack construction by returning it
		if first.instance == NODE_PACK_CONSTRUCTION {
			first.(PackConstructionNode).type = last.(TypeNode).type
			return first
		}

		resolver.resolve(context, first)
		resolver.resolve(context, last)

		return none as Node
	}

	override get_status() {
		return none as Status
	}

	override copy() {
		return CastNode(start)
	}

	override string() {
		return "Cast"
	}
}

Node CommandNode {
	instruction: Keyword
	container => find_parent(NODE_LOOP) as LoopNode
	finished: bool = false

	init(instruction: Keyword, position: Position) {
		this.instruction = instruction
		this.start = position
		this.instance = NODE_COMMAND
		this.is_resolvable = true

		if instruction != Keywords.CONTINUE { finished = true }
	}

	init(instruction: Keyword, position: Position, finished: bool) {
		this.instruction = instruction
		this.start = position
		this.finished = finished
		this.instance = NODE_COMMAND
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		if finished return none as Node

		# Try to find the parent loop
		container: LoopNode = this.container
		if container == none return none as Node

		# Continue nodes must execute the action of their parent loops
		if instruction != Keywords.CONTINUE return none as Node

		# Copy the action node if it is present and it is not empty
		if container.is_forever_loop or container.action.first == none {
			finished = true
			return none as Node
		}

		# Execute the action first then the continue
		result = InlineNode(start)
		loop iterator in container.action { result.add(iterator.clone()) }

		result.add(CommandNode(instruction, start, true))
		return result
	}

	override is_equal(other: Node) {
		return instance == other.instance and instruction == other.(CommandNode).instruction
	}

	override copy() {
		return CommandNode(instruction, start, finished)
	}

	override get_status() {
		if finished and container != none return none as Status
		return Status('Keyword must be used inside a loop')
	}

	override string() {
		return instruction.identifier
	}
}

Node NegateNode {
	init(object: Node, position: Position) {
		this.start = position
		this.instance = NODE_NEGATE
		this.is_resolvable = true
		add(object)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_NEGATE
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		return none as Node
	}

	override try_get_type() {
		return first.try_get_type()
	}

	override get_status() {
		type: Type = try_get_type()
		if type === none or type.is_number return none as Status

		return Status(start, 'Can not resolve the negation operation')
	}

	override copy() {
		return NegateNode(start)
	}

	override string() {
		return "Negate"
	}
}

Node ElseNode {
	body => first as ScopeNode

	predecessor(): Node {
		if previous != none and (previous.instance == NODE_IF or previous.instance == NODE_ELSE_IF) return previous
		return none as Node
	}

	init(context: Context, body: Node, start: Position, end: Position) {
		this.start = start
		this.instance = NODE_ELSE
		this.is_resolvable = true

		node = ScopeNode(context, start, end, false)
		loop child in body { node.add(child) }
		add(node)
	}

	init(start: Position) {
		this.start = start
		this.instance = NODE_ELSE
		this.is_resolvable = true
	}

	get_root(): IfNode {
		iterator = predecessor

		loop (iterator.instance != NODE_IF) {
			iterator = iterator.(ElseIfNode).predecessor
		}

		return iterator as IfNode
	}

	override resolve(context: Context) {
		resolver.resolve(body.context, body)
		return none as Node
	}

	override copy() {
		return ElseNode(start)
	}

	override string() {
		return "Else"
	}
}

Node IncrementNode {
	post: bool

	init(destination: Node, position: Position, post: bool) {
		this.instance = NODE_INCREMENT
		this.start = position
		this.post = post
		add(destination)
	}

	init(position: Position, post: bool) {
		this.instance = NODE_INCREMENT
		this.start = position
		this.post = post
	}

	override is_equal(other: Node) {
		return instance == other.instance and post == other.(IncrementNode).post and is_tree_equal(other)
	}

	override try_get_type() {
		return first.try_get_type()
	}

	override copy() {
		return IncrementNode(start, post)
	}

	override string() {
		if post return "PostIncrement"
		return "PreIncrement"
	}
}

Node DecrementNode {
	post: bool

	init(destination: Node, position: Position, post: bool) {
		this.instance = NODE_DECREMENT
		this.start = position
		this.post = post
		add(destination)
	}

	init(position: Position, post: bool) {
		this.instance = NODE_DECREMENT
		this.start = position
		this.post = post
	}

	override is_equal(other: Node) {
		return instance == other.instance and post == other.(DecrementNode).post and is_tree_equal(other)
	}

	override try_get_type() {
		return first.try_get_type()
	}

	override copy() {
		return DecrementNode(start, post)
	}

	override string() {
		if post return "PostDecrement"
		return "PreDecrement"
	}
}

Node NotNode {
	is_bitwise: bool

	init(object: Node, is_bitwise: bool, position: Position) {
		this.start = position
		this.instance = NODE_NOT
		this.is_bitwise = is_bitwise
		add(object)
	}

	init(position: Position, is_bitwise: bool) {
		this.start = position
		this.instance = NODE_NOT
		this.is_bitwise = is_bitwise
	}

	override try_get_type() {
		return first.try_get_type()
	}

	override copy() {
		return NotNode(start, is_bitwise)
	}

	override string() {
		return "Not"
	}
}

Node AccessorNode {
	format => get_type().format

	init(object: Node, arguments: Node, position: Position) {
		this.instance = NODE_ACCESSOR
		this.start = position
		this.is_resolvable = true

		add(object)

		# Automatically pack the arguments into a parenthesis node, if needed
		if arguments.instance != NODE_PARENTHESIS {
			node = ParenthesisNode(position)
			node.add(arguments)
			arguments = node
		}

		add(arguments)
	}

	init(position: Position) {
		this.instance = NODE_ACCESSOR
		this.start = position
		this.is_resolvable = true
	}

	get_stride(): large {
		return get_type().allocation_size
	}

	private create_operator_overload_function_call(object: Node, function: String, arguments: Node): LinkNode {
		return LinkNode(object, UnresolvedFunction(function, start).set_arguments(arguments), start)
	}

	private try_resolve_as_getter_accessor(type: Type): Node {
		# Determine if this node represents a setter accessor
		if parent != none and parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT and parent.first == this {
			# Indexed accessor setter is handled elsewhere
			return none as Node
		}

		# Ensure that the type contains overload for getter accessor
		if not type.is_local_function_declared(String(Operators.ACCESSOR_GETTER_FUNCTION_IDENTIFIER)) return none as Node
		return create_operator_overload_function_call(first, String(Operators.ACCESSOR_GETTER_FUNCTION_IDENTIFIER), last)
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		resolver.resolve(context, last)

		type = first.try_get_type()
		if type == none return none as Node

		return try_resolve_as_getter_accessor(type)
	}

	override try_get_type() {
		type = first.try_get_type()
		if type == none return none as Type
		return type.get_accessor_type()
	}

	override copy() {
		return AccessorNode(start)
	}

	override string() {
		return "Accessor"
	}
}

Node InlineNode {
	init(position: Position) {
		this.start = position
		this.instance = NODE_INLINE
	}

	override is_equal(other: Node) {
		return instance == other.instance and is_tree_equal(other)
	}

	override try_get_type() {
		if last == none return none as Type
		return last.try_get_type()
	}

	override copy() {
		return InlineNode(start)
	}

	override string() {
		return "Inline"
	}
}

FUNCTION_DATA_POINTER = 0
TABLE_DATA_POINTER = 1

Node DataPointerNode {
	offset: large
	type: large

	init(type: large, offset: large, position: Position) {
		this.offset = offset
		this.type = type
		this.start = position
		this.instance = NODE_DATA_POINTER
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset
	}

	override try_get_type() {
		return Link.get_variant(primitives.create_number(primitives.LARGE, FORMAT_INT64))
	}

	override copy() {
		return DataPointerNode(type, offset, start)
	}

	override string() {
		return "Empty Data Pointer"
	}
}

DataPointerNode FunctionDataPointerNode {
	function: FunctionImplementation

	init(function: FunctionImplementation, offset: large, position: Position) {
		DataPointerNode.init(FUNCTION_DATA_POINTER, offset, position)
		this.function = function
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset and function == other.(FunctionDataPointerNode).function
	}

	override copy() {
		return FunctionDataPointerNode(function, offset, start)
	}

	override string() {
		return "Function Data Pointer: " + function.get_fullname()
	}
}

DataPointerNode TableDataPointerNode {
	table: Table

	init(table: Table, offset: large, position: Position) {
		DataPointerNode.init(TABLE_DATA_POINTER, offset, position)
		this.table = table
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset and table == other.(TableDataPointerNode).table
	}

	override copy() {
		return TableDataPointerNode(table, offset, start)
	}

	override string() {
		return "Table Data Pointer: " + table.name
	}
}

Node StackAddressNode {
	type: Type
	identity: String
	bytes => max(type.content_size, 1)

	init(context: Context, type: Type, position: Position) {
		this.type = type
		this.identity = context.create_stack_address()
		this.instance = NODE_STACK_ADDRESS
		this.start = position
	}

	init(type: Type, identity: String, position: Position) {
		this.type = type
		this.identity = identity
		this.instance = NODE_STACK_ADDRESS
		this.start = position
	}

	override is_equal(other: Node) {
		return instance == other.instance and type == other.(StackAddressNode).type
	}

	override try_get_type() {
		return type
	}

	override copy() {
		return StackAddressNode(type, identity, start)
	}

	override string() {
		return "Stack Allocation " + type.name
	}
}

Node LabelNode {
	label: Label

	init(label: Label, position: Position) {
		this.label = label
		this.start = position
		this.instance = NODE_LABEL
	}

	override is_equal(other: Node) {
		return instance == other.instance and label == other.(LabelNode).label
	}

	override copy() {
		return LabelNode(label, start)
	}

	override string() {
		return label.name + ':'
	}
}

Node JumpNode {
	label: Label
	is_conditional: bool = false

	init(label: Label) {
		this.instance = NODE_JUMP
		this.label = label
	}

	init(label: Label, is_conditional: bool) {
		this.instance = NODE_JUMP
		this.label = label
		this.is_conditional = is_conditional
	}

	override is_equal(other: Node) {
		return instance == other.instance and label == other.(JumpNode).label and is_conditional == other.(JumpNode).is_conditional
	}

	override copy() {
		return JumpNode(label, is_conditional)
	}

	override string() {
		return "Jump " + label.name
	}
}

Node SectionNode {
	modifiers: large

	init(modifiers: large, position: Position) {
		this.modifiers = modifiers
		this.start = position
		this.instance = NODE_SECTION
	}

	override copy() {
		return SectionNode(modifiers, start)
	}

	override is_equal(other: Node) {
		return instance == other.instance and modifiers == other.(SectionNode).modifiers
	}
}

Node NamespaceNode {
	name: List<Token>
	blueprint: List<Token>
	is_parsed: bool = false

	init(name: List<Token>, blueprint: List<Token>) {
		this.name = name
		this.blueprint = blueprint
		this.instance = NODE_NAMESPACE
	}

	init(name: List<Token>, blueprint: List<Token>, is_parsed: bool) {
		this.name = name
		this.blueprint = blueprint
		this.instance = NODE_NAMESPACE
		this.is_parsed = is_parsed
	}

	# Summary:
	# Defines the actual namespace from the stored tokens.
	# This does not create the body of the namespace.
	create_namespace(context: Context): Type {
		position = this.name[].position

		loop (i = 0, i < name.size, i += 2) {
			if this.name[i].type != TOKEN_TYPE_IDENTIFIER abort('Invalid namespace tokens')

			name: String = this.name[i].(IdentifierToken).value
			type = context.get_type(name)

			# Use the type if it was found and its parent is the current context
			if type != none and type.parent === context {
				context = type
				continue
			}

			type = Type(context, name, MODIFIER_DEFAULT | MODIFIER_STATIC, position)
			context = type
		}

		return context as Type
	}

	parse(context: Context): _ {
		if is_parsed return
		is_parsed = true

		# Define the actual namespace
		result = create_namespace(context)

		# Create the body of the namespace
		parser.parse(this, result, List<Token>(blueprint))

		# Apply the static modifier to the parsed functions and variables
		loop function in result.functions {
			loop overload in function.value.overloads {
				overload.modifiers = overload.modifiers | MODIFIER_STATIC
			}
		}

		loop variable in result.variables {
			variable.value.modifiers = variable.value.modifiers | MODIFIER_STATIC
		}

		# Parse all the subtypes
		types = find_all(NODE_TYPE_DEFINITION)
		loop iterator in types { iterator.(TypeDefinitionNode).parse() }

		# Parse all subnamespaces
		subnamespaces = find_all(NODE_NAMESPACE)
		loop subnamespace in subnamespaces { subnamespace.(NamespaceNode).parse(result) }
	}

	override copy() {
		return NamespaceNode(name, blueprint, is_parsed)
	}
}

# Summary: Represents a manual call node which is used for lambda and virtual function calls
Node CallNode {
	self => first
	pointer => first.next
	parameters => last
	descriptor: FunctionType

	init(self: Node, pointer: Node, parameters: Node, descriptor: FunctionType, position: Position) {
		this.descriptor = descriptor
		this.start = position
		this.instance = NODE_CALL

		add(self)
		add(pointer)
		add(ListNode(parameters.start))

		loop parameter in parameters { last.add(parameter) }
	}

	init(descriptor: FunctionType, position: Position) {
		this.descriptor = descriptor
		this.start = position
		this.instance = NODE_CALL
	}

	override try_get_type() {
		return descriptor.return_type
	}

	override copy() {
		return CallNode(descriptor, start)
	}

	override string() {
		return "Call"
	}
}

INSPECTION_TYPE_NAME = 0
INSPECTION_TYPE_SIZE = 1
INSPECTION_TYPE_STRIDE = 2

Node InspectionNode {
	type: large
	
	init(type: large, node: Node, position: Position) {
		this.type = type
		this.instance = NODE_INSPECTION
		this.is_resolvable = true
		this.start = position
		add(node)
	}

	init(type: large, position: Position) {
		this.type = type
		this.instance = NODE_INSPECTION
		this.is_resolvable = true
		this.start = position
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		return none as Node
	}

	override get_status() {
		type: Type = try_get_type()
		if type == none or type.is_unresolved return Status(start, 'Can not resolve the type of the inspected object')
		return none as Status
	}

	override try_get_type() {
		if type == INSPECTION_TYPE_NAME return Link()
		return primitives.create_number(primitives.LARGE, FORMAT_INT64)
	}

	override copy() {
		return InspectionNode(type, start)
	}

	override string() {
		if type == INSPECTION_TYPE_NAME return "Name of"
		return "Size of"
	}
}

# Summary: Represents a node which outputs true if the content of the node is compiled successfully otherwise it returns false
Node CompilesNode {
	init(position: Position) {
		this.start = position
		this.instance = NODE_COMPILES
	}

	override copy() {
		return CompilesNode(start)
	}

	override try_get_type() {
		return primitives.create_bool()
	}
}

Node IsNode {
	type: Type
	result => last.(VariableNode).variable
	
	has_result_variable => first != last

	init(object: Node, type: Type, variable: Variable, position: Position) {
		this.type = type
		this.start = position
		this.instance = NODE_IS
		this.is_resolvable = true

		add(object)
		if variable != none add(VariableNode(variable, position))
	}

	init(type: Type, position: Position) {
		this.type = type
		this.start = position
		this.instance = NODE_IS
		this.is_resolvable = true
	}

	override try_get_type() {
		return primitives.create_bool()
	}

	override resolve(context: Context) {
		# Try to resolve the inspected object
		resolver.resolve(context, first)

		# Try to resolve the type
		resolved = resolver.resolve(context, type)
		if resolved != none { type = resolved }

		return none as Node
	}

	override get_status() {
		if type.is_unresolved return Status(start, 'Can not resolve the condition type')
		return first.get_status()
	}

	override copy() {
		return IsNode(type, start)
	}

	override string() {
		return "Is"
	}
}

Node LambdaNode {
	status: Status
	function: Function
	implementation: FunctionImplementation

	init(function: Function, position: Position) {
		this.function = function
		this.start = position
		this.status = Status(position, 'Can not resolve parameter types of this lambda')
		this.instance = NODE_LAMBDA
		this.is_resolvable = true
	}

	init(implementation: FunctionImplementation, position: Position) {
		this.implementation = implementation
		this.function = implementation.metadata
		this.start = position
		this.status = Status()
		this.instance = NODE_LAMBDA
		this.is_resolvable = true
	}

	init(status: Status, function: Function, implementation: FunctionImplementation, position: Position) {
		this.implementation = implementation
		this.function = function
		this.start = position
		this.status = status
		this.instance = NODE_LAMBDA
		this.is_resolvable = true
	}

	get_parameter_types(): List<Type> {
		parameter_types = List<Type>(function.parameters.size, false)
		loop parameter in function.parameters { parameter_types.add(parameter.type) }
		return parameter_types
	}

	get_incomplete_type(): FunctionType {
		return_type = none as Type
		if implementation != none { return_type = implementation.return_type }
		return FunctionType(get_parameter_types(), return_type, start)
	}

	override resolve(context: Context) {
		if implementation != none {
			status = Status()
			return none as Node
		}

		# Try to resolve all parameter types
		loop parameter in function.parameters {
			if parameter.type == none continue

			if parameter.type.is_unresolved {
				# Try to resolve the parameter type
				type = resolver.resolve(context, parameter.type)
				if type != none { parameter.type = type }
			}
		}

		# Before continuing, ensure all parameters are resolved
		loop parameter in function.parameters {
			if parameter.type == none or parameter.type.is_unresolved return none as Node
		}

		status = Status()
		implementation = function.implement(get_parameter_types())
		return none as Node
	}

	override try_get_type() {
		# Before returning the type, verify the lambda is implemented and the return type is resolved
		if implementation === none or implementation.return_type === none or implementation.return_type.is_unresolved return none as Type

		# Note: Parameter types are resolved, because the implementation can not exist without them
		return get_incomplete_type()
	}

	override copy() {
		return LambdaNode(status, function, implementation, start)
	}

	override get_status() {
		return status
	}
}

Node HasNode {
	source => first
	output => last as VariableNode

	init(source: Node, output: VariableNode, position: Position) {
		this.start = position
		this.instance = NODE_HAS
		this.is_resolvable = true

		add(source)
		add(output)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_HAS
		this.is_resolvable = true
	}

	override resolve(environment: Context) {
		resolver.resolve(environment, source)

		# Continue if the type of the source object can be extracted
		type = source.try_get_type()
		if type === none or type.is_unresolved return none as Node

		# Continue if the source object has the required getter function
		get_value_function_overloads = type.get_function(String(reconstruction.RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER))
		if get_value_function_overloads === none return none as Node

		get_value_function = get_value_function_overloads.get_implementation(List<Type>())
		if get_value_function === none or get_value_function.return_type === none or get_value_function.return_type.is_unresolved return none as Node

		# Set the type of the output variable to the return type of the getter function
		output.variable.type = get_value_function.return_type

		return none as Node
	}

	override try_get_type() {
		return primitives.create_bool()
	}

	override get_status() {
		type = source.try_get_type()
		if type == none or type.is_unresolved return Status(source.start, 'Can not resolve the type of the inspected object')

		has_value_function_overloads = type.get_function(String(reconstruction.RUNTIME_HAS_VALUE_FUNCTION_IDENTIFIER))
		if has_value_function_overloads === none return Status(source.start, 'Inspected object does not have a \'has_value(): bool\' function')

		has_value_function = has_value_function_overloads.get_implementation(List<Type>())
		if has_value_function === none or not primitives.is_primitive(has_value_function.return_type, primitives.BOOL) return Status(source.start, 'Inspected object does not have a \'has_value(): bool\' function')

		get_value_function_overloads = type.get_function(String(reconstruction.RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER))
		if get_value_function_overloads === none return Status(source.start, 'Inspected object does not have a \'get_value(): any\' function')

		get_value_function = get_value_function_overloads.get_implementation(List<Type>())
		if get_value_function === none or get_value_function.return_type === none or get_value_function.return_type.is_unresolved return Status(source.start, 'Inspected object does not have a \'get_value(): any\' function')

		return none as Status
	}

	override copy() {
		return HasNode(start)
	}

	override string() {
		return "Has"
	}
}

Node ExtensionFunctionNode {
	destination: Type
	descriptor: FunctionToken
	template_parameters: List<String>
	body: List<Token>
	end: Position

	init(destination: Type, descriptor: FunctionToken, body: List<Token>, start: Position, end: Position) {
		this.destination = destination
		this.descriptor = descriptor
		this.template_parameters = List<String>()
		this.body = body
		this.start = start
		this.end = end
		this.instance = NODE_EXTENSION_FUNCTION
		this.is_resolvable = true
	}

	init(destination: Type, descriptor: FunctionToken, template_parameters: List<String>, body: List<Token>, start: Position, end: Position) {
		this.destination = destination
		this.descriptor = descriptor
		this.template_parameters = template_parameters
		this.body = body
		this.start = start
		this.end = end
		this.instance = NODE_EXTENSION_FUNCTION
		this.is_resolvable = true
	}

	override resolve(context: Context) {
		if destination.is_unresolved {
			resolved = resolver.resolve(context, destination)
			if resolved == none return none as Node
			this.destination = resolved
		}

		function = none as Function

		if template_parameters.size > 0 {
			function = TemplateFunction(destination, MODIFIER_DEFAULT, descriptor.name, template_parameters, descriptor.parameters.tokens, start, end)
			function.(TemplateFunction).initialize()

			token = ParenthesisToken(`{`, start, end, body)
			function.blueprint.add(descriptor)
			function.blueprint.add(token)
		}
		else {
			function = Function(destination, MODIFIER_DEFAULT, descriptor.name, body, start, end)

			# Parse the parameters
			result = descriptor.get_parameters(function)
			if result has not parameters return none as Node

			function.parameters.add_all(parameters)
		}

		# If the destination is a namespace, mark the function as a static function
		if destination.is_static { function.modifiers = function.modifiers | MODIFIER_STATIC }

		destination.(Context).declare(function)
		return FunctionDefinitionNode(function, start)
	}

	override get_status() {
		message = "Can not resolve the destination " + destination.string() + ' of the extension function'
		return Status(start, message)
	}

	override copy() {
		return ExtensionFunctionNode(destination, descriptor, template_parameters, body, start, end)
	}

	override string() {
		return "Extension function"
	}
}

Node WhenNode {
	value => first
	inspected => value.next as VariableNode
	sections => last

	init(value: Node, inspected: VariableNode, sections: List<Node>, position: Position) {
		this.start = position
		this.instance = NODE_WHEN
		this.is_resolvable = true

		add(value)
		add(inspected)
		add(Node())

		loop section in sections {
			this.sections.add(section)
		}
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_WHEN
		this.is_resolvable = true
	}

	override try_get_type() {
		types = List<Type>()

		loop section in sections {
			body = get_section_body(section)
			value = body.last

			if value == none return none as Type

			type = value.try_get_type()
			if type == none return none as Type

			types.add(type)
		}

		return resolver.get_shared_type(types)
	}

	get_section_body(section: Node): ScopeNode {
		return when(section.instance) {
			NODE_IF => section.(IfNode).body
			NODE_ELSE_IF => section.(ElseIfNode).body
			NODE_ELSE => section.(ElseNode).body
			else => abort('Unsupported section') as ScopeNode
		}
	}

	override resolve(environment: Context) {
		resolver.resolve(environment, value)
		resolver.resolve(environment, inspected)
		resolver.resolve(environment, sections)
		return none as Node
	}

	override get_status() {
		inspected_type = value.try_get_type()
		inspected.variable.type = inspected_type

		if inspected_type == none return Status(inspected.start, 'Can not resolve the type of the inspected value')

		types = List<Type>()

		loop section in sections {
			body = get_section_body(section)
			value = body.last

			if value == none return Status(start, 'When-statement has an empty section')

			type = value.try_get_type()
			if type == none return Status(value.start, 'Can not resolve the section return type')
			
			types.add(type)
		}

		section_return_type = resolver.get_shared_type(types)
		if section_return_type == none return Status(start, 'Sections do not have a shared return type')

		return none as Status
	}

	override copy() {
		return WhenNode(start)
	}

	override string() {
		return "When"
	}
}

Node ListConstructionNode {
	type: Type = none

	init(elements: Node, position: Position) {
		this.instance = NODE_LIST_CONSTRUCTION
		this.start = position
		this.is_resolvable = true

		loop element in elements {
			add(element)
		}
	}

	init(type: Type, position: Position) {
		this.instance = NODE_LIST_CONSTRUCTION
		this.type = type
		this.start = position
		this.is_resolvable = true
	}

	override try_get_type() {
		# If the type is already set, return it
		if type != none return type

		# Resolve the type of a single element
		element_types = resolver.get_types(this)
		if element_types == none return none as Type
		element_type = resolver.get_shared_type(element_types)
		if element_type == none return none as Type

		# Try to find the environment context
		environment = try_get_parent_context()
		if environment == none return none as Type

		list_type = environment.get_type(String(parser.STANDARD_LIST_TYPE))
		if list_type == none or not list_type.is_template_type return none as Type

		# Get a list type with the resolved element type
		type = list_type.(TemplateType).get_variant([ element_type ])
		type.constructors.get_implementation(List<Type>())
		type.get_function(String(parser.STANDARD_LIST_ADDER)).get_implementation(element_type)
		return type
	}

	override resolve(context: Context) {
		loop element in this {
			resolver.resolve(context, element)
		}

		return none as Node
	}

	override get_status() {
		try_get_type()

		if type == none return Status(start, 'Can not resolve the shared type between the elements')

		return none as Status
	}

	override copy() {
		return ListConstructionNode(type, start)
	}

	override string() {
		elements: List<String> = List<String>()
		loop element in this { elements.add(element.string()) }

		return "[ " + String.join(", ", elements) + ' ]'
	}
}

Node PackConstructionNode {
	type: Type = none
	members: List<String>

	init(members: List<String>, arguments: List<Node>, position: Position) {
		this.instance = NODE_PACK_CONSTRUCTION
		this.start = position
		this.members = members
		this.is_resolvable = true

		# Add the arguments as children
		loop argument in arguments {
			add(argument)
		}
	}

	init(type: Type, members: List<String>, position: Position) {
		this.instance = NODE_PACK_CONSTRUCTION
		this.start = position
		this.type = type
		this.members = members
		this.is_resolvable = true
	}

	override try_get_type() {
		return type
	}

	validate_member_names(): bool {
		# Ensure that all member names are unique
		loop (i = 0, i < members.size, i++) {
			member = members[i]

			loop (j = i + 1, j < members.size, j++) {
				if members[j] == member return false
			}
		}

		return true
	}

	# Summary:
	# Returns whether the values for all the required members are present.
	# If a value for a member is missing, this function returns the member.
	# Otherwise, this function returns none.
	capture_missing_member(): Variable {
		loop iterator in type.variables {
			member = iterator.value

			if member.is_static or member.is_constant or member.is_hidden continue
			if not members.contains(member.name) return member
		}

		return none as Variable
	}

	override resolve(context: Context) {
		# Resolve the arguments
		loop argument in this {
			resolver.resolve(context, argument)
		}

		# Skip the process below, if it has been executed already
		if type != none {
			# Try to resolve the target type, if it is unresolved
			if type.is_unresolved {
				type = resolver.resolve(context, type)
			}

			return none as Node
		}

		# Try to resolve the type of the arguments, these types are the types of the members
		types = resolver.get_types(this)
		if types == none return none as Node

		# Ensure that all member names are unique
		if not validate_member_names() return none as Node

		# Create a new pack type in order to construct the pack later
		type = context.declare_unnamed_pack(start)

		# Declare the pack members
		loop (i = 0, i < members.size, i++) {
			type.(Context).declare(types[i], VARIABLE_CATEGORY_MEMBER, members[i])
		}

		return none as Node
	}

	override get_status() {
		# Ensure that all member names are unique
		if not validate_member_names() return Status(start, 'All pack members must be named differently')
		if type == none return Status(start, 'Can not resolve the types of the pack members')
		if type.is_unresolved return Status(start, 'Can not resolve the target type')
		if not type.is_pack return Status(start, 'Target type must be a pack type')

		missing = capture_missing_member()
		if missing !== none return Status(start, "Missing value for member " + missing.name)

		return none as Status
	}

	override copy() {
		return PackConstructionNode(type, members, start)
	}

	override string() {
		return "Pack { " + String.join(", ", members) + ' }'
	}
}

Node PackNode {
	type: Type

	init(type: Type) {
		this.type = type
		this.instance = NODE_PACK
	}

	override try_get_type() {
		return type
	}

	override copy() {
		return PackNode(type)
	}

	override string() {
		return "Pack"
	}
}

Node UndefinedNode {
	type: Type
	format: large

	init(type: Type, format: large) {
		this.type = type
		this.format = format
		this.instance = NODE_UNDEFINED
	}

	override try_get_type() {
		return type
	}

	override copy() {
		return UndefinedNode(type, format)
	}

	override string() {
		return "Undefined"
	}
}

Node UsingNode {
	is_allocator_resolved: bool = false

	init(allocated: Node, allocator: Node, position: Position) {
		this.instance = NODE_USING
		this.start = position
		this.is_resolvable = true
		add(allocated)
		add(allocator)
	}

	init(position: Position) {
		this.instance = NODE_USING
		this.start = position
	}

	override try_get_type() {
		return first.try_get_type()
	}

	add_allocator_function(): _ {
		if is_allocator_resolved return

		if not (first.instance === NODE_CONSTRUCTION) and
			not (first.instance === NODE_LINK and first.last.instance === NODE_CONSTRUCTION)  {
			return
		}

		allocated_type = first.try_get_type()
		if allocated_type === none or allocated_type.is_unresolved return

		allocator_type = last.try_get_type()
		if allocator_type === none or allocator_type.is_unresolved return

		# If the allocator is an integer or a link, treat it as an address where the object should be allocated
		if (allocator_type.is_number and allocator_type.format !== FORMAT_DECIMAL) or allocator_type.is_link {
			is_allocator_resolved = true
			return
		}

		allocator_function_name = String(parser.STANDARD_ALLOCATOR_FUNCTION)

		if not allocator_type.is_function_declared(allocator_function_name) and
			not allocator_type.is_virtual_function_declared(allocator_function_name) {
			return
		}

		allocator_object = last
		allocator_object.remove()

		size = max(1, allocated_type.content_size)
		arguments = Node()
		arguments.add(NumberNode(SYSTEM_SIGNED, size, start))

		allocator_call = UnresolvedFunction(allocator_function_name, start)
		allocator_call.set_arguments(arguments)

		add(LinkNode(allocator_object, allocator_call, start))
		is_allocator_resolved = true
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		resolver.resolve(context, last)

		add_allocator_function()

		return none as Node
	}

	override get_status() {
		# 1. Verify the allocated object is a construction
		if not (first.instance === NODE_CONSTRUCTION) and
			not (first.instance === NODE_LINK and first.last.instance === NODE_CONSTRUCTION)  {
			return Status(start, 'Left side must be a construction') 
		}

		# 2. Verify the allocator has an allocation function
		allocator_type = last.try_get_type()
		if allocator_type === none or allocator_type.is_unresolved return Status(start, 'Can not resolve the type of the allocator')

		# If the allocator is an integer or a link, treat it as an address where the object should be allocated
		if (allocator_type.is_number and allocator_type.format !== FORMAT_DECIMAL) or allocator_type.is_link return none as Status

		if not allocator_type.is_function_declared(String(parser.STANDARD_ALLOCATOR_FUNCTION)) and
			not allocator_type.is_virtual_function_declared(String(parser.STANDARD_ALLOCATOR_FUNCTION)) {
			return Status(start, 'Allocator does not have allocation function: allocate(size: i64): link')
		}

		return none as Status
	}

	override copy() {
		return UsingNode(start)
	}

	override string() {
		return "Using"
	}
}