namespace common

get_self_pointer(context: Context, position: Position) {
	self = context.get_self_pointer()
	if self != none => VariableNode(self, position) as Node

	if context.is_inside_lambda => UnresolvedIdentifier(String(LAMBDA_SELF_POINTER_IDENTIFIER), position) as Node
	=> UnresolvedIdentifier(String(SELF_POINTER_IDENTIFIER), position) as Node
}

# Summary: Reads template parameters from the next tokens inside the specified queue
# Pattern: <$1, $2, ... $n>
read_template_arguments(context: Context, tokens: List<Token>) {
	opening = tokens.take_first() as OperatorToken
	if opening.operator != Operators.LESS_THAN abort('Can not understand the template arguments')

	parameters = List<Type>()

	loop {
		parameter = read_type(context, tokens)
		if parameter == none stop

		parameters.add(parameter)

		# Consume the next token, if it is a comma
		if tokens[0].match(Operators.COMMA) tokens.take_first()
	}

	next = tokens.take_first()
	if not next.match(Operators.GREATER_THAN) abort('Can not understand the template arguments')

	=> parameters
}

# Summary: Reads a type component from the tokens and returns it
read_type_component(context: Context, tokens: List<Token>) {
	name = tokens.take_first().(IdentifierToken).value

	if tokens.size > 0 and tokens[0].match(Operators.LESS_THAN) {
		template_arguments = read_template_arguments(context, tokens)
		=> UnresolvedTypeComponent(name, template_arguments)
	}

	=> UnresolvedTypeComponent(name)
}

# Summary: Reads a type from the next tokens inside the specified tokens
# Pattern: $name [<$1, $2, ... $n>]
read_type(context: Context, tokens: List<Token>) {
	if tokens.size == 0 => none as Type

	next = tokens[0]

	if next.match(TOKEN_TYPE_PARENTHESIS) {
		abort('Reading function types is not supported')
		# => read_function_type(context, tokens)
	}

	if not next.match(TOKEN_TYPE_IDENTIFIER) => none as Type

	components = List<UnresolvedTypeComponent>()

	loop {
		components.add(read_type_component(context, tokens))

		# Stop collecting type components if there are no tokens left or if the next token is not a dot operator
		if tokens.size == 0 or not tokens[0].match(Operators.DOT) stop

		tokens.take_first()
	}

	type = UnresolvedType(components)

	if tokens.size > 0 {
		next = tokens[0]

		if next.match(`[`) { type.count = next as ParenthesisToken }
	}

	resolved = type.try_resolve_type(context)
	if resolved != none => resolved

	=> type
}

# Summary: Reads a type from the next tokens inside the specified tokens
# Pattern: $name [<$1, $2, ... $n>]
read_type(context: Context, tokens: List<Token>, start: large) {
	=> read_type(context, tokens.slice(start, tokens.size))
}

consume_type(state: parser.ParserState) {
	if not state.consume(TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS) => false

	loop {
		next = state.peek()
		if next == none => true

		if next.match(Operators.DOT) {
			state.consume()
			if not state.consume(TOKEN_TYPE_IDENTIFIER) => false
		}
		else next.match(Operators.LESS_THAN) {
			# TODO: Template arguments
		}
		else next.match(`(`) {
			# TODO: Function type
		}
		else next.match(`[`) {
			# TODO: Fixed arrays
		}
		else => true
	}
}

# Summary: Returns the types of the child nodes
get_types(node: Node) {
	types = List<Type>()

	loop iterator in node {
		type = iterator.try_get_type()
		if type == none or type.is_unresolved => none
		types.add(type)
	}

	=> types
}

find_condition(start) {
	iterator = start

	loop (iterator != none) {
		instance = iterator.instance
		if instance != NODE_SCOPE and instance != NODE_INLINE and instance != NODE_NORMAL and instance != NODE_PARENTHESIS => iterator
		iterator = iterator.last
	}

	abort('Could not find condition')
}

consume_block(from: parser.ParserState, destination: List<Token>) {
	# Return an empty list, if there is nothing to be consumed
	if from.end >= from.all.size => none as Status

	# Clone the tokens from the specified state
	tokens = from.all.slice(from.end, from.all.size)

	state = parser.ParserState()
	state.all = tokens

	consumptions = List<Pair<parser.DynamicToken, large>>()
	context = Context(String('0'), NORMAL_CONTEXT)

	loop (priority = parser.MAX_FUNCTION_BODY_PRIORITY, priority >= parser.MIN_PRIORITY, priority--) {
		loop {
			if not parser.next(context, tokens, priority, 0, state) stop
			
			state.error = none
			node = state.pattern.build(context, state, state.tokens)

			length = state.end - state.start
			consumed = 0

			loop (length-- > 0) {
				token = tokens[state.start]
				area = 1

				if token.match(TOKEN_TYPE_DYNAMIC) {
					# Look for the consumption, which is related to the current dynamic token, and increment the consumed tokens by the number of tokens it once consumed
					loop consumption in consumptions {
						if consumption.key != token continue
						area = consumption.value
						stop
					}
				}
				
				consumed += area
				tokens.remove_at(state.start)
			}

			if node == none {
				error = state.error
				if error as link == none { error = Status('Block consumption does not accept patterns returning nothing') }
				=> error
			}

			result = parser.DynamicToken(node)
			tokens.insert(state.start, result)
			consumptions.add(Pair<parser.DynamicToken, large>(result, consumed))
		}
	}

	next = tokens[0]

	if next.type == TOKEN_TYPE_DYNAMIC {
		consumed = 1

		# Determine how many tokens the next dynamic token consumed
		loop consumption in consumptions {
			if consumption.key != next continue
			consumed = consumption.value
			stop
		}

		# Read the consumed tokens from the source state
		source = from.all
		end = from.end

		loop (i = 0, i < consumed, i++) {
			destination.add(source[end + i])
		}

		=> none as Status
	}

	destination.add(next)
	=> none as Status
}

try_get_virtual_function_call(self: Node, self_type: Type, name: String, arguments: Node, argument_types: List<Type>) {
	# TODO: Virtual functions
	=> none as Node
}

try_get_virtual_function_call(environment: Context, name: String, arguments: Node, argument_types: List<Type>) {
	# TODO: Virtual functions
	=> none as Node
}

try_get_lambda_call(primary: Context, left: Node, name: String, arguments: Node, argument_types: List<Type>) {
	# TODO: Lambda calls
	=> none as Node
}

try_get_lambda_call(primary: Context, name: String, arguments: Node, argument_types: List<Type>) {
	# TODO: Lambda calls
	=> none as Node
}

# Summary: Collects all types and subtypes from the specified context
get_all_types(context: Context) {
	result = List<Type>()

	loop iterator in context.types {
		type = iterator.value
		result.add(type)
		result.add_range(get_all_types(type))
	}

	=> result
}

# Summary: Collects all function implementations from the specified context
get_all_function_implementations(context: Context) {
	# Collect all functions, constructors, destructors and virtual functions
	functions = List<Function>()

	loop type in get_all_types(context) {
		loop a in type.functions { functions.add_range(a.value.overloads) }
		loop b in type.virtuals { functions.add_range(b.value.overloads) }
		loop c in type.overrides { functions.add_range(c.value.overloads) }
		loop d in context.functions { functions.add_range(d.value.overloads) }

		functions.add_range(type.constructors.overloads)
		functions.add_range(type.destructors.overloads)
	}

	implementations = List<FunctionImplementation>()

	# Collect all the implementations from the functions and collect the inner implementations as well such as lambdas
	loop function in functions {
		loop implementation in function.implementations {
			implementations.add_range(get_all_function_implementations(implementation))
		}

		implementations.add(implementation)
	}

	# Remove all implementation duplicates
	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]

		loop (j = implementations.size - 1, j > i, j--) {
			if implementation != implementations[j] continue
			implementations.remove_at(j)
		}
	}

	=> implementations
}

get_edited(editor: Node) {
	iterator = editor.first

	loop (iterator != none) {
		if not iterator.match(NODE_CAST) => iterator
		iterator = iterator.first
	}

	abort('Editor did not have a destination')
}

# Summary: Returns whether the specified node represents a statement
is_statement(node: Node) {
	type = node.instance
	=> type == NODE_ELSE or type == NODE_ELSE_IF or type == NODE_IF or type == NODE_LOOP or type == NODE_SCOPE
}

# Summary: Returns whether the specified node represents a statement condition
is_condition(node: Node) {
	statement = node.find(NODE_ELSE_IF | NODE_IF | NODE_LOOP)
	if statement == none => false
	
	=> when(statement.instance) {
		NODE_IF => statement.(IfNode).condition == node
		NODE_ELSE_IF => statement.(ElseIfNode).condition == node
		NODE_LOOP => statement.(LoopNode).condition == node
		else => false
	}
}

# Summary: Returns whether a value is expected to return from the specified node
is_value_used(value: Node) {
	=> value.parent.match(NODE_CALL | NODE_CAST | NODE_PARENTHESIS | NODE_CONSTRUCTION | NODE_DECREMENT | NODE_FUNCTION | NODE_INCREMENT | NODE_LINK | NODE_NEGATE | NODE_NOT | NODE_ACCESSOR | NODE_OPERATOR | NODE_RETURN)
}

# Summary: Returns how many bits the value requires
get_bits(value: large, is_decimal: bool) {
	if is_decimal => SYSTEM_BITS

	if value < 0 {
		if value < -2147483648 => 64
		if value < -32768 => 32
		if value < -128 => 16
	}
	else {
		if value > 2147483647 => 64
		if value > 32767 => 32
		if value > 127 => 16
	}

	=> 8
}