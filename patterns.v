namespace parser

Pattern CommandPattern {
	constant KEYWORD = 0

	init() {
		# Pattern: stop/continue
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 2
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		keyword = tokens[KEYWORD].(KeywordToken).keyword
		return keyword === Keywords.STOP or keyword === Keywords.CONTINUE
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		return CommandNode(tokens[KEYWORD].(KeywordToken).keyword, tokens[KEYWORD].position)
	}
}

Pattern AssignPattern {
	constant DESTINATION = 0
	constant OPERATOR = 1

	init() {
		# Pattern: $name = ...
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 19
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[OPERATOR].match(Operators.ASSIGN)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Do not remove the assign operator after building the tokens
		state.end--

		destination = tokens[DESTINATION] as IdentifierToken
		name = destination.value

		if not context.is_variable_declared(name) {
			# Ensure the name is not reserved
			if name == SELF_POINTER_IDENTIFIER or name == LAMBDA_SELF_POINTER_IDENTIFIER {
				state.error = Status(destination.position, "Can not create variable with name " + name)
				return none as Node
			}

			# Determine the category and the modifiers of the variable
			is_constant = context.parent == none
			category = VARIABLE_CATEGORY_MEMBER

			if not context.is_type {
				if is_constant { category = VARIABLE_CATEGORY_GLOBAL }
				else { category = VARIABLE_CATEGORY_LOCAL }
			}

			modifiers = MODIFIER_DEFAULT
			if is_constant { modifiers |= MODIFIER_CONSTANT }

			# All variables in namespaces are static
			if context.is_namespace {
				modifiers |= MODIFIER_STATIC
			}

			variable = Variable(context, none as Type, category, name, modifiers)
			variable.position = destination.position

			context.declare(variable)

			return VariableNode(variable, destination.position)
		}

		variable = context.get_variable(name)

		# Static variables must be accessed using their parent types
		if variable.is_static return LinkNode(TypeNode(variable.parent as Type), VariableNode(variable, destination.position), destination.position)

		if variable.is_member {
			self = common.get_self_pointer(context, destination.position)
			return LinkNode(self, VariableNode(variable, destination.position), destination.position)
		}

		return VariableNode(variable, destination.position)
	}
}

Pattern FunctionPattern {
	constant FUNCTION = 0
	constant COLON = 1

	constant RETURN_TYPE_START = 2 # COLON + 1

	# Pattern: $name (...) [: $return-type] [\n] {...}
	init() {
		path.add(TOKEN_TYPE_FUNCTION)

		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Look for a return type
		if state.consume_operator(Operators.COLON) {
			# Expected: $name (...) : $return-type [\n] {...}
			if not common.consume_type(state) return false
		}

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Consume the function body
		return state.consume_parenthesis(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[FUNCTION] as FunctionToken
		blueprint = tokens[tokens.size - 1] as ParenthesisToken
		return_type = none as Type
		start = descriptor.position
		end = blueprint.end

		# Process the return type if such was consumed
		if tokens[COLON].match(Operators.COLON) {
			# Collect the return type tokens after the colon and before the line ending
			return_type_tokens = tokens.slice(RETURN_TYPE_START, tokens.size - 2)
			return_type = common.read_type(context, return_type_tokens)

			# Verify the return type could be parsed in some form
			if return_type == none {
				state.error = Status(tokens[COLON].position, 'Could not understand the return type')
				return none as Node
			}
		}

		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint.tokens, start, end)
		function.return_type = return_type

		result = descriptor.get_parameters(function)
		if result has not parameters {
			state.error = Status(result.get_error())
			return none as Node
		}

		function.parameters.add_all(parameters)

		conflict = context.declare(function)
		if conflict != none {
			state.error = Status(start, 'Function conflicts with another function')
			return none as Node
		}

		return FunctionDefinitionNode(function, start)
	}
}

Pattern OperatorPattern {
	constant LEFT = 0
	constant OPERATOR = 2
	constant RIGHT = 4

	init() {
		# Pattern: ... [\n] $operator [\n] ...
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OBJECT)

		priority = PRIORITY_ALL
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[OPERATOR].(OperatorToken).operator.priority == priority
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		token = tokens[OPERATOR]

		return OperatorNode(token.(OperatorToken).operator, token.position).set_operands(parse(context, tokens[LEFT]), parse(context, tokens[RIGHT]))
	}
}

Pattern TypePattern {
	constant NAME = 0
	constant BODY = 2

	init() {
		# Pattern: $name [\n] {...}
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME].(IdentifierToken)
		body = tokens[BODY].(ParenthesisToken)

		type = Type(context, name.value, MODIFIER_DEFAULT, name.position)

		return TypeDefinitionNode(type, body.tokens, name.position)
	}
}

Pattern ReturnPattern {
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not tokens[].match(Keywords.RETURN) return false

		state.consume(TOKEN_TYPE_OBJECT) # Optionally consume a return value
		return true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		return_value = none as Node

		if tokens.size > 1 {
			return_value = parser.parse(context, tokens[1])
		}

		return ReturnNode(return_value, tokens[].position)
	}
}

Pattern VariableDeclarationPattern {
	constant NAME = 0
	constant COLON = 1

	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 19
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[COLON].match(Operators.COLON) and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken

		if context.is_local_variable_declared(name.value) {
			state.error = Status(name.position, 'Variable already exists')
			return none as Node
		}

		if name.value == SELF_POINTER_IDENTIFIER or name.value == LAMBDA_SELF_POINTER_IDENTIFIER {
			state.error = Status(name.position, "Can not create variable with name " + name.value)
			return none as Node
		}

		type = common.read_type(context, tokens, COLON + 1)

		is_constant = context.parent == none

		# Determine the variable category
		category = VARIABLE_CATEGORY_MEMBER

		if not context.is_type {
			if is_constant { category = VARIABLE_CATEGORY_GLOBAL }
			else { category = VARIABLE_CATEGORY_LOCAL }
		}

		# Determine the modifiers of the variable
		modifiers = MODIFIER_DEFAULT
		if is_constant { modifiers |= MODIFIER_CONSTANT }
		if context.is_namespace { modifiers |= MODIFIER_STATIC }

		variable = Variable(context, type, category, name.value, modifiers)
		variable.position = tokens[NAME].position

		context.declare(variable)

		return VariableNode(variable, name.position)
	}
}

Pattern IfPattern {
	constant KEYWORD = 0
	constant CONDITION = 1
	constant BODY = 2

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)

		priority = 1
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		keyword = tokens[KEYWORD].(KeywordToken).keyword
		if keyword != Keywords.IF and keyword != Keywords.ELSE return false

		# Prevents else-if from thinking that a body is a condition
		if tokens[CONDITION].match(`{`) return false

		# Try to consume curly brackets
		next = state.peek()
		if next == none return false
		if next.match(`{`) state.consume()

		return true
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		condition = parser.parse(environment, tokens[CONDITION])
		start = tokens[KEYWORD].position
		end = none as Position

		body = none as List<Token>
		last = tokens[tokens.size - 1]

		context = Context(environment, NORMAL_CONTEXT)
		
		if last.match(`{`) {
			body = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			body = List<Token>()
			error = common.consume_block(state, body)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				return none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		if tokens[KEYWORD].(KeywordToken).keyword == Keywords.IF return IfNode(context, condition, node, start, end)
		return ElseIfNode(context, condition, node, start, end)
	}
}

Pattern ElsePattern {
	init() {
		# Pattern: $if/$else-if [\n] else [\n] {...}/...
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)

		priority = 1
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure there is an (else) if-statement before this else-statement
		if state.start == 0 return false
		token = state.all[state.start - 1]

		# If the previous token represents an (else) if-statement, just continue
		if token.type != TOKEN_TYPE_DYNAMIC or not token.(DynamicToken).node.match(NODE_IF | NODE_ELSE_IF) {
			# The previous token must be a line ending in order for this pass function to succeed
			if token.type != TOKEN_TYPE_END or state.start == 1 return false

			# Now, the token before the line ending must be an (else) if-statement in order for this pass function to succeed
			token = state.all[state.start - 2]
			if token.type != TOKEN_TYPE_DYNAMIC or not token.(DynamicToken).node.match(NODE_IF | NODE_ELSE_IF) return false
		}

		# Ensure the keyword is the else-keyword
		if tokens[].(KeywordToken).keyword != Keywords.ELSE return false

		next = state.peek()
		if next == none return false
		if next.match(`{`) state.consume()
		return true
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		start = tokens[].position
		end = none as Position

		body = none as List<Token>
		last = tokens[tokens.size - 1]

		context = Context(environment, NORMAL_CONTEXT)
		
		if last.match(`{`) {
			body = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			body = List<Token>()
			error = common.consume_block(state, body)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				return none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		return ElseNode(context, node, start, end)
	}
}

Pattern LinkPattern {
	constant STANDARD_TOKEN_COUNT = 5

	constant LEFT = 0
	constant OPERATOR = 2
	constant RIGHT = 4

	init() {
		# Pattern: ... [\n] . [\n] ...
		path.add(TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_DYNAMIC)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the operator is the dot operator
		if not tokens[OPERATOR].match(Operators.DOT) return false
		# Try to consume template arguments
		if tokens[RIGHT].match(TOKEN_TYPE_IDENTIFIER) {
			backup = state.save()
			if not common.consume_template_function_call(state) state.restore(backup)
		}

		return true
	}

	private build_template_function_call(context: Context, tokens: List<Token>, left: Node): LinkNode {
		# Load the properties of the template function call
		name = tokens[RIGHT].(IdentifierToken)
		descriptor = FunctionToken(name, tokens[tokens.size - 1] as ParenthesisToken)
		descriptor.position = name.position
		template_arguments = common.read_template_arguments(context, tokens, RIGHT + 1)

		primary = common.get_context(left)

		if primary != none {
			right = parser.parse_function(context, primary, descriptor, template_arguments, true)
			return LinkNode(left, right, tokens[OPERATOR].position)
		}

		right = UnresolvedFunction(name.value, template_arguments, descriptor.position)
		right.(UnresolvedFunction).set_arguments(descriptor.parse(context))
		return LinkNode(left, right, tokens[OPERATOR].position)
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		left = parser.parse(environment, tokens[LEFT])

		# When there are more tokens than the standard count, it means a template function has been consumed
		if tokens.size != STANDARD_TOKEN_COUNT return build_template_function_call(environment, tokens, left)

		# If the right operand is a parenthesis token, this is a cast expression
		if tokens[RIGHT].match(TOKEN_TYPE_PARENTHESIS) {
			# Read the cast type from the content token
			type = common.read_type(environment, tokens[RIGHT].(ParenthesisToken).tokens)

			if type == none {
				state.error = Status(tokens[RIGHT].position, 'Can not understand the cast')
				return none as Node
			}

			return CastNode(left, TypeNode(type, tokens[RIGHT].position), tokens[OPERATOR].position)
		}

		# Try to retrieve the primary context from the left token
		primary = common.get_context(left)
		right = none as Node
		token = tokens[RIGHT]

		if primary == none {
			# Since the primary context could not be retrieved, an unresolved link node must be returned
			if token.match(TOKEN_TYPE_IDENTIFIER) {
				right = UnresolvedIdentifier(token.(IdentifierToken).value, token.position)
			}
			else token.match(TOKEN_TYPE_FUNCTION) {
				right = UnresolvedFunction(token.(FunctionToken).name, token.position).set_arguments(token.(FunctionToken).parse(environment))
			}
			else {
				abort('Could not create unresolved node')
			}

			return LinkNode(left, right, tokens[OPERATOR].position)
		}

		right = parser.parse(environment, primary, token)

		# Try to build the right node as a virtual function or lambda call
		if right.match(NODE_UNRESOLVED_FUNCTION) {
			function = right as UnresolvedFunction
			types = List<Type>()
			loop argument in function { types.add(argument.try_get_type()) }

			position = tokens[OPERATOR].position

			# Try to form a virtual function call
			result = none as Node
			if primary.is_type { result = common.try_get_virtual_function_call(left, primary as Type, function.name, function, types, position) }

			if result != none return result

			# Try to form a lambda function call
			result = common.try_get_lambda_call(primary, left, function.name, function, types)

			if result != none {
				result.start = position
				return result
			}
		}

		return LinkNode(left, right, tokens[OPERATOR].position)
	}
}

Pattern ListPattern {
	constant ID = 1

	constant LEFT = 0
	constant COMMA = 2
	constant RIGHT = 4

	init() {
		# Pattern: ... , ...
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 0
		id = ID
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[COMMA].(OperatorToken).operator == Operators.COMMA
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		left = tokens[LEFT]
		right = tokens[RIGHT]
		
		# If the left token represents a list node, add the right operand to it and return the list
		if left.match(TOKEN_TYPE_DYNAMIC) {
			node = left.(DynamicToken).node
			
			if node.match(NODE_LIST) {
				node.add(parser.parse(context, right))
				return node
			}
		}

		return ListNode(tokens[COMMA].position, parser.parse(context, left), parser.parse(context, right))
	}
}

Pattern SingletonPattern {
	init() {
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_NUMBER | TOKEN_TYPE_STRING)
		priority = 0
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		return parser.parse(context, tokens[])
	}
}

Pattern LoopPattern {
	constant KEYWORD = 0
	constant STEPS = 1
	constant BODY = 3

	constant WHILE_LOOP = 1 # Example: (i < 10)
	constant SHORT_FOR_LOOP = 2 # Example: (i < 10, i++)
	constant FOR_LOOP = 3 # (i = 0, i < 10, i++)

	init() {
		# Pattern: loop (...) [\n] {...}
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_PARENTHESIS)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 1
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[KEYWORD].(KeywordToken).keyword == Keywords.LOOP and tokens[BODY].match(`{`)
	}

	private shared get_steps(context: Context, state: ParserState, parenthesis: ParenthesisToken): Node {
		if parenthesis.tokens.size == 0 return none as Node

		steps = none as Node
		sections = parenthesis.get_sections()

		if sections.size == WHILE_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(Node())
		}
		else sections.size == SHORT_FOR_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else sections.size == FOR_LOOP {
			steps = Node()
			steps.add(parser.parse(context, sections[], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[2], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else {
			state.error = Status(parenthesis.position, 'Too many sections')
			return none as Node
		}

		return steps
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		steps_context = Context(context, NORMAL_CONTEXT)
		body_context = Context(steps_context, NORMAL_CONTEXT)

		steps_token = tokens[STEPS]
		steps = get_steps(steps_context, state, steps_token as ParenthesisToken)
		if steps == none return none as Node

		body_token = tokens[BODY] as ParenthesisToken
		body = ScopeNode(body_context, body_token.position, body_token.end, false)

		parser.parse(body, body_context, body_token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		return LoopNode(steps_context, steps, body, tokens[KEYWORD].position)
	}
}

Pattern ForeverLoopPattern {
	constant KEYWORD = 0
	constant BODY = 2

	init() {
		# Pattern: loop [\n] {...}
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 1
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[KEYWORD].(KeywordToken).keyword == Keywords.LOOP and tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		steps_context = Context(context, NORMAL_CONTEXT)
		body_context = Context(steps_context, NORMAL_CONTEXT)

		body_token = tokens[BODY] as ParenthesisToken
		body = ScopeNode(body_context, body_token.position, body_token.end, false)

		parser.parse(body, body_context, body_token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		return LoopNode(steps_context, none as Node, body, tokens[KEYWORD].position)
	}
}

Pattern CastPattern {
	constant OBJECT = 0
	constant CAST = 1
	constant TYPE = 2

	init() {
		# Pattern: $value as $type
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_KEYWORD)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[CAST].(KeywordToken).keyword == Keywords.AS and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		type = common.read_type(context, tokens, TYPE)

		if type == none abort('Can not resolve the cast type')

		return CastNode(object, TypeNode(type, tokens[TYPE].position), tokens[CAST].position)
	}
}

Pattern UnarySignPattern {
	constant SIGN = 0
	constant OBJECT = 1

	init() {
		# Pattern 1: - $value
		# Pattern 2: + $value
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		sign = tokens[SIGN].(OperatorToken).operator
		if sign != Operators.ADD and sign != Operators.SUBTRACT return false
		if state.start == 0 return true
		previous = state.all[state.start - 1]
		return previous.type == TOKEN_TYPE_OPERATOR or previous.type == TOKEN_TYPE_KEYWORD
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		value = parser.parse(context, tokens[OBJECT])
		sign = tokens[SIGN].(OperatorToken).operator

		if value.match(NODE_NUMBER) {
			if sign == Operators.SUBTRACT return value.(NumberNode).negate()
			return value
		}

		if sign == Operators.SUBTRACT return NegateNode(value, tokens[SIGN].position)
		return value
	}
}

Pattern PostIncrementPattern {
	constant OBJECT = 0
	constant OPERATOR = 1

	init() {
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		operator = tokens[OPERATOR].(OperatorToken).operator
		return operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) return IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
		return DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
	}
}

Pattern PreIncrementPattern {
	constant OPERATOR = 0
	constant OBJECT = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		operator = tokens[OPERATOR].(OperatorToken).operator
		return operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) return IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
		return DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
	}
}

Pattern NotPattern {
	constant NOT = 0
	constant OBJECT = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 14
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[NOT].match(Operators.EXCLAMATION) or tokens[NOT].match(Keywords.NOT)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		return NotNode(parser.parse(context, tokens[OBJECT]), tokens[NOT].match(Operators.EXCLAMATION), tokens[NOT].position)
	}
}

Pattern AccessorPattern {
	constant OBJECT = 0
	constant ARGUMENTS = 1

	init() {
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[ARGUMENTS].(ParenthesisToken).opening == `[`
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		arguments = parser.parse(context, tokens[ARGUMENTS])

		# If there are no arguments, add number zero as argument
		if arguments.first === none {
			arguments.add(NumberNode(SYSTEM_FORMAT, 0, tokens[ARGUMENTS].position))
		}

		return AccessorNode(object, arguments, tokens[ARGUMENTS].position)
	}
}

Pattern ImportPattern {
	constant CPP_LANGUAGE_TAG_1 = 'cpp'
	constant CPP_LANGUAGE_TAG_2 = 'c++'
	constant VIVID_LANGUAGE_TAG = 'vivid'

	constant IMPORT = 0
	constant LANGUAGE = 1
	constant FUNCTION = 2
	constant COLON = 3

	constant TYPE_START = 1

	init() {
		# Pattern 1: import ['$language'] $name (...) [: $type]
		# Pattern 2: import $1.$2. ... .$n
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the first token contains the import modifier
		# NOTE: Multiple modifiers are packed into a single token
		modifier_keyword = tokens[IMPORT].(KeywordToken)
		if modifier_keyword.keyword.type != KEYWORD_TYPE_MODIFIER return false

		modifiers = modifier_keyword.keyword.(ModifierKeyword).modifier
		if not has_flag(modifiers, MODIFIER_IMPORTED) return false

		next = state.peek()
		
		# Pattern: import $1.$2. ... .$n
		if next != none and next.match(TOKEN_TYPE_IDENTIFIER) return common.consume_type(state)

		# Pattern: import ['$language'] $name (...) [: $type]
		# Optionally consume a language identifier
		state.consume_optional(TOKEN_TYPE_STRING)

		if not state.consume(TOKEN_TYPE_FUNCTION) return false

		next = state.peek()

		# Try to consume a return type
		if next != none and next.match(Operators.COLON) {
			state.consume()
			return common.consume_type(state)
		}

		# There is no return type, so add an empty token
		state.tokens.add(Token(TOKEN_TYPE_NONE))
		return true
	}

	# Summary: Return whether the captured tokens represent a function import instead of namespace import
	private shared is_function_import(tokens: List<Token>): bool {
		return not tokens[TYPE_START].match(TOKEN_TYPE_IDENTIFIER)
	}

	# Summary: Imports the function contained in the specified tokens
	private shared import_function(environment: Context, state: ParserState, tokens: List<Token>): Node {
		descriptor = tokens[FUNCTION] as FunctionToken
		language = LANGUAGE_VIVID

		if tokens[LANGUAGE].match(TOKEN_TYPE_STRING) {
			language = when(tokens[LANGUAGE].(StringToken).text.to_lower()) {
				CPP_LANGUAGE_TAG_1 => LANGUAGE_CPP
				CPP_LANGUAGE_TAG_2 => LANGUAGE_CPP
				VIVID_LANGUAGE_TAG => LANGUAGE_VIVID
				else => LANGUAGE_OTHER
			}
		}

		return_type = primitives.create_unit()

		# If the colon operator is present, it means there is a return type in the tokens
		if tokens[COLON].match(Operators.COLON) {
			return_type = common.read_type(environment, tokens, COLON + 1)
			
			# Ensure the return type was read successfully
			if return_type == none {
				state.error = Status(descriptor.position, 'Can not resolve the return type')
				return none as Node
			}
		}

		modifiers = combine_modifiers(MODIFIER_DEFAULT, tokens[].(KeywordToken).keyword.(ModifierKeyword).modifier)
		function = none as Function

		# If the function is a constructor or a destructor, handle it differently
		if descriptor.name == Keywords.INIT.identifier and environment.is_type {
			function = Constructor(environment, modifiers, descriptor.position, none as Position, false)

			if not environment.is_type {
				state.error = Status(descriptor.position, 'Constructor can only be imported inside a type')
				return none as Node
			}
		}
		else descriptor.name == Keywords.DEINIT.identifier and environment.is_type {
			function = Destructor(environment, modifiers, descriptor.position, none as Position, false)

			if not environment.is_type {
				state.error = Status(descriptor.position, 'Destructor can only be imported inside a type')
				return none as Node
			}
		}
		else {
			function = Function(environment, modifiers, descriptor.name, descriptor.position, none as Position)
		}

		function.modifiers |= MODIFIER_IMPORTED
		function.return_type = return_type
		function.language = language

		result = descriptor.get_parameters(function)
		
		if result has not parameters {
			state.error = Status(descriptor.position, result.get_error())
			return none as Node
		}

		function.parameters = parameters

		# Declare the function in the environment
		if descriptor.name == Keywords.INIT.identifier and environment.is_type {
			environment.(Type).add_constructor(function as Constructor)
		}
		else descriptor.name == Keywords.DEINIT.identifier and environment.is_type {
			environment.(Type).add_destructor(function as Destructor)
		}
		else {
			environment.declare(function)
		}

		return FunctionDefinitionNode(function, descriptor.position)
	}

	# Summary: Imports the namespace contained in the specified tokens
	private shared import_namespace(environment: Context, state: ParserState, tokens: List<Token>): Node {
		imported_namespace = common.read_type(environment, tokens, 1)
		
		if imported_namespace == none {
			state.error = Status('Can not resolve the import')
			return none as Node
		}

		environment.imports.add(imported_namespace)
		return none as Node
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		if is_function_import(tokens) return import_function(environment, state, tokens)
		return import_namespace(environment, state, tokens)
	}
}

Pattern ConstructorPattern {
	constant HEADER = 0

	init() {
		# Pattern: init/deinit (...) [\n] {...}
		path.add(TOKEN_TYPE_FUNCTION)
		priority = 23
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Constructors and destructors must be inside a type
		if not context.is_type return false

		# Ensure the function matches either a constructor or a destructor
		descriptor = tokens[HEADER] as FunctionToken
		if not (descriptor.name == Keywords.INIT.identifier) and not (descriptor.name == Keywords.DEINIT.identifier) return false

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Consume the function body
		return state.consume_parenthesis(`{`)
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[HEADER] as FunctionToken
		type = environment as Type

		blueprint = tokens[tokens.size - 1] as ParenthesisToken
		start = descriptor.position
		end = blueprint.end

		function = none as Function
		is_constructor = descriptor.name == Keywords.INIT.identifier

		if is_constructor { function = Constructor(type, MODIFIER_DEFAULT, start, end, false) }
		else { function = Destructor(type, MODIFIER_DEFAULT, start, end, false) }

		result = descriptor.get_parameters(function)
		
		if result has not parameters {
			state.error = Status(descriptor.position, result.get_error())
			return none as Node
		}

		function.parameters = parameters
		function.blueprint = blueprint.tokens

		if is_constructor type.add_constructor(function as Constructor)
		else { type.add_destructor(function as Destructor) }

		return FunctionDefinitionNode(function, descriptor.position)
	}
}

Pattern ExpressionVariablePattern {
	constant ARROW = 1

	init() {
		# Pattern: $name => ...
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 21
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return (context.is_type or context.is_namespace) and tokens[ARROW].match(Operators.HEAVY_ARROW)
	}

	override build(type: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[] as IdentifierToken

		# Create function which has the name of the property but has no parameters
		function = Function(type, MODIFIER_DEFAULT, name.value, name.position, none as Position)

		blueprint = List<Token>()
		blueprint.add(KeywordToken(Keywords.RETURN, tokens[ARROW].position))

		error = common.consume_block(state, blueprint)

		if error != none {
			state.error = error
			return none as Node
		}

		# Save the blueprint
		function.blueprint.add_all(blueprint)

		# Finally, declare the function
		type.declare(function)

		return FunctionDefinitionNode(function, name.position)
	}
}

Pattern InheritancePattern {
	# NOTE: There can not be an optional line break since function import return types can be consumed accidentally for example
	
	constant INHERITANT = 0
	constant TEMPLATE_ARGUMENTS = 1
	constant INHERITOR = 2

	# Pattern: $type [<$1, $2, ..., $n>] $type_definition
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 21
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Remove the consumed identifier, so that a whole type can be consumed
		state.end--
		state.tokens.remove_at(0)

		if not common.consume_type(state) return false

		# Require the next token to represent a type definition
		next = state.peek()
		if next == none or next.type != TOKEN_TYPE_DYNAMIC return false

		node = next.(DynamicToken).node
		if node.instance != NODE_TYPE_DEFINITION return false

		state.consume()
		return true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Load all inheritant tokens
		inheritant_tokens = tokens.slice(0, tokens.size - 1)

		inheritor_node = tokens[tokens.size - 1].(DynamicToken).node
		inheritor = inheritor_node.(TypeNode).type

		if inheritor.is_template_type {
			template_type = inheritor as TemplateType

			# If any of the inherited tokens represent a template parameter, the inheritant tokens must be added to the template type
			# NOTE: Inherited types, which are not dependent on template parameters, can be added as a supertype directly
			loop token in inheritant_tokens {
				# Require the token to be an identifier token
				if token.type != TOKEN_TYPE_IDENTIFIER continue

				# If the token is a template parameter, add the inheritant tokens into the template type blueprint
				loop template_parameter in template_type.template_parameters {
					if not (template_parameter == token.(IdentifierToken).value) continue

					template_type.inherited.insert_all(0, inheritant_tokens)
					return inheritor_node
				}
			}
		}

		inheritant = common.read_type(context, inheritant_tokens)

		if inheritant == none {
			position = inheritant_tokens[].position
			state.error = Status(position, 'Can not resolve the inherited type')
			return none as Node
		}

		if not inheritor.is_inheriting_allowed(inheritant) {
			position = inheritant_tokens[].position
			state.error = Status(position, 'Can not inherit the type since it would have caused a cyclic inheritance')
			return none as Node
		}

		inheritor.supertypes.insert(0, inheritant)
		return inheritor_node
	}
}

Pattern ModifierSectionPattern {
	constant MODIFIERS = 0
	constant COLON = 1

	# Pattern: $modifiers :
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OPERATOR)
		priority = 20
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[MODIFIERS].(KeywordToken).keyword.type != KEYWORD_TYPE_MODIFIER return false
		return tokens[COLON].match(Operators.COLON)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		modifiers = tokens[MODIFIERS].(KeywordToken).keyword.(ModifierKeyword).modifier
		return SectionNode(modifiers, tokens[MODIFIERS].position)
	}
}

Pattern SectionModificationPattern {
	constant SECTION = 0
	constant OBJECT = 2

	# Pattern: $section [\n] $object
	init() {
		path.add(TOKEN_TYPE_DYNAMIC)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_DYNAMIC)
		priority = 0
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Require the first consumed token to represent a modifier section
		if tokens[SECTION].(DynamicToken).node.instance != NODE_SECTION return false

		# Require the next token to represent a variable, function definition, or type definition
		target = tokens[OBJECT].(DynamicToken).node
		type = target.instance

		if type == NODE_TYPE_DEFINITION or type == NODE_FUNCTION_DEFINITION or type == NODE_VARIABLE return true

		# Allow member variable assignments as well
		if not target.match(Operators.ASSIGN) return false

		# Require the destination operand to be a member variable
		return target.first.instance == NODE_VARIABLE and target.first.(VariableNode).variable.is_member
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Load the section and target node
		section = tokens[SECTION].(DynamicToken).node as SectionNode
		target = tokens[OBJECT].(DynamicToken).node

		if target.instance == NODE_VARIABLE {
			variable = target.(VariableNode).variable
			modifiers = variable.modifiers
			variable.modifiers = combine_modifiers(modifiers, section.modifiers)
			section.add(target)

			# Static variables are categorized as global variables
			if has_flag(section.modifiers, MODIFIER_STATIC) { variable.category = VARIABLE_CATEGORY_GLOBAL }
		}
		else target.instance == NODE_FUNCTION_DEFINITION {
			function = target.(FunctionDefinitionNode).function
			modifiers = function.modifiers
			function.modifiers = combine_modifiers(modifiers, section.modifiers)
			section.add(target)
		}
		else target.instance == NODE_TYPE_DEFINITION {
			type = target.(TypeDefinitionNode).type
			modifiers = type.modifiers
			type.modifiers = combine_modifiers(modifiers, section.modifiers)
			section.add(target)
		}
		else target.instance == NODE_OPERATOR {
			variable = target.(OperatorNode).first.(VariableNode).variable
			modifiers = variable.modifiers
			variable.modifiers = combine_modifiers(modifiers, section.modifiers)
			section.add(target)
		}

		return section
	}
}

Pattern NamespacePattern {
	# Pattern: namespace $1.$2. ... .$n [\n] [{...}]
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 23
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Require the first token to be a namespace keyword
		if tokens[].(KeywordToken).keyword != Keywords.NAMESPACE return false

		loop {
			# Continue if the next operator is a dot
			next = state.peek()
			if next == none or not next.match(Operators.DOT) stop

			# Consume the dot operator
			state.consume()

			# The next token must be an identifier
			if not state.consume(TOKEN_TYPE_IDENTIFIER) return false
		}

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Optionally consume curly brackets
		state.consume_optional(TOKEN_TYPE_PARENTHESIS)

		tokens = state.tokens
		last = tokens[tokens.size - 1]
		return last.type == TOKEN_TYPE_NONE or last.match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Save the end index of the name
		end = tokens.size - 2

		# Collect all the parent types and ensure they all are namespaces
		types = context.get_parent_types()

		loop type in types {
			if type.is_static continue
			state.error = Status(tokens[].position, 'Can not create a namespace inside a normal type')
			return none as Node
		}

		blueprint = none as List<Token>

		if tokens[tokens.size - 1].type == TOKEN_TYPE_NONE {
			# Collect all tokens after the name
			blueprint = List<Token>()

			loop (i = state.end, i < state.all.size, i++) {
				blueprint.add(state.all[i])
			}

			state.tokens.add_all(blueprint)
			state.end += blueprint.size
		}
		else {
			# Get the blueprint from the the curly brackets
			blueprint = tokens[tokens.size - 1].(ParenthesisToken).tokens
		}

		# Create the namespace node
		name = tokens.slice(1, end)
		return NamespaceNode(name, blueprint)
	}
}

Pattern IterationLoopPattern {
	constant LOOP = 0
	constant ITERATOR = 1
	constant IN = 2
	constant ITERATED = 3
	constant BODY = 5

	constant ITERATOR_FUNCTION = 'iterator'
	constant NEXT_FUNCTION = 'next'
	constant VALUE_FUNCTION = 'value'

	# Pattern: loop $name in $object [\n] {...}
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 2
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[LOOP].match(Keywords.LOOP) and tokens[IN].match(Keywords.IN) and tokens[BODY].match(`{`)
	}

	get_iterator(context: Context, tokens: List<Token>): Variable {
		identifier = tokens[ITERATOR].(IdentifierToken).value
		iterator = context.declare(none as Type, VARIABLE_CATEGORY_LOCAL, identifier)
		iterator.position = tokens[ITERATOR].position
		return iterator
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		position = tokens[ITERATOR].position

		iterator = environment.declare_hidden(none as Type)
		iterator.position = position

		iterated = parser.parse(environment, tokens[ITERATED]) as Node

		# The iterator is created by calling the iterator function and using its result
		initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(iterator, position),
			LinkNode(iterated, UnresolvedFunction(String(ITERATOR_FUNCTION), position), position)
		)

		# The condition calls the next function, which returns whether a new element was loaded
		condition = LinkNode(VariableNode(iterator, position), UnresolvedFunction(String(NEXT_FUNCTION), position), position)

		steps_context = Context(environment, NORMAL_CONTEXT)
		body_context = Context(steps_context, NORMAL_CONTEXT)

		value = get_iterator(body_context, tokens)

		# Loads the new value into the value variable
		load = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(value, position),
			LinkNode(VariableNode(iterator, position), UnresolvedFunction(String(VALUE_FUNCTION), position), position)
		)

		# Create the loop steps
		steps = Node()
		
		container = Node()
		container.add(initialization)
		steps.add(container)

		container = Node()
		container.add(condition)
		steps.add(container)

		steps.add(Node())

		# Create the loop body
		token = tokens[BODY] as ParenthesisToken
		body = ScopeNode(body_context, token.position, token.end, false)
		body.add(load)

		result = parser.parse(body_context, token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		loop child in result { body.add(child) }

		return LoopNode(steps_context, steps, body, tokens[LOOP].position)
	}
}

Pattern TemplateFunctionPattern {
	constant TEMPLATE_PARAMETERS_START = 2

	# Pattern: $name <$1, $2, ... $n> (...) [: $return-type] [\n] {...}
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 23
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Pattern: $name <$1, $2, ... $n> (...) [: $return-type] [\n] {...}
		if not common.consume_template_parameters(state) return false

		# Now there must be function parameters next
		if not state.consume_parenthesis(`(`) return false

		# Optionally consume return type
		if state.consume_operator(Operators.COLON) {
			# Expect return type
			if not common.consume_type(state) return false
		}

		# Optionally consume a line ending
		state.consume(TOKEN_TYPE_END)

		# Consume the function body
		return state.consume_parenthesis(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[] as IdentifierToken
		blueprint = tokens[tokens.size - 1] as ParenthesisToken
		start = name.position
		end = blueprint.end

		# Try to find the start of the optional return type
		parameters_index = 0
		colon_index = tokens.find_index(i -> i.match(Operators.COLON))

		if colon_index >= 0 {
			# Parameters are just to the left of the colon
			parameters_index = colon_index - 1
		}
		else {
			# Index of the parameters can be determined from the end of tokens, because the user did not add the return type
			# Case 1: $name <$1, $2, ... $n> (...) {...}
			# Case 2: $name <$1, $2, ... $n> (...) \n {...}
			parameters_index = tokens.size - 2
			if tokens[parameters_index].type == TOKEN_TYPE_END { parameters_index-- }
		}

		# Extract the template parameters
		template_parameter_tokens = tokens.slice(TEMPLATE_PARAMETERS_START, parameters_index - 1)
		template_parameters = common.get_template_parameters(template_parameter_tokens)

		if template_parameters.size == 0 {
			state.error = Status(start, 'Expected at least one template parameter')
			return none as Node
		}

		parenthesis = tokens[parameters_index] as ParenthesisToken
		descriptor = FunctionToken(name, parenthesis)
		descriptor.position = start

		# Create the template function
		template_function = TemplateFunction(context, MODIFIER_DEFAULT, name.value, template_parameters, parenthesis.tokens, start, end)

		# Determine the parameters of the template function
		if descriptor.clone().(FunctionToken).get_parameters(template_function) has not parameters {
			state.error = Status(start, 'Can not determine the parameters of the template function')
			return none as Node
		}

		template_function.parameters.add_all(parameters)

		# Save the created blueprint
		template_function.blueprint.add(descriptor)
		template_function.blueprint.add_all(tokens.slice(parameters_index + 1, tokens.size))

		# Declare the template function
		context.declare(template_function)

		return FunctionDefinitionNode(template_function, start)
	}
}

Pattern TemplateFunctionCallPattern {
	# Pattern: $name <$1, $2, ... $n> (...)
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return common.consume_template_function_call(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[] as IdentifierToken
		descriptor = FunctionToken(name, tokens[tokens.size - 1] as ParenthesisToken)
		descriptor.position = name.position
		template_arguments = common.read_template_arguments(context, tokens, 1)
		return parser.parse_function(context, context, descriptor, template_arguments, false)
	}
}

Pattern TemplateTypeMemberAccessPattern {
	# Pattern: $name <$1, $2, ... $n> .
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not common.consume_template_arguments(state) return false

		next = state.peek()
		return next !== none and next.match(Operators.DOT)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		position = tokens[].position
		type = common.read_type(context, tokens)

		if type === none {
			state.error = Status(position, 'Can not resolve the accessed type')
			return none as Node
		}

		return TypeNode(type, position)
	}
}

Pattern TemplateTypePattern {
	constant NAME = 0
	constant TEMPLATE_PARAMETERS = 1
	constant BODY = 3

	constant TEMPLATE_PARAMETERS_START = 2
	constant TEMPLATE_PARAMETERS_END = 3

	# Pattern: $name <$1, $2, ... $n> [\n] {...}
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Pattern: $name <$1, $2, ... $n> (...) [\n] {...}
		if not common.consume_template_parameters(state) return false

		# Optionally, consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Consume the body of the template type
		return state.consume_parenthesis(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken
		body = tokens[tokens.size - 1] as ParenthesisToken

		template_parameter_tokens = tokens.slice(TEMPLATE_PARAMETERS_START, tokens.size - TEMPLATE_PARAMETERS_END)
		template_parameters = common.get_template_parameters(template_parameter_tokens)

		blueprint = List<Token>(2, false)
		blueprint.add(name.clone())
		blueprint.add(body.clone())

		# Create the template type
		template_type = TemplateType(context, name.value, MODIFIER_DEFAULT, blueprint, template_parameters, name.position)
		return TypeDefinitionNode(template_type, List<Token>(), name.position)
	}
}

Pattern VirtualFunctionPattern {
	constant VIRTUAL = 0
	constant FUNCTION = 1
	constant COLON = 2
	constant RETURN_TYPE = 3

	# Pattern: virtual $function [: $return-type] [\n] [{...}]
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_OPTIONAL)
		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not tokens[VIRTUAL].match(Keywords.VIRTUAL) or not context.is_type return false

		colon = tokens[COLON]

		# If the colon token is not none, it must represent colon operator and the return type must be consumed successfully
		if colon.type != TOKEN_TYPE_NONE and (not colon.match(Operators.COLON) or not common.consume_type(state)) return false

		state.consume(TOKEN_TYPE_END) # Optionally consume a line ending
		state.consume_parenthesis(`{`) # Optionally consume a function body
		return true
	}

	# Summary:
	# Creates a virtual function which does not have a default implementation
	create_virtual_function_without_implementation(context: Context, state: ParserState, tokens: List<Token>): VirtualFunction {
		# The default return type is unit, if the return type is not defined
		return_type = primitives.create_unit()
		colon = tokens[COLON]

		if colon.type != TOKEN_TYPE_NONE {
			return_type = common.read_type(context, tokens, RETURN_TYPE)

			if return_type == none {
				state.error = Status(colon.position, 'Can not resolve return type of the virtual function')
				return none as VirtualFunction
			}
		}

		descriptor = tokens[FUNCTION] as FunctionToken
		start = tokens[].position

		# Ensure there is no other virtual function with the same name as this virtual function
		type = context.find_type_parent()

		if type == none {
			state.error = Status(start, 'Missing virtual function type parent')
			return none as VirtualFunction
		}

		if type.is_virtual_function_declared(descriptor.name) {
			state.error = Status(start, 'Virtual function with same name is already declared in one of the inherited types')
			return none as VirtualFunction
		}

		function = VirtualFunction(type, descriptor.name, return_type, start, none as Position)

		if descriptor.get_parameters(function) has not parameters {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			return none as VirtualFunction
		}

		loop parameter in parameters {
			if parameter.type != none continue
			state.error = Status(start, 'All parameters of a virtual function must have a type')
			return none as VirtualFunction
		}

		function.parameters.add_all(parameters)

		type.declare(function)
		return function
	}

	# Summary: Creates a virtual function which does have a default implementation
	create_virtual_function_with_implementation(context: Context, state: ParserState, tokens: List<Token>): VirtualFunction {
		# Try to resolve the return type
		return_type = none as Type
		colon = tokens[COLON]

		if colon.type != TOKEN_TYPE_NONE {
			return_type = common.read_type(context, tokens, RETURN_TYPE)

			if return_type == none {
				state.error = Status(colon.position, 'Can not resolve return type of the virtual function')
				return none as VirtualFunction
			}
		}

		descriptor = tokens[FUNCTION] as FunctionToken
		blueprint = tokens[tokens.size - 1] as ParenthesisToken
		start = tokens[].position
		end = blueprint.end

		# Ensure there is no other virtual function with the same name as this virtual function
		type = context.find_type_parent()

		if type == none {
			state.error = Status(start, 'Missing virtual function type parent')
			return none as VirtualFunction
		}

		if type.is_virtual_function_declared(descriptor.name) {
			state.error = Status(start, 'Virtual function with same name is already declared in one of the inherited types')
			return none as VirtualFunction
		}

		# Create the virtual function declaration
		virtual_function = VirtualFunction(type, descriptor.name, return_type, start, none as Position)

		if descriptor.get_parameters(virtual_function) has not parameters {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			return none as VirtualFunction
		}

		loop parameter in parameters {
			if parameter.type != none continue
			state.error = Status(start, 'All parameters of a virtual function must have a type')
			return none as VirtualFunction
		}

		virtual_function.parameters.add_all(parameters)

		# Create the default implementation of the virtual function
		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint.tokens, descriptor.position, end)

		# Define the parameters of the default implementation
		if descriptor.get_parameters(function) has not implementation_parameters {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			return none as VirtualFunction
		}

		function.parameters.add_all(implementation_parameters)
		
		# Declare both the virtual function and its default implementation
		type.declare(virtual_function)
		context.(Type).declare_override(function)

		return virtual_function
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		function = none as Function

		if tokens[tokens.size - 1].match(`{`) {
			function = create_virtual_function_with_implementation(context, state, tokens)
		}
		else {
			function = create_virtual_function_without_implementation(context, state, tokens)
		}

		if function == none return none as Node

		return FunctionDefinitionNode(function, tokens[].position)
	}
}

Pattern SpecificModificationPattern {
	constant MODIFIER = 0
	constant OBJECT = 2

	# Pattern: $modifiers [\n] $variable/$function/$type
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_DYNAMIC)
		priority = PRIORITY_ALL
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		modifier = tokens[MODIFIER] as KeywordToken
		if modifier.keyword.type != KEYWORD_TYPE_MODIFIER return false

		node = tokens[OBJECT].(DynamicToken).node
		return node.match(NODE_CONSTRUCTION | NODE_VARIABLE | NODE_FUNCTION_DEFINITION | NODE_TYPE_DEFINITION) or (node.instance == NODE_LINK and node.last.instance == NODE_CONSTRUCTION)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		modifiers = tokens[MODIFIER].(KeywordToken).keyword.(ModifierKeyword).modifier
		destination = tokens[OBJECT].(DynamicToken).node

		if destination.instance == NODE_VARIABLE {
			variable = destination.(VariableNode).variable
			variable.modifiers = combine_modifiers(variable.modifiers, modifiers)

			# Static variables are categorized as global variables
			if has_flag(modifiers, MODIFIER_STATIC) { variable.category = VARIABLE_CATEGORY_GLOBAL }
		}
		else destination.instance == NODE_FUNCTION_DEFINITION {
			if has_flag(modifiers, MODIFIER_IMPORTED) {
				state.error = Status(tokens[MODIFIER].position, 'Can not add modifier import to a function definition')
				return none as Node
			}

			function = destination.(FunctionDefinitionNode).function
			function.modifiers = combine_modifiers(function.modifiers, modifiers)
		}
		else destination.instance == NODE_TYPE_DEFINITION {
			type = destination.(TypeDefinitionNode).type
			type.modifiers = combine_modifiers(type.modifiers, modifiers)
		}
		else destination.instance == NODE_CONSTRUCTION {
			construction = destination as ConstructionNode
			construction.is_stack_allocated = has_flag(modifiers, MODIFIER_INLINE)
		}
		else destination.instance == NODE_LINK {
			construction = destination.last as ConstructionNode
			construction.is_stack_allocated = has_flag(modifiers, MODIFIER_INLINE)
		}

		return destination
	}
}

Pattern TypeInspectionPattern {
	constant SIZE_INSPECTION_IDENTIFIER = 'sizeof'
	constant STRIDE_INSPECTION_IDENTIFIER = 'strideof'
	constant NAME_INSPECTION_IDENTIFIER = 'nameof'

	# Pattern: strideof($type)/sizeof($type)/nameof($type)
	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		descriptor = tokens[] as FunctionToken
		if not (descriptor.name == SIZE_INSPECTION_IDENTIFIER or descriptor.name == STRIDE_INSPECTION_IDENTIFIER or descriptor.name == NAME_INSPECTION_IDENTIFIER) return false

		# Create a temporary state which in order to check whether the parameters contains a type
		state = ParserState()
		state.all = descriptor.parameters.tokens
		state.tokens = List<Token>()
		return common.consume_type(state) and state.end == state.all.size
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[] as FunctionToken
		type = common.read_type(context, descriptor.parameters.tokens)

		if type == none {
			state.error = Status(descriptor.position, 'Can not resolve the inspected type')
			return none as Node
		}

		position = descriptor.position

		if descriptor.name == NAME_INSPECTION_IDENTIFIER {
			if type.is_resolved return StringNode(type.string(), position)
			return InspectionNode(INSPECTION_TYPE_NAME, TypeNode(type), position)
		}

		if descriptor.name == STRIDE_INSPECTION_IDENTIFIER {
			return InspectionNode(INSPECTION_TYPE_STRIDE, TypeNode(type), position)
		}

		return InspectionNode(INSPECTION_TYPE_SIZE, TypeNode(type), position)
	}
}

Pattern CompilesPattern {
	constant COMPILES = 0
	constant CONDITIONS = 2

	init() {
		# Pattern: compiles [\n] {...}
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 5
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[COMPILES].match(Keywords.COMPILES) and tokens[CONDITIONS].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		conditions = parser.parse(context, tokens[CONDITIONS].(ParenthesisToken))
		result = CompilesNode(tokens[COMPILES].position)
		loop condition in conditions { result.add(condition) }
		return result
	}
}

Pattern IsPattern {
	constant KEYWORD = 1
	constant TYPE = 2

	# Pattern: $object is [not] $type [$name]
	init() {
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 16
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not tokens[KEYWORD].match(Keywords.IS) and not tokens[KEYWORD].match(Keywords.IS_NOT) return false

		# Consume the type
		if not common.consume_type(state) return false

		# Try consuming the result variable
		state.consume(TOKEN_TYPE_IDENTIFIER)
		return true
	}

	override build(context: Context, state: ParserState, formatted: List<Token>) {
		negate = formatted[KEYWORD].match(Keywords.IS_NOT)

		source = parser.parse(context, formatted[])
		tokens = formatted.slice(TYPE, formatted.size)
		type = common.read_type(context, tokens)

		if type == none {
			state.error = Status(formatted[TYPE].position, 'Can not understand the type')
			return none as Node
		}

		result = none as Node

		# If there is a token left in the queue, it must be the result variable name
		if tokens.size > 0 {
			name = tokens.pop_or(none as Token).(IdentifierToken).value
			variable = Variable(context, type, VARIABLE_CATEGORY_LOCAL, name, MODIFIER_DEFAULT)
			context.declare(variable)

			result = IsNode(source, type, variable, formatted[KEYWORD].position)
		}
		else {
			result = IsNode(source, type, none as Variable, formatted[KEYWORD].position)
		}

		if negate return NotNode(result, false, result.start)
		return result
	}
}

Pattern OverrideFunctionPattern {
	constant OVERRIDE = 0
	constant FUNCTION = 1

	# Pattern: override $name (...) [\n] {...}
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		priority = 22
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not context.is_type or not tokens[OVERRIDE].match(Keywords.OVERRIDE) return false # Override functions must be inside types

		# Consume the function body
		return state.consume_parenthesis(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[FUNCTION] as FunctionToken
		blueprint = tokens[tokens.size - 1] as ParenthesisToken
		start = descriptor.position
		end = blueprint.end

		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint.tokens, start, end)

		# Parse the function parameters
		result = descriptor.get_parameters(function)

		if result has not parameters {
			state.error = Status(start, 'Could not resolve the parameters')
			return none as Node
		}

		function.parameters.add_all(parameters)

		# Declare the override function and return a function definition node
		context.(Type).declare_override(function)
		return FunctionDefinitionNode(function, start)
	}
}

Pattern LambdaPattern {
	constant PARAMETERS = 0
	constant OPERATOR = 1
	constant BODY = 3

	# Pattern 1: ($1, $2, ..., $n) -> [\n] ...
	# Pattern 2: $name -> [\n] ...
	# Pattern 3: ($1, $2, ..., $n) -> [\n] {...}
	init() {
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# If the parameters are added inside parenthesis, it must be a normal parenthesis
		if tokens[PARAMETERS].type == TOKEN_TYPE_PARENTHESIS and not tokens[PARAMETERS].match(`(`) return false
		if not tokens[OPERATOR].match(Operators.ARROW) return false

		# Try to consume normal curly parenthesis as the body blueprint
		next = state.peek()
		if next !== none and next.match(`{`) state.consume()

		return true
	}

	private shared get_parameter_tokens(tokens: List<Token>): ParenthesisToken {
		parameter = tokens[PARAMETERS]
		if parameter.type == TOKEN_TYPE_PARENTHESIS return parameter as ParenthesisToken

		return ParenthesisToken(`(`, parameter.position, common.get_end_of_token(parameter), [ parameter ])
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		blueprint = none as List<Token>
		start = tokens[PARAMETERS].position
		end = none as Position
		last = tokens[tokens.size - 1]

		# Load the function blueprint
		if last.match(`{`) {
			blueprint = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			blueprint = List<Token>()
			position = last.position

			error = common.consume_block(state, blueprint)

			if error != none {
				state.error = error
				return none as Node
			}

			blueprint.insert(0, KeywordToken(Keywords.RETURN, position))
			if blueprint.size > 0 { end = common.get_end_of_token(blueprint[blueprint.size - 1]) }
		}

		environment = context.find_lambda_container_parent()

		if environment === none {
			state.error = Status(start, 'Can not create a lambda here')
			return none as Node
		}

		name = to_string(environment.create_lambda())

		# Create a function token manually since it contains some useful helper functions
		header = FunctionToken(IdentifierToken(name), get_parameter_tokens(tokens))
		function = Lambda(context, MODIFIER_DEFAULT, name, blueprint, start, end)
		environment.declare(function)

		# Parse the lambda parameters
		result = header.get_parameters(function)
		if result has not parameters {
			state.error = Status(start, 'Could not resolve the parameters')
			return none as Node
		}

		function.parameters.add_all(parameters)

		# The lambda can be implemented already, if all parameters are resolved
		implement = true

		loop parameter in parameters {
			if parameter.type != none and parameter.type.is_resolved continue
			implement = false
			stop
		}

		if implement {
			types = List<Type>(parameters.size, false)
			loop parameter in parameters { types.add(parameter.type) }

			implementation = function.implement(types)
			return LambdaNode(implementation, start)
		}

		return LambdaNode(function, start)
	}
}

Pattern RangePattern {
	constant LEFT = 0
	constant OPERATOR = 2
	constant RIGHT = 4

	constant RANGE_TYPE_NAME = 'Range'

	# Pattern: $start [\n] .. [\n] $end
	init() {
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_OBJECT)
		priority = 5
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[OPERATOR].match(Operators.RANGE)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		left = parser.parse(context, tokens[LEFT])
		right = parser.parse(context, tokens[RIGHT])

		arguments = Node()
		arguments.add(left)
		arguments.add(right)

		return UnresolvedFunction(String(RANGE_TYPE_NAME), tokens[OPERATOR].position).set_arguments(arguments)
	}
}

Pattern HasPattern {
	constant HAS = 1
	constant NAME = 2

	# Pattern: $object has [not] $name
	init() {
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 16
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[HAS].match(Keywords.HAS) or tokens[HAS].match(Keywords.HAS_NOT)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		negate = tokens[HAS].match(Keywords.HAS_NOT)

		source = parser.parse(context, tokens[])
		name = tokens[NAME] as IdentifierToken
		position = name.position

		if context.is_local_variable_declared(name.value) {
			state.error = Status(position, 'Variable already exists')
			return none as Node
		}

		variable = Variable(context, none as Type, VARIABLE_CATEGORY_LOCAL, name.value, MODIFIER_DEFAULT)
		variable.position = position
		context.declare(variable)

		result = HasNode(source, VariableNode(variable, position), tokens[HAS].position)

		if negate return NotNode(result, false, result.start)
		return result
	}
}

Pattern ExtensionFunctionPattern {
	# Pattern: ($type) . $name [<$T1, $T2, ..., $Tn>] () [: $return-type] [\n] {...}
	init() {
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 23
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Consume a dot operator
		if not state.consume_operator(Operators.DOT) return false
	
		# Attempt to consume a function token. If that fails, we expect a template function extension.
		if not state.consume(TOKEN_TYPE_FUNCTION) {
			# Consume the name
			if not state.consume(TOKEN_TYPE_IDENTIFIER) return false

			# Consume the template parameters
			if not common.consume_template_parameters(state) return false

			# Consume parenthesis
			if not state.consume(TOKEN_TYPE_PARENTHESIS) return false
		}

		# Look for a return type
		if state.consume_operator(Operators.COLON) {
			# Expected: ($type).$name [<$T1, $T2, ..., $Tn>] () : $return-type [\n] {...}
			if not common.consume_type(state) return false
		}

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# The last token must be the body of the function
		next = state.peek()
		if next == none or not next.match(`{`) return false
		
		state.consume()
		return true
	}

	private shared is_template_function_extension(tokens: List<Token>): bool {
		return tokens[2].type != TOKEN_TYPE_FUNCTION
	}

	private shared get_template_parameters(tokens: List<Token>, parameters: List<String>): large {
		i = 4 # Pattern: ($type) . $name < $T1, $T2, ..., $Tn > () [: $return-type] [\n] {...}

		loop (i + 1 < tokens.size, i += 2) {
			parameters.add(tokens[i].(IdentifierToken).value)
			if tokens[i + 1].match(Operators.GREATER_THAN) return i + 2
		}

		panic('Failed to find the end of template parameters')
	}

	private shared create_template_function_extension(environment: Context, destination: Type, state: ParserState, tokens: List<Token>, body: List<Token>): Node {
		# Extract the extension function name
		name = tokens[2] as IdentifierToken

		# Extract the template parameters and the index of the parameters
		template_parameters = List<String>()
		parameters_index = get_template_parameters(tokens, template_parameters)

		# Create a function token from the name and parameters (helper object)
		descriptor = FunctionToken(IdentifierToken(name.value), tokens[parameters_index], name.position)

		# Extract the return type if it is specified
		return_type_tokens = List<Token>()
		colon_index = parameters_index + 1

		if tokens[colon_index].match(Operators.COLON) {
			return_type_start = colon_index
			return_type_end = tokens.size - 2
			return_type_tokens = tokens.slice(return_type_start, return_type_end)
		}

		return ExtensionFunctionNode(destination, descriptor, template_parameters, return_type_tokens, body, tokens[].position, tokens[tokens.size - 1].(ParenthesisToken).end)
	}

	private shared create_standard_function_extension(environment: Context, destination: Type, state: ParserState, tokens: List<Token>, body: List<Token>): Node {
		descriptor = tokens[2] as FunctionToken

		# Extract the return type if it is specified
		return_type_tokens = List<Token>()
		colon_index = 3

		if tokens[colon_index].match(Operators.COLON) {
			return_type_start = colon_index
			return_type_end = tokens.size - 2
			return_type_tokens = tokens.slice(return_type_start, return_type_end)
		}

		return ExtensionFunctionNode(destination, descriptor, return_type_tokens, body, tokens[].position, tokens[tokens.size - 1].(ParenthesisToken).end)
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		destination = common.read_type(environment, tokens[].(ParenthesisToken).tokens)

		if destination == none {
			state.error = Status(tokens[].position, 'Can not resolve the destination type')
			return none as Node
		}

		# Extract the body tokens
		body = tokens[tokens.size - 1].(ParenthesisToken).tokens

		if is_template_function_extension(tokens) return create_template_function_extension(environment, destination, state, tokens, body)
		return create_standard_function_extension(environment, destination, state, tokens, body)
	}
}

Pattern WhenPattern {
	constant VALUE = 1
	constant BODY = 3

	constant IF_STATEMENT = 0
	constant ELSE_IF_STATEMENT = 1
	constant ELSE_STATEMENT = 2

	# Pattern: when(...) [\n] {...}
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_PARENTHESIS)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 19
		is_consumable = false
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the keyword is the when keyword
		if not tokens[].match(Keywords.WHEN) return false
		if not tokens[VALUE].match(`(`) return false

		return tokens[BODY].match(`{`)
	}

	override build(environment: Context, state: ParserState, all: List<Token>) {
		position = all[].position

		# Load the inspected value into a variable
		inspected_value = parser.parse(environment, all[VALUE])
		inspected_value_variable = environment.declare_hidden(inspected_value.try_get_type())
		
		tokens = all[BODY].(ParenthesisToken).tokens
		parser.create_function_tokens(tokens)

		if tokens.size == 0 {
			state.error = Status(position, 'When-statement can not be empty')
			return none as Node
		}

		sections = List<Node>()
		type = IF_STATEMENT

		loop (tokens.size > 0) {
			# Remove all line-endings from the start
			loop (tokens.size > 0) {
				token = tokens[]
				if token.type != TOKEN_TYPE_END and not token.match(Operators.COMMA) stop
				tokens.remove_at(0)
			}

			if tokens.size == 0 stop

			# Find the heavy arrow operator, which marks the start of the executable body, every section must have one
			index = -1
			
			loop (i = 0, i < tokens.size, i++) {
				if not tokens[i].match(Operators.HEAVY_ARROW) continue
				index = i
				stop
			}

			if index < 0 {
				state.error = Status(tokens[].position, 'All sections in when-statements must have a heavy arrow operator')
				return none as Node
			}

			if index == 0 {
				state.error = Status(tokens[].position, 'Section condition can not be empty')
				return none as Node
			}

			arrow = tokens[index]

			# Take out the section condition
			condition_tokens = tokens.slice(0, index)
			condition = none as Node

			tokens.remove_all(0, index + 1)

			if not condition_tokens[].match(Keywords.ELSE) {
				# Insert an equals-operator to the condition, if it does start with a keyword or an operator
				if not condition_tokens[].match(TOKEN_TYPE_KEYWORD | TOKEN_TYPE_OPERATOR) {
					condition_tokens.insert(0, OperatorToken(Operators.EQUALS, condition_tokens[].position))
				}

				condition_tokens.insert(0, IdentifierToken(inspected_value_variable.name, position))
				condition = parser.parse(environment, condition_tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
			}
			else {
				type = ELSE_STATEMENT
			}

			if tokens.size == 0 {
				state.error = Status(position, 'Missing section body')
				return none as Node
			}

			context = Context(environment, NORMAL_CONTEXT)
			body = none as Node

			if tokens[].match(`{`) {
				parenthesis = tokens.pop_or(none as Token) as ParenthesisToken
				body = parser.parse(context, parenthesis.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
			}
			else {
				# Consume the section body, but disable the list pattern so that commas at the end of sections do not join anything
				state = ParserState()
				state.all = tokens
				result = List<Token>()

				error = common.consume_block(state, result, ListPattern.ID)

				if error != none {
					state.error = error
					return none as Node
				}

				body = parser.parse(context, result, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

				# Remove the consumed tokens
				tokens.remove_all(0, state.end)
			}

			# Finish the when-statement, when an else-section is encountered
			if type == ELSE_STATEMENT {
				sections.add(ElseNode(context, body, arrow.position, none as Position))
				stop
			}

			# If the section is not an else-section, the condition must be present
			if condition == none {
				state.error = Status(arrow.position, 'Missing section condition')
				return none as Node
			}
			
			# Add the conditional section
			if type == IF_STATEMENT {
				sections.add(IfNode(context, condition, body, arrow.position, none as Position))
				type = ELSE_IF_STATEMENT
			}
			else {
				sections.add(ElseIfNode(context, condition, body, arrow.position, none as Position))
			}
		}

		return WhenNode(inspected_value, VariableNode(inspected_value_variable, position), sections, position)
	}
}

Pattern ListConstructionPattern {
	private constant LIST = 0

	# Pattern: [ $element-1, $element-2, ... ]
	init(){
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 2
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[LIST].match(`[`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		elements = parser.parse(context, tokens[LIST])
		position = tokens[LIST].position

		return ListConstructionNode(elements, position)
	}
}

Pattern PackConstructionPattern {
	constant PARENTHESIS = 1

	# Pattern: pack { $member-1 : $value-1, $member-2 : $value-2, ... }
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the keyword is 'pack'
		if not tokens[].match(Keywords.PACK) return false

		if not tokens[PARENTHESIS].match(`{`) return false

		# The pack must have members
		if tokens[PARENTHESIS].(ParenthesisToken).tokens.size == 0 return false

		# Now, we must ensure this really is a pack construction.
		# The tokens must be in the form of: { $member-1 : $value-1, $member-2 : $value-2, ... }
		sections = tokens[PARENTHESIS].(ParenthesisToken).get_sections()

		loop section in sections {
			# Remove all line endings from the section
			section = section.filter(i -> i.type != TOKEN_TYPE_END)

			# Empty sections do not matter, they can be ignored
			if section.size == 0 continue

			# Verify the section begins with a member name, a colon and some token.
			if section.size < 3 return false

			# The first token must be an identifier.
			if section[].type != TOKEN_TYPE_IDENTIFIER return false

			# The second token must be a colon.
			if not section[1].match(Operators.COLON) return false
		}

		return true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# We know that this is a pack construction.
		# The tokens must be in the form of: { $member-1 : $value-1, $member-2 : $value-2, ... }
		sections = tokens[PARENTHESIS].(ParenthesisToken).get_sections()

		members = List<String>()
		arguments = List<Node>()

		# Parse all the member values
		loop section in sections {
			# Remove all line endings from the section
			section = section.filter(i -> i.type != TOKEN_TYPE_END)

			# Empty sections do not matter, they can be ignored
			if section.size == 0 continue

			member = section[].(IdentifierToken).value
			value = parser.parse(context, section.slice(2), parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY).first

			# Ensure the member has a value
			if value == none {
				state.error = Status(section[].position, 'Missing value for member')
				return none as Node
			}

			members.add(member)
			arguments.add(value)
		}

		return PackConstructionNode(members, arguments, tokens[].position)
	}
}

Pattern UsingPattern {
	# Pattern: ... using ...
	init() {
		path.add(TOKEN_TYPE_ANY)
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_ANY)
		priority = 5
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[1].(IdentifierToken).value == Keywords.USING.identifier
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		allocated = parser.parse(context, tokens[])
		allocator = parser.parse(context, tokens[2])
		return UsingNode(allocated, allocator, tokens[1].position)
	}
}

Pattern GlobalScopeAccessPattern {
	# Pattern: global
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		return tokens[].(KeywordToken).keyword === Keywords.GLOBAL
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Find the root context (global scope)
		loop (context.parent !== none) { context = context.parent }

		# Return the context as a node
		return ContextNode(context, tokens[].position)
	}
}

Pattern DeinitializerPattern {
	# Pattern: deinit [\n] {...}
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not (tokens[].(IdentifierToken).value == Keywords.DEINIT.identifier) return false

		return tokens[2].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		return DeinitializerNode(tokens[2].(ParenthesisToken).tokens, tokens[].position)
	}
}