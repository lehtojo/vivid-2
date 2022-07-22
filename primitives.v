Type Number {
	bits: normal
	bytes => bits / 8
	unsigned => is_unsigned(format)

	init(format: large, bits: normal, name: String) {
		Type.init(name, MODIFIER_DEFAULT | MODIFIER_PRIMITIVE | MODIFIER_NUMBER, 0)
		this.reference_size = bits / 8
		this.format = format
		this.bits = bits
	}

	override match(other: Type) {
		return other.is_number and other.is_primitive and this.identifier == other.(Number).identifier and this.bytes == other.(Number).bytes and this.format == other.(Number).format
	}
}

Number Link {
	# Summary: Creates a link type which has the specified offset type
	static get_variant(argument: Type) {
		link = Link(argument)
		return link
	}

	# Summary: Creates a link type which has the specified offset type and the specified name
	static get_variant(argument: Type, name: String) {
		link = Link(argument)
		link.name = name
		return link
	}

	init(accessor_type: Type) {
		Number.init(SYSTEM_FORMAT, SYSTEM_BITS, "link")
		this.template_arguments = List<Type>(1, true)
		this.template_arguments[] = accessor_type
		this.identifier = String(primitives.LINK_IDENTIFIER)
		this.modifiers |= MODIFIER_TEMPLATE_TYPE
	}

	init() {
		Number.init(SYSTEM_FORMAT, SYSTEM_BITS, "link")
		this.template_arguments = List<Type>(0, false)
		this.identifier = String(primitives.LINK_IDENTIFIER)
		this.modifiers |= MODIFIER_TEMPLATE_TYPE
	}

	override match(other: Type) {
		return this.name == other.name and this.identifier == other.identifier and get_accessor_type().match(other.(Link).get_accessor_type())
	}

	override clone() {
		return get_variant(get_accessor_type(), name)
	}

	override get_accessor_type() {
		if template_arguments.size > 0 return template_arguments[]
		return primitives.create_number(primitives.U8, FORMAT_UINT8)
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

	create_number(primitive: link, format: large) {
		return create_number(String(primitive), format)
	}

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
			else => number.name.data
		})

		return number
	}

	# Summary:
	# Creates a primitive number which matches the specified settings
	create_number(bits: large, signed: bool, is_decimal: bool) {
		number = none as Number

		if is_decimal {
			number = Number(FORMAT_DECIMAL, 64, String(DECIMAL))
		}
		else signed {
			number = when(bits) {
				8 => Number(FORMAT_INT8, 8, String(TINY)),
				16 => Number(FORMAT_INT16, 16, String(SMALL)),
				32 => Number(FORMAT_INT32, 32, String(NORMAL)),
				64 => Number(FORMAT_INT64, 64, String(LARGE)),
				else => Number(FORMAT_INT64, 64, String(LARGE))
			}
		}
		else {
			number = when(bits) {
				8 => Number(FORMAT_UINT8, 8, String(U8)),
				16 => Number(FORMAT_UINT16, 16, String(U16)),
				32 => Number(FORMAT_UINT32, 32, String(U32)),
				64 => Number(FORMAT_UINT64, 64, String(U64)),
				else => Number(FORMAT_UINT64, 64, String(U64))
			}
		}

		number.identifier = String(when(number.name) {
			DECIMAL => DECIMAL_IDENTIFIER,
			LARGE => LARGE_IDENTIFIER,
			NORMAL => NORMAL_IDENTIFIER,
			SMALL => SMALL_IDENTIFIER,
			TINY => TINY_IDENTIFIER,
			U64 => U64_IDENTIFIER,
			U32 => U32_IDENTIFIER,
			U16 => U16_IDENTIFIER,
			U8 => U8_IDENTIFIER,
			else => number.name.data
		})

		return number
	}

	create_unit() {
		return Type(String(UNIT), MODIFIER_PRIMITIVE)
	}

	create_bool() {
		return create_number(BOOL, FORMAT_UINT8)
	}

	# Summary: Returns whether the specified type is primitive type and whether its name matches the specified name
	is_primitive(type: Type, expected: String) {
		return type != none and type.is_primitive and type.name == expected
	}

	# Summary: Returns whether the specified type is primitive type and whether its name matches the specified name
	is_primitive(type: Type, expected: link) {
		return type != none and type.is_primitive and type.name == expected
	}

	inject(context: Context) {
		signed_integer_8 = create_number(TINY, FORMAT_INT8)
		signed_integer_16 = create_number(SMALL, FORMAT_INT16)
		signed_integer_32 = create_number(NORMAL, FORMAT_INT32)
		signed_integer_64 = create_number(LARGE, FORMAT_INT64)

		unsigned_integer_8 = create_number(U8, FORMAT_UINT8)
		unsigned_integer_16 = create_number(U16, FORMAT_UINT16)
		unsigned_integer_32 = create_number(U32, FORMAT_UINT32)
		unsigned_integer_64 = create_number(U64, FORMAT_UINT64)

		context.declare(create_unit())
		context.declare(create_bool())
		context.declare(Link())

		context.declare(signed_integer_8)
		context.declare(signed_integer_16)
		context.declare(signed_integer_32)
		context.declare(signed_integer_64)
		context.declare_type_alias(String(I8), signed_integer_8)
		context.declare_type_alias(String(I16), signed_integer_16)
		context.declare_type_alias(String(I32), signed_integer_32)
		context.declare_type_alias(String(I64), signed_integer_64)

		context.declare(unsigned_integer_8)
		context.declare(unsigned_integer_16)
		context.declare(unsigned_integer_32)
		context.declare(unsigned_integer_64)
		context.declare_type_alias(String(CHAR), signed_integer_8)
		context.declare_type_alias(String(BYTE), unsigned_integer_8)

		context.declare(create_number(DECIMAL, FORMAT_DECIMAL))

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
		return when(format) {
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