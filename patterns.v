namespace parser

Pattern CommandPattern {
	constant INSTRUCTION = 0

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 2
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		instruction = tokens[INSTRUCTION].(KeywordToken).keyword
		=> instruction == Keywords.STOP or instruction == Keywords.CONTINUE or instruction == Keywords.RETURN
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		instruction = tokens[INSTRUCTION].(KeywordToken).keyword
		if instruction == Keywords.RETURN => ReturnNode(none as Node, tokens[INSTRUCTION].position)
		=> CommandNode(instruction, tokens[INSTRUCTION].position)
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[OPERATOR].match(Operators.ASSIGN)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Do not remove the assign operator after building the tokens
		state.end--

		destination = tokens[DESTINATION] as IdentifierToken
		name = destination.value

		if not context.is_variable_declared(name) {
			# Ensure the name is not reserved
			if name == SELF_POINTER_IDENTIFIER or name == LAMBDA_SELF_POINTER_IDENTIFIER {
				state.error = Status(destination.position, String('Can not declare variable with name ') + name)
				=> none as Node
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

			=> VariableNode(variable, destination.position)
		}

		variable = context.get_variable(name)
		
		# Static variables must be accessed using their parent types
		if variable.is_static => LinkNode(TypeNode(variable.parent as Type), VariableNode(variable, destination.position), destination.position)

		if variable.is_member {
			self = common.get_self_pointer(context, destination.position)
			=> LinkNode(self, VariableNode(variable, destination.position), destination.position)
		}

		=> VariableNode(variable, destination.position)
	}
}

Pattern FunctionPattern {
	constant FUNCTION = 0
	constant BODY = 2

	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 20
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[FUNCTION] as FunctionToken
		blueprint = tokens[BODY] as ParenthesisToken

		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint.tokens, descriptor.position, blueprint.end)
		
		result = descriptor.get_parameters(function)
		if not (result has parameters) {
			state.error = Status(result.value as String)
			=> none as Node
		}

		function.parameters.add_range(parameters)

		conflict = context.declare(function)
		if conflict != none {
			state.error = Status(descriptor.position, 'Function conflicts with another function')
			=> none as Node
		}

		=> FunctionDefinitionNode(function, descriptor.position)
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
		=> tokens[OPERATOR].(OperatorToken).operator.priority == priority
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		token = tokens[OPERATOR]

		=> OperatorNode(token.(OperatorToken).operator, token.position).set_operands(parse(context, tokens[LEFT]), parse(context, tokens[RIGHT]))
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[BODY].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME].(IdentifierToken)
		body = tokens[BODY].(ParenthesisToken)

		type = Type(context, name.value, MODIFIER_DEFAULT, name.position)

		=> TypeDefinitionNode(type, body.tokens, name.position)
	}
}

Pattern ReturnPattern {
	constant RETURN = 0
	constant VALUE = 1

	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[RETURN].match(Operators.HEAVY_ARROW)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> ReturnNode(parser.parse(context, tokens[VALUE]), tokens[RETURN].position)
	}
}

Pattern VariableDeclarationPattern {
	constant NAME = 0
	constant COLON = 1

	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[COLON].match(Operators.COLON) and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken

		if context.is_local_variable_declared(name.value) {
			state.error = Status(name.position, 'Variable already exists')
			=> none as Node
		}

		if name.value == SELF_POINTER_IDENTIFIER or name.value == LAMBDA_SELF_POINTER_IDENTIFIER {
			state.error = Status(name.position, 'Can not declare variable, since the name is reserved')
			=> none as Node
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

		=> VariableNode(variable, name.position)
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		keyword = tokens[KEYWORD].(KeywordToken).keyword
		if keyword != Keywords.IF and keyword != Keywords.ELSE => false

		# Try to consume curly brackets
		next = state.peek()
		if next == none => false
		if next.match(`{`) state.consume()

		=> true
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
				=> none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		if tokens[KEYWORD].(KeywordToken).keyword == Keywords.IF => IfNode(context, condition, node, start, end)
		=> ElseIfNode(context, condition, node, start, end)
	}
}

Pattern ElsePattern {
	constant ELSE = 0

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)

		priority = 1
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[ELSE].(KeywordToken).keyword != Keywords.ELSE => false
		next = state.peek()
		if next == none => false
		if next.match(`{`) state.consume()
		=> true
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		start = tokens[ELSE].position
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
				=> none as Node
			}
		}

		node = parser.parse(context, body, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		
		=> ElseNode(context, node, start, end)
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
		path.add(TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_DYNAMIC)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Ensure the operator is the dot operator
		if not tokens[OPERATOR].match(Operators.DOT) => false
		# Try to consume template arguments
		if tokens[RIGHT].match(TOKEN_TYPE_IDENTIFIER) {
			backup = state.save()
			if not common.consume_template_function_call(state) state.restore(backup)
		}

		=> true
	}

	private build_template_function_call() {
		abort('Template function call is not supported yet')
		=> none as LinkNode
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		# When there are more tokens than the standard count, it means a template function has been consumed
		if tokens.size != STANDARD_TOKEN_COUNT => build_template_function_call()

		left = parser.parse(environment, tokens[LEFT])

		# If the right operand is a parenthesis token, this is a cast expression
		if tokens[RIGHT].match(TOKEN_TYPE_PARENTHESIS) {
			# Read the cast type from the parenthesis token
			abort('Link casting is not supported')
		}

		# Try to retrieve the primary context from the left token
		primary = left.try_get_type()
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

			=> LinkNode(left, right, tokens[OPERATOR].position)
		}

		right = parser.parse(environment, primary, token)

		# Try to build the right node as a virtual function or lambda call
		if right.match(NODE_UNRESOLVED_FUNCTION) {
			# TODO: Support virtual calls and lambda calls
		}

		=> LinkNode(left, right, tokens[OPERATOR].position)
	}
}

Pattern ListPattern {
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[COMMA].(OperatorToken).operator == Operators.COMMA
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		left = tokens[LEFT]
		right = tokens[RIGHT]
		
		# If the left token represents a list node, add the right operand to it and return the list
		if left.match(TOKEN_TYPE_DYNAMIC) {
			node = left.(DynamicToken).node
			
			if node.match(NODE_LIST) {
				node.add(parser.parse(context, right))
				=> node
			}
		}

		=> ListNode(tokens[COMMA].position, parser.parse(context, left), parser.parse(context, right))
	}
}

Pattern SingletonPattern {
	init() {
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_NUMBER | TOKEN_TYPE_STRING)
		priority = 0
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> parser.parse(context, tokens[0])
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
		# Pattern: loop [(...)] [\n] {...}
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)

		priority = 1
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[KEYWORD].(KeywordToken).keyword == Keywords.LOOP and tokens[BODY].match(`{`)
	}

	private static get_steps(context: Context, state: ParserState, parenthesis: ParenthesisToken) {
		if parenthesis.tokens.size == 0 => none as Node

		steps = none as Node
		sections = parenthesis.get_sections()

		if sections.size == WHILE_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(Node())
		}
		else sections.size == SHORT_FOR_LOOP {
			steps = Node()
			steps.add(Node())
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else sections.size == FOR_LOOP {
			steps = Node()
			steps.add(parser.parse(context, sections[0], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[1], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
			steps.add(parser.parse(context, sections[2], parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY))
		}
		else {
			state.error = Status(parenthesis.position, 'Too many sections')
			=> none as Node
		}

		=> steps
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		steps_context = Context(context, NORMAL_CONTEXT)
		body_context = Context(steps_context, NORMAL_CONTEXT)

		steps_token = tokens[STEPS]
		steps = none as Node

		if steps_token.type != TOKEN_TYPE_NONE {
			steps = get_steps(steps_context, state, steps_token as ParenthesisToken)
			if steps == none => none as Node
		}

		body_token = tokens[BODY] as ParenthesisToken
		body = ScopeNode(body_context, body_token.position, body_token.end)

		parser.parse(body, body_context, body_token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		=> LoopNode(steps_context, steps, body, tokens[KEYWORD].position)
	}
}

Pattern CastPattern {
	constant OBJECT = 0
	constant CAST = 1
	constant TYPE = 2

	init() {
		path.add(TOKEN_TYPE_OBJECT)
		path.add(TOKEN_TYPE_KEYWORD)

		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[CAST].(KeywordToken).keyword == Keywords.AS and common.consume_type(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		type = common.read_type(context, tokens, TYPE)

		if type == none abort('Can not resolve the cast type')

		=> CastNode(object, TypeNode(type, tokens[TYPE].position), tokens[CAST].position)
	}
}

Pattern UnarySignPattern {
	constant SIGN = 0
	constant OBJECT = 1
	
	init() {
		path.add(TOKEN_TYPE_OPERATOR)
		path.add(TOKEN_TYPE_OBJECT)

		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		sign = tokens[SIGN].(OperatorToken).operator
		if sign != Operators.ADD and sign != Operators.SUBTRACT => false
		if state.start == 0 => false
		previous = state.all[state.start - 1]
		=> previous.type == TOKEN_TYPE_OPERATOR or previous.type == TOKEN_TYPE_KEYWORD
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		sign = tokens[SIGN].(OperatorToken).operator

		if object.match(NODE_NUMBER) {
			if sign == Operators.SUBTRACT => object.(NumberNode).negate()
			=> object
		}

		if sign == Operators.SUBTRACT => NegateNode(object, tokens[SIGN].position)
		=> object
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
		=> operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) => IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
		=> DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, true)
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
		=> operator == Operators.INCREMENT or operator == Operators.DECREMENT
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		if tokens[OPERATOR].match(Operators.INCREMENT) => IncrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
		=> DecrementNode(parser.parse(context, tokens[OBJECT]), tokens[OPERATOR].position, false)
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
		=> tokens[NOT].match(Operators.EXCLAMATION) or tokens[NOT].match(Keywords.NOT)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		=> NotNode(parser.parse(context, tokens[OBJECT]), tokens[NOT].position)
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
		parenthesis = tokens[ARGUMENTS] as ParenthesisToken
		=> parenthesis.opening == `[` and not parenthesis.empty
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		object = parser.parse(context, tokens[OBJECT])
		arguments = parser.parse(context, tokens[ARGUMENTS])

		=> AccessorNode(object, arguments, tokens[ARGUMENTS].position)
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
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 20
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[IMPORT].(KeywordToken).keyword != Keywords.IMPORT => false

		next = state.peek()
		
		# Pattern: import $1.$2. ... .$n
		if next != none and next.match(TOKEN_TYPE_IDENTIFIER) => common.consume_type(state)

		# Pattern: import ['$language'] $name (...) [: $type]
		# Optionally consume a language identifier
		state.consume_optional(TOKEN_TYPE_STRING)

		if not state.consume(TOKEN_TYPE_FUNCTION) => false

		next = state.peek()

		# Try to consume a return type
		if next != none and next.match(Operators.COLON) => common.consume_type(state)

		# There is no return type, so add an empty token
		state.tokens.add(Token(TOKEN_TYPE_NONE))
		=> true
	}

	# Summary: Return whether the captured tokens represent a function import instead of namespace import
	private static is_function_import(tokens: List<Token>) {
		=> not tokens[TYPE_START].match(TOKEN_TYPE_IDENTIFIER)
	}

	# Summary: Imports the function contained in the specified tokens
	private static import_function(environment: Context, state: ParserState, tokens: List<Token>) {
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
				=> false
			}
		}

		function = Function(environment, MODIFIER_DEFAULT | MODIFIER_IMPORTED, descriptor.name, descriptor.position, none as Position)
		function.language = language

		result = descriptor.get_parameters(function)
		
		if not (result has parameters) {
			state.error = Status(descriptor.position, result.value as String)
			=> false
		}

		function.parameters = parameters

		implementation = FunctionImplementation(function, return_type, environment)
		
		# Try to set the parsed parameters
		status = implementation.set_parameters(parameters)

		if status.problematic {
			state.error = status
			=> false
		}
		
		function.implementations.add(implementation)
		implementation.implement(function.blueprint)

		environment.declare(function)
		=> true
	}

	# Summary: Imports the namespace contained in the specified tokens
	private static import_namespace(environment: Context, state: ParserState, tokens: List<Token>) {
		imported_namespace = common.read_type(environment, tokens, 1)
		
		if imported_namespace == none {
			state.error = Status('Can not resolve the import')
			=> false
		}

		environment.imports.add(imported_namespace)
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		if is_function_import(tokens) import_function(environment, state, tokens)
		else { import_namespace(environment, state, tokens) }
		=> none as Node
	}
}

Pattern ConstructorPattern {
	constant HEADER = 0

	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		priority = 21
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Constructors and destructors must be inside a type
		if not context.is_type => false

		# Ensure the function matches either a constructor or a destructor
		descriptor = tokens[HEADER] as FunctionToken
		if not (descriptor.name == Keywords.INIT.identifier) and not (descriptor.name == Keywords.DEINIT.identifier) => false

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Try to consume curly brackets or a heavy arrow operator
		next = state.peek()
		
		if next.match(`{`) or next.match(Operators.HEAVY_ARROW) {
			state.consume()
			=> true
		}

		=> false
	}

	override build(environment: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[HEADER] as FunctionToken
		type = environment as Type

		start = descriptor.position
		end = none as Position

		blueprint = none as List<Token>
		last = tokens[tokens.size - 1]

		if last.match(`{`) {
			blueprint = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}
		else {
			blueprint = List<Token>()
			error = common.consume_block(state, blueprint)
			
			# Abort, if an error is returned
			if error != none {
				state.error = error
				=> none as Node
			}
		}

		function = none as Function
		is_constructor = descriptor.name == Keywords.INIT.identifier

		if is_constructor { function = Constructor(type, MODIFIER_DEFAULT, start, end, false) }
		else { function = Destructor(type, MODIFIER_DEFAULT, start, end, false) }

		result = descriptor.get_parameters(function)
		
		if not (result has parameters) {
			state.error = Status(descriptor.position, result.value as String)
			=> none as Node
		}

		function.parameters = parameters
		function.blueprint = blueprint

		if is_constructor type.add_constructor(function as Constructor)
		else type.add_destructor(function as Destructor)

		=> FunctionDefinitionNode(function, descriptor.position)
	}
}

Pattern ExpressionVariablePattern {
	constant ARROW = 1

	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		path.add(TOKEN_TYPE_OPERATOR)

		priority = 21
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> (context.is_type or context.is_namespace) and tokens[ARROW].match(Operators.HEAVY_ARROW)
	}

	override build(type: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[0] as IdentifierToken

		# Create function which has the name of the property but has no parameters
		function = Function(type, MODIFIER_DEFAULT, name.value, name.position, none as Position)

		# Add the heavy arrow operator token to the start of the blueprint to represent a return statement
		blueprint = List<Token>()
		blueprint.add(tokens[ARROW])

		error = common.consume_block(state, blueprint)
		if error != none {
			state.error = error
			=> none as Node
		}

		# Save the blueprint
		function.blueprint.add_range(blueprint)

		# Finally, declare the function
		type.declare(function)

		=> FunctionDefinitionNode(function, name.position)
	}
}

Pattern InheritancePattern {
	# NOTE: There can not be an optional line break since function import return types can be consumed accidentally for example
	
	constant INHERITANT = 0
	constant TEMPLATE_ARGUMENTS = 1
	constant INHERITOR = 2

	# Pattern: Pattern: $type [<$1, $2, ..., $n>] $type_definition
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 21
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Remove the consumed identifier, so that a whole type can be consumed
		state.end--
		state.tokens.remove_at(0)

		if not common.consume_type(state) => false

		# Require the next token to represent a type definition
		next = state.peek()
		if next == none or next.type != TOKEN_TYPE_DYNAMIC => false

		node = next.(DynamicToken).node
		if node.instance != NODE_TYPE_DEFINITION => false

		state.consume()
		=> true
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Load all inheritant tokens
		inheritant_tokens = List<Token>(tokens.size - 1, false)

		loop (i = 0, i < tokens.size - 1, i++) {
			inheritant_tokens.add(tokens[i])
		}

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

					template_type.inherited.insert_range(0, inheritant_tokens)
					=> inheritor_node
				}
			}
		}

		inheritant = common.read_type(context, inheritant_tokens)

		if inheritant == none {
			position = inheritant_tokens[0].position
			state.error = Status(position, 'Can not resolve the inherited type')
			=> none as Node
		}

		if not inheritor.is_inheriting_allowed(inheritant) {
			position = inheritant_tokens[0].position
			state.error = Status(position, 'Can not inherit the type since it would have caused a cyclic inheritance')
			=> none as Node
		}

		inheritor.supertypes.insert(0, inheritant)
		=> inheritor_node
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if tokens[MODIFIERS].(KeywordToken).keyword.type != KEYWORD_TYPE_MODIFIER => false
		=> tokens[COLON].match(Operators.COLON)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		modifiers = tokens[MODIFIERS].(KeywordToken).keyword.(ModifierKeyword).modifier
		=> SectionNode(modifiers, tokens[MODIFIERS].position)
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Require the first consumed token to represent a modifier section
		if tokens[SECTION].(DynamicToken).node.instance != NODE_SECTION => false

		# Require the next token to represent a variable, function definition, or type definition
		target = tokens[OBJECT].(DynamicToken).node
		type = target.instance

		if type != NODE_TYPE_DEFINITION and type != NODE_FUNCTION_DEFINITION and type != NODE_VARIABLE => false

		# Allow member variable assignments as well
		if not target.match(Operators.ASSIGN) => false

		# Require the destination operand to be a member variable
		=> target.first.instance != NODE_VARIABLE and target.first.(VariableNode).variable.is_member
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

		=> section
	}
}

Pattern NamespacePattern {
	# Pattern: $1.$2. ... .$n [\n] [{...}]
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 23
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Require the first token to be a namespace keyword
		if tokens[0].(KeywordToken).keyword != Keywords.NAMESPACE => false

		loop {
			# Continue if the next operator is a dot
			next = state.peek()
			if next == none or not next.match(Operators.DOT) stop

			# Consume the dot operator
			state.consume()

			# The next token must be an identifier
			if not state.consume(TOKEN_TYPE_IDENTIFIER) => false
		}

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Optionally consume curly brackets
		state.consume_optional(TOKEN_TYPE_PARENTHESIS)

		tokens = state.tokens
		last = tokens[tokens.size - 1]
		=> last.type == TOKEN_TYPE_NONE or last.match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		# Save the end index of the name
		end = tokens.size - 2

		# Collect all the parent types and ensure they all are namespaces
		types = context.get_parent_types()

		loop type in types {
			if type.is_static continue
			state.error = Status(tokens[0].position, 'Can not create a namespace inside a normal type')
			=> none as Node
		}

		blueprint = none as List<Token>

		if tokens[tokens.size - 1].type == TOKEN_TYPE_NONE {
			# Collect all tokens after the name
			blueprint = List<Token>()

			loop (i = state.end, i < state.all.size, i++) {
				blueprint.add(state.all[i])
			}

			state.tokens.add_range(blueprint)
			state.end += blueprint.size
		}
		else {
			# Get the blueprint from the the curly brackets
			blueprint = tokens[tokens.size - 1].(ParenthesisToken).tokens
		}

		# Create the namespace node
		name = tokens.slice(1, end)
		=> NamespaceNode(name, blueprint)
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[LOOP].match(Keywords.LOOP) and tokens[IN].match(Keywords.IN) and tokens[BODY].match(`{`)
	}

	get_iterator(context: Context, tokens: List<Token>) {
		identifier = tokens[ITERATOR].(IdentifierToken).value
		iterator = context.declare(none as Type, VARIABLE_CATEGORY_LOCAL, identifier)
		iterator.position = tokens[ITERATOR].position
		=> iterator
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

		value = get_iterator(steps_context, tokens)

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
		body = ScopeNode(body_context, token.position, token.end)
		body.add(load)

		result = parser.parse(body_context, token.tokens, parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)
		loop child in result { body.add(child) }

		=> LoopNode(steps_context, steps, body, tokens[LOOP].position)
	}
}

Pattern TemplateFunctionPattern {
	constant NAME = 0
	constant PARAMETERS_OFFSET = 1

	constant TEMPLATE_PARAMETERS_START = 2
	constant TEMPLATE_PARAMETERS_END = 4

	# Pattern: $name <$1, $2, ... $n> (...) [\n] {...}
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 23
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# Pattern: $name <$1, $2, ... $n> (...) [\n] {...}
		next = state.peek()
		if next == none or not next.match(Operators.LESS_THAN) => false
		state.consume()

		loop {
			if not state.consume(TOKEN_TYPE_IDENTIFIER) => false

			next = state.peek()
			if next == none => false

			if next.match(Operators.GREATER_THAN) {
				state.consume()
				stop
			}

			if next.match(Operators.COMMA) {
				state.consume()
				continue
			}

			=> false
		}

		# Now there must be function parameters next
		next = state.peek()
		if next == none or not next.match(`(`) => false
		state.consume()

		# Optionally consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Try to consume curly brackets
		next = state.peek()
		if next == none => false

		# 1. Support regular function body
		# 2. Support short template function body
		if next.match(`{`) or next.match(Operators.HEAVY_ARROW) {
			state.consume()
			=> true
		}

		=> false
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken
		blueprint = none as ParenthesisToken
		start = name.position
		end = none as Position

		if tokens[tokens.size - 1].match(`{`) {
			blueprint = tokens[tokens.size - 1] as ParenthesisToken
			end = blueprint.end
		}

		# Find the end of the template parameters and collect them
		template_parameters_end = -1

		loop (i = tokens.size - 1, i >= 0, i--) {
			if not tokens[i].match(Operators.GREATER_THAN) continue
			template_parameters_end = i
			stop
		}

		if template_parameters_end == -1 {
			state.error = Status(start, 'Can not find the end of the template parameters')
			=> none as Node
		}

		template_parameter_tokens = tokens.slice(TEMPLATE_PARAMETERS_START, template_parameters_end)
		template_parameters = common.get_template_parameters(template_parameter_tokens, tokens[TEMPLATE_PARAMETERS_START + 1].position)

		if template_parameters.size == 0 {
			state.error = Status(start, 'Expected at least one template parameter')
			=> none as Node
		}

		parenthesis = tokens[template_parameters_end + PARAMETERS_OFFSET] as ParenthesisToken
		descriptor = FunctionToken(name, parenthesis)
		descriptor.position = start

		template_function = TemplateFunction(context, MODIFIER_DEFAULT, name.value, template_parameters, parenthesis.tokens, start, end)

		# Initialize the template function by parsing its parameters
		if not template_function.initialize() {
			state.error = Status(parenthesis.position, 'Can not understand the parameters')
			=> none as Node
		}

		if blueprint == none {
			# Take the heavy arrow token into the blueprint as well
			result = List<Token>(1, false)
			result.add(tokens[tokens.size - 1])

			if not common.consume_block(state, result) {
				state.error = Status(start, 'Short template function has an empty body')
				=> none as Node
			}

			blueprint = ParenthesisToken(result)
			blueprint.opening = `{`
		}

		# Save the created blueprint
		template_function.blueprint.add(descriptor)
		template_function.blueprint.add(blueprint)

		# Determine the parameters of the template function
		if not (descriptor.clone().(FunctionToken).get_parameters(template_function) has parameters) {
			state.error = Status(start, 'Can not determine the parameters of the template function')
			=> none as Node
		}

		template_function.parameters.add_range(parameters)

		context.declare(template_function)

		=> FunctionDefinitionNode(template_function, start)
	}
}

Pattern TemplateFunctionCallPattern {
	# Pattern: $name <$1, $2, ... $n> (...)
	init() {
		path.add(TOKEN_TYPE_IDENTIFIER)
		priority = 19
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> common.consume_template_function_call(state)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[0] as IdentifierToken
		descriptor = FunctionToken(name, tokens[tokens.size - 1] as ParenthesisToken)
		descriptor.position = name.position
		template_arguments = common.read_template_arguments(context, tokens, 1)
		=> parser.parse_function(context, context, descriptor, template_arguments, false)
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
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		# TODO: Remove the following duplication with the template function pattern
		# Pattern: $name <$1, $2, ... $n> (...) [\n] {...}
		next = state.peek()
		if next == none or not next.match(Operators.LESS_THAN) => false
		state.consume()

		loop {
			if not state.consume(TOKEN_TYPE_IDENTIFIER) => false

			next = state.peek()
			if next == none => false

			if next.match(Operators.GREATER_THAN) {
				state.consume()
				stop
			}

			if next.match(Operators.COMMA) {
				state.consume()
				continue
			}

			=> false
		}

		# Optionally, consume a line ending
		state.consume_optional(TOKEN_TYPE_END)

		# Consume the body of the template type
		next = state.peek()
		=> state.consume(TOKEN_TYPE_PARENTHESIS) and next.(ParenthesisToken).match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		name = tokens[NAME] as IdentifierToken
		body = tokens[tokens.size - 1] as ParenthesisToken

		template_parameter_tokens = tokens.slice(TEMPLATE_PARAMETERS_START, tokens.size - TEMPLATE_PARAMETERS_END)
		template_parameters = common.get_template_parameters(template_parameter_tokens, tokens[TEMPLATE_PARAMETERS].position)

		blueprint = List<Token>(2, false)
		blueprint.add(name.clone())
		blueprint.add(body.clone())

		# Create the template type
		template_type = TemplateType(context, name.value, MODIFIER_DEFAULT, blueprint, template_parameters, name.position)
		=> TypeDefinitionNode(template_type, List<Token>(), name.position)
	}
}

Pattern VirtualFunctionPattern {
	constant VIRTUAL = 0
	constant FUNCTION = 1
	constant COLON = 2
	constant RETURN_TYPE = 3

	# Pattern: virtual $function [: $type] [\n] [{...}]
	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_OPTIONAL)
		priority = 22
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not tokens[VIRTUAL].match(Keywords.VIRTUAL) or not context.is_type => false

		colon = tokens[COLON]

		# If the colon token is not none, it must represent colon operator and the return type must be consumed successfully
		if colon.type != TOKEN_TYPE_NONE and [not colon.match(Operators.COLON) or not common.consume_type(state)] => false

		state.consume(TOKEN_TYPE_END)

		# Try to consume a function body, which would be the default implementation of the virtual function
		next = state.peek()
		if next == none => true

		if next.match(`{`) or next.match(Operators.HEAVY_ARROW) state.consume()
		=> true
	}

	# Summary:
	# Creates a virtual function which does not have a default implementation
	create_virtual_function_without_implementation(context: Context, state: ParserState, tokens: List<Token>) {
		# The default return type is unit, if the return type is not defined
		return_type = primitives.create_unit()
		colon = tokens[COLON]

		if colon.type != TOKEN_TYPE_NONE {
			return_type = common.read_type(context, tokens, RETURN_TYPE)

			if return_type == none {
				state.error = Status(colon.position, 'Can not resolve return type of the virtual function')
				=> none as VirtualFunction
			}
		}

		descriptor = tokens[FUNCTION] as FunctionToken
		start = tokens[0].position

		# Ensure there is no other virtual function with the same name as this virtual function
		type = context.find_type_parent()

		if type == none {
			state.error = Status(start, 'Missing virtual function type parent')
			=> none as VirtualFunction
		}

		if type.is_virtual_function_declared(descriptor.name) {
			state.error = Status(start, 'Virtual function with same name is already declared in one of the inherited types')
			=> none as VirtualFunction
		}

		function = VirtualFunction(type, descriptor.name, return_type, start, none as Position)

		if not (descriptor.get_parameters(function) has parameters) {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			=> none as VirtualFunction
		}

		loop parameter in parameters {
			if parameter.type != none continue
			state.error = Status(start, 'All parameters of a virtual function must have a type')
			=> none as VirtualFunction
		}

		function.parameters.add_range(parameters)

		type.declare(function)
		=> function
	}

	# Summary: Creates a virtual function which does have a default implementation
	create_virtual_function_with_implementation(context: Context, state: ParserState, tokens: List<Token>) {
		# Try to resolve the return type
		return_type = none as Type
		colon = tokens[COLON]

		if colon.type != TOKEN_TYPE_NONE {
			return_type = common.read_type(context, tokens, RETURN_TYPE)

			if return_type == none {
				state.error = Status(colon.position, 'Can not resolve return type of the virtual function')
				=> none as VirtualFunction
			}
		}

		# Get the default implementation of this virtual function
		blueprint = none as List<Token>
		end = none as Position
		last = tokens[tokens.size - 1]

		if last.match(Operators.HEAVY_ARROW) {
			position = last.position
			result = common.consume_block(state, blueprint)

			# If the result is not none, something went wrong
			if result != none {
				state.error = result
				=> none as VirtualFunction
			}

			blueprint.insert(0, OperatorToken(Operators.HEAVY_ARROW, position))
			if blueprint.size > 0 { end = common.get_end_of_token(blueprint[blueprint.size - 1]) }
		}
		else {
			blueprint = last.(ParenthesisToken).tokens
			end = last.(ParenthesisToken).end
		}

		descriptor = tokens[FUNCTION] as FunctionToken
		start = tokens[0].position

		# Ensure there is no other virtual function with the same name as this virtual function
		type = context.find_type_parent()

		if type == none {
			state.error = Status(start, 'Missing virtual function type parent')
			=> none as VirtualFunction
		}

		if type.is_virtual_function_declared(descriptor.name) {
			state.error = Status(start, 'Virtual function with same name is already declared in one of the inherited types')
			=> none as VirtualFunction
		}

		# Create the virtual function declaration
		virtual_function = VirtualFunction(type, descriptor.name, return_type, start, none as Position)

		if not (descriptor.get_parameters(virtual_function) has parameters) {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			=> none as VirtualFunction
		}

		loop parameter in parameters {
			if parameter.type != none continue
			state.error = Status(start, 'All parameters of a virtual function must have a type')
			=> none as VirtualFunction
		}

		virtual_function.parameters.add_range(parameters)

		# Create the default implementation of the virtual function
		function = Function(context, MODIFIER_DEFAULT, descriptor.name, blueprint, descriptor.position, end)

		# Define the parameters of the default implementation
		if not (descriptor.get_parameters(function) has implementation_parameters) {
			state.error = Status(start, 'Can not resolve the parameters of the virtual function')
			=> none as VirtualFunction
		}

		function.parameters.add_range(implementation_parameters)
		
		# Declare both the virtual function and its default implementation
		type.declare(virtual_function)
		context.(Type).declare_override(function)

		=> virtual_function
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		function = none as Function

		if tokens[tokens.size - 1].match(`{`) or tokens[tokens.size - 1].match(Operators.HEAVY_ARROW) {
			function = create_virtual_function_with_implementation(context, state, tokens)
		}
		else {
			function = create_virtual_function_without_implementation(context, state, tokens)
		}

		if function == none => none as Node

		=> FunctionDefinitionNode(function, tokens[0].position)
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
		if modifier.keyword.type != KEYWORD_TYPE_MODIFIER => false

		node = tokens[OBJECT].(DynamicToken).node
		=> node.match(NODE_CONSTRUCTION | NODE_VARIABLE | NODE_FUNCTION_DEFINITION | NODE_TYPE_DEFINITION) or (node.instance == NODE_LINK and node.last.instance == NODE_CONSTRUCTION)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		modifiers = tokens[MODIFIER].(KeywordToken).keyword.(ModifierKeyword).modifier
		destination = tokens[OBJECT].(DynamicToken).node

		if destination.instance == NODE_VARIABLE {
			variable = destination.(VariableNode).variable
			variable.modifiers = combine_modifiers(variable.modifiers, modifiers)
		}
		else destination.instance == NODE_FUNCTION_DEFINITION {
			if has_flag(modifiers, MODIFIER_IMPORTED) {
				state.error = Status(tokens[MODIFIER].position, 'Can not add modifier import to a function definition')
				=> none as Node
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

		=> destination
	}
}

Pattern TypeInspectionPattern {
	constant SIZE_INSPECTION_IDENTIFIER = 'sizeof'
	constant NAME_INSPECTION_IDENTIFIER = 'nameof'

	# Pattern: sizeof($type)/nameof($type)
	init() {
		path.add(TOKEN_TYPE_FUNCTION)
		priority = 18
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		descriptor = tokens[0] as FunctionToken
		if not (descriptor.name == SIZE_INSPECTION_IDENTIFIER or descriptor.name == NAME_INSPECTION_IDENTIFIER) => false

		# Create a temporary state which in order to check whether the parameters contains a type
		state = ParserState()
		state.all = descriptor.parameters.tokens
		state.tokens = List<Token>()
		=> common.consume_type(state) and state.end == state.all.size
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		descriptor = tokens[0] as FunctionToken
		type = common.read_type(context, descriptor.parameters.tokens)

		if type == none {
			state.error = Status(descriptor.position, 'Can not resolve the inspected type')
			=> none as Node
		}

		position = descriptor.position

		if descriptor.name == NAME_INSPECTION_IDENTIFIER {
			if type.is_resolved => StringNode(type.string(), position)
			=> InspectionNode(INSPECTION_TYPE_NAME, TypeNode(type), position)
		}

		=> InspectionNode(INSPECTION_TYPE_SIZE, TypeNode(type), position)
	}
}

Pattern CompilesPattern {
	constant COMPILES = 0
	constant CONDITIONS = 2

	init() {
		path.add(TOKEN_TYPE_KEYWORD)
		path.add(TOKEN_TYPE_END | TOKEN_TYPE_OPTIONAL)
		path.add(TOKEN_TYPE_PARENTHESIS)
		priority = 5
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		=> tokens[COMPILES].match(Keywords.COMPILES) and tokens[CONDITIONS].match(`{`)
	}

	override build(context: Context, state: ParserState, tokens: List<Token>) {
		conditions = parser.parse(context, tokens[CONDITIONS].(ParenthesisToken))
		result = CompilesNode(tokens[COMPILES].position)
		loop condition in conditions { result.add(condition) }
		=> result
	}
}

# TODO: Test
Pattern IsPattern {
	constant KEYWORD = 1
	constant TYPE = 2

	# Pattern $object is [not] $type [$name]
	init() {
		path.add(TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_FUNCTION)
		path.add(TOKEN_TYPE_KEYWORD)
		priority = 5
	}

	override passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny) {
		if not tokens[KEYWORD].match(Keywords.IS) and not tokens[KEYWORD].match(Keywords.IS_NOT) => false

		# Consume the type
		if not common.consume_type(state) => false

		# Try consuming the result variable
		state.consume(TOKEN_TYPE_IDENTIFIER)
		=> true
	}

	override build(context: Context, state: ParserState, formatted: List<Token>) {
		negate = formatted[KEYWORD].match(Keywords.IS_NOT)

		source = parser.parse(context, formatted[0])
		tokens = formatted.slice(TYPE, formatted.size)
		type = common.read_type(context, tokens)

		if type == none {
			state.error = Status(formatted[TYPE].position, 'Can not understand the type')
			=> none as Node
		}

		result = none as Node

		# If there is a token left in the queue, it must be the result variable name
		if tokens.size > 0 {
			name = tokens.take_first().(IdentifierToken).value
			variable = Variable(context, type, VARIABLE_CATEGORY_LOCAL, name, MODIFIER_DEFAULT)
			context.declare(variable)

			result = IsNode(source, type, variable, formatted[KEYWORD].position)
		}
		else {
			result = IsNode(source, type, none as Variable, formatted[KEYWORD].position)
		}

		if negate => NotNode(result, result.start)
		=> result
	}
}

# ExtensionFunctionPattern
# HasPattern
# LambdaPattern
# OverrideFunctionPattern
# RangePattern
# ShortFunctionPattern
# WhenPattern