TINY_MIN = -128
TINY_MAX = 127
SMALL_MIN = -32768
SMALL_MAX = 32767
NORMAL_MIN = -2147483648
NORMAL_MAX = 2147483647
LARGE_MIN = 0x8000000000000000
LARGE_MAX = 9223372036854775807

U8_MIN = 0
U8_MAX = 255
U16_MIN = 0
U16_MAX = 65535
U32_MIN = 0
U32_MAX = 4294967295
U64_MIN = 0
U64_MAX = 0xFFFFFFFFFFFFFFFF

ACCESS_TYPE_UNKNOWN = 0
ACCESS_TYPE_READ = 1
ACCESS_TYPE_WRITE = 2

namespace common

get_self_pointer(context: Context, position: Position) {
	self = context.get_self_pointer()
	if self != none return VariableNode(self, position) as Node

	if context.is_inside_lambda return UnresolvedIdentifier(String(LAMBDA_SELF_POINTER_IDENTIFIER), position) as Node
	return UnresolvedIdentifier(String(SELF_POINTER_IDENTIFIER), position) as Node
}

# Summary: Reads template parameters from the next tokens inside the specified queue
# Pattern: <$1, $2, ... $n>
read_template_arguments(context: Context, tokens: List<Token>, offset: large) {
	return read_template_arguments(context, tokens.slice(offset, tokens.size))
}

# Summary: Reads template arguments from the next tokens inside the specified queue
# Pattern: <$1, $2, ... $n>
read_template_arguments(context: Context, tokens: List<Token>) {
	opening = tokens.pop_or(none as Token) as OperatorToken
	if opening.operator != Operators.LESS_THAN abort('Can not understand the template arguments')

	arguments = List<Type>()

	loop {
		argument = read_type(context, tokens)
		if argument === none stop

		arguments.add(argument)

		# Consume the next token, if it is a comma
		if tokens[].match(Operators.COMMA) tokens.pop_or(none as Token)
	}

	next = tokens.pop_or(none as Token)
	if not next.match(Operators.GREATER_THAN) abort('Can not understand the template arguments')

	return arguments
}

# Summary: Reads a type component from the tokens and returns it
read_type_component(context: Context, tokens: List<Token>) {
	name = tokens.pop_or(none as Token).(IdentifierToken).value

	if tokens.size > 0 and tokens[].match(Operators.LESS_THAN) {
		template_arguments = read_template_arguments(context, tokens)
		return UnresolvedTypeComponent(name, template_arguments)
	}

	return UnresolvedTypeComponent(name)
}

# Summary: Reads a type which represents a function from the specified tokens
read_function_type(context: Context, tokens: List<Token>, position: Position) {
	# Dequeue the parameter types
	parameters = tokens.pop_or(none as Token) as ParenthesisToken

	# Dequeue the arrow operator
	tokens.pop_or(none as Token)

	# Dequeues the return type
	return_type = read_type(context, tokens) as Type

	# The return type must exist
	if return_type == none return none as FunctionType

	# Read all the parameter types
	parameter_types = List<Type>()
	parameter_tokens = parameters.tokens

	loop (parameter_tokens.size > 0) {
		parameter_type = read_type(context, parameter_tokens) as Type
		if parameter_type == none return none as FunctionType
		parameter_types.add(parameter_type)
		parameter_tokens.pop_or(none as Token) # Consume the comma, if there are tokens left
	}

	return FunctionType(parameter_types, return_type, position)
}

# Summary:
# Creates an unnamed pack type from the specified tokens.
# Pattern: { $member-1: $type-1, $member-2: $type-2, ... }
read_pack_type(context: Context, tokens: List<Token>, position: Position) {
	pack_type = context.declare_unnamed_pack(position)
	sections = tokens.pop_or(none as Token).(ParenthesisToken).get_sections()

	# We are not going to feed the sections straight to the parser while using the pack type as context, because it would allow defining whole member functions
	loop section in sections {
		# Determine the member name and its type
		member = section[].(IdentifierToken).value

		type = read_type(context, section.slice(2))
		if type == none return none as Type

		# Create the member using the determined properties
		pack_type.(Context).declare(type, VARIABLE_CATEGORY_MEMBER, member)
	}

	return pack_type
}

# Summary: Reads a type from the next tokens inside the specified tokens
# Pattern: $name [<$1, $2, ... $n>]
read_type(context: Context, tokens: List<Token>) {
	if tokens.size == 0 return none as Type

	next = tokens[]

	if next.match(TOKEN_TYPE_PARENTHESIS) {
		if next.match(`(`) return read_function_type(context, tokens, next.position)
		if next.match(`{`) return read_pack_type(context, tokens, next.position)

		return none as Type
	}

	if not next.match(TOKEN_TYPE_IDENTIFIER) return none as Type

	components = List<UnresolvedTypeComponent>()

	loop {
		components.add(read_type_component(context, tokens))

		# Stop collecting type components if there are no tokens left or if the next token is not a dot operator
		if tokens.size == 0 or not tokens[].match(Operators.DOT) stop

		tokens.pop_or(none as Token)
	}

	type = UnresolvedType(components)

	# If there are no more tokens, return the type
	if tokens.size === 0 return type.resolve_or_this(context)

	# Array types:
	next = tokens[]

	if next.match(`[`) {
		tokens.pop_or(none as Token)

		type.size = next as ParenthesisToken
		return type.resolve_or_this(context)
	}

	# Count the number of pointers
	loop {
		# Require at least one token
		if tokens.size === 0 stop

		# Expect a multiplication operator (pointer)
		if not tokens[].match(Operators.MULTIPLY) stop
		tokens.pop_or(none as Token)

		# Wrap the current type around a pointer
		type.pointers++
	}

	return type.resolve_or_this(context)
}

# Summary: Reads a type from the next tokens inside the specified tokens
# Pattern: $name [<$1, $2, ... $n>]
read_type(context: Context, tokens: List<Token>, start: large) {
	return read_type(context, tokens.slice(start, tokens.size))
}

# Summary: Returns whether the specified node is a function call
is_function_call(node: Node) {
	if node.instance == NODE_LINK { node = node.last }
	return node.instance == NODE_CALL or node.instance == NODE_FUNCTION
}

# Summary: Returns whether the specified node tree contains a memory load
is_memory_accessed(node: Node) {
	instances = NODE_ACCESSOR | NODE_LINK
	return node.match(instances) or node.find(instances) !== none
}

# Summary: Returns whether the specified node accesses any member of the specified type and the access requires self pointer
is_self_pointer_required(node: Node) {
	if node.instance != NODE_FUNCTION and node.instance != NODE_VARIABLE return false
	if node.parent.match(NODE_CONSTRUCTION | NODE_LINK) return false

	if node.instance == NODE_FUNCTION {
		function = node.(FunctionNode).function
		return function.is_member and not function.is_static
	}

	variable = node.(VariableNode).variable
	return variable.is_member and not variable.is_static
}

# Summary:
# Pattern: <$1, $2, ... $n>
consume_template_arguments(state: ParserState) {
	# Next there must be the opening of the template parameters
	next = state.peek()
	if next == none or not next.match(Operators.LESS_THAN) return false
	state.consume()

	# Keep track whether at least one argument has been consumed
	is_argument_consumed = false

	loop {
		next = state.peek()
		if next === none return false

		# If the consumed operator is a greater than operator, it means the template arguments have ended
		if next.match(Operators.GREATER_THAN) {
			state.consume()
			return is_argument_consumed
		}

		# If the operator is a comma, it means the template arguments have not ended
		if next.match(Operators.COMMA) {
			state.consume()
			continue
		}

		if consume_type(state) {
			is_argument_consumed = true
			continue
		}

		# The template arguments must be invalid
		return false
	}
}

# Summary:
# Consumes a template function call except the name in the beginning
# Pattern: <$1, $2, ... $n> (...)
consume_template_function_call(state: ParserState) {
	# Consume pattern: <$1, $2, ... $n>
	if not consume_template_arguments(state) return false

	# Now there must be function parameters next
	next = state.peek()
	if next == none or not next.match(`(`) return false

	state.consume()
	return true
}

# Summary: Consumes a function type
# Pattern: (...) -> $type
consume_function_type(state: ParserState) {
	# Consume a normal parenthesis
	next = state.peek()
	if next == none or not next.match(`(`) return false
	state.consume()

	# Consume an arrow operator
	next = state.peek()
	if next == none or not next.match(Operators.ARROW) return false
	state.consume()

	# Consume the return type
	return consume_type(state)
}

# Summary:
# Consumes a pack type.
# Pattern: { $member-1: $type, $member-2: $type, ... }
consume_pack_type(state: ParserState) {
	# Consume curly brackets
	brackets = state.peek()
	if brackets == none or not brackets.match(`{`) return false

	# Verify the curly brackets contain pack members using sections
	# Pattern: { $member-1: $type, $member-2: $type, ... }
	sections = brackets.(ParenthesisToken).get_sections()
	if sections.size == 0 return false

	loop section in sections {
		if section.size < 3 return false

		# Verify the first token is a member name
		if section[].type != TOKEN_TYPE_IDENTIFIER return false

		# Verify the second token is a colon
		if not section[1].match(Operators.COLON) return false
	}

	return true
}

consume_type_end(state: ParserState) {
	next = none as Token

	# Consume pointers
	loop {
		next = state.peek()
		if next === none return

		if not next.match(Operators.MULTIPLY) stop
		state.consume()
	}

	# Do not allow creating nested arrays
	if next.match(`[`) {
		state.consume()
	}
}

consume_type(state: ParserState) {
	if not state.consume(TOKEN_TYPE_IDENTIFIER) {
		next = state.peek()
		if next === none return false

		if next.match(`{`) {
			if not consume_pack_type(state) return false
		}
		else next.match(`(`) {
			if not consume_function_type(state) return false
		}
		else {
			return false
		}

		return true
	}

	loop {
		next = state.peek()
		if next === none return true

		if next.match(Operators.DOT) {
			state.consume()
			if not state.consume(TOKEN_TYPE_IDENTIFIER) return false
		}
		else next.match(Operators.LESS_THAN) {
			if not consume_template_arguments(state) return false
		}
		else {
			stop
		}
	}

	consume_type_end(state)
	return true
}

# Summary: Returns the types of the child nodes
get_types(node: Node) {
	types = List<Type>()

	loop iterator in node {
		type = iterator.try_get_type()
		if type == none or type.is_unresolved return none
		types.add(type)
	}

	return types
}

find_condition(start) {
	iterator = start

	loop (iterator != none) {
		instance = iterator.instance
		if instance != NODE_SCOPE and instance != NODE_INLINE and instance != NODE_NORMAL and instance != NODE_PARENTHESIS return iterator
		iterator = iterator.last
	}

	abort('Could not find condition')
}

consume_block(from: ParserState, destination: List<Token>) {
	return consume_block(from, destination, 0)
}

consume_block(from: ParserState, destination: List<Token>, disabled: large) {
	# Return an empty list, if there is nothing to be consumed
	if from.end >= from.all.size return none as Status

	# Clone the tokens from the specified state
	tokens = clone(from.all.slice(from.end, from.all.size))

	state = ParserState()
	state.all = tokens

	consumptions = List<Pair<parser.DynamicToken, large>>()
	context = Context("0", NORMAL_CONTEXT)

	loop (priority = parser.MAX_FUNCTION_BODY_PRIORITY, priority >= parser.MIN_PRIORITY, priority--) {
		loop {
			if not parser.next_consumable(context, tokens, priority, 0, state, disabled) stop
			
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
						if consumption.first != token continue
						area = consumption.second
						stop
					}
				}
				
				consumed += area
				tokens.remove_at(state.start)
			}

			if node == none {
				error = state.error
				if error === none { error = Status('Block consumption does not accept patterns returning nothing') }
				return error
			}

			result = parser.DynamicToken(node)
			tokens.insert(state.start, result)
			consumptions.add(Pair<parser.DynamicToken, large>(result, consumed))
		}
	}

	next = tokens[]

	if next.type == TOKEN_TYPE_DYNAMIC {
		consumed = 1

		# Determine how many tokens the next dynamic token consumed
		loop consumption in consumptions {
			if consumption.first != next continue
			consumed = consumption.second
			stop
		}

		# Read the consumed tokens from the source state
		source = from.all
		end = from.end

		loop (i = 0, i < consumed, i++) {
			destination.add(source[end + i])
		}

		from.end += consumed
		return none as Status
	}

	# Just consume the first token
	from.end++
	destination.add(next)
	return none as Status
}

get_template_parameters(template_parameter_tokens: List<Token>) {
	template_parameters = List<String>()

	loop (i = 0, i < template_parameter_tokens.size, i++) {
		if i % 2 != 0 continue
		if template_parameter_tokens[i].type != TOKEN_TYPE_IDENTIFIER abort('Template parameter tokens were invalid')

		template_parameters.add(template_parameter_tokens[i].(IdentifierToken).value)
	}

	return template_parameters
}

# Summary: Returns whether the two specified types are compatible
compatible(expected: Type, actual: Type) {
	if expected == none or actual == none or expected.is_unresolved or actual.is_unresolved return false

	if expected.match(actual) return true

	if not expected.is_primitive or not actual.is_primitive {
		if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) return false
	} 
	else resolver.get_shared_type(expected, actual) == none return false

	return true
}

# Summary:  Returns whether the specified actual types are compatible with the specified expected types, that is whether the actual types can be casted to match the expected types. This function also requires that the actual parameters are all resolved, otherwise this function returns false.
compatible(expected_types: List<Type>, actual_types: List<Type>) {
	if expected_types.size != actual_types.size return false

	loop (i = 0, i < expected_types.size, i++) {
		expected = expected_types[i]
		if expected == none continue

		actual = actual_types[i]
		if expected.match(actual) continue

		if not expected.is_primitive or not actual.is_primitive {
			if not expected.is_type_inherited(actual) and not actual.is_type_inherited(expected) return false
		} 
		else resolver.get_shared_type(expected, actual) == none return false
	}

	return true
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(self: Node, self_type: Type, name: String, arguments: Node, argument_types: List<Type>, position: Position) {
	if not self_type.is_virtual_function_declared(name) return none as CallNode

	# Ensure all the parameters are resolved
	loop argument_type in argument_types {
		if argument_type == none or argument_type.is_unresolved return none as CallNode
	}

	# Try to find a virtual function with the parameter types
	overload = self_type.get_virtual_function(name).get_overload(argument_types) as VirtualFunction
	if overload == none or overload.return_type == none return none as CallNode

	required_self_type = overload.find_type_parent()
	if required_self_type == none abort('Could not retrieve virtual function parent type')

	# Require that the self type has runtime configuration
	if required_self_type.configuration == none return none as CallNode

	configuration = required_self_type.get_configuration_variable()
	alignment = required_self_type.get_all_virtual_functions().index_of(overload)
	if alignment == -1 abort('Could not compute virtual function alignment')

	function_pointer = AccessorNode(LinkNode(self.clone(), VariableNode(configuration)), NumberNode(SYSTEM_FORMAT, alignment + 1, position), position)

	# Cast the self pointer, if necessary
	if self_type != required_self_type {
		casted = CastNode(self, TypeNode(required_self_type), self.start)
		self = casted
	}

	# Determine the parameter types
	parameter_types = List<Type>(argument_types.size, false)
	loop parameter in overload.parameters { parameter_types.add(parameter.type) }

	return CallNode(self, function_pointer, arguments, FunctionType(required_self_type, parameter_types, overload.return_type, position), position)
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(environment: Context, self: Node, self_type: Type, descriptor: FunctionToken) {
	arguments = descriptor.parse(environment)
	argument_types = List<Type>()
	loop argument in arguments { argument_types.add(argument.try_get_type()) }

	return try_get_virtual_function_call(self, self_type, descriptor.name, arguments, argument_types, descriptor.position)
}

# Summary: Tries to build a virtual function call which has a specified owner
try_get_virtual_function_call(environment: Context, name: String, arguments: Node, argument_types: List<Type>, position: Position) {
	if not environment.is_inside_function return none as CallNode

	type = environment.find_type_parent()
	if type == none return none as CallNode

	self = get_self_pointer(environment, position)
	return try_get_virtual_function_call(self, type, name, arguments, argument_types, position)
}

# Summary: Tries to build a virtual function call which uses the current self pointer
try_get_virtual_function_call(environment: Context, descriptor: FunctionToken) {
	if not environment.is_inside_function return none as CallNode

	type = environment.find_type_parent()
	if type == none return none as CallNode

	self = get_self_pointer(environment, descriptor.position)
	return try_get_virtual_function_call(environment, self, type, descriptor)
}

# Summary: Tries to build a lambda call which is stored inside a specified owner
try_get_lambda_call(primary: Context, left: Node, name: String, arguments: Node, argument_types: List<Type>) {
	if not primary.is_variable_declared(name) return none as CallNode

	variable = primary.get_variable(name)

	# Require the variable to represent a function
	if variable.type == none or not variable.type.is_function_type return none as CallNode
	properties = variable.type as FunctionType

	# Require that the specified argument types pass the required parameter types
	if not compatible(properties.parameters, argument_types) return none as CallNode
	
	position = left.start
	self = LinkNode(left, VariableNode(variable), position)
	
	# Determine where the function pointer is located
	offset = 1
	if settings.is_garbage_collector_enabled { offset = 2 }

	# Load the function pointer using the offset
	function_pointer = AccessorNode(self.clone(), NumberNode(SYSTEM_FORMAT, offset, position), position)
	return CallNode(self, function_pointer, arguments, properties, position)
}

# Summary: Tries to build a lambda call which is stored inside the current scope or in the self pointer
try_get_lambda_call(environment: Context, name: String, arguments: Node, argument_types: List<Type>) {
	if not environment.is_variable_declared(name) return none as CallNode

	variable = environment.get_variable(name)

	# Require the variable to represent a function
	if variable.type == none or not variable.type.is_function_type return none as CallNode
	properties = variable.type as FunctionType

	# Require that the specified argument types pass the required parameter types
	if not compatible(properties.parameters, argument_types) return none as CallNode

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
	return CallNode(self, function_pointer, arguments, properties, position)
}

# Summary: Tries to build a lambda call which is stored inside the current scope or in the self pointer
try_get_lambda_call(environment: Context, descriptor: FunctionToken) {
	arguments = descriptor.parse(environment)
	argument_types = List<Type>()
	loop argument in arguments { argument_types.add(argument.try_get_type()) }

	return try_get_lambda_call(environment, descriptor.name, arguments, argument_types)
}

# Summary: Collects all types and subtypes from the specified context
get_all_types(context: Context) {
	return get_all_types(context, true)
}

# Summary: Collects all types and subtypes from the specified context
get_all_types(context: Context, include_imported: bool) {
	result = List<Type>()

	loop iterator in context.types {
		type = iterator.value
		if include_imported or not type.is_imported result.add(type)
		result.add_all(get_all_types(type))
	}

	return result
}

# Summary:
# Collects all functions from the specified context and its subcontexts.
# NOTE: This function does not return lambda functions.
get_all_visible_functions(context: Context) {
	# Collect all functions, constructors, destructors and virtual functions
	functions = List<Function>()

	loop type in get_all_types(context) {
		loop a in type.functions { functions.add_all(a.value.overloads) }
		loop b in type.virtuals { functions.add_all(b.value.overloads) }
		loop c in type.overrides { functions.add_all(c.value.overloads) }

		functions.add_all(type.constructors.overloads)
		functions.add_all(type.destructors.overloads)
	}

	loop function in context.functions {
		functions.add_all(function.value.overloads)
	}
	
	return functions.distinct()
}

# Summary: Collects all function implementations from the specified context
get_all_function_implementations(context: Context) {
	return get_all_function_implementations(context, true)
}

# Summary: Collects all function implementations from the specified context
get_all_function_implementations(context: Context, include_imported: bool) {
	# Collect all functions, constructors, destructors and virtual functions
	functions = List<Function>()

	loop type in get_all_types(context) {
		loop a in type.functions { functions.add_all(a.value.overloads) }
		loop b in type.virtuals { functions.add_all(b.value.overloads) }
		loop c in type.overrides { functions.add_all(c.value.overloads) }

		functions.add_all(type.constructors.overloads)
		functions.add_all(type.destructors.overloads)
	}

	loop function in context.functions {
		functions.add_all(function.value.overloads)
	}

	implementations = List<FunctionImplementation>()

	# Collect all the implementations from the functions and collect the inner implementations as well such as lambdas
	loop function in functions {
		loop implementation in function.implementations {
			implementations.add_all(get_all_function_implementations(implementation))
			if include_imported or not implementation.is_imported implementations.add(implementation)
		}
	}

	return implementations.distinct()
}

# Summary: Try to determine the type of access related to the specified node
try_get_access_type(node: Node) {
	parent = none as Node

	loop (iterator = node.parent, iterator != none, iterator = iterator.parent) {
		if iterator.instance == NODE_CAST continue
		parent = iterator
		stop
	}

	if parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT {
		if parent.first == node or node.is_under(parent.first) return ACCESS_TYPE_WRITE
		return ACCESS_TYPE_READ
	}

	if parent.match(NODE_INCREMENT | NODE_DECREMENT) return ACCESS_TYPE_WRITE
	return ACCESS_TYPE_READ
}

# Summary: Returns whether the specified is edited
is_edited(node: Node) {
	parent = none as Node

	loop (iterator = node.parent, iterator != none, iterator = iterator.parent) {
		if iterator.instance == NODE_CAST continue
		parent = iterator
		stop
	}

	if parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT return parent.first == node or node.is_under(parent.first)
	return parent.match(NODE_INCREMENT | NODE_DECREMENT)
}

# Summary: Returns the node which is the destination of the specified edit
get_edited(editor: Node) {
	iterator = editor.first

	loop (iterator != none) {
		if not iterator.match(NODE_CAST) return iterator
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

	return node
}

# Summary:
# Tries to return the node which edits the specified node.
# Returns null if the specified node is not edited.
try_get_editor(node: Node) {
	editor = none as Node

	loop (iterator = node.parent, iterator != none, iterator = iterator.parent) {
		if iterator.instance == NODE_CAST continue
		editor = iterator
		stop
	}

	if editor == none return none as Node

	if editor.instance == NODE_OPERATOR and editor.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT return editor
	if editor.instance == NODE_INCREMENT or editor.instance == NODE_DECREMENT return editor

	return none as Node
}

# Summary: Returns the node which edits the specified node
get_editor(edited: Node) {
	editor = try_get_editor(edited)
	if editor != none return editor

	abort('Could not find the editor node')
}

# Summary: Returns whether the specified node represents a statement
is_statement(node: Node) {
	type = node.instance
	return type == NODE_ELSE or type == NODE_ELSE_IF or type == NODE_IF or type == NODE_LOOP or type == NODE_SCOPE
}

# Summary: Returns whether the specified node represents a constant
is_constant(node: Node) {
	source = common.get_source(node)

	if source.instance == NODE_VARIABLE return source.(VariableNode).variable.is_constant
	return source.match(NODE_NUMBER | NODE_STRING | NODE_DATA_POINTER)
}

# Summary: Returns whether the specified node represents a statement condition
is_condition(node: Node) {
	statement = node.find(NODE_ELSE_IF | NODE_IF | NODE_LOOP)
	if statement == none return false
	
	return when(statement.instance) {
		NODE_IF => statement.(IfNode).condition == node
		NODE_ELSE_IF => statement.(ElseIfNode).condition == node
		NODE_LOOP => statement.(LoopNode).condition == node
		else => false
	}
}

# Summary: Returns whether the specified node represents a local variable
is_local_variable(node: Node) {
	return node.instance == NODE_VARIABLE and node.(VariableNode).variable.is_predictable
}

# Summary: Returns whether a value is expected to return from the specified node
is_value_used(value: Node) {
	return value.parent.match(NODE_CALL | NODE_CAST | NODE_PARENTHESIS | NODE_CONSTRUCTION | NODE_DECREMENT | NODE_FUNCTION | NODE_INCREMENT | NODE_LINK | NODE_NEGATE | NODE_NOT | NODE_ACCESSOR | NODE_OPERATOR | NODE_RETURN)
}

# Summary: Returns how many bits the value requires
get_bits(value: large, is_decimal: bool) {
	if is_decimal return SYSTEM_BITS

	if value < 0 {
		if value < -2147483648 return 64
		if value < -32768 return 32
		if value < -128 return 16
	}
	else {
		if value > 2147483647 return 64
		if value > 32767 return 32
		if value > 127 return 16
	}

	return 8
}

# Summary: Returns whether the specified integer fulfills the following equation:
# x = 2^y where y is an integer constant
is_power_of_two(value: large) {
	return (value & (value - 1)) == 0
}

# Summary:
# Returns whether the node represents a number that is power of two
is_power_of_two(node: Node) {
	return node.instance == NODE_NUMBER and node.(NumberNode).format != FORMAT_DECIMAL and is_power_of_two(node.(NumberNode).value)
}

integer_log2(value: large) {
	i = 0

	loop {
		value = value |> 1
		if value == 0 return i
		i++
	}
}

# Summary: Joins the specified token lists with the specified separator
join(separator: Token, parts: List<List<Token>>) {
	result = List<Token>()
	if parts.size == 0 return result

	loop tokens in parts {
		result.add_all(tokens)
		result.add(separator)
	}

	result.remove_at(result.size - 1)
	return result
}

# Summary: Converts the specified type into tokens
get_tokens(type: Type, position: Position) {
	result = List<Token>()

	if type.is_unnamed_pack {
		# Construct the following pattern from the members of the pack: [ $member-1: $type-1 ], [ $member-2: $type-2 ], ...
		members = List<List<Token>>()

		loop iterator in type.variables {
			member = iterator.value

			member_tokens = List<Token>()
			member_tokens.add(IdentifierToken(member.name, position))
			member_tokens.add(OperatorToken(Operators.COLON, position))
			member_tokens.add_all(get_tokens(member.type, position))

			members.add(member_tokens)
		}

		# Now, join the token arrays with commas and put them inside curly brackets: { $member-1: $type-1, $member-2: $type-2, ... }
		result.add(ParenthesisToken(`{`, position, position, join(OperatorToken(Operators.COMMA, position), members)))

		return result
	}

	if type.is_function_type {
		function = type as FunctionType
		parameters = function.parameters.map<List<Token>>((i: Type) -> get_tokens(i, position))
		separator = OperatorToken(Operators.COMMA, position)
		separator.position = position

		result.add(ParenthesisToken(`(`, position, position, join(separator, parameters)))
		result.add(OperatorToken(Operators.ARROW, position))
		result.add_all(get_tokens(function.return_type, position))

		return result
	}

	if type.is_array_type {
		result.add_all(get_tokens(type.(ArrayType).element, position))
		result.add(ParenthesisToken(`[`, position, position, [ NumberToken(type.(ArrayType).size, SYSTEM_FORMAT, position, position) as Token ]))
		return result
	}

	if type.parent != none and type.parent.is_type {
		result.add_all(get_tokens(type.parent, position))
		result.add(OperatorToken(Operators.DOT, position))
	}

	if type.is_user_defined { result.add(IdentifierToken(type.identifier, position)) }
	else { result.add(IdentifierToken(type.name, position)) }

	if type.template_arguments.size > 0 {
		result.add(OperatorToken(Operators.LESS_THAN, position))

		arguments = List<List<Token>>(type.template_arguments.size, true)

		loop (i = 0, i < arguments.size, i++) {
			arguments[i] = get_tokens(type.template_arguments[i], position)
		}

		separator = OperatorToken(Operators.COMMA, position)
		result.add_all(join(separator, arguments))

		result.add(OperatorToken(Operators.GREATER_THAN, position))
	}

	return result
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

	if end != none return end

	return token.position.translate(1)
}

# Summary: Creates a function header without return type from the specified values
# Format: $name($type1, $type2, ... $typen) / $name<$type1, $type2, ... $typen>($type1, $type2, ... $typen)
to_string(name: String, arguments: List<Type>, template_arguments: List<Type>) {
	template_argument_strings = List<String>(template_arguments.size, false)

	loop template_argument in template_arguments {
		if template_argument == none or template_argument.is_unresolved {
			template_argument_strings.add("?")
		}
		else {
			template_argument_strings.add(template_argument.string())
		}
	}

	argument_strings = List<String>(arguments.size, false)

	loop argument in arguments {
		if argument == none or argument.is_unresolved {
			argument_strings.add("?")
		}
		else {
			argument_strings.add(argument.string())
		}
	}

	if template_argument_strings.size > 0 return name + `<` + String.join(", ", template_argument_strings) + '>(' + String.join(", ", argument_strings) + `)`
	
	return name + `(` + String.join(", ", argument_strings) + `)`
}

# Summary: Aligns the member variables of the specified type
align_members(type: Type) {
	position = 0

	# Member variables:
	loop iterator in type.variables {
		variable = iterator.value
		if variable.is_static or variable.is_constant continue
		variable.alignment = position
		variable.is_aligned = true
		position += variable.type.allocation_size
	}
}

# Summary:
# Returns all local variables, which represent the specified pack variable
get_pack_proxies(context: Context, prefix: String, type: Type, category: large) {
	proxies = List<Variable>()

	loop iterator in type.variables {
		member = iterator.value
		name = prefix + '.' + member.name

		# Create proxies for each member, even for nested pack members
		proxy = context.get_variable(name)
		if proxy == none { proxy = context.declare(member.type, category, name) }

		if member.type.is_pack {
			proxies.add_all(get_pack_proxies(context, name, member.type, category))
		}
		else {
			proxies.add(proxy)
		}
	}

	return proxies
}

# Summary:
# Returns all local variables, which represent the specified pack variable
get_pack_proxies(variable: Variable) {
	# If we are accessing a pack proxy, no need to add dot to the name
	if variable.name.starts_with(`.`) return get_pack_proxies(variable.parent, variable.name, variable.type, variable.category)

	return get_pack_proxies(variable.parent, String(`.`) + variable.name, variable.type, variable.category)
}

# Summary:
# Returns true if the specified node represents integer zero
is_zero(node: Node) {
	return node != none and node.instance == NODE_NUMBER and node.(NumberNode).value == 0
}