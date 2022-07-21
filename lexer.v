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
MODIFIER_FUNCTION_TYPE = 16384
MODIFIER_ARRAY_TYPE = 32768
MODIFIER_PLAIN = 65536
MODIFIER_PACK = 196608 # 131072 | MODIFIER_PLAIN

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
STRING_OBJECT = `\"`
# MULTILINE_COMMENT
MULTILINE_COMMENT = '###'
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
TEXT_TYPE_HEXADECIMAL = 7
TEXT_TYPE_END = 8
TEXT_TYPE_UNSPECIFIED = 9

POSITIVE_INFINITY_CONSTANT = 'POSITIVE_INFINITY'
NEGATIVE_INFINITY_CONSTANT = 'NEGATIVE_INFINITY'

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
		return this
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
	readonly ABSOLUTE_EQUALS: ComparisonOperator
	readonly ABSOLUTE_NOT_EQUALS: ComparisonOperator
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

	public all: Map<String, Operator>
	public assignment_operators: Map<String, AssignmentOperator>
	
	public operator_overloads: Map<Operator, String>

	private add(operator: Operator) {
		all.add(operator.identifier, operator)

		if operator.type == OPERATOR_TYPE_ASSIGNMENT and operator.(AssignmentOperator).operator != none and operator.(AssignmentOperator).operator.identifier.length > 0 {
			assignment_operators.add(operator.(AssignmentOperator).operator.identifier, operator.(AssignmentOperator))
		}
	}

	get_assignment_operator(operator: Operator) {
		if assignment_operators.contains_key(operator.identifier) return assignment_operators[operator.identifier]
		return none as Operator
	}

	initialize() {
		COLON = IndependentOperator(":")
		POWER = ClassicOperator("^", 15, true)
		MULTIPLY = ClassicOperator("*", 12, true)
		DIVIDE = ClassicOperator("/", 12, true)
		MODULUS = ClassicOperator("%", 12, true)
		ADD = ClassicOperator("+", 11, true)
		SUBTRACT = ClassicOperator("-", 11, true)
		SHIFT_LEFT = ClassicOperator("<|", 10, true)
		SHIFT_RIGHT = ClassicOperator("|>", 10, true)
		GREATER_THAN = ComparisonOperator(">", 9)
		GREATER_OR_EQUAL = ComparisonOperator(">=", 9)
		LESS_THAN = ComparisonOperator("<", 9)
		LESS_OR_EQUAL = ComparisonOperator("<=", 9)
		EQUALS = ComparisonOperator("==", 8)
		NOT_EQUALS = ComparisonOperator("!=", 8)
		ABSOLUTE_EQUALS = ComparisonOperator("===", 8)
		ABSOLUTE_NOT_EQUALS = ComparisonOperator("!==", 8)
		BITWISE_AND = ClassicOperator("&", 7, true)
		BITWISE_XOR = ClassicOperator("\xA4", 6, true)
		BITWISE_OR = ClassicOperator("|", 5, true)
		RANGE = IndependentOperator("..")
		LOGICAL_AND = Operator("and", OPERATOR_TYPE_LOGICAL, 4)
		LOGICAL_OR = Operator("or", OPERATOR_TYPE_LOGICAL, 3)
		ASSIGN = AssignmentOperator("=", none as Operator, 1)
		ASSIGN_POWER = AssignmentOperator("^=", POWER, 1)
		ASSIGN_ADD = AssignmentOperator("+=", ADD, 1)
		ASSIGN_SUBTRACT = AssignmentOperator("-=", SUBTRACT, 1)
		ASSIGN_MULTIPLY = AssignmentOperator("*=", MULTIPLY, 1)
		ASSIGN_DIVIDE = AssignmentOperator("/=", DIVIDE, 1)
		ASSIGN_MODULUS = AssignmentOperator("%=", MODULUS, 1)
		ASSIGN_BITWISE_AND = AssignmentOperator("&=", BITWISE_AND, 1)
		ASSIGN_BITWISE_XOR = AssignmentOperator("\xA4=", BITWISE_XOR, 1)
		ASSIGN_BITWISE_OR = AssignmentOperator("|=", BITWISE_OR, 1)
		EXCLAMATION = IndependentOperator("!")
		COMMA = IndependentOperator(",")
		DOT = IndependentOperator(".")
		INCREMENT = IndependentOperator("++")
		DECREMENT = IndependentOperator("--")
		ARROW = IndependentOperator("->")
		HEAVY_ARROW = IndependentOperator("=>")
		END = IndependentOperator("\n")
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
		add(ABSOLUTE_EQUALS.set_counterpart(ABSOLUTE_NOT_EQUALS))
		add(ABSOLUTE_NOT_EQUALS.set_counterpart(ABSOLUTE_EQUALS))
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

		operator_overloads.add(ADD, "plus")
		operator_overloads.add(SUBTRACT, "minus")
		operator_overloads.add(MULTIPLY, "times")
		operator_overloads.add(DIVIDE, "divide")
		operator_overloads.add(MODULUS, "remainder")
		operator_overloads.add(ASSIGN_ADD, "assign_plus")
		operator_overloads.add(ASSIGN_SUBTRACT, "assign_minus")
		operator_overloads.add(ASSIGN_MULTIPLY, "assign_times")
		operator_overloads.add(ASSIGN_DIVIDE, "assign_divide")
		operator_overloads.add(ASSIGN_MODULUS, "assign_remainder")
		operator_overloads.add(EQUALS, "equals")
	}

	exists(identifier: String) {
		return all.contains_key(identifier)
	}

	get(identifier: String) {
		return all[identifier]
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

# Summary: Returns a bit mask, which is used to determine, which modifiers should be excluded when combining modifiers
get_modifier_excluder(modifiers: large) {
	if (modifiers & MODIFIER_PRIVATE) != 0 return MODIFIER_PUBLIC | MODIFIER_PROTECTED
	if (modifiers & MODIFIER_PROTECTED) != 0 return MODIFIER_PUBLIC | MODIFIER_PRIVATE
	if (modifiers & MODIFIER_PUBLIC) != 0 return MODIFIER_PRIVATE | MODIFIER_PROTECTED
	return 0
}

# Summary: Adds the specified modifier to the specified modifiers
combine_modifiers(modifiers: large, modifier: large) {
	return (modifiers | modifier) & (!get_modifier_excluder(modifier))
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
	readonly HAS_NOT: Keyword
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
	readonly OVERRIDE: Keyword
	readonly PACK: Keyword
	readonly PLAIN: Keyword
	readonly PRIVATE: Keyword
	readonly PROTECTED: Keyword
	readonly PUBLIC: Keyword
	readonly READONLY: Keyword
	readonly RETURN: Keyword
	readonly STATIC: Keyword
	readonly STOP: Keyword
	readonly VIRTUAL: Keyword
	readonly WHEN: Keyword

	public readonly all: Map<String, Keyword>

	private add(keyword: Keyword) {
		all.add(keyword.identifier, keyword)
	}

	initialize() {
		AS = Keyword("as", KEYWORD_TYPE_NORMAL)
		COMPILES = Keyword("compiles", KEYWORD_TYPE_NORMAL)
		CONSTANT = ModifierKeyword("constant", MODIFIER_CONSTANT)
		CONTINUE = Keyword("continue", KEYWORD_TYPE_FLOW)
		DEINIT = Keyword("deinit", KEYWORD_TYPE_NORMAL)
		ELSE = Keyword("else", KEYWORD_TYPE_FLOW)
		EXPORT = ModifierKeyword("export", MODIFIER_EXPORTED)
		HAS = Keyword("has", KEYWORD_TYPE_NORMAL)
		HAS_NOT = Keyword("has not", KEYWORD_TYPE_NORMAL)
		IF = Keyword("if", KEYWORD_TYPE_FLOW)
		IN = Keyword("in", KEYWORD_TYPE_NORMAL)
		INLINE = ModifierKeyword("inline", MODIFIER_INLINE)
		IS = Keyword("is", KEYWORD_TYPE_NORMAL)
		IS_NOT = Keyword("is not", KEYWORD_TYPE_NORMAL)
		INIT = Keyword("init", KEYWORD_TYPE_NORMAL)
		IMPORT = ModifierKeyword("import", MODIFIER_IMPORTED)
		LOOP = Keyword("loop", KEYWORD_TYPE_FLOW)
		NAMESPACE = Keyword("namespace", KEYWORD_TYPE_NORMAL)
		NOT = Keyword("not", KEYWORD_TYPE_NORMAL)
		OUTLINE = ModifierKeyword("outline", MODIFIER_OUTLINE)
		PACK = ModifierKeyword("pack", MODIFIER_PACK)
		PLAIN = ModifierKeyword("plain", MODIFIER_PLAIN)
		OVERRIDE = Keyword("override", KEYWORD_TYPE_NORMAL)
		PRIVATE = ModifierKeyword("private", MODIFIER_PRIVATE)
		PROTECTED = ModifierKeyword("protected", MODIFIER_PROTECTED)
		PUBLIC = ModifierKeyword("public", MODIFIER_PUBLIC)
		READONLY = ModifierKeyword("readonly", MODIFIER_READONLY)
		RETURN = Keyword("return", KEYWORD_TYPE_FLOW)
		STATIC = ModifierKeyword("static", MODIFIER_STATIC)
		STOP = Keyword("stop", KEYWORD_TYPE_FLOW)
		VIRTUAL = Keyword("virtual", KEYWORD_TYPE_NORMAL)
		WHEN = Keyword("when", KEYWORD_TYPE_FLOW)

		all = Map<String, Keyword>()

		add(AS)
		add(COMPILES)
		add(CONSTANT)
		add(CONTINUE)
		add(ELSE)
		add(EXPORT)
		add(HAS)
		add(HAS_NOT)
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
		add(OVERRIDE)
		add(PACK)
		add(PLAIN)
		add(PRIVATE)
		add(PROTECTED)
		add(PUBLIC)
		add(READONLY)
		add(RETURN)
		add(STATIC)
		add(STOP)
		add(VIRTUAL)
		add(WHEN)
	}

	exists(identifier: String) {
		return all.contains_key(identifier)
	}

	get(identifier: String) {
		return all[identifier]
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

	init(file: SourceFile, line: normal, character: normal) {
		this.file = file
		this.line = line
		this.character = character
		this.local = 0
		this.absolute = 0
	}

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
		return this
	}

	next_character() {
		character++
		local++
		absolute++
		return this
	}

	translate(characters: normal) {
		return Position(line, character + characters, local + characters, absolute + characters)
	}

	clone() {
		return Position(line, character, local, absolute)
	}

	equals(other: Position) {
		return absolute == other.absolute and file == other.file
	}

	string() {
		if file === none return "<unknown>" + ':' + to_string(friendly_line) + ':' + to_string(friendly_character)
		return file.fullname + ':' + to_string(friendly_line) + ':' + to_string(friendly_character)
	}
}

Token {
	readonly type: small
	position: Position

	init(type: small) {
		this.type = type
	}

	match(types: large) {
		return (this.type & types) != 0
	}

	string() {
		if type == TOKEN_TYPE_END return "\n"
		return String.empty
	}

	virtual clone() {
		token = Token(type)
		token.position = position
		return token
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
		return value
	}

	override clone() {
		return IdentifierToken(value, position)
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
		return operator.identifier
	}

	override clone() {
		return OperatorToken(operator, position)
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
		this.position = position
	}

	string() {
		return keyword.identifier
	}

	override clone() {
		return KeywordToken(keyword, position)
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

	decimal_value() {
		return bits_to_decimal(data)
	}

	string() {
		if format == FORMAT_DECIMAL return to_string(decimal_value())
		return to_string(data)
	}

	override clone() {
		return NumberToken(data, format, position, end)
	}
}

Token StringToken {
	text: String
	opening: char
	end => position.translate(text.length + 2)

	init(text: String) {
		Token.init(TOKEN_TYPE_STRING)
		this.text = text.slice(1, text.length - 1)
		this.opening = text[0]
	}

	init(text: String, opening: char, position: Position) {
		Token.init(TOKEN_TYPE_STRING)
		this.text = text
		this.position = position
		this.opening = opening
	}

	string() {
		return String(opening) + text + opening
	}

	override clone() {
		return StringToken(text, opening, position)
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

	init(tokens: List<Token>) {
		Token.init(TOKEN_TYPE_PARENTHESIS)
		this.opening = `(`
		this.tokens = List<Token>(tokens)
	}

	get_sections() {
		sections = List<List<Token>>()
		if tokens.size == 0 return sections

		section = List<Token>()

		loop token in tokens {
			if token.match(Operators.COMMA) {
				sections.add(section)
				section = List<Token>()
				continue
			}

			section.add(token)
		}

		sections.add(section)
		return sections
	}

	string() {
		values = List<String>(tokens.size, false)
		loop token in tokens { values.add(to_string(token)) }

		return String(opening) + String.join(` `, values) + String(get_closing(opening))
	}

	override clone() {
		clone = List<Token>(tokens.size, true)

		loop (i = 0, i < tokens.size, i++) {
			clone[i] = tokens[i].clone()
		}

		return ParenthesisToken(opening, position, end, clone)
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
		tokens.add_all(parameters.tokens)

		result = List<Parameter>()

		loop (tokens.size > 0) {
			# Ensure the name is valid
			name = tokens.pop_or(none as Token)
			if name == none or not name.match(TOKEN_TYPE_IDENTIFIER) {
				return Error<List<Parameter>, String>("Can not understand the parameters")
			}
			
			next = tokens.pop_or(none as Token)
			
			if next == none or next.match(Operators.COMMA) {
				result.add(Parameter(name.(IdentifierToken).value, name.position, none as Type))
				continue
			}

			# If there are tokens left and the next token is not a comma, it must represent a parameter type
			if not next.match(Operators.COLON) {
				return Error<List<Parameter>, String>("Can not understand the parameters")
			}

			parameter_type = common.read_type(context, tokens)

			if parameter_type == none {
				return Error<List<Parameter>, String>("Can not understand the parameter type")
			}

			result.add(Parameter(name.(IdentifierToken).value, name.position, parameter_type))

			# If there are tokens left, the next token must be a comma and it must be removed before starting over
			if tokens.size > 0 and not tokens.pop_or(none as Token).match(Operators.COMMA) {
				return Error<List<Parameter>, String>("Can not understand the parameters")
			}
		}

		loop parameter in result {
			context.declare(parameter.type, VARIABLE_CATEGORY_PARAMETER, parameter.name).position = parameter.position
		}

		return Ok<List<Parameter>, String>(result)
	}

	parse(context: Context) {
		if node != none and node.first != none return node

		result = parser.parse(context, List<Token>(parameters.tokens), parser.MIN_PRIORITY, parser.MAX_FUNCTION_BODY_PRIORITY)

		if result.first != none and result.first.match(NODE_LIST) { node = result.first }
		else { node = result }

		return node
	}
	
	string() {
		return name + parameters.string()
	}

	override clone() {
		return FunctionToken(identifier.clone() as IdentifierToken, parameters.clone() as ParenthesisToken, position)
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
	if token.type == TOKEN_TYPE_IDENTIFIER return token.(IdentifierToken).string()
	else token.type == TOKEN_TYPE_NUMBER return token.(NumberToken).string()
	else token.type == TOKEN_TYPE_PARENTHESIS return token.(ParenthesisToken).string()
	else token.type == TOKEN_TYPE_KEYWORD return token.(KeywordToken).string()
	else token.type == TOKEN_TYPE_OPERATOR return token.(OperatorToken).string()
	else token.type == TOKEN_TYPE_FUNCTION return token.(FunctionToken).string()
	else token.type == TOKEN_TYPE_STRING return token.(StringToken).string()
	return token.string()
}

# Summary: Returns a string, which represents the specified tokens
to_string(tokens: List<Token>) {
	values = List<String>(tokens.size, false)
	loop token in tokens { values.add(to_string(token)) }
	return String.join(` `, values)
}

# Summary: Returns whether the format is an unsigned format
is_unsigned(format: large) {
	return (format & 1) != 0
}

# Summary: Returns whether the format is an unsigned format
is_signed(format: large) {
	return (format & 1) == 0
}

to_format(bytes: large) {
	return (bytes <| 1) | 1
}

to_format(bytes: large, unsigned: bool) {
	return (bytes <| 1) | unsigned
}

to_bytes(format: large) {
	return (format |> 1) & FORMAT_SIZE_MASK
}

to_bits(format: large) {
	return ((format |> 1) & FORMAT_SIZE_MASK) * 8
}

# Summary: Returns whether the specified flags contains the specified flag
has_flag(flags: large, flag: large) {
	return (flags & flag) == flag
}

# Summary: Removes the exponent or the number type from the specified string
private get_number_part(text: String) {
	i = 0
	loop (i < text.length and (is_digit(text[i]) or text[i] == DECIMAL_SEPARATOR), i++) {}
	return text.slice(0, i)
}

# Summary: Returns the value of the exponent which is contained in the specified number string
private get_exponent(text: String) {
	i = text.index_of(EXPONENT_SEPARATOR)
	if i == -1 return Ok<large, String>(0)

	if text.length == ++i return Error<large, String>("Invalid exponent")

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
	if as_integer(exponent) has result return Ok<large, String>(sign * result)

	return Error<large, String>("Invalid exponent")
}

# Summary: Returns the format which has the same properties as specified
private get_format(bits: large, unsigned: bool) {
	# TODO: Compute this instead
	format = when(bits) {
		8 => FORMAT_INT8,
		16 => FORMAT_INT16,
		32 => FORMAT_INT32,
		64 => FORMAT_INT64,
		128 => FORMAT_INT128,
		256 => FORMAT_INT256,
		else => FORMAT_INT64
	}

	if unsigned return format | 1
	return format
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
		else return FORMAT_INT64
	}

	# Take all the digits, which represent the bit size
	j = ++i
	loop (j < text.length and is_digit(text[j++])) {}

	# If digits were captured and the number can be parsed, return a format, which matches it
	if j > i and as_integer(text.slice(i, j)) has bits return get_format(bits, unsigned)

	# Return the default format
	return get_format(SYSTEM_BITS, unsigned)
}

# Summary: Tries to convert the specified string to a number token
try_create_number_token(text: String, position: Position) {
	if get_exponent(text) has not exponent return Error<NumberToken, String>("Invalid exponent")

	if text.index_of(DECIMAL_SEPARATOR) != -1 {
		if as_decimal(get_number_part(text)) has not value return Error<NumberToken, String>("Can not resolve the number")

		# Apply the exponent
		scale = 1.0
		loop (i = 0, i < abs(exponent), i++) { scale *= 10 }

		if exponent >= 0 { value *= scale }
		else { value /= scale }

		return Ok<NumberToken, String>(NumberToken(value, FORMAT_DECIMAL, text.length, position))
	}
	else {
		if as_integer(get_number_part(text)) has not value return Error<NumberToken, String>("Can not resolve the number")

		# Apply the exponent
		scale = 1
		loop (i = 0, i < abs(exponent), i++) { scale *= 10 }

		if exponent >= 0 { value *= scale }
		else { value /= scale }

		# Determine the number format
		format = get_number_format(text)
		
		return Ok<NumberToken, String>(NumberToken(value, format, text.length, position))
	}
}

# Summary: Returns the closing parenthesis of the specified opening parenthesis
get_closing(opening: char) {
	if opening == `(` return `)`
	return opening + 2
}

# Returns whether the specified character is an operator
is_operator(i: char) {
	return (i >= `*` and i <= `/`) or (i >= `:` and i <= `?`) or i == `&` or i == `%` or i == `!` or i == `^` or i == `|` or i == -92 # 0xA4 = 164 => -92 as char
}

# Summary:
# Returns all the characters which can mix with the specified character.
# If this function returns null, it means the specified character can mix with any character.
get_mixing_characters(i: char) {
	return when(i) {
		`.` => '.0123456789',
		`,` => '',
		`<` => '|=',
		`>` => '|=-:',
		else => none as link
	}
}

# Summary: Returns whether the two specified characters can mix
mixes(a: char, b: char) {
	allowed = get_mixing_characters(a)
	if allowed != none return index_of(allowed, b) != -1

	allowed = get_mixing_characters(b)
	if allowed != none return index_of(allowed, a) != -1

	return true
}

# Summary: Returns whether the characters represent a start of a hexadecimal number
is_start_of_hexadecimal(current: char, next: char) {
	return current == `0` and next == `x`
}

# Summary: Returns whether the character is a text
is_text(i: char) {
	return (i >= `a` and i <= `z`) or (i >= `A` and i <= `Z`) or (i == `_`)
}

# Summary: Returns whether the character is start of a parenthesis
is_parenthesis(i: char) {
	return i == `(` or i == `[` or i == `{`
}

# Summary: Returns whether the character is start of a comment
is_comment(i: char) {
	return i == COMMENT
}

# Summary: Returns whether the character start of a string
is_string(i: char) {
	return i == STRING or i == STRING_OBJECT
}

# Summary: Returns whether the character start of a character value
is_character_value(i: char) {
	return i == CHARACTER
}

# Summary: Returns the type of the specified character
get_text_type(current: char, next: char) {
	if is_text(current) return TEXT_TYPE_TEXT
	if is_start_of_hexadecimal(current, next) return TEXT_TYPE_HEXADECIMAL
	if is_digit(current) return TEXT_TYPE_NUMBER
	if is_parenthesis(current) return TEXT_TYPE_PARENTHESIS
	if is_operator(current) return TEXT_TYPE_OPERATOR
	if is_comment(current) return TEXT_TYPE_COMMENT
	if is_string(current) return TEXT_TYPE_STRING
	if is_character_value(current) return TEXT_TYPE_CHARACTER
	if current == LINE_ENDING return TEXT_TYPE_END
	return TEXT_TYPE_UNSPECIFIED
}

# Summary: Returns whether the character is part of the progressing token
is_part_of(previous_type: large, current_type: large, previous: char, current: char, next: char) {
	if not mixes(previous, current) return false

	if current_type == previous_type or previous_type == TEXT_TYPE_UNSPECIFIED return true

	if previous_type == TEXT_TYPE_TEXT return current_type == TEXT_TYPE_NUMBER or current_type == TEXT_TYPE_HEXADECIMAL

	if previous_type == TEXT_TYPE_HEXADECIMAL return current_type == TEXT_TYPE_NUMBER or
		(previous == `0` and current == `x`) or
		(current >= `a` and current <= `f`) or (current >= `A` and current <= `F`)

	if previous_type == TEXT_TYPE_NUMBER return (current == DECIMAL_SEPARATOR and is_digit(next)) or
		current == EXPONENT_SEPARATOR or
		current == SIGNED_TYPE_SEPARATOR or
		current == UNSIGNED_TYPE_SEPARATOR or
		(previous == EXPONENT_SEPARATOR and (current == `+` or current == `-`))
	
	return false
}

# Summary: Skips all the spaces starting from the specified position
skip_spaces(text: String, position: Position) {
	loop (position.local < text.length) {
		if text[position.local] != ` ` stop
		position.next_character()
	}

	return position
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
		else i == COMMENT {
			position = skip_comment(text, position)
		}
		else i == STRING {
			position = skip_closures(STRING, text, position)
		}
		else i == STRING_OBJECT {
			position = skip_closures(STRING_OBJECT, text, position)
		}
		else i == CHARACTER {
			position = skip_character_value(text, position)
		}
		else {
			if i == opening { count++ }
			else i == closing { count-- }

			position.next_character()
		}

		if count == 0 return position
	}

	return none as Position
}

# Summary: Returns whether a multiline comment begins at the specified position
is_multiline_comment(text: String, start: Position) {
	return start.local + MULTILINE_COMMENT_LENGTH * 2 <= text.length and text.slice(start.local, start.local + MULTILINE_COMMENT_LENGTH) == MULTILINE_COMMENT and text[start.local + MULTILINE_COMMENT_LENGTH] != COMMENT
}

# Summary: Skips the current comment and returns the position
skip_comment(text: String, start: Position) {
	if is_multiline_comment(text, start) {
		end = text.index_of(MULTILINE_COMMENT, start.local + MULTILINE_COMMENT_LENGTH)
		if end == -1 abort('Multiline comment does not have a closing')

		# Skip to the end of the multiline comment
		end += MULTILINE_COMMENT_LENGTH

		# Count how many line endings there are in the multiline comment
		comment = text.slice(start.local, end)
		lines = 0

		loop (i = 0, i < comment.length, i++) {
			if comment[i] == `\n` lines++
		}

		# Determine the index of the last line ending inside the multiline comment
		last_line_ending = comment.last_index_of(`\n`)

		# If the 'multiline comment' is actually expressed in a single line, handle it separately
		if last_line_ending == -1 return Position(start.line + lines, start.character + comment.length, end, start.absolute + comment.length)

		last_line_ending += start.local # The index must be relative to the whole text
		last_line_ending++ # Skip the line ending
		return Position(start.line + lines, end - last_line_ending, end, start.absolute + comment.length)
	}

	i = text.index_of(LINE_ENDING, start.local)

	if i != -1 {
		length = i - start.local
		return Position(start.line, start.character + length, start.local + length, start.absolute + length)
	}
	else {
		length = text.length - start.local
		return Position(start.line, start.character + length, start.local + length, start.absolute + length)
	}
}

# Summary: Skips closures which has the same character in both ends
skip_closures(closure: char, text: String, start: Position) {
	i = text.index_of(closure, start.local + 1)
	j = text.index_of(LINE_ENDING, start.local + 1)

	if i == -1 or j != -1 and j < i return none as Position

	length = i + 1 - start.local
	return Position(start.line, start.character + length, start.local + length, start.absolute + length)
}

# Summary: Skips the current character value and returns the position
skip_character_value(text: String, start: Position) {
	return skip_closures(CHARACTER, text, start)
}

# Summary: Converts the specified hexadecimal string into an integer value
hexadecimal_to_integer(text: String) {
	result = 0

	loop (i = 0, i < text.length, i++) {
		digit = text[i]
		value = 0

		if digit >= `0` and digit <= `9` { value = digit - `0` }
		else digit >= `A` and digit <= `F` { value = digit - `A` + 10 }
		else digit >= `a` and digit <= `f` { value = digit - `a` + 10 }
		else return Optional<large>()

		result = result * 16 + value
	}

	return Optional<large>(result)
}

# Summary: Returns a list of tokens which represents the specified text
get_special_character_value(text: String) {
	command = text[1]
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
		return Error<large, String>("Can not understand string command")
	}

	hexadecimal = text.slice(2, text.length)
	
	if hexadecimal.length != length {
		return Error<large, String>("Invalid character")
	}

	if hexadecimal_to_integer(hexadecimal) has value return Ok<large, String>(value)

	return Error<large, String>(String(error))
}

# Summary: Returns the integer value of the character value
get_character_value(text: String) {
	text = text.slice(1, text.length - 1) # Remove the closures

	if text.length == 0 return Error<large, String>("Character value is empty")

	if text[0] != `\\` {
		if text.length != 1 return Error<large, String>("Character value allows only one character")
		return Ok<large, String>(text[0])
	}

	if text.length == 2 and text[1] == `\\` return Ok<large, String>(`\\`)
	if text.length <= 2 {
		return Error<large, String>("Invalid character")
	}

	return get_special_character_value(text)
}

get_next_token(text: String, start: Position) {
	# Firstly the spaces must be skipped to find the next token
	position = skip_spaces(text, start)

	# Verify there is text to iterate
	if position.local == text.length return Ok<TextArea, String>(none as TextArea)

	current = text[position.local]
	next = 0 as char
	if position.local + 1 < text.length { next = text[position.local + 1] }

	type = get_text_type(current, next)
	area = TextArea(position.clone(), type)

	if type == TEXT_TYPE_COMMENT {
		area.end = skip_comment(text, area.start)
		area.text = text.slice(area.start.local, area.end.local)
		return Ok<TextArea, String>(area)
	}
	else type == TEXT_TYPE_PARENTHESIS {
		end = skip_parenthesis(text, area.start)
		if end === none return Error<TextArea, String>("Can not find the closing parenthesis")

		area.end = end
		area.text = text.slice(area.start.local, area.end.local)
		return Ok<TextArea, String>(area)
	}
	else type == TEXT_TYPE_END {
		area.end = position.clone().next_line()
		area.text = "\n"
		return Ok<TextArea, String>(area)
	}
	else type == TEXT_TYPE_STRING {
		end = skip_closures(current, text, area.start)
		if end === none {
			return Error<TextArea, String>("Can not find the end of the string")
		}

		area.end = end
		area.text = text.slice(area.start.local, area.end.local)
		return Ok<TextArea, String>(area)
	}
	else type == TEXT_TYPE_CHARACTER {
		area.end = skip_character_value(text, area.start)

		result = get_character_value(text.slice(area.start.local, area.end.local))
		if result has not value return Error<TextArea, String>(result.get_error())

		bits = common.get_bits(value, false)

		area.text = to_string(result.get_value()) + SIGNED_TYPE_SEPARATOR + to_string(bits)
		area.type = TEXT_TYPE_NUMBER
		return Ok<TextArea, String>(area)
	}

	position.next_character()

	# Possible types are now: TEXT, NUMBER, OPERATOR
	loop (position.local < text.length) {
		previous = current
		current = next

		if position.local + 1 < text.length { next = text[position.local + 1] }
		else { next = 0 as char }

		# Determine what text type the current character represents
		type = get_text_type(current, next)

		if not is_part_of(area.type, type, previous, current, next) stop

		position.next_character()
	}

	area.end = position
	area.text = text.slice(area.start.local, area.end.local)
	return Ok<TextArea, String>(area)
}

# Summary: Parses a token from the specified text
parse_text_token(text: String) {
	if Operators.exists(text) return OperatorToken(text)
	if Keywords.exists(text) return KeywordToken(text)
	return IdentifierToken(text)
}

# Summary: Parses the specified hexadecimal text to an integer
parse_hexadecimal(area: TextArea) {
	# Extract the integer value from the hexadecimal by skipping the 0x prefix
	if hexadecimal_to_integer(area.text.slice(2)) has value return Ok<large, String>(value)
	return Error<large, String>("Can not understand the hexadecimal " + area.text)
}

# Summary: Parses a token from a text area
parse_token(area: TextArea) {
	if area.type == TEXT_TYPE_OPERATOR {
		if not Operators.exists(area.text) return Error<Token, String>("Unknown operator")
		return Ok<Token, String>(OperatorToken(area.text))
	}
	else area.type == TEXT_TYPE_NUMBER {
		result = try_create_number_token(area.text, area.start)
		if result has not number return Error<Token, String>(result.get_error())
		return Ok<Token, String>(number)
	}
	else area.type == TEXT_TYPE_PARENTHESIS {
		text = area.text
		if text.length == 2 return Ok<Token, String>(ParenthesisToken(text[0], area.start, area.end, List<Token>()))

		result: Outcome<List<Token>, String> = get_tokens(text.slice(1, text.length - 1), area.start.clone().next_character(), true)
		if result has not tokens return Error<Token, String>(result.get_error())

		return Ok<Token, String>(ParenthesisToken(text[0], area.start, area.end, tokens))
	}

	token = none as Token

	if area.type == TEXT_TYPE_TEXT { token = parse_text_token(area.text) }
	else area.type == TEXT_TYPE_END { token = Token(TOKEN_TYPE_END) }
	else area.type == TEXT_TYPE_STRING { token = StringToken(area.text) }
	else area.type == TEXT_TYPE_HEXADECIMAL {
		result = parse_hexadecimal(area)
		if result has not value return Error<Token, String>(result.get_error())

		token = NumberToken(value, SYSTEM_FORMAT, area.start, area.end)
	}
	
	if token != none return Ok<Token, String>(token)
	return Error<Token, String>("Unknown token " + area.text)
}

# Summary: Join all sequential modifier keywords into one token
join_sequential_modifiers(tokens: List<Token>) {
	loop (i = tokens.size - 2, i >= 0, i--) {
		# Require both the current and the next tokens to be modifier keywords
		a = tokens[i]
		b = tokens[i + 1]

		if a.type != TOKEN_TYPE_KEYWORD or b.type != TOKEN_TYPE_KEYWORD continue

		x = a.(KeywordToken).keyword
		y = b.(KeywordToken).keyword

		if x.type != KEYWORD_TYPE_MODIFIER or y.type != KEYWORD_TYPE_MODIFIER continue

		# Combine the two modifiers into one token, and remove the second token
		modifiers = x.(ModifierKeyword).modifier | y.(ModifierKeyword).modifier
		a.(KeywordToken).keyword = ModifierKeyword(String.empty, modifiers)
		tokens.remove_at(i + 1)
	}
}

# Summary: Finds not-keywords and negates adjacent keywords when possible
negate_keywords(tokens: List<Token>) {
	loop (i = tokens.size - 2, i >= 0, i--) {
		# Require the current token to be a keyword
		token = tokens[i]
		if token.type != TOKEN_TYPE_KEYWORD continue

		# Require the next token to be a not-keyword
		if not tokens[i + 1].match(Keywords.NOT) continue

		negated = when(token.(KeywordToken).keyword) {
			Keywords.IS => Keywords.IS_NOT,
			Keywords.HAS => Keywords.HAS_NOT,
			else => none as Keyword
		}

		if negated !== none {
			token.(KeywordToken).keyword = negated
			tokens.remove_at(i + 1)
		}
	}
}

# Summary: Postprocesses the specified tokens
postprocess(tokens: List<Token>) {
	join_sequential_modifiers(tokens)
	negate_keywords(tokens)
}

# Summary: Preprocesses the specified text, meaning that a more suitable version of the text is returned for tokenization
preprocess(text: String) {
	builder = StringBuilder()
	builder.append(text)
	builder.replace('\xC2\xA4', '\xA4') # Simplify U+00A4 (currency sign), so that XOR operations are supported

	# Converts all special characters in the text to use the hexadecimal character format:
	# Start from the second last character and look for special characters
	loop (i = builder.length - 2, i >= 0, i--) {
		# Special characters start with '\\'
		if builder[i] != `\\` continue

		# Skip occurrences where there are two sequential '\\' characters
		# Example: '\\\\n' = \n != '\\\x0A'
		if i - 1 >= 0 and builder[i - 1] == `\\` continue

		value = when(builder[i + 1]) {
			`a` => '\\x07'
			`b` => '\\x08'
			`f` => '\\x0C'
			`n` => '\\x0A'
			`r` => '\\x0D'
			`t` => '\\x09'
			`v` => '\\x0B'
			`e` => '\\x1B'
			`\"` => '\\x22'
			`\'` => '\\x27'
			else => none as link
		}

		if value == none continue

		builder.remove(i, i + 2)
		builder.insert(i, value)
	}

	return builder.string()
}

# Summary: Returns a list of tokens which represents the specified text
get_tokens(text: String, postprocess: bool) {
	return get_tokens(text, Position(), postprocess)
}

# Summary: Returns a list of tokens which represents the specified text
get_tokens(text: String, anchor: Position, postprocess: bool) {
	tokens = List<Token>(text.length / 5, false) # Guess the amount of tokens and preallocate memory for the tokens
	position = Position(anchor.line, anchor.character, 0, anchor.absolute)

	text = preprocess(text)

	loop (position.local < text.length) {
		area_result = get_next_token(text, position.clone())
		if area_result has not area return Error<List<Token>, String>(area_result.get_error())
		if area == none stop

		if area.type != TEXT_TYPE_COMMENT {
			token_result = parse_token(area)
			if token_result has not token return Error<List<Token>, String>(token_result.get_error())

			token.position = area.start
			tokens.add(token)
		}

		position = area.end
	}

	if postprocess postprocess(tokens)

	return Ok<List<Token>, String>(tokens)
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
tokenize() {
	files = settings.source_files

	loop (i = 0, i < files.size, i++) {
		file = files[i]

		result = get_tokens(file.content, true)
		if result has not tokens return Status(result.get_error())

		register_file(tokens, file)
		file.tokens = tokens
	}

	return Status()
}

# Summary: Creates an identical list of tokens compared to the specified list
clone(tokens: List<Token>) {
	clone = List<Token>(tokens.size, true)

	loop (i = 0, i < tokens.size, i++) {
		clone[i] = tokens[i].clone()
	}

	return clone
}