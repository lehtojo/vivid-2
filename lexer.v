FORMAT_INT8 = 2
FORMAT_UINT8 = 3     # 2 | 1
FORMAT_INT16 = 4
FORMAT_UINT16 = 5     # 4 | 1
FORMAT_INT32 = 8
FORMAT_UINT32 = 9     # 8 | 1
FORMAT_INT64 = 16
FORMAT_UINT64 = 17    # 16 | 1
FORMAT_INT128 = 32
FORMAT_UINT128 = 33   # 32 | 1
FORMAT_INT256 = 64
FORMAT_UINT256 = 65   # 64 | 1
FORMAT_DECIMAL = 144 # 16 | 128

FORMAT_SIZE_MASK = 63 # 1 | 2 | 4 | 8 | 16 | 32

OPERATOR_TYPE_CLASSIC = 0
OPERATOR_TYPE_COMPARISON = 1
OPERATOR_TYPE_LOGICAL = 2
OPERATOR_TYPE_ASSIGNMENT = 3
OPERATOR_TYPE_INDEPENDENT = 4

KEYWORD_TYPE_MODIFIER = 0
KEYWORD_TYPE_FLOW = 1
KEYWORD_TYPE_NORMAL = 2

MODIFIER_PUBLIC = 1
MODIFIER_PRIVATE = 2
MODIFIER_PROTECTED = 4
MODIFIER_STATIC = 8
MODIFIER_IMPORTED = 16
MODIFIER_READONLY = 32
MODIFIER_EXPORTED = 64
MODIFIER_CONSTANT = 128
MODIFIER_TEMPLATE_TYPE = 256
MODIFIER_TEMPLATE_FUNCTION = 512
MODIFIER_OUTLINE = 1024
MODIFIER_INLINE = 2048
MODIFIER_PRIMITIVE = 4096
MODIFIER_NUMBER = 8192

MODIFIER_DEFAULT = 1 # MODIFIER_PUBLIC

TOKEN_TYPE_PARENTHESIS = 1
TOKEN_TYPE_FUNCTION = 2
TOKEN_TYPE_KEYWORD = 4
TOKEN_TYPE_IDENTIFIER = 8
TOKEN_TYPE_NUMBER = 16
TOKEN_TYPE_OPERATOR = 32
TOKEN_TYPE_OPTIONAL = 64
TOKEN_TYPE_DYNAMIC = 128
TOKEN_TYPE_END = 256
TOKEN_TYPE_STRING = 512

TOKEN_TYPE_OBJECT = 667 # TOKEN_TYPE_PARENTHESIS | TOKEN_TYPE_FUNCTION | TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_NUMBER | TOKEN_TYPE_DYNAMIC | TOKEN_TYPE_STRING
TOKEN_TYPE_NONE = 0
TOKEN_TYPE_ANY = -1

TOKEN_TYPE_COUNT = 10

LINE_ENDING = `\n`
COMMENT = `#`
STRING = `\'`
# MULTILINE_COMMENT
MULTILINE_COMMENT = '##'
CHARACTER = `\x60`
DECIMAL_SEPARATOR = `.`
EXPONENT_SEPARATOR = `e`
SIGNED_TYPE_SEPARATOR = `i`
UNSIGNED_TYPE_SEPARATOR = `u`

MULTILINE_COMMENT_LENGTH = 3

TEXT_TYPE_TEXT = 0
TEXT_TYPE_NUMBER = 1
TEXT_TYPE_PARENTHESIS = 2
TEXT_TYPE_OPERATOR = 3
TEXT_TYPE_COMMENT = 4
TEXT_TYPE_STRING = 5
TEXT_TYPE_CHARACTER = 6
TEXT_TYPE_END = 7
TEXT_TYPE_UNSPECIFIED = 8

Operator {
	readonly identifier: String
	readonly type: tiny
	readonly priority: tiny

	init(identifier: String, type: tiny, priority: tiny) {
		this.identifier = identifier
		this.type = type
		this.priority = priority
	}
}

Operator AssignmentOperator {
	readonly operator: Operator

	init(identifier: String, operator: Operator, priority: tiny) {
		Operator.init(identifier, OPERATOR_TYPE_ASSIGNMENT, priority)
		this.operator = operator
	}
}

Operator ClassicOperator {
	readonly shared: bool

	init(identifier: String, priority: tiny, shared: bool) {
		Operator.init(identifier, OPERATOR_TYPE_CLASSIC, priority)
		this.shared = shared
	}
}

Operator ComparisonOperator {
	counterpart: Operator

	init(identifier: String, priority: tiny) {
		Operator.init(identifier, OPERATOR_TYPE_COMPARISON, priority)
	}

	set_counterpart(counterpart: ComparisonOperator) {
		this.counterpart = counterpart
		=> this
	}
}

Operator IndependentOperator {
	init(identifier: String) {
		Operator.init(identifier, OPERATOR_TYPE_INDEPENDENT, -1)
	}
}

namespace Operators {
	constant ACCESSOR_SETTER_FUNCTION_IDENTIFIER = 'set'
	constant ACCESSOR_GETTER_FUNCTION_IDENTIFIER = 'get'

	readonly COLON: IndependentOperator
	readonly POWER: ClassicOperator
	readonly MULTIPLY: ClassicOperator
	readonly DIVIDE: ClassicOperator
	readonly MODULUS: ClassicOperator
	readonly ADD: ClassicOperator
	readonly SUBTRACT: ClassicOperator
	readonly SHIFT_LEFT: ClassicOperator
	readonly SHIFT_RIGHT: ClassicOperator
	readonly GREATER_THAN: ComparisonOperator
	readonly GREATER_OR_EQUAL: ComparisonOperator
	readonly LESS_THAN: ComparisonOperator
	readonly LESS_OR_EQUAL: ComparisonOperator
	readonly EQUALS: ComparisonOperator
	readonly NOT_EQUALS: ComparisonOperator
	readonly BITWISE_AND: ClassicOperator
	readonly BITWISE_XOR: ClassicOperator
	readonly BITWISE_OR: ClassicOperator
	readonly RANGE: IndependentOperator
	readonly LOGICAL_AND: Operator
	readonly LOGICAL_OR: Operator
	readonly ASSIGN: AssignmentOperator
	readonly ASSIGN_POWER: AssignmentOperator
	readonly ASSIGN_ADD: AssignmentOperator
	readonly ASSIGN_SUBTRACT: AssignmentOperator
	readonly ASSIGN_MULTIPLY: AssignmentOperator
	readonly ASSIGN_DIVIDE: AssignmentOperator
	readonly ASSIGN_MODULUS: AssignmentOperator
	readonly ASSIGN_BITWISE_AND: AssignmentOperator
	readonly ASSIGN_BITWISE_XOR: AssignmentOperator
	readonly ASSIGN_BITWISE_OR: AssignmentOperator
	readonly EXCLAMATION: IndependentOperator
	readonly COMMA: IndependentOperator
	readonly DOT: IndependentOperator
	readonly INCREMENT: IndependentOperator
	readonly DECREMENT: IndependentOperator
	readonly ARROW: IndependentOperator
	readonly HEAVY_ARROW: IndependentOperator
	readonly END: IndependentOperator
	
	# NOTE: The user should not be able to use this operator since it is meant for internal usage
	readonly ATOMIC_EXCHANGE_ADD: ClassicOperator

	private all: Map<String, Operator>
	private assignment_operators: Map<String, AssignmentOperator>
	
	public operator_overloads: Map<Operator, String>

	private add(operator: Operator) {
		all.add(operator.identifier, operator)

		if operator.type == OPERATOR_TYPE_ASSIGNMENT and operator.(AssignmentOperator).operator != none and operator.(AssignmentOperator).operator.identifier.length > 0 {
			assignment_operators.add(operator.(AssignmentOperator).operator.identifier, operator.(AssignmentOperator))
		}
	}

	initialize() {
		COLON = IndependentOperator(String(':'))
		POWER = ClassicOperator(String('^'), 15, true)
		MULTIPLY = ClassicOperator(String('*'), 12, true)
		DIVIDE = ClassicOperator(String('/'), 12, true)
		MODULUS = ClassicOperator(String('%'), 12, true)
		ADD = ClassicOperator(String('+'), 11, true)
		SUBTRACT = ClassicOperator(String('-'), 11, true)
		SHIFT_LEFT = ClassicOperator(String('<|'), 10, true)
		SHIFT_RIGHT = ClassicOperator(String('|>'), 10, true)
		GREATER_THAN = ComparisonOperator(String('>'), 9)
		GREATER_OR_EQUAL = ComparisonOperator(String('>='), 9)
		LESS_THAN = ComparisonOperator(String('<'), 9)
		LESS_OR_EQUAL = ComparisonOperator(String('<='), 9)
		EQUALS = ComparisonOperator(String('=='), 8)
		NOT_EQUALS = ComparisonOperator(String('!='), 8)
		BITWISE_AND = ClassicOperator(String('&'), 7, true)
		BITWISE_XOR = ClassicOperator(String('¤'), 6, true)
		BITWISE_OR = ClassicOperator(String('|'), 5, true)
		RANGE = IndependentOperator(String('..'))
		LOGICAL_AND = Operator(String('and'), OPERATOR_TYPE_LOGICAL, 4)
		LOGICAL_OR = Operator(String('or'), OPERATOR_TYPE_LOGICAL, 3)
		ASSIGN = AssignmentOperator(String('='), none as Operator, 1)
		ASSIGN_POWER = AssignmentOperator(String('^='), POWER, 1)
		ASSIGN_ADD = AssignmentOperator(String('+='), ADD, 1)
		ASSIGN_SUBTRACT = AssignmentOperator(String('-='), SUBTRACT, 1)
		ASSIGN_MULTIPLY = AssignmentOperator(String('*='), MULTIPLY, 1)
		ASSIGN_DIVIDE = AssignmentOperator(String('/='), DIVIDE, 1)
		ASSIGN_MODULUS = AssignmentOperator(String('%='), MODULUS, 1)
		ASSIGN_BITWISE_AND = AssignmentOperator(String('&='), BITWISE_AND, 1)
		ASSIGN_BITWISE_XOR = AssignmentOperator(String('¤='), BITWISE_XOR, 1)
		ASSIGN_BITWISE_OR = AssignmentOperator(String('|='), ASSIGN_BITWISE_OR, 1)
		EXCLAMATION = IndependentOperator(String('!'))
		COMMA = IndependentOperator(String(','))
		DOT = IndependentOperator(String('.'))
		INCREMENT = IndependentOperator(String('++'))
		DECREMENT = IndependentOperator(String('--'))
		ARROW = IndependentOperator(String('->'))
		HEAVY_ARROW = IndependentOperator(String('=>'))
		END = IndependentOperator(String('\n'))
		ATOMIC_EXCHANGE_ADD = ClassicOperator(String.empty, 11, true)

		all = Map<String, Operator>()
		assignment_operators = Map<String, AssignmentOperator>()
		operator_overloads = Map<Operator, String>()

		add(COLON)
		add(POWER)
		add(MULTIPLY)
		add(DIVIDE)
		add(MODULUS)
		add(ADD)
		add(SUBTRACT)
		add(SHIFT_LEFT)
		add(SHIFT_RIGHT)
		add(GREATER_THAN.set_counterpart(LESS_OR_EQUAL))
		add(GREATER_OR_EQUAL.set_counterpart(LESS_THAN))
		add(LESS_THAN.set_counterpart(GREATER_OR_EQUAL))
		add(LESS_OR_EQUAL.set_counterpart(GREATER_THAN))
		add(EQUALS.set_counterpart(NOT_EQUALS))
		add(NOT_EQUALS.set_counterpart(EQUALS))
		add(BITWISE_AND)
		add(BITWISE_XOR)
		add(BITWISE_OR)
		add(RANGE)
		add(LOGICAL_AND)
		add(LOGICAL_OR)
		add(ASSIGN)
		add(ASSIGN_POWER)
		add(ASSIGN_ADD)
		add(ASSIGN_SUBTRACT)
		add(ASSIGN_MULTIPLY)
		add(ASSIGN_DIVIDE)
		add(ASSIGN_MODULUS)
		add(ASSIGN_BITWISE_AND)
		add(ASSIGN_BITWISE_XOR)
		add(ASSIGN_BITWISE_OR)
		add(EXCLAMATION)
		add(COMMA)
		add(DOT)
		add(INCREMENT)
		add(DECREMENT)
		add(ARROW)
		add(HEAVY_ARROW)
		add(END)

		operator_overloads.add(ADD, String('plus'))
		operator_overloads.add(SUBTRACT, String('minus'))
		operator_overloads.add(MULTIPLY, String('times'))
		operator_overloads.add(DIVIDE, String('divide'))
		operator_overloads.add(MODULUS, String('remainder'))
		operator_overloads.add(ASSIGN_ADD, String('assign_plus'))
		operator_overloads.add(ASSIGN_SUBTRACT, String('assign_minus'))
		operator_overloads.add(ASSIGN_MULTIPLY, String('assign_times'))
		operator_overloads.add(ASSIGN_DIVIDE, String('assign_divide'))
		operator_overloads.add(ASSIGN_MODULUS, String('assign_remainder'))
		operator_overloads.add(EQUALS, String('equals'))
	}

	exists(identifier: String) {
		=> all.contains_key(identifier)
	}

	get(identifier: String) {
		=> all[identifier]
	}
}

Keyword {
	readonly type: tiny
	readonly identifier: String

	init(identifier, type) {
		this.identifier = identifier
		this.type = type
	}
}

Keyword ModifierKeyword {
	modifier: normal

	init(identifier: String, modifier: normal) {
		Keyword.init(identifier, KEYWORD_TYPE_MODIFIER)
		this.modifier = modifier
	}
}

namespace Keywords {
	readonly AS: Keyword
	readonly COMPILES: Keyword
	readonly CONSTANT: Keyword
	readonly CONTINUE: Keyword
	readonly DEINIT: Keyword
	readonly ELSE: Keyword
	readonly EXPORT: Keyword
	readonly HAS: Keyword
	readonly IF: Keyword
	readonly IN: Keyword
	readonly INLINE: Keyword
	readonly IS: Keyword
	readonly IS_NOT: Keyword
	readonly INIT: Keyword
	readonly IMPORT: Keyword
	readonly LOOP: Keyword
	readonly NAMESPACE: Keyword
	readonly NOT: Keyword
	readonly OUTLINE: Keyword
	readonly PRIVATE: Keyword
	readonly PROTECTED: Keyword
	readonly PUBLIC: Keyword
	readonly READONLY: Keyword
	readonly RETURN: Keyword
	readonly STATIC: Keyword
	readonly STOP: Keyword
	readonly WHEN: Keyword

	public readonly all: Map<String, Keyword>

	private add(keyword: Keyword) {
		all.add(keyword.identifier, keyword)
	}

	initialize() {
		AS = Keyword(String('as'), KEYWORD_TYPE_NORMAL)
		COMPILES = Keyword(String('compiles'), KEYWORD_TYPE_NORMAL)
		CONSTANT = ModifierKeyword(String('constant'), MODIFIER_CONSTANT)
		CONTINUE = Keyword(String('continue'), KEYWORD_TYPE_FLOW)
		DEINIT = Keyword(String('deinit'), KEYWORD_TYPE_NORMAL)
		ELSE = Keyword(String('else'), KEYWORD_TYPE_FLOW)
		EXPORT = ModifierKeyword(String('export'), MODIFIER_EXPORTED)
		HAS = ModifierKeyword(String('constant'), MODIFIER_CONSTANT)
		IF = Keyword(String('if'), KEYWORD_TYPE_FLOW)
		IN = ModifierKeyword(String('constant'), MODIFIER_CONSTANT)
		INLINE = ModifierKeyword(String('inline'), MODIFIER_INLINE)
		IS = Keyword(String('is'), KEYWORD_TYPE_NORMAL)
		IS_NOT = Keyword(String('is not'), KEYWORD_TYPE_NORMAL)
		INIT = Keyword(String('init'), KEYWORD_TYPE_NORMAL)
		IMPORT = ModifierKeyword(String('import'), MODIFIER_IMPORTED)
		LOOP = Keyword(String('loop'), KEYWORD_TYPE_FLOW)
		NAMESPACE = ModifierKeyword(String('constant'), MODIFIER_CONSTANT)
		NOT = Keyword(String('not'), KEYWORD_TYPE_NORMAL)
		OUTLINE = ModifierKeyword(String('outline'), MODIFIER_OUTLINE)
		PRIVATE = ModifierKeyword(String('private'), MODIFIER_PRIVATE)
		PROTECTED = ModifierKeyword(String('protected'), MODIFIER_PROTECTED)
		PUBLIC = ModifierKeyword(String('public'), MODIFIER_PUBLIC)
		READONLY = ModifierKeyword(String('readonly'), MODIFIER_READONLY)
		RETURN = Keyword(String('return'), KEYWORD_TYPE_FLOW)
		STATIC = ModifierKeyword(String('static'), MODIFIER_STATIC)
		STOP = Keyword(String('stop'), KEYWORD_TYPE_FLOW)
		WHEN = Keyword(String('when'), KEYWORD_TYPE_FLOW)

		all = Map<String, Keyword>()

		add(AS)
		add(COMPILES)
		add(CONSTANT)
		add(CONTINUE)
		add(ELSE)
		add(EXPORT)
		add(HAS)
		add(IF)
		add(IN)
		add(INLINE)
		add(IS)
		add(IS_NOT)
		add(IMPORT)
		add(LOOP)
		add(NAMESPACE)
		add(NOT)
		add(OUTLINE)
		add(PRIVATE)
		add(PROTECTED)
		add(PUBLIC)
		add(READONLY)
		add(RETURN)
		add(STATIC)
		add(STOP)
		add(WHEN)
	}

	exists(identifier: String) {
		=> all.contains_key(identifier)
	}

	get(identifier: String) {
		=> all[identifier]
	}
}

Position {
	file: SourceFile = none as SourceFile
	line: normal
	character: normal
	local: normal
	absolute: normal
	cursor: bool = false

	friendly_line => line + 1
	friendly_character => character + 1

	init(line: normal, character: normal, local: normal, absolute: normal) {
		this.line = line
		this.character = character
		this.local = local
		this.absolute = absolute
	}

	init() {
		this.line = 0
		this.character = 0
		this.local = 0
		this.absolute = 0
	}

	next_line() {
		line++
		character = 0
		local++
		absolute++
		=> this
	}

	next_character() {
		character++
		local++
		absolute++
		=> this
	}

	translate(characters: normal) {
		=> Position(line, character + characters, local + characters, absolute + characters)
	}

	clone() {
		=> Position(line, character, local, absolute)
	}

	equals(other: Position) {
		=> absolute == other.absolute and file == other.file
	}
}

Token {
	readonly type: small
	position: Position

	init(type: small) {
		this.type = type
	}

	match(type: large) {
		=> this.type == type
	}

	string() {
		if type == TOKEN_TYPE_END => String('\n')
		=> String.empty
	}

	virtual clone() {
		token = Token(type)
		token.position = position
		=> token
	}
}

Token IdentifierToken {
	value: String
	end => position.translate(value.length)

	init(value: String) {
		Token.init(TOKEN_TYPE_IDENTIFIER)
		this.value = value
	}

	init(value: String, position: Position) {
		Token.init(TOKEN_TYPE_IDENTIFIER)
		this.value = value
		this.position = position
	}

	string() {
		=> value
	}

	override clone() {
		=> IdentifierToken(value, position)
	}
}

Token OperatorToken {
	operator: Operator
	end => position.translate(operator.identifier.length)

	init(identifier: String) {
		Token.init(TOKEN_TYPE_OPERATOR)	
		operator = Operators.get(identifier)
	}

	init(operator: Operator, position: Position) {
		Token.init(TOKEN_TYPE_OPERATOR)
		this.operator = operator
		this.position = position
	}

	string() {
		=> operator.identifier
	}

	override clone() {
		=> OperatorToken(operator, position)
	}
}

Token KeywordToken {
	keyword: Keyword
	end => position.translate(keyword.identifier.length)

	init(keyword: String) {
		Token.init(TOKEN_TYPE_KEYWORD)
		this.keyword = Keywords.get(keyword)
	}

	init(keyword: Keyword, position: Position) {
		Token.init(TOKEN_TYPE_KEYWORD)
		this.keyword = keyword
	}

	string() {
		=> keyword.identifier
	}

	override clone() {
		=> KeywordToken(keyword, position)
	}
}

Token NumberToken {
	data: large

	bits => get_bytes(format) * 8
	bytes => get_bytes(format)

	format: normal
	end: Position

	init(data: large, format: large, length: large, position: Position) {
		Token.init(TOKEN_TYPE_NUMBER)
		this.data = data
		this.format = format
		this.position = position
		this.end = position.translate(length)
	}

	init(data: decimal, format: large, length: large, position: Position) {
		Token.init(TOKEN_TYPE_NUMBER)
		this.data = decimal_to_bits(data)
		this.format = format
		this.position = position
		this.end = position.translate(length)
	}

	init(data: large, format: large, start: Position, end: Position) {
		Token.init(TOKEN_TYPE_NUMBER)
		this.data = data
		this.format = format
		this.position = start
		this.end = end
	}

	decimal_value() => bits_to_decimal(data)

	string() {
		if format == FORMAT_DECIMAL => to_string(decimal_value())
		=> to_string(data)
	}

	override clone() {
		=> NumberToken(data, format, position, end)
	}
}

Token StringToken {
	text: String
	end => position.translate(text.length + 2)

	init(text: String) {
		Token.init(TOKEN_TYPE_STRING)
		this.text = text.slice(1, text.length - 1)
	}

	init(text: String, position: Position) {
		Token.init(TOKEN_TYPE_STRING)
		this.text = text
		this.position = position
	}

	string() {
		=> String(STRING) + text + STRING
	}

	override clone() {
		=> StringToken(text, position)
	}
}

Token ParenthesisToken {
	opening: char
	tokens: List<Token>
	end: Position

	empty => tokens.size == 0

	init(opening: char, start: Position, end: Position, tokens: List<Token>) {
		Token.init(TOKEN_TYPE_PARENTHESIS)
		this.position = start
		this.end = end
		this.opening = opening
		this.tokens = tokens
	}

	get_sections() {
		sections = List<List<Token>>()
		if tokens.size == 0 => sections

		section = List<Token>()

		loop token in tokens {
			if (token.match(Operators.COMMA)) {
				sections.add(section)
				section = List<Token>()
				continue
			}

			section.add(token)
		}

		sections.add(section)
		=> sections
	}

	string() {
		values = List<String>(tokens.size, false)
		loop token in tokens { values.add(to_string(token)) }

		=> String(opening) + String.join(` `, values) + String(get_closing(opening))
	}

	override clone() {
		clone = List<Token>(tokens.size, true)

		loop (i = 0, i < tokens.size, i++) {
			clone[i] = tokens[i].clone()
		}

		=> ParenthesisToken(opening, position, end, clone)
	}
}

Token FunctionToken {
	readonly identifier: IdentifierToken
	readonly parameters: ParenthesisToken
	readonly node: Node

	name => this.identifier.value

	init(identifier: IdentifierToken, parameters: ParenthesisToken) {
		Token.init(TOKEN_TYPE_FUNCTION)
		this.identifier = identifier
		this.parameters = parameters
	}

	init(identifier: IdentifierToken, parameters: ParenthesisToken, position: Position) {
		Token.init(TOKEN_TYPE_FUNCTION)
		this.identifier = identifier
		this.parameters = parameters
		this.position = position
	}

	# Summary: Returns the parameters of this token
	get_parameters(context: Context) {
		tokens = List<Token>(parameters.tokens.size, false)
		tokens.add_range(parameters.tokens)

		result = List<Parameter>()

		loop (tokens.size > 0) {
			# Ensure the name is valid
			name = tokens.take_first()
			if name == none or not name.match(TOKEN_TYPE_IDENTIFIER) => Error<List<Parameter>, String>(String('Can not understand the parameters'))
			
			next = tokens.take_first()
			
			if next == none or next.match(Operators.COMMA) {
				result.add(Parameter(name.(IdentifierToken).value, name.position, none as Type))
				continue
			}

			# If there are tokens left and the next token is not a comma, it must represent a parameter type
			if not next.match(Operators.COLON) => Error<List<Parameter>, String>(String('Can not understand the parameters'))

			parameter_type = common.read_type(context, tokens)
			if parameter_type == none => Error<List<Parameter>, String>(String('Can not understand the parameter type'))

			result.add(Parameter(name.(IdentifierToken).value, name.position, parameter_type))

			# If there are tokens left, the next token must be a comma and it must be removed before starting over
			if tokens.size > 0 and not tokens.take_first().match(Operators.COMMA) => Error<List<Parameter>, String>(String('Can not understand the parameters'))
		}

		loop parameter in result {
			context.declare(parameter.type, VARIABLE_CATEGORY_PARAMETER, parameter.name).position = parameter.position
		}

		=> Ok<List<Parameter>, String>(result)
	}

	parse(context: Context) {
		if node != none and node.first != none => node

		result = parser.parse(context, List<Token>(parameters.tokens), parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		if result.first != none and result.first.match(NODE_LIST) { node = result.first }
		else { node = result }

		=> node
	}
	
	string() {
		=> name + parameters.string()
	}

	override clone() {
		=> FunctionToken(identifier.clone() as IdentifierToken, parameters.clone() as ParenthesisToken, position)
	}
}

TextArea {
	start: Position
	end: Position
	type: normal
	text: String

	init(start: Position, type: normal) {
		this.start = start
		this.type = type
	}
}

# Summary: Converts the specified token to string based on its type
to_string(token: Token) {
	if token.type == TOKEN_TYPE_IDENTIFIER => token.(IdentifierToken).string()
	else token.type == TOKEN_TYPE_NUMBER => token.(NumberToken).string()
	else token.type == TOKEN_TYPE_PARENTHESIS => token.(ParenthesisToken).string()
	else token.type == TOKEN_TYPE_KEYWORD => token.(KeywordToken).string()
	else token.type == TOKEN_TYPE_OPERATOR => token.(OperatorToken).string()
	else token.type == TOKEN_TYPE_FUNCTION => token.(FunctionToken).string()
	else token.type == TOKEN_TYPE_STRING => token.(StringToken).string()
	=> token.string()
}

# Summary: Returns whether the format is an unsigned format
is_unsigned(format: large) {
	=> (format & 1) != 0
}

# Summary: Returns whether the format is an unsigned format
is_signed(format: large) {
	=> (format & 1) == 0
}

to_format(bytes: large) {
	=> (bytes <| 1) | 1
}

to_format(bytes: large, unsigned: bool) {
	=> (bytes <| 1) | unsigned
}

to_bytes(format: large) {
	=> (format |> 1) & FORMAT_SIZE_MASK
}

to_bits(format: large) {
	=> [(format |> 1) & FORMAT_SIZE_MASK] * 8
}

# Summary: Returns whether the specified flags contains the specified flag
has_flag(flags: large, flag: large) {
	=> (flags & flag) == flag
}

# Summary: Removes the exponent or the number type from the specified string
private get_number_part(text: String) {
	i = 0
	
	loop (i < text.length, i++) {
		if is_digit(text[i]) or text[i] == DECIMAL_SEPARATOR continue
	}

	=> text.slice(0, i)
}

# Summary: Returns the value of the exponent which is contained in the specified number string
private get_exponent(text: String) {
	i = text.index_of(EXPONENT_SEPARATOR)
	if i == -1 => Ok<large, String>(0)

	if text.length == ++i => Error<large, String>(String('Invalid exponent'))

	sign = 1

	if text[i] == `-` {
		sign = -1
		i++
	}
	else text[i] == `+` {
		i++
	}

	j = i
	loop (j < text.length and is_digit(text[j]), j++) {}
	exponent = text.slice(i, j)

	# Try to convert the exponent string to an integer
	if as_number(exponent) has result => Ok<large, String>(sign * result)

	=> Error<large, String>(String('Invalid exponent'))
}

# Summary: Returns the format which has the same properties as specified
private get_format(bits: large, unsigned: bool) {
	format = when(bits) {
		8 => FORMAT_INT8,
		16 => FORMAT_INT16,
		32 => FORMAT_INT32,
		64 => FORMAT_INT64,
		128 => FORMAT_INT128,
		256 => FORMAT_INT256,
		else => FORMAT_INT64
	}

	if unsigned => format | 1
	=> format
}

# Summary: Returns the format which is expressed in the specified number string
private get_number_format(text: String) {
	i = text.index_of(SIGNED_TYPE_SEPARATOR)
	unsigned = false

	if i == -1 {
		i = text.index_of(UNSIGNED_TYPE_SEPARATOR)

		if i != -1 {
			unsigned = true
		}
		else => FORMAT_INT64
	}

	s = i
	loop (is_digit(text[++i])) {}

	if as_number(text.slice(s, i)) has bits => get_format(bits, unsigned)
	=> get_format(SYSTEM_BITS, unsigned)
}

# Summary: Tries to convert the specified string to a number token
try_create_number_token(text: String, position: Position) {
	if not (get_exponent(text) has exponent) => Error<NumberToken, String>(String('Invalid exponent'))

	if text.index_of(DECIMAL_SEPARATOR) != -1 {
		if not (as_decimal(get_number_part(text)) has value) => Error<NumberToken, String>(String('Can not resolve the number'))

		loop (i = 0, i < exponent, i++) { value *= 10 }

		=> Ok<NumberToken, String>(NumberToken(value, FORMAT_DECIMAL, text.length, position))
	}
	else {
		if not (as_number(get_number_part(text)) has value) => Error<NumberToken, String>(String('Can not resolve the number'))

		loop (i = 0, i < exponent, i++) { value *= 10 }

		format = get_number_format(text)
		
		=> Ok<NumberToken, String>(NumberToken(value, format, text.length, position))
	}
}

# Summary: Returns the closing parenthesis of the specified opening parenthesis
get_closing(opening: char) {
	if opening == `(` => `)`
	=> opening + 2
}

# Returns whether the specified character is an operator
is_operator(i: char) {
	=> i >= 33 and i <= 47 and i != COMMENT and i != STRING or i >= 58 and i <= 63 or i == 94 or i == 124 or i == 126 or i == `¤`
}

# Summary:
# Returns all the characters which can mix with the specified character.
# If this function returns null, it means the specified character can mix with any character.
get_mixing_characters(i: char) {
	=> when(i) {
		`.` => '.0123456789',
		`,` => '',
		`<` => '|=',
		`>` => '|=-:',
		else => none as link
	}
}

# Summary: Returns whether the two specified characters can mix
mixes(a: char, b: char) {
	x = get_mixing_characters(a)
	if x != none => String(x).index_of(b) != -1

	y = get_mixing_characters(b)
	if y != none => String(y).index_of(a) != -1

	=> true
}

# Summary: Returns whether the character is a text
is_text(i: char) {
	=> (i >= `a` and i <= `z`) or (i >= `A` and i <= `Z`) or (i == `_`)
}

# Summary: Returns whether the character is start of a parenthesis
is_parenthesis(i: char) {
	=> i == `(` or i == `[` or i == `{`
}

# Summary: Returns whether the character is start of a comment
is_comment(i: char) {
	=> i == COMMENT
}

# Summary: Returns whether the character start of a string
is_string(i: char) {
	=> i == STRING
}

# Summary: Returns whether the character start of a character value
is_character_value(i: char) {
	=> i == CHARACTER
}

# Summary: Returns the type of the specified character
get_text_type(i: char) {
	if is_text(i) => TEXT_TYPE_TEXT
	if is_digit(i) => TEXT_TYPE_NUMBER
	if is_parenthesis(i) => TEXT_TYPE_PARENTHESIS
	if is_operator(i) => TEXT_TYPE_OPERATOR
	if is_comment(i) => TEXT_TYPE_COMMENT
	if is_string(i) => TEXT_TYPE_STRING
	if is_character_value(i) => TEXT_TYPE_CHARACTER
	if i == LINE_ENDING => TEXT_TYPE_END
	=> TEXT_TYPE_UNSPECIFIED
}

# Summary: Returns whether the character is part of the progressing token
is_part_of(previous: large, current: large, previous_character: char, current_character: char, next_character: char) {
	if not mixes(previous_character, current_character) => false
	if current == previous or previous == TEXT_TYPE_UNSPECIFIED => true

	if previous == TEXT_TYPE_TEXT => current == TEXT_TYPE_NUMBER
	if previous == TEXT_TYPE_NUMBER => (current_character == DECIMAL_SEPARATOR and is_digit(next_character)) or
		current_character == EXPONENT_SEPARATOR or
		current_character == SIGNED_TYPE_SEPARATOR or
		current_character == UNSIGNED_TYPE_SEPARATOR or
		(previous_character == EXPONENT_SEPARATOR and (current_character == `+` or current_character == `-`))
	
	=> false
}

# Summary: Skips all the spaces starting from the specified position
skip_spaces(text: String, position: Position) {
	loop (position.local < text.length) {
		if text[position.local] != ` ` stop
		position.next_character()
	}

	=> position
}

# Summary: Finds the corresponding end parenthesis and returns its position
skip_parenthesis(text: String, start: Position) {
	position = start.clone()

	opening = text[position.local]
	closing = get_closing(opening)

	count = 0

	loop (position.local < text.length) {
		i = text[position.local]

		if i == LINE_ENDING position.next_line()
		else i == STRING {
			position = skip_string(text, position)
		}
		else i == CHARACTER {
			position = skip_character_value(text, position)
		}
		else {
			if i == opening { count++ }
			else i == closing { count-- }

			position.next_character()
		}

		if count == 0 => position
	}

	=> none as Position
}

# Summary: Returns whether a multiline comment begins at the specified position
is_multiline_comment(text: String, start: Position) {
	=> start.local + MULTILINE_COMMENT_LENGTH * 2 <= text.length and text.slice(start.local, start.local + MULTILINE_COMMENT_LENGTH) == MULTILINE_COMMENT and text[start.local + MULTILINE_COMMENT_LENGTH] != COMMENT
}

# Summary: Skips the current comment and returns the position
skip_comment(text: String, start: Position) {
	if is_multiline_comment(text, start) {
		require(false, 'Multiline comments are not supported yet')
	}

	i = text.index_of(LINE_ENDING, start.local)

	if i != -1 {
		length = i - start.local
		=> Position(start.line, start.character + length, start.local + length, start.absolute + length)
	}
	else {
		length = text.length - start.local
		=> Position(start.line, start.character + length, start.local + length, start.absolute + length)
	}
}

# Summary: Skips closures which has the same character in both ends
skip_closures(closure: char, text: String, start: Position) {
	i = text.index_of(closure, start.local + 1)
	j = text.index_of(LINE_ENDING, start.local + 1)

	if i == -1 or j != -1 and j < i => none as Position

	length = i + 1 - start.local
	=> Position(start.line, start.character + length, start.local + length, start.absolute + length)
}

# Summary: Skips the current string and returns the position
skip_string(text: String, start: Position) {
	=> skip_closures(STRING, text, start)
}

# Summary: Skips the current character value and returns the position
skip_character_value(text: String, start: Position) {
	=> skip_closures(CHARACTER, text, start)
}

# Summary: Returns a list of tokens which represents the specified text
get_special_character_value(text: String) {
	command = text[0]
	length = 0
	error = ''

	if command == `x` {
		length = 2
		error = 'Can not understand hexadecimal value'
	}
	else command == `u` {
		length = 4
		error = 'Can not understand unicode character'
	}
	else command == `U` {
		length = 8
		error = 'Can not understand unicode character'
	}
	else {
		=> Error<large, String>(String('Can not understand string command'))
	}

	hexadecimal = text.slice(2, text.length)
	
	if hexadecimal.length != length => Error<large, String>(String('Invalid character'))
	if as_number(hexadecimal) has value => Ok<large, String>(value)

	=> Error<large, String>(String(error))
}

# Summary: Returns the integer value of the character value
get_character_value(text: String, position: Position) {
	text = text.slice(1, text.length - 1) # Remove the closures

	if text.length == 0 => Error<large, String>(String('Character value is empty'))

	if text[0] != `\\` {
		if text.length != 1 => Error<large, String>(String('Character value allows only one character'))
		=> Ok<large, String>(text[0])
	}

	if text.length == 2 and text[1] == `\\` => Ok<large, String>(`\\`)
	if text.length <= 2 => Error<large, String>(String('Invalid character'))

	=> get_special_character_value(text)
}

get_next_token(text: String, start: Position) {
	# Firsly the spaces must be skipped to find the next token
	position = skip_spaces(text, start)

	# Verify there is text to iterate
	if position.local == text.length => Ok<TextArea, String>(none as TextArea)

	type = get_text_type(text[position.local])
	area = TextArea(position.clone(), type)

	if area.type == TEXT_TYPE_COMMENT {
		area.end = skip_comment(text, area.start)
		area.text = text.slice(area.start.local, area.end.local)
		=> Ok<TextArea, String>(area)
	}
	else area.type == TEXT_TYPE_PARENTHESIS {
		end = skip_parenthesis(text, area.start)
		if end as link == none => Error<TextArea, String>(String('Can not find the closing parenthesis'))

		area.end = end
		area.text = text.slice(area.start.local, area.end.local)
		=> Ok<TextArea, String>(area)
	}
	else area.type == TEXT_TYPE_END {
		area.end = position.clone().next_line()
		area.text = String('\n')
		=> Ok<TextArea, String>(area)
	}
	else area.type == TEXT_TYPE_STRING {
		end = skip_string(text, area.start)
		if end as link == none => Error<TextArea, String>(String('Can not find the end of the string'))

		area.end = end
		area.text = text.slice(area.start.local, area.end.local)
		=> Ok<TextArea, String>(area)
	}
	else area.type == TEXT_TYPE_CHARACTER {
		area.end = skip_character_value(text, area.start)

		result = get_character_value(text.slice(area.start.local, area.end.local), area.start)
		if not (result has value) => Error<TextArea, String>(result.value as String)

		area.text = to_string(result.value)
		area.type = TEXT_TYPE_NUMBER
		=> Ok<TextArea, String>(area)
	}

	position.next_character()

	# Possible types are now: TEXT, NUMBER, OPERATOR
	loop (position.local < text.length) {
		current_character = text[position.local]

		# There cannot be number and content tokens side by side
		if is_parenthesis(current_character) {
			if area.type == TEXT_TYPE_NUMBER => Error<TextArea, String>(String('Missing operator between number and parenthesis'))
			stop
		}

		type = get_text_type(current_character)

		previous_character = 0 as char
		next_character = 0 as char

		if position.local > 0 {
			previous_character = text[position.local - 1]
		}
		if position.local + 1 < text.length {
			next_character = text[position.local + 1]
		}

		if not is_part_of(area.type, type, previous_character, current_character, next_character) stop

		position.next_character()
	}

	area.end = position
	area.text = text.slice(area.start.local, area.end.local)
	=> Ok<TextArea, String>(area)
}

# Summary: Parses a token from the specified text
parse_text_token(text: String) {
	if Operators.exists(text) => OperatorToken(text)
	if Keywords.exists(text) => KeywordToken(text)
	=> IdentifierToken(text)
}

# Summary: Parses a token from a text area
parse_token(area: TextArea) {
	if area.type == TEXT_TYPE_OPERATOR {
		if not Operators.exists(area.text) => Error<Token, String>(String('Unknown operator'))
		=> Ok<Token, String>(OperatorToken(area.text))
	}
	else area.type == TEXT_TYPE_NUMBER {
		result = try_create_number_token(area.text, area.start)
		if not (result has number) => Error<Token, String>(result.value as String)
		=> Ok<Token, String>(number)
	}
	else area.type == TEXT_TYPE_PARENTHESIS {
		text = area.text
		if text.length == 2 => Ok<Token, String>(ParenthesisToken(text[0], area.start, area.end, List<Token>()))

		result = get_tokens(text.slice(1, text.length - 1), true)
		if not (result has tokens) => Error<Token, String>(result.value as String)

		=> Ok<Token, String>(ParenthesisToken(text[0], area.start, area.end, tokens))
	}

	token = none as Token

	if area.type == TEXT_TYPE_TEXT { token = parse_text_token(area.text) }
	else area.type == TEXT_TYPE_END { token = Token(TOKEN_TYPE_END) }
	else area.type == TEXT_TYPE_STRING { token = StringToken(area.text) }
	
	if token != none => Ok<Token, String>(token)
	=> Error<Token, String>(String('Unknown token ') + area.text)
}

# Summary: Join all sequential modifier keywords into one token
join(tokens: List<Token>) {}

# Summary: Returns a list of tokens which represents the specified text
get_tokens(text: String, join: bool) {
	=> get_tokens(text, Position(), join)
}

# Summary: Returns a list of tokens which represents the specified text
get_tokens(text: String, anchor: Position, join: bool) {
	tokens = List<Token>()
	position = Position(anchor.line, anchor.character, 0, anchor.absolute)

	loop (position.local < text.length) {
		area_result = get_next_token(text, position.clone())
		if not (area_result has area) => Error<List<Token>, String>(area_result.value as String)
		if area == none stop

		if area.type != TEXT_TYPE_COMMENT {
			token_result = parse_token(area)
			if not (token_result has token) => Error<List<Token>, String>(token_result.value as String)

			token.position = area.start
			tokens.add(token)
		}

		position = area.end
	}

	if not join => Ok<List<Token>, String>(tokens)

	join(tokens)
	=> Ok<List<Token>, String>(tokens)
}

# Summary: Ensures all the tokens have a reference to the specified file
register_file(tokens: List<Token>, file: SourceFile) {
	loop token in tokens {
		token.position.file = file

		if token.type == TOKEN_TYPE_PARENTHESIS {
			register_file(token.(ParenthesisToken).tokens, file)
		}
		else token.type == TOKEN_TYPE_FUNCTION {
			function = token.(FunctionToken)
			function.identifier.position.file = file
			function.parameters.position.file = file

			register_file(function.parameters.tokens, file)
		}
	}
}

# Summary: Creates tokens from file contents
tokenize(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_FILES)) as Optional<Array<SourceFile>> has files) => Status('Nothing to tokenize')
	
	loop (i = 0, i < files.count, i++) {
		file = files[i]

		#println(file.content)

		result = get_tokens(file.content, true)
		if not (result has tokens) => Status(result.value as String)

		register_file(tokens, file)
		file.tokens = tokens

		values = List<String>(file.tokens.size, false)
		loop token in file.tokens { values.add(to_string(token)) }

		#println(String.join(` `, values))
	}

	=> Status()
}

# Summary: Creates an identical list of tokens compared to the specified list
clone(tokens: List<Token>) {
	clone = List<Token>(tokens.size, true)

	loop (i = 0, i < tokens.size, i++) {
		clone[i] = tokens[i].clone()
	}

	=> clone
}