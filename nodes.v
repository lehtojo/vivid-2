NODE_FUNCTION_DEFINITION = 1
NODE_LINK = 2
NODE_NUMBER = 4
NODE_OPERATOR = 8
NODE_SCOPE = 16
NODE_TYPE = 32
NODE_TYPE_DEFINITION = 64
NODE_UNRESOLVED_IDENTIFIER = 128
NODE_VARIABLE = 256
NODE_STRING = 512
NODE_LIST = 1024
NODE_UNRESOLVED_FUNCTION = 2048
NODE_CONSTRUCTION = 4096
NODE_FUNCTION = 8192
NODE_RETURN = 16384
NODE_PARENTHESIS = 32768
NODE_IF = 65536
NODE_ELSE_IF = 131072
NODE_LOOP = 262144
NODE_CAST = 524288
NODE_COMMAND = 1048576
NODE_NEGATE = 2097152
NODE_ELSE = 4194304
NODE_INCREMENT = 8388608
NODE_DECREMENT = 16777216
NODE_NOT = 33554432
NODE_ACCESSOR = 67108864
NODE_INLINE = 134217728
NODE_NORMAL = 268435456
NODE_CALL = 536870912
NODE_CONTEXT_INLINE = 1073741824
NODE_DATA_POINTER = 2147483648
NODE_STACK_ADDRESS = 4294967296
NODE_DISABLED = 8589934592
NODE_LABEL = 17179869184
NODE_JUMP = 34359738368
NODE_DECLARE = 68719476736
NODE_SECTION = 137438953472
NODE_NAMESPACE = 274877906944
NODE_INSPECTION = 549755813888
NODE_COMPILES = 1099511627776
NODE_IS = 2199023255552
NODE_LAMBDA = 4398046511104
NODE_HAS = 8796093022208
NODE_EXTENSION_FUNCTION = 17592186044416
NODE_WHEN = 35184372088832
NODE_LIST_CONSTRUCTION = 70368744177664
NODE_PACK_CONSTRUCTION = 140737488355328
NODE_PACK = 281474976710656
NODE_UNDEFINED = 562949953421312 # 1 <| 49

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

	negate() {
		if format == FORMAT_DECIMAL {
			value = value ¤ [1 <| 63]
		}
		else {
			value = -value
		}

		=> this
	}

	convert(format: large) {
		if format == FORMAT_DECIMAL {
			if this.format != FORMAT_DECIMAL { this.value = decimal_to_bits(value as decimal) }
		}
		else {
			if this.format == FORMAT_DECIMAL { this.value = bits_to_decimal(value) }
		}

		this.format = format
	}

	override equals(other: Node) {
		=> value == other.(NumberNode).value and format == other.(NumberNode).format and type == other.(NumberNode).type
	}

	override try_get_type() {
		if type == none { type = numbers.get(format) }
		=> type
	}

	override copy() {
		=> NumberNode(format, value, start)
	}

	override string() {
		if format == FORMAT_DECIMAL => String('Decimal Number ') + to_string(bits_to_decimal(value))
		=> String('Number ') + to_string(value)
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

	set_operands(left: Node, right: Node) {
		add(left)
		add(right)
		=> this
	}

	private try_resolve_as_setter_accessor() {
		if operator != Operators.ASSIGN => none as Node

		# Since the left node represents an accessor, its first node must represent the target object
		object = first.first
		type = object.try_get_type()

		if type == none or not type.is_local_function_declared(String(Operators.ACCESSOR_SETTER_FUNCTION_IDENTIFIER)) => none as Node

		# Since the left node represents an accessor, its last node must represent its arguments
		arguments = first.last

		# Since the current node is the assign-operator, the right node must represent the assigned value which should be the last parameter
		arguments.add(last)

		=> create_operator_overload_function_call(object, String(Operators.ACCESSOR_SETTER_FUNCTION_IDENTIFIER), arguments)
	}

	private create_operator_overload_function_call(object: Node, function: String, arguments: Node) {
		=> LinkNode(object, UnresolvedFunction(function, start).set_arguments(arguments), start)
	}

	override resolve(context: Context) {
		# First resolve any problems in the other nodes
		resolver.resolve(context, first)
		resolver.resolve(context, last)

		# Check if the left node represents an accessor and if it is being assigned a value
		if operator.type == OPERATOR_TYPE_ASSIGNMENT and first.match(NODE_ACCESSOR) {
			result = try_resolve_as_setter_accessor()
			if result != none => result
		}

		# Try to resolve this operator node as an operator overload function call
		type = first.try_get_type()
		if type == none => none as Node

		if not type.is_operator_overloaded(operator) => none as Node

		# Retrieve the function name corresponding to the operator of this node
		overload = Operators.operator_overloads[operator]
		arguments = Node()
		arguments.add(last)

		=> create_operator_overload_function_call(first, overload, arguments)
	}

	private get_classic_type() {
		left_type = first.try_get_type()
		right_type = last.try_get_type()

		# Return the left type only if it represents a link, which is modified with an integer type
		if primitives.is_primitive(left_type, primitives.LINK) and right_type != none and right_type.is_number and right_type.format != FORMAT_DECIMAL and (operator == Operators.ADD or operator == Operators.SUBTRACT or operator == Operators.MULTIPLY) => left_type

		=> resolver.get_shared_type(left_type, right_type)
	}

	override equals(other: Node) {
		=> operator == other.(OperatorNode).operator and default_equals(other)
	}

	override try_get_type() {
		=> when(operator.type) {
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
		=> OperatorNode(operator, start)
	}

	override string() {
		=> String('Operator ') + operator.identifier
	}
}

Node ScopeNode {
	context: Context
	end: Position

	init(context: Context, start: Position, end: Position) {
		this.instance = NODE_SCOPE
		this.context = context
		this.start = start
		this.end = end
	}

	override equals(other: Node) {
		=> context.identity == other.(ScopeNode).context.identity and default_equals(other)
	}

	override copy() {
		=> ScopeNode(context, start, end)
	}

	override string() {
		=> String('Scope')
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

	override equals(other: Node) {
		=> variable == other.(VariableNode).variable
	}

	override try_get_type() {
		=> variable.type
	}

	override copy() {
		=> VariableNode(variable, start)
	}

	override string() {
		=> String('Variable ') + variable.name
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
		if primary == none => none as Node

		if last.match(NODE_UNRESOLVED_FUNCTION) {
			function = last as UnresolvedFunction

			# First, try to resolve the function normally
			result = function.resolve(environment, primary)

			if result != none {
				last.replace(result)
				=> none as Node
			}

			# Try to get the parameter types from the function node
			types = resolver.get_types(function)
			if types == none => none as Node

			# Try to form a virtual function call
			result = common.try_get_virtual_function_call(first, primary, function.name, function, types, start)
			if result == none { result = common.try_get_lambda_call(primary, first, function.name, function, types) }

			if result != none {
				result.start = start
				=> result
			}
		}
		else last.match(NODE_UNRESOLVED_IDENTIFIER) {
			resolver.resolve(primary, last)
		}
		else {
			# Consider a situation where the right operand is a function call. The function arguments need the environment context to be resolved.
			resolver.resolve(environment, last)
		}

		=> none as Node
	}

	override try_get_type() {
		=> last.try_get_type()
	}

	override copy() {
		=> LinkNode(start)
	}

	override string() {
		=> String('Link')
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

	private try_resolve_as_function_pointer(context: Context) {
		# TODO: Function pointers
		=> none as Node
	}

	override equals(other: Node) {
		=> value == other.(UnresolvedIdentifier).value
	}

	override resolve(context: Context) {
		linked = parent != none and parent.match(NODE_LINK)
		result = parser.parse_identifier(context, IdentifierToken(value, start), linked)

		if result.match(NODE_UNRESOLVED_IDENTIFIER) => try_resolve_as_function_pointer(context)
		=> result
	}

	override get_status() {
		=> Status(start, String('Can not resolve identifier ') + value)
	}

	override copy() {
		=> UnresolvedIdentifier(value, start)
	}

	override string() {
		=> String('Unresolved Identifier ') + value
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

	set_arguments(arguments: Node) {
		loop argument in arguments { add(argument) }
		=> this
	}

	private try_resolve_lambda_parameters(primary: Context, call_arguments: List<CallArgument>) {
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
			if actual_types.size != overload.parameters.size => false

			# Collect the expected parameter types
			expected_types = overload.parameters.map<Type>((j: Parameter) -> j.type)

			# Determine the final parameter types as follows:
			# - Prefer the actual parameter types over the expected parameter types
			# - If the actual parameter type is not defined, use the expected parameter type
			types = List<Type>(expected_types.size, false)

			loop (i = 0, i < types.size, i++) {
				actual_type = actual_types[i]
				if actual_type != none { types.add(actual_type) }
				else { types.add(expected_types[i]) }
			}

			# Check if the final parameter types pass
			=> types.all(i -> i != none and i.is_resolved) and overload.passes(types, arguments)
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

				if expected.is_function_type {
					# Since the actual parameter type is lambda type and the expected is not, the current candidate can be removed
					candidates.remove_at(i)
					stop
				}
			}
		}

		# Resolve the lambda type only if there is only one option left since the analysis would go too complex
		if candidates.size != 1 return

		match = candidates[0]
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
				if actual_parameter as link != none and not (expected_parameter.type == actual_parameter.type) return
			}

			# Since none of the parameters conflicted with the expected parameters types, the expected parameter types can be transferred
			loop (j = 0, j < expected.parameters.size, j++) {
				call_arguments[i].value.(LambdaNode).function.parameters[j].type = expected.parameters[j]
			}
		}
	}

	resolve(environment: Context, primary: Context) {
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
			=> none as Node
		}

		is_normal_unlinked_call = not linked and arguments.size == 0

		# First, ensure this function can be a lambda call
		if is_normal_unlinked_call {
			# Try to form a lambda function call
			result = common.try_get_lambda_call(environment, name, this as Node, argument_types)

			if result != none {
				result.start = start
				=> result
			}
		}

		# Try to find a suitable function by name and parameter types
		function = parser.get_function_by_name(primary, name, argument_types, arguments, linked)

		# Lastly, try to form a virtual function call if the function could not be found
		if function == none and is_normal_unlinked_call {
			result = common.try_get_virtual_function_call(environment, name, this, argument_types, start)

			if result != none {
				result.start = start
				=> result
			}
		}

		if function == none => none as Node

		node = FunctionNode(function, start).set_arguments(this)

		if function.is_constructor {
			type = function.find_type_parent()
			if type == none abort('Missing constructor parent type')

			# If the descriptor name is not the same as the function name, it is a direct call rather than a construction
			if not (type.identifier == name) => node
			=> ConstructionNode(node, node.start)
		}

		# When the function is a member function and the this function is not part of a link it means that the function needs the self pointer
		if function.is_member and not function.is_static and not linked {
			self = common.get_self_pointer(environment, start)
			=> LinkNode(self, node, start)
		}

		=> node
	}

	override equals(other: Node) {
		=> name == other.(UnresolvedFunction).name and default_equals(other)
	}

	override resolve(context: Context) {
		=> resolve(context, context)
	}

	override copy() {
		=> UnresolvedFunction(name, arguments, start)
	}

	override get_status() {
		types = List<Type>()
		loop iterator in this { types.add(iterator.try_get_type()) }
		=> Status(start, String('Can not find function ') + common.to_string(name, types, arguments))
	}

	override string() {
		=> String('Unresolved Function ') + name
	}
}

Node TypeNode {
	type: Type

	init(type: Type) {
		this.instance = NODE_TYPE
		this.type = type
	}

	init(type: Type, position: Position) {
		this.instance = NODE_TYPE
		this.type = type
		this.start = position
	}

	override equals(other: Node) {
		=> type == other.(TypeNode).type
	}

	override try_get_type() {
		=> type
	}

	override copy() {
		=> TypeNode(type, start)
	}

	override string() {
		=> String('Type ') + type.name
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

	parse() {
		# Static types can not be constructed
		if not type.is_static and not type.is_plain type.add_runtime_configuration()

		# Create the body of the type
		parser.parse(this, type, List<Token>(blueprint))
		blueprint.clear()

		# Add all member initializations
		type.initialization.add_range(find_top(i -> i.match(Operators.ASSIGN)))

		# Add member initialization to the constructors that have been created before loading the member initializations
		loop constructor in type.constructors.overloads {
			constructor.(Constructor).add_member_initializations()
		}
	}

	override equals(other: Node) {
		=> type == other.(TypeDefinitionNode).type
	}

	override copy() {
		=> TypeDefinitionNode(type, blueprint, start)
	}

	override string() {
		=> String('Type Definition ') + type.name
	}
}

Node FunctionDefinitionNode {
	function: Function

	init(function: Function, position: Position) {
		this.instance = NODE_FUNCTION_DEFINITION
		this.function = function
		this.start = position
	}

	override equals(other: Node) {
		=> function == other.(FunctionDefinitionNode).function
	}

	override copy() {
		=> FunctionDefinitionNode(function, start)
	}

	override string() {
		=> String('Function Definition ') + function.name
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

	override equals(other: Node) {
		=> text == other.(StringNode).text
	}

	override try_get_type() {
		=> Link()
	}

	override copy() {
		=> StringNode(text, identifier, start)
	}

	override string() {
		=> String('String ') + text
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

	set_arguments(arguments: Node) {
		loop argument in arguments { add(argument) }
		=> this
	}

	override equals(other: Node) {
		=> function == other.(FunctionNode).function and default_equals(other)
	}

	override try_get_type() {
		=> function.return_type
	}

	override copy() {
		=> FunctionNode(function, start)
	}

	override string() {
		=> String('Function Call ') + function.name
	}
}

Node ConstructionNode {
	constructor => first as FunctionNode
	is_stack_allocated: bool = false

	init(constructor: FunctionNode, position: Position) {
		this.start = position
		this.instance = NODE_CONSTRUCTION
		add(constructor)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_CONSTRUCTION
	}

	override try_get_type() {
		=> constructor.function.find_type_parent()
	}

	override copy() {
		=> ConstructionNode(start)
	}

	override string() {
		=> String('Construction ') + constructor.function.name
	}
}

Node ParenthesisNode {
	init(position: Position) {
		this.start = position
		this.instance = NODE_PARENTHESIS
	}

	override try_get_type() {
		if last == none => none as Type
		=> last.try_get_type()
	}

	override copy() {
		=> ParenthesisNode(start)
	}

	override string() {
		=> String('Parenthesis')
	}
}

Node ReturnNode {
	value => first

	init(node: Node, position: Position) {
		this.instance = NODE_RETURN
		this.start = position

		# Add the return value, if it exists
		if node != none add(node)
	}

	override copy() {
		=> ReturnNode(none as Node, start)
	}

	override string() {
		=> String('Return')
	}
}

Node IfNode {
	condition_container => first
	condition => common.find_condition(first)
	body => last as ScopeNode

	successor() {
		if next != none and (next.instance == NODE_ELSE_IF or next.instance == NODE_ELSE) => next
		=> none as Node
	}

	predecessor() {
		if instance == NODE_IF => none as Node
		if previous != none and (previous.instance == NODE_IF or previous.instance == NODE_ELSE_IF) => previous
		=> none as Node
	}

	init(context: Context, condition: Node, body: Node, start: Position, end: Position) {
		this.start = start
		this.instance = NODE_IF
		this.is_resolvable = true

		# Create the condition
		node = Node()
		node.add(condition)
		add(node)

		# Create the body
		node = ScopeNode(context, start, end)
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

	get_successors() {
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

		=> successors
	}

	get_branches() {
		branches = List<Node>(1, false)
		branches.add(this)

		if successor == none => branches

		if successor.instance == NODE_ELSE_IF {
			branches.add_range(successor.(ElseIfNode).get_branches())
		}
		else {
			branches.add(successor)
		}

		=> branches
	}

	override resolve(context: Context) {
		resolver.resolve(context, condition)
		resolver.resolve(body.context, body)

		if successor != none resolver.resolve(context, successor)

		=> none as Node
	}

	override copy() {
		=> IfNode(start)
	}

	override string() {
		=> String('If')
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

	get_root() {
		iterator = predecessor

		loop (iterator.instance != NODE_IF) {
			iterator = iterator.(ElseIfNode).predecessor
		}

		=> iterator as IfNode
	}

	override copy() {
		=> ElseIfNode(start)
	}

	override string() {
		=> String('Else If')
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
		=> ListNode(start)
	}

	override string() {
		=> String('List')
	}
}

Node LoopNode {
	context: Context

	steps => first
	body => last as ScopeNode

	initialization => first.first
	action => first.last

	scope: Scope
	start_label: Label
	exit_label: Label

	is_forever_loop => first == last

	condition_container => first.first.next
	
	condition() {
		=> common.find_condition(first.first.next)
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
		=> none as Node
	}

	override copy() {
		=> LoopNode(context, start, start_label, exit_label)
	}

	override string() {
		=> String('Loop')
	}
}

Node CastNode {
	init(object: Node, type: Node, position: Position) {
		this.start = position
		this.instance = NODE_CAST

		add(object)
		add(type)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_CAST
	}

	override try_get_type() {
		=> last.try_get_type()
	}

	override copy() {
		=> CastNode(start)
	}

	override string() {
		=> String('Cast')
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
		if finished => none as Node

		# Try to find the parent loop
		container: LoopNode = this.container
		if container == none => none as Node

		# Continue nodes must execute the action of their parent loops
		if instruction != Keywords.CONTINUE => none as Node

		# Copy the action node if it is present and it is not empty
		if container.is_forever_loop or container.action.first == none {
			finished = true
			=> none as Node
		}

		# Execute the action first then the continue
		result = InlineNode(start)
		loop iterator in container.action { result.add(iterator.clone()) }

		result.add(CommandNode(instruction, start, true))
		=> result
	}

	override equals(other: Node) {
		=> instruction == other.(CommandNode).instruction
	}

	override copy() {
		=> CommandNode(instruction, start, finished)
	}

	override get_status() {
		if finished and container != none => Status()
		=> Status('Keyword must be used inside a loop')
	}

	override string() {
		=> instruction.identifier
	}
}

Node NegateNode {
	init(object: Node, position: Position) {
		this.start = position
		this.instance = NODE_NEGATE
		add(object)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_NEGATE
	}

	override try_get_type() {
		=> first.try_get_type()
	}

	override copy() {
		=> NegateNode(start)
	}

	override string() {
		=> String('Negate')
	}
}

Node ElseNode {
	body => first as ScopeNode

	predecessor() {
		if previous != none and (previous.instance == NODE_IF or previous.instance == NODE_ELSE_IF) => previous
		=> none as Node
	}

	init(context: Context, body: Node, start: Position, end: Position) {
		this.start = start
		this.instance = NODE_ELSE
		this.is_resolvable = true

		node = ScopeNode(context, start, end)
		loop child in body { node.add(child) }
		add(node)
	}

	init(start: Position) {
		this.start = start
		this.instance = NODE_ELSE
		this.is_resolvable = true
	}

	get_root() {
		iterator = predecessor

		loop (iterator.instance != NODE_IF) {
			iterator = iterator.(ElseIfNode).predecessor
		}

		=> iterator as IfNode
	}

	override resolve(context: Context) {
		resolver.resolve(body.context, body)
		=> none as Node
	}

	override copy() {
		=> ElseNode(start)
	}

	override string() {
		=> String('Else')
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

	override equals(other: Node) {
		=> post == other.(IncrementNode).post and default_equals(other)
	}

	override try_get_type() {
		=> first.try_get_type()
	}

	override copy() {
		=> IncrementNode(start, post)
	}

	override string() {
		if post => String('PostIncrement')
		=> String('PreIncrement')
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

	override equals(other: Node) {
		=> post == other.(DecrementNode).post and default_equals(other)
	}

	override try_get_type() {
		=> first.try_get_type()
	}

	override copy() {
		=> DecrementNode(start, post)
	}

	override string() {
		if post => String('PostDecrement')
		=> String('PreDecrement')
	}
}

Node NotNode {
	init(object: Node, position: Position) {
		this.start = position
		this.instance = NODE_NOT
		add(object)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_NOT
	}

	override try_get_type() {
		=> first.try_get_type()
	}

	override copy() {
		=> NotNode(start)
	}

	override string() {
		=> String('Not')
	}
}

Node AccessorNode {
	stride => get_type().reference_size
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

	get_stride() {
		=> get_type().allocation_size
	}

	private create_operator_overload_function_call(object: Node, function: String, arguments: Node) {
		=> LinkNode(object, UnresolvedFunction(function, start).set_arguments(arguments), start)
	}

	private try_resolve_as_getter_accessor(type: Type) {
		# Determine if this node represents a setter accessor
		if parent != none and parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT and parent.first == this {
			# Indexed accessor setter is handled elsewhere
			=> none as Node
		}

		# Ensure that the type contains overload for getter accessor
		if not type.is_local_function_declared(String(Operators.ACCESSOR_GETTER_FUNCTION_IDENTIFIER)) => none as Node
		=> create_operator_overload_function_call(first, String(Operators.ACCESSOR_GETTER_FUNCTION_IDENTIFIER), last)
	}

	override resolve(context: Context) {
		resolver.resolve(context, first)
		resolver.resolve(context, last)

		type = first.try_get_type()
		if type == none => none as Node

		=> try_resolve_as_getter_accessor(type)
	}

	override try_get_type() {
		type = first.try_get_type()
		if type == none => none as Type
		=> type.get_accessor_type()
	}

	override copy() {
		=> AccessorNode(start)
	}

	override string() {
		=> String('Accessor')
	}
}

Node InlineNode {
	is_context: bool = false

	init(position: Position) {
		this.start = position
		this.instance = NODE_INLINE
	}

	override equals(other: Node) {
		=> is_context == other.(InlineNode).is_context and default_equals(other)
	}

	override try_get_type() {
		if last == none => none as Type
		=> last.try_get_type()
	}

	override copy() {
		=> InlineNode(start)
	}

	override string() {
		=> String('Inline')
	}
}

InlineNode ContextInlineNode {
	context: Context

	init(context: Context, position: Position) {
		InlineNode.init(position)
		this.start = position
		this.instance = NODE_INLINE
		this.context = context
		this.is_context = true
	}

	override equals(other: Node) {
		if is_context != other.(InlineNode).is_context or context.identity != other.(ContextInlineNode).context.identity => false
		=> default_equals(other)
	}

	override copy() {
		=> ContextInlineNode(context, start)
	}

	override string() {
		=> String('Context Inline')
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

	override equals(other: Node) {
		=> type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset
	}

	override try_get_type() {
		=> Link.get_variant(primitives.create_number(primitives.LARGE, FORMAT_INT64))
	}

	override copy() {
		=> DataPointerNode(type, offset, start)
	}

	override string() {
		=> String('Empty Data Pointer')
	}
}

DataPointerNode FunctionDataPointerNode {
	function: FunctionImplementation

	init(function: FunctionImplementation, offset: large, position: Position) {
		DataPointerNode.init(FUNCTION_DATA_POINTER, offset, position)
		this.function = function
	}

	override equals(other: Node) {
		=> type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset and function == other.(FunctionDataPointerNode).function
	}

	override copy() {
		=> FunctionDataPointerNode(function, offset, start)
	}

	override string() {
		=> String('Function Data Pointer: ') + function.get_fullname()
	}
}

DataPointerNode TableDataPointerNode {
	table: Table

	init(table: Table, offset: large, position: Position) {
		DataPointerNode.init(TABLE_DATA_POINTER, offset, position)
		this.table = table
	}

	override equals(other: Node) {
		=> type == other.(DataPointerNode).type and offset == other.(DataPointerNode).offset and table == other.(TableDataPointerNode).table
	}

	override copy() {
		=> TableDataPointerNode(table, offset, start)
	}

	override string() {
		=> String('Table Data Pointer: ') + table.name
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

	override equals(other: Node) {
		=> type == other.(DataPointerNode).type
	}

	override try_get_type() {
		=> type
	}

	override copy() {
		=> StackAddressNode(type, identity, start)
	}

	override string() {
		=> String('Stack Allocation ') + type.name
	}
}

Node LabelNode {
	label: Label

	init(label: Label, position: Position) {
		this.label = label
		this.start = position
		this.instance = NODE_LABEL
	}

	override equals(other: Node) {
		=> label == other.(LabelNode).label
	}

	override copy() {
		=> LabelNode(label, start)
	}

	override string() {
		=> label.name + ':'
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

	override equals(other: Node) {
		=> label == other.(JumpNode).label and is_conditional == other.(JumpNode).is_conditional
	}

	override copy() {
		=> JumpNode(label, is_conditional)
	}

	override string() {
		=> String('Jump ') + label.name
	}
}

Node DeclareNode {
	variable: Variable
	registerize: bool = true

	init(variable: Variable) {
		this.variable = variable
		this.instance = NODE_DECLARE
	}

	init(variable: Variable, position: Position) {
		this.variable = variable
		this.start = position
		this.instance = NODE_DECLARE
	}

	override equals(other: Node) {
		=> variable == other.(DeclareNode).variable and registerize == other.(DeclareNode).registerize
	}

	override copy() {
		=> DeclareNode(variable, start)
	}

	override string() {
		=> String('Declare ') + variable.name
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
		=> SectionNode(modifiers, start)
	}

	override equals(other: Node) {
		=> modifiers == other.(SectionNode).modifiers
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
	create_namespace(context: Context) {
		position = this.name[0].position

		loop (i = 0, i < name.size, i += 2) {
			if this.name[i].type != TOKEN_TYPE_IDENTIFIER abort('Invalid namespace tokens')

			name: String = this.name[i].(IdentifierToken).value
			type = context.get_type(name)

			if type == none {
				type = Type(context, name, MODIFIER_DEFAULT | MODIFIER_STATIC, position)
				context = type
			}
			else {
				context = type
			}
		}

		=> context as Type
	}

	parse(context: Context) {
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
		=> NamespaceNode(name, blueprint, is_parsed)
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
		=> descriptor.return_type
	}

	override copy() {
		=> CallNode(descriptor, start)
	}

	override string() {
		=> String('Call')
	}
}

INSPECTION_TYPE_NAME = 0
INSPECTION_TYPE_SIZE = 1
INSPECTION_TYPE_CAPACITY = 2

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
		=> none as Node
	}

	override get_status() {
		type: Type = try_get_type()
		if type == none or type.is_unresolved => Status(start, 'Can not resolve the type of the inspected object')
		=> Status()
	}

	override try_get_type() {
		if type == INSPECTION_TYPE_NAME => Link()
		=> primitives.create_number(primitives.LARGE, FORMAT_INT64)
	}

	override copy() {
		=> InspectionNode(type, start)
	}

	override string() {
		if type == INSPECTION_TYPE_NAME => String('Name of')
		=> String('Size of')
	}
}

# Summary: Represents a node which outputs true if the content of the node is compiled successfully otherwise it returns false
Node CompilesNode {
	init(position: Position) {
		this.start = position
		this.instance = NODE_COMPILES
	}

	override copy() {
		=> CompilesNode(start)
	}

	override try_get_type() {
		=> primitives.create_bool()
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
		=> primitives.create_bool()
	}

	override resolve(context: Context) {
		# Try to resolve the inspected object
		resolver.resolve(context, first)

		# Try to resolve the type
		resolved = resolver.resolve(context, type)
		if resolved != none { type = resolved }

		=> none as Node
	}

	override get_status() {
		if type.is_unresolved => Status(start, 'Can not resolve the condition type')
		=> first.get_status()
	}

	override copy() {
		=> IsNode(type, start)
	}

	override string() {
		=> String('Is')
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

	get_parameter_types() {
		parameter_types = List<Type>(function.parameters.size, false)
		loop parameter in function.parameters { parameter_types.add(parameter.type) }
		=> parameter_types
	}

	get_incomplete_type() {
		return_type = none as Type
		if implementation != none { return_type = implementation.return_type }
		=> FunctionType(get_parameter_types(), return_type, start)
	}

	override resolve(context: Context) {
		if implementation != none {
			status = Status()
			=> none as Node
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
			if parameter.type == none or parameter.type.is_unresolved => none as Node
		}

		status = Status()
		implementation = function.implement(get_parameter_types())
		=> none as Node
	}

	override try_get_type() {
		if implementation != none and implementation.return_type != none => get_incomplete_type()
		=> none as Type
	}

	override copy() {
		=> LambdaNode(status, function, implementation, start)
	}

	override get_status() {
		=> status
	}
}

Node HasNode {
	constant RUNTIME_HAS_VALUE_FUNCTION_IDENTIFIER = 'has_value'
	constant RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER = 'get_value'

	constant RUNTIME_HAS_VALUE_FUNCTION_HEADER = 'has_value(): bool'
	constant RUNTIME_GET_VALUE_FUNCTION_HEADER = 'get_value(): any'

	source => first
	result => last as VariableNode

	init(source: Node, result: VariableNode, position: Position) {
		this.start = position
		this.instance = NODE_HAS
		this.is_resolvable = true

		add(source)
		add(result)
	}

	init(position: Position) {
		this.start = position
		this.instance = NODE_HAS
		this.is_resolvable = true
	}

	override resolve(environment: Context) {
		position = start
		resolver.resolve(environment, source)

		type = source.try_get_type()
		if type == none or type.is_unresolved => none as Node

		has_value_function = type.get_function(String(RUNTIME_HAS_VALUE_FUNCTION_IDENTIFIER)).get_implementation(List<Type>())
		if has_value_function == none or not primitives.is_primitive(has_value_function.return_type, primitives.BOOL) => none as Node

		get_value_function = type.get_function(String(RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER)).get_implementation(List<Type>())
		if get_value_function == none or get_value_function.return_type == none or get_value_function.return_type.is_unresolved => none as Node

		inline_context = Context(environment, NORMAL_CONTEXT)

		source_variable = inline_context.declare_hidden(type)
		result_variable = inline_context.declare_hidden(primitives.create_bool())

		# Declare the result variable at the start of the function
		declaration = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(result.variable, position),
			CastNode(NumberNode(SYSTEM_FORMAT, 0, position), TypeNode(get_value_function.return_type, position), position)
		)

		reconstruction.get_insert_position(this).insert(declaration)

		# Set the result variable equal to false
		initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(result_variable, position),
			NumberNode(SYSTEM_FORMAT, 0, position)
		)

		# Load the source into a variable
		load = OperatorNode(Operators.ASSIGN, position).set_operands(VariableNode(source_variable, position), source)

		# First the function 'has_value(): bool' must return true in order to call the function 'get_value(): any'
		condition = LinkNode(VariableNode(source_variable, position), FunctionNode(has_value_function, position), position)

		# If the function 'has_value(): bool' returns true, load the value using the function 'get_value(): any' and set the result variable equal to true
		body = Node()
		body.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(result.variable, position),
			LinkNode(VariableNode(source_variable), FunctionNode(get_value_function, position), position)
		))
		body.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(result_variable, position),
			NumberNode(SYSTEM_FORMAT, 1, position)
		))

		assignment_context = Context(environment, NORMAL_CONTEXT)
		assignment = IfNode(assignment_context, condition, body, position, none as Position)

		result = ContextInlineNode(inline_context, position)
		result.add(initialization)
		result.add(load)
		result.add(assignment)
		result.add(VariableNode(result_variable))
		=> result
	}

	override try_get_type() {
		=> primitives.create_bool()
	}

	override get_status() {
		type = source.try_get_type()
		if type == none or type.is_unresolved => Status(source.start, 'Can not resolve the type of the inspected object')

		message = String('Ensure the inspected object has the following functions ') + RUNTIME_HAS_VALUE_FUNCTION_HEADER + ' and ' + RUNTIME_GET_VALUE_FUNCTION_HEADER
		=> Status(start, message)
	}

	override copy() {
		=> HasNode(start)
	}

	override string() {
		=> String('Has')
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
			if resolved == none => none as Node
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
			if not (result has parameters) => none as Node

			function.parameters.add_range(parameters)
		}

		# If the destination is a namespace, mark the function as a static function
		if destination.is_static { function.modifiers = function.modifiers | MODIFIER_STATIC }

		destination.(Context).declare(function)
		=> FunctionDefinitionNode(function, start)
	}

	override get_status() {
		message = String('Can not resolve the destination ') + destination.string() + ' of the extension function'
		=> Status(start, message)
	}

	override copy() {
		=> ExtensionFunctionNode(destination, descriptor, template_parameters, body, start, end)
	}

	override string() {
		=> String('Extension function')
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

			if value == none => none as Type

			type = value.try_get_type()
			if type == none => none as Type

			types.add(type)
		}

		=> resolver.get_shared_type(types)
	}

	get_section_body(section: Node) {
		=> when(section.instance) {
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
		=> none as Node
	}

	override get_status() {
		inspected_type = value.try_get_type()
		inspected.variable.type = inspected_type

		if inspected_type == none => Status(inspected.start, 'Can not resolve the type of the inspected value')

		types = List<Type>()

		loop section in sections {
			body = get_section_body(section)
			value = body.last

			if value == none => Status(start, 'When-statement has an empty section')

			type = value.try_get_type()
			if type == none => Status(value.start, 'Can not resolve the section return type')
			
			types.add(type)
		}

		if resolver.get_shared_type(types) == none => Status(start, 'Sections do not have a shared return type')
		=> Status()
	}

	override copy() {
		=> WhenNode(start)
	}

	override string() {
		=> String('When')
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
		if type != none => type

		# Resolve the type of a single element
		element_types = resolver.get_types(this)
		if element_types == none => none as Type
		element_type = resolver.get_shared_type(element_types)
		if element_type == none => none as Type

		# Try to find the environment context
		environment = try_get_parent_context()
		if environment == none => none as Type

		list_type = environment.get_type(String(parser.STANDARD_LIST_TYPE))
		if list_type == none or not list_type.is_template_type => none as Type

		# Get a list type with the resolved element type
		type = list_type.(TemplateType).get_variant([ element_type ])
		type.constructors.get_implementation(List<Type>())
		type.get_function(String(parser.STANDARD_LIST_ADDER)).get_implementation(element_type)
		=> type
	}

	override resolve(context: Context) {
		loop element in this {
			resolver.resolve(context, element)
		}

		=> none as Node
	}

	override get_status() {
		if type == none => Status(Position, 'Can not resolve the shared type between the elements')

		=> Status()
	}

	override copy() {
		=> ListConstructionNode(type, start)
	}

	override string() {
		elements: List<String> = List<String>()
		loop element in this { elements.add(element.string()) }

		=> String('[ ') + String.join(String(', '), elements) + ' ]'
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
		=> type
	}

	validate_member_names() {
		# Ensure that all member names are unique
		loop (i = 0, i < members.size, i++) {
			member = members[i]

			loop (j = i + 1, j < members.size, j++) {
				if members[j] == member => false
			}
		}

		=> true
	}

	override resolve(context: Context) {
		# Resolve the arguments
		loop argument in this {
			resolver.resolve(context, argument)
		}

		# Skip the process below, if it has been executed already
		if type != none => none as Node

		# Try to resolve the type of the arguments, these types are the types of the members
		types = resolver.get_types(this)
		if types == none => none as Node

		# Ensure that all member names are unique
		if not validate_member_names() => none as Node

		# Create a new pack type in order to construct the pack later
		type = context.declare_unnamed_pack(start)

		# Declare the pack members
		loop (i = 0, i < members.size, i++) {
			type.(Context).declare(types[i], VARIABLE_CATEGORY_MEMBER, members[i])
		}

		=> none as Node
	}

	override get_status() {
		# Ensure that all member names are unique
		if not validate_member_names() => Status(start, 'All pack members must be named differently')

		if type == none => Status(start, 'Can not resolve the types of the pack members')

		=> Status()
	}

	override copy() {
		=> PackConstructionNode(type, members, start)
	}

	override string() {
		=> String('Pack { ') + String.join(String(', '), members) + ' }'
	}
}

Node PackNode {
	type: Type

	init(type: Type) {
		this.type = type
		this.instance = NODE_PACK
	}

	override try_get_type() {
		=> type
	}

	override copy() {
		=> PackNode(type)
	}

	override string() {
		=> String('Pack')
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
		=> type
	}

	override copy() {
		=> UndefinedNode(type, format)
	}

	override string() {
		=> String('Undefined')
	}
}