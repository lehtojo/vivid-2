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
NODE_LOOP_CONTROL = 17179869184
NODE_LABEL = 34359738368
NODE_JUMP = 68719476736 # 1 <| 36

Node NumberNode {
	value: large
	format: large
	type: Type

	init(format: large, value: large, start: Position) {
		this.instance = NODE_NUMBER
		this.format = format
		this.value = value
	}

	negate() {
		if format == FORMAT_DECIMAL {
			value = value ¤ [1 <| 64]
		}
		else {
			value = -value
		}

		=> this
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
		if primitives.is_primitive(left_type, primitives.LINK) and right_type.is_number and right_type.format != FORMAT_DECIMAL and (operator == Operators.ADD or operator == Operators.SUBTRACT or operator == Operators.MULTIPLY) => left_type

		=> resolver.get_shared_type(left_type, right_type)
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
		this.start = start
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
		this.start = start
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
			result = common.try_get_virtual_function_call(first, primary, function.name, function, types)
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

	override resolve(context: Context) {
		linked = parent != none and parent.match(NODE_LINK)
		result = parser.parse_identifier(context, IdentifierToken(value, start), linked)

		if result.match(NODE_UNRESOLVED_IDENTIFIER) => try_resolve_as_function_pointer(context)
		=> result
	}

	override copy() {
		=> UnresolvedIdentifier(value, start)
	}

	override string() {
		=> String('Unresolved Identifier ') + value
	}
}

Node UnresolvedFunction {
	name: String
	arguments: Array<Type>

	init(name: String, position: Position) {
		this.instance = NODE_UNRESOLVED_FUNCTION
		this.name = name
		this.arguments = Array<Type>()
		this.start = position
		this.is_resolvable = true
	}

	init(name: String, arguments: Array<Type>, position: Position) {
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

	private try_resolve_lambda_parameters(primary: Context, argument_types: List<Type>) {

	}

	resolve(environment: Context, primary: Context) {
		linked = environment != primary

		# Try to resolve all the arguments
		loop argument in this { resolver.resolve(environment, argument) }

		# Try to resolve all the template arguments
		loop (i = 0, i < arguments.count, i++) {
			result = resolver.resolve(environment, arguments[i])
			if result == none continue
			arguments[i] = result
		}

		# Try to collect all argument types and record whether any of them is unresolved
		argument_types = List<Type>()
		unresolved = false

		loop argument in this { 
			argument_type = argument.try_get_type()
			argument_types.add(argument_type)
			if argument_type == none or argument_type.is_unresolved { unresolved = true }
		}

		if unresolved {
			try_resolve_lambda_parameters(primary, argument_types)
			=> none as Node
		}

		is_normal_unlinked_call = not linked and arguments.count == 0

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
			result = common.try_get_virtual_function_call(environment, name, this, argument_types)

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

	override resolve(context: Context) {
		=> resolve(context, context)
	}

	override copy() {
		=> UnresolvedFunction(name, arguments, start)
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

		if blueprint.size == 0 return
		parse()
	}

	parse() {
		# Static types can not be constructed
		if not type.is_static type.add_runtime_configuration()

		# Create the body of the type
		parser.parse(this, type, List<Token>(blueprint))
		blueprint.clear()
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
		# TODO: Add references
		this.start = position
		this.instance = NODE_FUNCTION
	}

	set_arguments(arguments: Node) {
		loop argument in arguments { add(argument) }
		=> this
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

	init() { this.instance = NODE_IF }

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
	continue_label: Label
	start_label: Label
	exit_label: Label

	is_forever_loop => first == last
	
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

	init(context: Context, position: Position, continue_label: Label, start_label: Label, exit_label: Label) {
		this.context = context
		this.start = position
		this.continue_label = continue_label
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
		=> LoopNode(context, start, continue_label, start_label, exit_label)
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
	parent_loop => find_parent(NODE_LOOP) as LoopNode
	finished: bool = false

	init(instruction: Keyword, position: Position) {
		this.instruction = instruction
		this.start = position
		this.instance = NODE_COMMAND

		if instruction != Keywords.CONTINUE { finished = true }
	}

	init(instruction: Keyword, position: Position, finished: bool) {
		this.instruction = instruction
		this.finished = finished
		this.start = position
		this.instance = NODE_COMMAND
	}

	override copy() {
		=> CommandNode(instruction, start, finished)
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

	init(object: Node, arguments: Node) {
		this.instance = NODE_ACCESSOR
		this.is_resolvable = true

		add(object)

		node = ParenthesisNode()
		node.add(arguments)

		add(node)
	}

	init(object: Node, arguments: Node, position: Position) {
		this.instance = NODE_ACCESSOR
		this.start = position
		this.is_resolvable = true

		add(object)
		add(arguments)
	}

	init(position: Position) {
		this.instance = NODE_ACCESSOR
		this.start = position
		this.is_resolvable = true
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
		this.instance = NODE_CONTEXT_INLINE
		this.context = context
		this.is_context = true
	}

	override copy() {
		=> ContextInlineNode(context, start)
	}

	override string() {
		=> String('Context Inline')
	}
}

Node DataPointerNode {
	data: large
	offset: large
	type: Type

	init(data: large, offset: large, position: Position) {
		this.data = data
		this.offset = offset
		this.instance = NODE_DATA_POINTER
		this.start = position
		this.type = Link.get_variant(primitives.create_number(primitives.LARGE, FORMAT_INT64))
	}

	override try_get_type() {
		=> type
	}

	override copy() {
		=> DataPointerNode(data, offset, start)
	}

	override string() {
		=> String('Data Pointer')
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

Node LoopControlNode {
	instruction: Keyword
	container => find_parent(NODE_LOOP) as LoopNode
	finished: bool = false

	init(instruction: Keyword, parent: Position) {
		this.instruction = instruction
		this.start = position
		this.instance = NODE_LOOP_CONTROL

		if instruction != Keywords.CONTINUE { finished = true }
	}

	init(instruction: Keyword, position: Position, finished: bool) {
		this.instruction = instruction
		this.start = position
		this.finished = finished
		this.instance = NODE_LOOP_CONTROL
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

		result.add(LoopControlNode(instruction, start, true))
		=> result
	}

	override get_status() {
		if finished and container != none => Status()
		=> Status('Keyword must be used inside a loop')
	}
}

Node LabelNode {
	label: Label

	init(label: Label, position: Position) {
		this.label = label
		this.start = position
		this.instance = NODE_LABEL
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

	override string() {
		=> String('Jump ') + label.name
	}
}