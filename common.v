namespace common

get_self_pointer(context: Context, position: Position) {
	self = context.get_self_pointer()
	if self != none => VariableNode(self, position) as Node

	if context.is_inside_lambda => UnresolvedIdentifier(String(LAMBDA_SELF_POINTER_IDENTIFIER), position) as Node
	=> UnresolvedIdentifier(String(SELF_POINTER_IDENTIFIER), position) as Node
}

# Summary: Reads template parameters from the next tokens inside the specified queue
# Pattern: <$1, $2, ... $n>
read_template_arguments(context: Context, tokens: List<Token>, offset: large) {
	=> read_template_arguments(context, tokens.slice(offset, tokens.size))
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

# Summary: Reads a type which represents a function from the specified tokens
read_function_type(context: Context, tokens: List<Token>, position: Position) {
	# Dequeue the parameter types
	parameters = tokens.take_first() as ParenthesisToken

	# Dequeue the arrow operator
	tokens.take_first()

	# Dequeues the return type
	return_type = read_type(context, tokens) as Type

	# The return type must exist
	if return_type == none => none as FunctionType

	# Read all the parameter types
	parameter_types = List<Type>()
	parameter_tokens = parameters.tokens

	loop (parameter_tokens.size > 0) {
		parameter_type = read_type(context, parameter_tokens) as Type
		if parameter_type == none => none as FunctionType
		parameter_types.add(parameter_type)
		parameter_tokens.take_first() # Consume the comma, if there are tokens left
	}

	=> FunctionType(parameter_types, return_type, position)
}

# Summary: Reads a type from the next tokens inside the specified tokens
# Pattern: $name [<$1, $2, ... $n>]
read_type(context: Context, tokens: List<Token>) {
	if tokens.size == 0 => none as Type

	next = tokens[0]
	if next.match(TOKEN_TYPE_PARENTHESIS) => read_function_type(context, tokens, next.position)

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

# Summary:
# Pattern: <$1, $2, ... $n>
consume_template_arguments(state: ParserState) {
	# Next there must be the opening of the template parameters
	next = state.peek()
	if next == none or not next.match(Operators.LESS_THAN) => false
	state.consume()

	loop {
		backup = state.save()
		if not consume_type(state) state.restore(backup)

		next = state.peek()
		if not state.consume(TOKEN_TYPE_OPERATOR) => false

		# If the consumed operator is a greater than operator, it means the template arguments have ended
		if next.match(Operators.GREATER_THAN) => true

		# If the operator is a comma, it means the template arguments have not ended
		if next.match(Operators.COMMA) continue

		# The template arguments must be invalid
		=> false
	}
}

# Summary:
# Consumes a template function call except the name in the beginning
# Pattern: <$1, $2, ... $n> (...)
consume_template_function_call(state: ParserState) {
	# Consume pattern: <$1, $2, ... $n>
	if not consume_template_arguments(state) => false

	# Now there must be function parameters next
	next = state.peek()
	if next == none or not next.match(`(`) => false

	state.consume()
	=> true
}

# Summary: Consumes a function type
# Pattern: (...) -> $type
consume_function_type(state: ParserState) {
	# Consume a normal parenthesis
	next = state.peek()
	if next == none or not next.match(`(`) => false
	state.consume()

	# Consume an arrow operator
	next = state.peek()
	if next == none or not next.match(Operators.ARROW) => false
	state.consume()

	# Consume the return type
	=> consume_type(state)
}

consume_type(state: ParserState) {
	if not state.consume(TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS) => false

	loop {
		next = state.peek()
		if next == none => true

		if next.match(Operators.DOT) {
			state.consume()
			if not state.consume(TOKEN_TYPE_IDENTIFIER) => false
		}
		else next.match(Operators.LESS_THAN) {
			if not consume_template_arguments(state) => false
		}
		else next.match(`(`) {
			if not consume_function_type(state) => false
		}
		else next.match(`[`) {
			state.consume()
			=> true
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

consume_block(from: ParserState, destination: List<Token>) {
	=> consume_block(from, destination, 0)
}

consume_block(from: ParserState, destination: List<Token>, disabled: large) {
	# Return an empty list, if there is nothing to be consumed
	if from.end >= from.all.size => none as Status

	# Clone the tokens from the specified state
	tokens = clone(from.all.slice(from.end, from.all.size))

	state = ParserState()
	state.all = tokens

	consumptions = List<Pair<parser.DynamicToken, large>>()
	context = Context(String('0'), NORMAL_CONTEXT)

	loop (priority = parser.MAX_FUNCTION_BODY_PRIORITY, priority >= parser.MIN_PRIORITY, priority--) {
		loop {
			if not parser.next(context, tokens, priority, 0, state, disabled) stop
			
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

		from.end += consumed
		=> none as Status
	}

	# Just consume the first token
	from.end++
	destination.add(next)
	=> none as Status
}

get_template_parameters(template_parameter_tokens: List<Token>, template_parameter_start: Position) {
	template_parameters = List<String>()

	loop (i = 0, i < template_parameter_tokens.size, i++) {
		if i % 2 != 0 continue
		if template_parameter_tokens[i].type != TOKEN_TYPE_IDENTIFIER abort('Template parameter tokens were invalid')

		template_parameters.add(template_parameter_tokens[i].(IdentifierToken).value)
	}

	=> template_parameters
}

# Summary: Returns whether the two specified types are compatible
compatible(expected: Type, actual: Type) {
	if expected == none or actual == none or expected.is_unresolved or actual.is_unresolved => false

	if expected.match(actual) => true

	if not expected.is_primitive or not actual.is_primitive {
		if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) => false
	} 
	else resolver.get_shared_type(expected, actual) == none => false

	=> true
}

# Summary:  Returns whether the specified actual types are compatible with the specified expected types, that is whether the actual types can be casted to match the expected types. This function also requires that the actual parameters are all resolved, otherwise this function returns false.
compatible(expected_types: List<Type>, actual_types: List<Type>) {
	if expected_types.size != actual_types.size => false

	loop (i = 0, i < expected_types.size, i++) {
		expected = expected_types[i]
		if expected == none continue

		actual = actual_types[i]
		if expected.match(actual) continue

		if not expected.is_primitive or not actual.is_primitive {
			if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) => false
		} 
		else resolver.get_shared_type(expected, actual) == none => false
	}

	=> true
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(self: Node, self_type: Type, name: String, arguments: Node, argument_types: List<Type>, position: Position) {
	if not self_type.is_virtual_function_declared(name) => none as CallNode

	# Ensure all the parameters are resolved
	loop argument_type in argument_types {
		if argument_type == none or argument_type.is_unresolved => none as CallNode
	}

	# Try to find a virtual function with the parameter types
	overload = self_type.get_virtual_function(name).get_overload(argument_types) as VirtualFunction
	if overload == none or overload.return_type == none => none as CallNode

	required_self_type = overload.find_type_parent()
	if required_self_type == none abort('Could not retrieve virtual function parent type')

	# Require that the self type has runtime configuration
	if required_self_type.configuration == none => none as CallNode

	configuration = required_self_type.get_configuration_variable()
	alignment = required_self_type.get_all_virtual_functions().index_of(overload)
	if alignment == -1 abort('Could not compute virtual function alignment')

	function_pointer = AccessorNode(LinkNode(self.clone(), VariableNode(configuration)), NumberNode(SYSTEM_FORMAT, alignment + 1, position), position)

	# Cast the self pointer, if neccessary
	if self_type != required_self_type {
		self = CastNode(self, TypeNode(required_self_type), self.start)
	}

	# Determine the parameter types
	parameter_types = List<Type>(argument_types.size, false)
	loop parameter in overload.parameters { parameter_types.add(parameter.type) }

	=> CallNode(self, function_pointer, arguments, FunctionType(required_self_type, parameter_types, overload.return_type, position), position)
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(environment: Context, self: Node, self_type: Type, descriptor: FunctionToken) {
	arguments = descriptor.parse(environment)
	argument_types = List<Type>()
	loop argument in arguments { argument_types.add(argument.try_get_type()) }

	=> try_get_virtual_function_call(self, self_type, descriptor.name, arguments, argument_types, descriptor.position)
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(environment: Context, name: String, arguments: Node, argument_types: List<Type>, position: Position) {
	if not environment.is_inside_function => none as CallNode

	type = environment.find_type_parent()
	if type == none => none as CallNode

	self = get_self_pointer(environment, position)
	=> try_get_virtual_function_call(self, type, name, arguments, argument_types, position)
}

# Summary: Tries to build a virtual function call which uses the current self pointer
try_get_virtual_function_call(environment: Context, descriptor: FunctionToken) {
	if not environment.is_inside_function => none as CallNode

	type = environment.find_type_parent()
	if type == none => none as CallNode

	self = get_self_pointer(environment, descriptor.position)
	=> try_get_virtual_function_call(environment, self, type, descriptor)
}

# Summary: Tries to build a lambda call which is stored inside a specified owner
try_get_lambda_call(primary: Context, left: Node, name: String, arguments: Node, argument_types: List<Type>) {
	if not primary.is_variable_declared(name) => none as CallNode

	variable = primary.get_variable(name)

	# Require the variable to represent a function
	if variable.type == none or not variable.type.is_function_type => none as CallNode
	properties = variable.type as FunctionType

	# Require that the specified argument types pass the required parameter types
	if not compatible(properties.parameters, argument_types) => none as CallNode
	
	position = left.start
	self = LinkNode(left, VariableNode(variable), position)
	
	# Determine where the function pointer is located
	offset = 1
	if settings.is_garbage_collector_enabled { offset = 2 }

	# Load the function pointer using the offset
	function_pointer = AccessorNode(self.clone(), NumberNode(SYSTEM_FORMAT, offset, position), position)
	=> CallNode(self, function_pointer, arguments, properties, position)
}

# Summary: Tries to build a lambda call which is stored inside the current scope or in the self pointer
try_get_lambda_call(environment: Context, name: String, arguments: Node, argument_types: List<Type>) {
	if not environment.is_variable_declared(name) => none as CallNode

	variable = environment.get_variable(name)

	# Require the variable to represent a function
	if variable.type == none or not variable.type.is_function_type => none as CallNode
	properties = variable.type as FunctionType

	# Require that the specified argument types pass the required parameter types
	if not compatible(properties.parameters, argument_types) => none as CallNode

	self = none as Node
	position = arguments.start

	if variable.is_member {
		self_pointer = get_self_pointer(environment, position)
		self = LinkNode(self_pointer, VariableNode(variable), position)
	}
	else {
		self = VariableNode(variable)
	}

	# Determine where the function pointer is located
	offset = 1
	if settings.is_garbage_collector_enabled { offset = 2 }

	function_pointer = AccessorNode(self.clone(), NumberNode(SYSTEM_FORMAT, offset, position), position)
	=> CallNode(self, function_pointer, arguments, properties, position)
}

# Summary: Tries to build a lambda call which is stored inside the current scope or in the self pointer
try_get_lambda_call(environment: Context, descriptor: FunctionToken) {
	arguments = descriptor.parse(environment)
	argument_types = List<Type>()
	loop argument in arguments { argument_types.add(argument.try_get_type()) }

	=> try_get_lambda_call(environment, descriptor.name, arguments, argument_types)
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

# Summary:
# Collects all functions from the specified context and its subcontexts.
# NOTE: This function does not return lambda functions.
get_all_visible_functions(context: Context) {
	# Collect all functions, constructors, destructors and virtual functions
	functions = List<Function>()

	loop type in get_all_types(context) {
		loop a in type.functions { functions.add_range(a.value.overloads) }
		loop b in type.virtuals { functions.add_range(b.value.overloads) }
		loop c in type.overrides { functions.add_range(c.value.overloads) }

		functions.add_range(type.constructors.overloads)
		functions.add_range(type.destructors.overloads)
	}

	loop function in context.functions {
		functions.add_range(function.value.overloads)
	}
	
	=> functions.distinct()
}

# Summary: Collects all function implementations from the specified context
get_all_function_implementations(context: Context) {
	# Collect all functions, constructors, destructors and virtual functions
	functions = List<Function>()

	loop type in get_all_types(context) {
		loop a in type.functions { functions.add_range(a.value.overloads) }
		loop b in type.virtuals { functions.add_range(b.value.overloads) }
		loop c in type.overrides { functions.add_range(c.value.overloads) }

		functions.add_range(type.constructors.overloads)
		functions.add_range(type.destructors.overloads)
	}

	loop function in context.functions {
		functions.add_range(function.value.overloads)
	}

	implementations = List<FunctionImplementation>()

	# Collect all the implementations from the functions and collect the inner implementations as well such as lambdas
	loop function in functions {
		loop implementation in function.implementations {
			implementations.add_range(get_all_function_implementations(implementation))
			implementations.add(implementation)
		}
	}

	=> implementations.distinct()
}

# Summary: Returns whether the specified is edited
is_edited(node: Node) {
	parent = none as Node

	loop (iterator = node.parent, iterator != none, iterator = iterator.parent) {
		if iterator.instance == NODE_CAST continue
		parent = iterator
		stop
	}

	if parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT => parent.first == node or node.is_under(parent.first)
	=> parent.match(NODE_INCREMENT | NODE_DECREMENT)
}

# Summary: Returns the node which is the destination of the specified edit
get_edited(editor: Node) {
	iterator = editor.first

	loop (iterator != none) {
		if not iterator.match(NODE_CAST) => iterator
		iterator = iterator.first
	}

	abort('Editor did not have a destination')
}

# Summary:
# Tries to returns the source value which is assigned without any casting or filtering.
# Returns null if the specified editor is not an assignment operator.
get_source(node: Node) {
	loop {
		# Do not return the cast node since it does not represent the source value
		if node.match(NODE_CAST) {
			node = node.(CastNode).first
			continue
		}

		# Do not return the following nodes since they do not represent the source value
		if node.match(NODE_PARENTHESIS | NODE_INLINE) {
			node = node.last
			continue
		}

		stop
	}

	=> node
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

# Summary: Returns whether the specified integer fulfills the following equation:
# x = 2^y where y is an integer constant
is_power_of_two(value: large) {
	=> (value & (value - 1)) == 0
}

integer_log2(value: large) {
	i = 0

	loop {
		value = value |> 1
		if value == 0 => i
		i++
	}
}

# Summary: Joins the specified token lists with the specified separator
join(separator: Token, elements: List<List<Token>>) {
	result = List<Token>()

	loop element in elements {
		result.add_range(result)
		result.add(separator)
	}

	result.remove_at(result.size - 1)
	=> result
}

# Summary: Converts the specified type into tokens
get_tokens(type: Type, position: Position) {
	result = List<Token>()

	###
	TODO: Function types

	if type.is_function_type {
		# ...
	}
	###

	if type.parent != none and type.parent.is_type {
		result.add_range(get_tokens(type.parent, position))
		result.add(OperatorToken(Operators.DOT, position))
	}

	if type.is_user_defined { result.add(IdentifierToken(type.identifier, position)) }
	else { result.add(IdentifierToken(type.name, position)) }

	if type.template_arguments.size > 0 {
		result.add(OperatorToken(Operators.LESS_THAN, position))

		arguments = List<List<Token>>(type.template_arguments.size, false)

		loop (i = 0, i < arguments.size, i++) {
			arguments[i] = get_tokens(type.template_arguments[i], position)
		}

		separator = OperatorToken(Operators.COMMA, position)
		result.add_range(join(separator, arguments))

		result.add(OperatorToken(Operators.GREATER_THAN, position))
	}

	=> result
}

# Summary: Returns the position which represents the end of the specified token
get_end_of_token(token: Token) {
	end = when(token.type) {
		TOKEN_TYPE_PARENTHESIS => token.(ParenthesisToken).end
		TOKEN_TYPE_FUNCTION => token.(FunctionToken).identifier.end
		TOKEN_TYPE_IDENTIFIER => token.(IdentifierToken).end
		TOKEN_TYPE_KEYWORD => token.(KeywordToken).end
		TOKEN_TYPE_NUMBER => token.(NumberToken).end
		TOKEN_TYPE_OPERATOR => token.(OperatorToken).end
		TOKEN_TYPE_STRING => token.(StringToken).end
		else => none as Position
	}

	if end != none => end

	=> token.position.translate(1)
}

# Summary: Creates a function header without return type from the specified values
# Format: $name($type1, $type2, ... $typen) / $name<$type1, $type2, ... $typen>($type1, $type2, ... $typen)
to_string(name: String, arguments: List<Type>, template_arguments: List<Type>) {
	template_argument_strings = List<String>(template_arguments.size, false)

	loop template_argument in template_arguments {
		if template_argument == none or template_argument.is_unresolved {
			template_argument_strings.add(String('?'))
		}
		else {
			template_argument_strings.add(template_argument.string())
		}
	}

	argument_strings = List<String>(arguments.size, false)

	loop argument in arguments {
		if argument == none or argument.is_unresolved {
			argument_strings.add(String('?'))
		}
		else {
			argument_strings.add(argument.string())
		}
	}

	if template_argument_strings.size > 0 => name + `<` + String.join(String(', '), template_argument_strings) + '>(' + String.join(String(', '), argument_strings) + `)`
	
	=> name + `(` + String.join(String(', '), argument_strings) + `)`
}

# Summary: Aligns the member variables of the specified type
align_members(type: Type) {
	position = 0

	# Member variables:
	loop iterator in type.variables {
		variable = iterator.value
		if variable.is_static continue
		variable.alignment = position
		variable.is_aligned = true
		position += variable.type.reference_size
	}
}