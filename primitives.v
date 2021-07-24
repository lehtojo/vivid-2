Type Number {
	bits: normal
	bytes => bits / 8
	unsigned => is_unsigned(format)

	init(format: large, bits: normal, name: String) {
		Type.init(name, MODIFIER_DEFAULT | MODIFIER_PRIMITIVE | MODIFIER_NUMBER)
		this.reference_size = bits / 8
		this.format = format
		this.bits = bits
	}

	override match(other: Type) {
		=> other.is_number and other.is_primitive and this.identifier == other.(Number).identifier and this.bytes == other.(Number).bytes and this.format == other.(Number).format
	}
}

Number Link {
	# Summary: Creates a link type which has the specified offset type
	static get_variant(argument: Type) {
		link = Link(argument)
		=> link
	}

	# Summary: Creates a link type which has the specified offset type and the specified name
	static get_variant(argument: Type, name: String) {
		link = Link(argument)
		link.name = name
		=> link
	}

	init(accessor_type: Type) {
		Number.init(SYSTEM_FORMAT, SYSTEM_BITS, String('link'))
		this.template_arguments = List<Type>(1, true)
		this.template_arguments[0] = accessor_type
		this.identifier = String(primitives.LINK_IDENTIFIER)
		this.modifiers |= MODIFIER_TEMPLATE_TYPE
	}

	init() {
		Number.init(SYSTEM_FORMAT, SYSTEM_BITS, String('link'))
		this.template_arguments = List<Type>(0, false)
		this.identifier = String(primitives.LINK_IDENTIFIER)
		this.modifiers |= MODIFIER_TEMPLATE_TYPE
	}

	override match(other: Type) {
		=> this.name == other.name and this.identifier == other.identifier and get_accessor_type().match(other.(Link).get_accessor_type())
	}

	override clone() {
		=> get_variant(get_accessor_type(), name)
	}

	override get_accessor_type() {
		if template_arguments.size > 0 => template_arguments[0]
		=> primitives.create_number(primitives.U8, FORMAT_UINT8)
	}
}

namespace primitives {
	constant UNIT = '_'
	constant LINK = 'link'
	constant BOOL = 'bool'
	constant DECIMAL = 'decimal'
	constant LARGE = 'large'
	constant NORMAL = 'normal'
	constant SMALL = 'small'
	constant TINY = 'tiny'
	constant I64 = 'i64'
	constant I32 = 'i32'
	constant I16 = 'i16'
	constant I8 = 'i8'
	constant U64 = 'u64'
	constant U32 = 'u32'
	constant U16 = 'u16'
	constant U8 = 'u8'
	constant L64 = 'l64'
	constant L32 = 'l32'
	constant L16 = 'l16'
	constant L8 = 'l8'
	constant CHAR = 'char'
	constant BYTE = 'byte'

	constant LINK_IDENTIFIER = 'Ph'
	constant BOOL_IDENTIFIER = 'b'
	constant DECIMAL_IDENTIFIER = 'd'
	constant LARGE_IDENTIFIER = 'x'
	constant NORMAL_IDENTIFIER = 'i'
	constant SMALL_IDENTIFIER = 's'
	constant TINY_IDENTIFIER = 'c'
	constant I64_IDENTIFIER = 'x'
	constant I32_IDENTIFIER = 'i'
	constant I16_IDENTIFIER = 's'
	constant I8_IDENTIFIER = 'c'
	constant U64_IDENTIFIER = 'y'
	constant U32_IDENTIFIER = 'j'
	constant U16_IDENTIFIER = 't'
	constant U8_IDENTIFIER = 'h'
	constant BYTE_IDENTIFIER = 'h'
	constant CHAR_IDENTIFIER = 'c'

	create_number(primitive: link, format: large) => create_number(String(primitive), format)

	create_number(primitive: String, format: large) {
		number = Number(format, to_bits(format), primitive)
		number.identifier = String(when(primitive) {
			LINK => LINK_IDENTIFIER
			BOOL => BOOL_IDENTIFIER
			DECIMAL => DECIMAL_IDENTIFIER
			LARGE => LARGE_IDENTIFIER
			NORMAL => NORMAL_IDENTIFIER
			SMALL => SMALL_IDENTIFIER
			TINY => TINY_IDENTIFIER
			I64 => I64_IDENTIFIER
			I32 => I32_IDENTIFIER
			I16 => I16_IDENTIFIER
			I8 => I8_IDENTIFIER
			U64 => U64_IDENTIFIER
			U32 => U32_IDENTIFIER
			U16 => U16_IDENTIFIER
			U8 => U8_IDENTIFIER
			BYTE => BYTE_IDENTIFIER
			CHAR => CHAR_IDENTIFIER
			else => number.name.text
		})

		=> number
	}

	create_unit() {
		=> Type(String(UNIT), MODIFIER_PRIMITIVE)
	}

	create_bool() {
		=> create_number(BOOL, FORMAT_UINT8)
	}

	# Summary: Returns whether the specified type is primitive type and whether its name matches the specified name
	is_primitive(type: Type, expected: String) {
		=> type != none and type.is_primitive and type.name == expected
	}

	# Summary: Returns whether the specified type is primitive type and whether its name matches the specified name
	is_primitive(type: Type, expected: link) {
		=> type != none and type.is_primitive and type.name == expected
	}

	inject(context: Context) {
		context.declare(create_unit())
		context.declare(create_bool())
		context.declare(Link())
		context.declare(create_number(CHAR, FORMAT_INT8))
		context.declare(create_number(TINY, FORMAT_INT8))
		context.declare(create_number(SMALL, FORMAT_INT16))
		context.declare(create_number(NORMAL, FORMAT_INT32))
		context.declare(create_number(LARGE, FORMAT_INT64))
		context.declare(create_number(I8, FORMAT_INT8))
		context.declare(create_number(I16, FORMAT_INT16))
		context.declare(create_number(I32, FORMAT_INT32))
		context.declare(create_number(I64, FORMAT_INT64))
		context.declare(create_number(U8, FORMAT_UINT8))
		context.declare(create_number(U16, FORMAT_UINT16))
		context.declare(create_number(U32, FORMAT_UINT32))
		context.declare(create_number(U64, FORMAT_UINT64))
		context.declare(create_number(DECIMAL, FORMAT_DECIMAL))
		context.declare(create_number(BYTE, FORMAT_UINT8))
		context.declare(Link.get_variant(create_number(U8, FORMAT_UINT8), String(L8)))
		context.declare(Link.get_variant(create_number(U16, FORMAT_UINT16), String(L16)))
		context.declare(Link.get_variant(create_number(U32, FORMAT_UINT32), String(L32)))
		context.declare(Link.get_variant(create_number(U64, FORMAT_UINT64), String(L64)))
	}
}

namespace numbers {
	private INT8: Number
	private INT16: Number
	private INT32: Number
	private INT64: Number
	private UINT8: Number
	private UINT16: Number
	private UINT32: Number
	private UINT64: Number
	private DECIMAL: Number

	initialize() {
		INT8 = primitives.create_number(primitives.TINY, FORMAT_INT8)
		INT16 = primitives.create_number(primitives.SMALL, FORMAT_INT16)
		INT32 = primitives.create_number(primitives.NORMAL, FORMAT_INT32)
		INT64 = primitives.create_number(primitives.LARGE, FORMAT_INT64)
		UINT8 = primitives.create_number(primitives.U8, FORMAT_UINT8)
		UINT16 = primitives.create_number(primitives.U16, FORMAT_UINT16)
		UINT32 = primitives.create_number(primitives.U32, FORMAT_UINT32)
		UINT64 = primitives.create_number(primitives.U64, FORMAT_UINT64)
		DECIMAL = primitives.create_number(primitives.DECIMAL, FORMAT_DECIMAL)
	}

	get(format: large) {
		=> when(format) {
			FORMAT_INT8 => INT8
			FORMAT_INT16 => INT16
			FORMAT_INT32 => INT32
			FORMAT_INT64 => INT64
			FORMAT_UINT8 => UINT8
			FORMAT_UINT16 => UINT16
			FORMAT_UINT32 => UINT32
			FORMAT_UINT64 => UINT64
			FORMAT_DECIMAL => DECIMAL
			else => UINT64
		}
	}
}