# Order: From most expensive to least expensive
HANDLE_MEMORY = 1
HANDLE_MEDIA_REGISTER = 2
HANDLE_REGISTER = 4
HANDLE_EXPRESSION = 8
HANDLE_MODIFIER = 16
HANDLE_CONSTANT = 32
HANDLE_NONE = 64

INSTANCE_NONE = 1
INSTANCE_CONSTANT_DATA_SECTION = 2
INSTANCE_DATA_SECTION = 4
INSTANCE_CONSTANT = 8
INSTANCE_STACK_VARIABLE = 16
INSTANCE_MEMORY = 32
INSTANCE_STACK_MEMORY = 64
INSTANCE_TEMPORARY_MEMORY = 128
INSTANCE_COMPLEX_MEMORY = 256
INSTANCE_EXPRESSION = 512
INSTANCE_STACK_ALLOCATION = 1024
INSTANCE_REGISTER = 2048
INSTANCE_MODIFIER = 4096
INSTANCE_LOWER_12_BITS = 8192
INSTANCE_DISPOSABLE_PACK = 16384

# Summary: Converts the specified size to corresponding size modifier
to_size_modifier(bytes: large) {
	=> when(bytes) {
		1 => 'byte'
		2 => 'word'
		4 => 'dword'
		8 => 'qword'
		16 => 'xword'
		32 => 'yword'
		else => {
			abort('Invalid size')
			'.?'
		}
	}
}

BYTE_ALLOCATOR = '.byte'
SHORT_ALLOCATOR = '.word'
LONG_ALLOCATOR = '.dword'
QUAD_ALLOCATOR = '.qword'
XWORD_ALLOCATOR = '.xword'
YWORD_ALLOCATOR = '.yword'

# Summary: Converts the specified size to corresponding data section allocator
to_data_section_allocator(bytes: large) {
	=> when(bytes) {
		1 => '.byte'
		2 => '.word'
		4 => '.dword'
		8 => '.qword'
		16 => '.xword'
		32 => '.yword'
		else => {
			abort('Invalid size')
			'.?'
		}
	}
}

Handle {
	type: large
	instance: large
	format: large = SYSTEM_FORMAT
	size => to_bytes(format)
	unsigned => is_unsigned(format)

	init() {
		type = HANDLE_NONE
		instance = INSTANCE_NONE
	}

	init(type: large, instance: large) {
		this.type = type
		this.instance = instance
	}

	# Summary: Returns all results which the handle requires to be in registers
	virtual get_register_dependent_results() {
		=> List<Result>()
	}

	# Summary: Returns all results used in the handle
	virtual get_inner_results() {
		=> List<Result>()
	}

	virtual use(instruction: Instruction) {}

	virtual equals(other: Handle) {
		=> this.instance == other.instance and this.format == other.format
	}

	virtual finalize() {
		=> Handle()
	}

	virtual string() {
		=> String('?')
	}
}

Handle ConstantHandle {
	value: large
	
	bits() {
		=> common.get_bits(value, format == FORMAT_DECIMAL)
	}
	
	init(value: large) {
		Handle.init(HANDLE_CONSTANT, INSTANCE_CONSTANT)
		this.value = value
	}

	init(value: large, format: large) {
		Handle.init(HANDLE_CONSTANT, INSTANCE_CONSTANT)
		this.value = value
		this.format = format
	}

	init(value: large, format: large, size: large) {
		Handle.init(HANDLE_CONSTANT, INSTANCE_CONSTANT)
		this.value = value
		this.format = format
		this.size = size
	}

	convert(format: large) {
		if this.format == format return

		if format == FORMAT_DECIMAL { value = decimal_to_bits(value as decimal) }
		else { value = bits_to_decimal(value) }

		this.format = format
	}

	string_shared() {
		if format == FORMAT_DECIMAL => to_string(bits_to_decimal(value)).replace(`,`, `.`)
		=> to_string(value).replace(`,`, `.`)
	}

	override string() {
		if settings.is_x64 => string_shared()
		=> String('#') + string_shared()
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.format == other.format and this.value == other.(ConstantHandle).value
	}

	override finalize() {
		=> ConstantHandle(value, format, size)
	}
}

Handle RegisterHandle {
	register: Register

	init(register: Register) {
		if register.is_media_register { Handle.init(HANDLE_MEDIA_REGISTER, INSTANCE_REGISTER) }
		else { Handle.init(HANDLE_REGISTER, INSTANCE_REGISTER) }

		this.register = register
	}

	init(register: Register, format: large, size: large) {
		if register.is_media_register { Handle.init(HANDLE_MEDIA_REGISTER, INSTANCE_REGISTER) }
		else { Handle.init(HANDLE_REGISTER, INSTANCE_REGISTER) }

		this.register = register
		this.format = format
		this.size = size
	}

	override string() {
		if size == 0 => register[SYSTEM_BYTES]
		=> register[size]
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.register == other.(RegisterHandle).register
	}

	override finalize() {
		=> RegisterHandle(register, format, size)
	}
}

Handle MemoryHandle {
	unit: Unit
	start: Result
	offset: large

	init(unit: Unit, start: Result, offset: large) {
		Handle.init(HANDLE_MEMORY, INSTANCE_MEMORY)
		this.unit = unit
		this.start = start
		this.offset = offset
	}

	virtual get_absolute_offset() {
		=> offset
	}

	override use(instruction: Instruction) {
		start.use(instruction)
	}

	get_start() {
		=> when(start.value.instance) {
			INSTANCE_REGISTER => start.value.(RegisterHandle).register,
			INSTANCE_STACK_ALLOCATION => unit.get_stack_pointer(),
			else => none as Register
		}
	}

	get_offset() {
		=> when(start.value.instance) {
			INSTANCE_CONSTANT => start.value.(ConstantHandle).value + get_absolute_offset(),
			INSTANCE_STACK_ALLOCATION => start.value.(StackAllocationHandle).get_absolute_offset() + get_absolute_offset(),
			else => get_absolute_offset()
		}
	}

	default_string() {
		start: Register = get_start()
		offset: large = get_offset()

		if start == none {
			if settings.is_x64 => String(to_size_modifier(size)) + ' [' + to_string(offset) + `]`
			else => String('[xzr, #') + to_string(offset) + `]`
		}
		else {
			if settings.is_x64 {
				offset_text = String.empty

				if offset > 0 { offset_text = String(`+`) + to_string(offset) }
				else offset < 0 { offset_text = to_string(offset) }

				=> String(to_size_modifier(size)) + ' [' + start.string() + offset_text + `]`
			}
			else {
				=> String('[') + start.string() + String(', #') + to_string(offset) + `]`
			}
		}
	}

	override string() {
		=> default_string()
	}

	override get_register_dependent_results() {
		if start.is_stack_allocation => List<Result>()

		all = List<Result>()
		all.add(start)
		=> all
	}

	override get_inner_results() {
		all = List<Result>()
		all.add(start)
		=> all
	}

	override finalize() {
		if start.is_standard_register or start.is_constant or start.is_stack_allocation {
			handle = MemoryHandle(unit, Result(start.value, start.format), offset)
			handle.format = format
			=> handle
		}

		abort('Start of the memory handle was in invalid format during finalization')
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.start.value.equals(other.(MemoryHandle).start.value) and offset == other.(MemoryHandle).offset
	}
}

MemoryHandle StackMemoryHandle {
	is_absolute: bool

	init(unit: Unit, offset: large, is_absolute: bool) {
		register = RegisterHandle(unit.get_stack_pointer())
		MemoryHandle.init(unit, Result(register, SYSTEM_FORMAT), offset)

		this.is_absolute = is_absolute
		this.instance = INSTANCE_STACK_MEMORY
	}

	override get_absolute_offset() {
		if is_absolute => unit.stack_offset + offset
		=> offset
	}

	override finalize() {
		if start.value.(RegisterHandle).register == unit.get_stack_pointer() {
			handle = StackMemoryHandle(unit, offset, is_absolute)
			handle.format = format
			=> handle
		}

		abort('Stack memory handle did not use the stack pointer register')
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.offset == other.(StackMemoryHandle).offset and this.is_absolute == other.(StackMemoryHandle).is_absolute
	}
}

StackMemoryHandle StackVariableHandle {
	variable: Variable

	init(unit: Unit, variable: Variable) {
		StackMemoryHandle.init(unit, variable.alignment, true)

		this.variable = variable
		this.instance = INSTANCE_STACK_VARIABLE

		if not variable.is_predictable abort('Creating stack variable handles of unpredictable variables is not allowed')
	}

	override get_absolute_offset() {
		offset = variable.alignment

		if is_absolute => unit.stack_offset + offset
		=> offset
	}

	override string() {
		offset = variable.alignment
		=> default_string()
	}

	override finalize() {
		handle = StackVariableHandle(unit, variable)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.variable == other.(StackVariableHandle).variable
	}
}

StackMemoryHandle TemporaryMemoryHandle {
	identity: String

	init(unit: Unit) {
		StackMemoryHandle.init(unit, 0, true)
		this.identity = unit.get_next_identity()
		this.instance = INSTANCE_TEMPORARY_MEMORY
	}

	init(unit: Unit, identity: String) {
		StackMemoryHandle.init(unit, 0, true)
		this.identity = identity
		this.instance = INSTANCE_TEMPORARY_MEMORY
	}

	override finalize() {
		handle = TemporaryMemoryHandle(unit, identity)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.identity == other.(TemporaryMemoryHandle).identity
	}
}

DATA_SECTION_MODIFIER_NONE = 0
DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE = 1
DATA_SECTION_MODIFIER_PROCEDURE_LINKAGE_TABLE = 2

Handle DataSectionHandle {
	constant X64_GLOBAL_OFFSET_TABLE = '@GOTPCREL'
	constant X64_PROCEDURE_LINKAGE_TABLE = '@PLT'

	constant ARM64_GLOBAL_OFFSET_TABLE_PREFIX = ':got:'

	identifier: String
	offset: large

	# Address means whether to use the value of the address or not
	address: bool = false
	modifier: large = DATA_SECTION_MODIFIER_NONE

	init(identifier: String, address: bool) {
		Handle.init(HANDLE_MEMORY, INSTANCE_DATA_SECTION)
		this.identifier = identifier
		this.address = address
	}

	init(identifier: String, offset: large, address: bool, modifier: large) {
		Handle.init(HANDLE_MEMORY, INSTANCE_DATA_SECTION)
		this.identifier = identifier
		this.offset = offset
		this.address = address
		this.modifier = modifier
	}

	override string() {
		# If the value of the address is only required, return it
		if address {
			if settings.is_x64 {
				if modifier == DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE => String.empty
				if modifier == DATA_SECTION_MODIFIER_PROCEDURE_LINKAGE_TABLE => identifier + X64_PROCEDURE_LINKAGE_TABLE
			}
			else {
				if modifier == DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE => String(ARM64_GLOBAL_OFFSET_TABLE_PREFIX) + identifier
			}

			=> identifier
		}

		# When building for Arm64, the code below should not execute
		if not settings.is_x64 => String.empty

		# If a modifier is attached, the offset is taken into account elsewhere
		if modifier != DATA_SECTION_MODIFIER_NONE {
			if modifier == DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE {
				=> String(to_size_modifier(size)) + ' [' + identifier + X64_GLOBAL_OFFSET_TABLE + ']'
			}

			if modifier == DATA_SECTION_MODIFIER_PROCEDURE_LINKAGE_TABLE {
				=> String(to_size_modifier(size)) + ' [' + identifier + X64_PROCEDURE_LINKAGE_TABLE + ']'
			}

			=> String.empty
		}

		# Apply the offset if it is not zero
		if offset != 0 {
			postfix = to_string(offset)
			if offset > 0 { postfix = String('+') + postfix }

			=> String(to_size_modifier(size)) + ' [' + identifier + postfix + ']'
		}

		=> String(to_size_modifier(size)) + ' [' + identifier + ']'
	}

	override finalize() {
		handle = DataSectionHandle(identifier, offset, address, modifier)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.identifier == other.(DataSectionHandle).identifier and this.offset == other.(DataSectionHandle).offset and this.address == other.(DataSectionHandle).address and this.modifier == other.(DataSectionHandle).modifier
	}
}

CONSTANT_TYPE_INTEGER = 0
CONSTANT_TYPE_DECIMAL = 1
CONSTANT_TYPE_BYTES = 2

DataSectionHandle ConstantDataSectionHandle {
	value_type: large

	init(identifier: String) {
		DataSectionHandle.init(identifier, false)
		this.instance = INSTANCE_CONSTANT_DATA_SECTION
	}
}

ConstantDataSectionHandle NumberDataSectionHandle {
	value: large

	init(handle: ConstantHandle) {
		ConstantDataSectionHandle.init(handle.string())
		this.value = handle.value

		if handle.format == FORMAT_DECIMAL { value_type = CONSTANT_TYPE_DECIMAL }
		else { value_type = CONSTANT_TYPE_INTEGER }
	}

	init(identifier: String, value: large, value_type: large) {
		ConstantDataSectionHandle.init(identifier)
		this.value = value
		this.value_type = value_type
	}

	override finalize() {
		handle = NumberDataSectionHandle(identifier, value, value_type)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.identifier == other.(DataSectionHandle).identifier and this.value_type == other.(ConstantDataSectionHandle).value_type
	}
}

ConstantDataSectionHandle ByteArrayDataSectionHandle {
	value: Array<byte>

	init(bytes: Array<byte>) {
		values = List<String>()
		loop value in bytes { values.add(to_string(value)) }
		ConstantDataSectionHandle.init(String('{ ') + String.join(String(', '), values) + ' }')
		this.value = bytes
		this.value_type = CONSTANT_TYPE_BYTES
	}

	init(identifier: String, bytes: Array<byte>) {
		ConstantDataSectionHandle.init(identifier)
		this.value = bytes
		this.value_type = CONSTANT_TYPE_BYTES
	}

	override finalize() {
		handle = ByteArrayDataSectionHandle(identifier, value)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and this.identifier == other.(DataSectionHandle).identifier and this.value_type == other.(ConstantDataSectionHandle).value_type
	}
}

Handle ComplexMemoryHandle {
	start: Result
	index: Result
	stride: large
	offset: large

	init(start: Result, index: Result, stride: large, offset: large) {
		Handle.init(HANDLE_MEMORY, INSTANCE_COMPLEX_MEMORY)
		this.start = start
		this.index = index
		this.stride = stride
		this.offset = offset

		if not settings.is_x64 and offset != 0 abort('Arm64 does not support memory handles with multiple offsets')
	}

	override use(instruction: Instruction) {
		start.use(instruction)
		index.use(instruction)
	}

	get_start() {
		=> when(start.value.instance) {
			INSTANCE_REGISTER => start.value.(RegisterHandle).register,
			else => none as Register
		}
	}

	get_index() {
		=> when(index.value.instance) {
			INSTANCE_REGISTER => index.value.(RegisterHandle).register,
			else => none as Register
		}
	}

	get_offset() {
		offset: large = this.offset

		offset += when(start.value.instance) {
			INSTANCE_CONSTANT => start.value.(ConstantHandle).value,
			else => 0
		}

		offset += when(index.value.instance) {
			INSTANCE_CONSTANT => index.value.(ConstantHandle).value * stride,
			else => 0
		}

		=> offset
	}

	override string() {
		# Examples: [1], [rax], [rax-1], [rax+rbx], [rax+rbx+1], [rax+rbx*2], [rax+rbx*2-1]
		start: Register = get_start()
		index: Register = get_index()
		offset: large = get_offset()

		result = String(' [')

		if start != none { result = result + start.string() }

		if index != none {
			# Add a plus-operator to separate the base from the index if needed
			if result.length > 2 { result = result + String(`+`) }
			result = result + index.string()

			# Multiply the index register, if the stride is not one
			if stride != 1 { result = result + String(`*`) + to_string(stride) }
		}

		# Finally, add the offset. Add the sign always, if something has been added to the result.
		if result.length > 2 {
			if offset > 0 { result = result + String(`+`) + to_string(offset) }
			else offset < 0 { result = result + to_string(offset) }
		}
		else {
			result = result + to_string(offset)
		}

		=> String(to_size_modifier(size)) + result + ']'
	}

	override get_register_dependent_results() {
		all = List<Result>()
		all.add(start)

		if not index.is_constant and not index.is_modifier all.add(index)

		=> all
	}

	override get_inner_results() {
		all = List<Result>()
		all.add(start)
		all.add(index)
		=> all
	}

	override finalize() {
		handle = ComplexMemoryHandle(
			Result(start.value.finalize(), start.format),
			Result(index.value.finalize(), index.format),
			stride,
			offset
		)

		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		=> this.instance == other.instance and start.value.equals(other.(ComplexMemoryHandle).start.value) and index.value.equals(other.(ComplexMemoryHandle).index.value) and stride == other.(ComplexMemoryHandle).stride and offset == other.(ComplexMemoryHandle).offset
	}
}

Handle ExpressionHandle {
	multiplicand: Result
	multiplier: large
	addition: Result
	number: large

	static create_addition(left: Result, right: Result) {
		=> ExpressionHandle(left, 1, right, 0)
	}

	static create_addition(left: Handle, right: Handle) {
		=> ExpressionHandle(Result(left, SYSTEM_FORMAT), 1, Result(right, SYSTEM_FORMAT), 0)
	}

	static create_memory_address(start: Result, offset: large) {
		if settings.is_x64 => ExpressionHandle(start, 1, none as Result, offset)

		=> ExpressionHandle(start, 1, Result(ConstantHandle(offset), SYSTEM_FORMAT), 0)
	}

	static create_memory_address(start: Result, offset: Result, stride: large) {
		=> ExpressionHandle(offset, stride, start, 0)
	}

	init(multiplicand: Result, multiplier: large, addition: Result, number: large) {
		Handle.init(HANDLE_EXPRESSION, INSTANCE_EXPRESSION)
		this.multiplicand = multiplicand
		this.multiplier = multiplier
		this.addition = addition
		this.number = number
	}

	override use(instruction: Instruction) {
		multiplicand.use(instruction)
		if addition != none addition.use(instruction)
	}

	validate() {
		if (multiplicand.is_standard_register or multiplicand.is_constant) and (addition == none or (addition.is_standard_register or addition.is_constant)) and multiplier > 0 return
		abort('Invalid expression handle')
	}

	get_start() {
		if addition == none => none as Register

		=> when(addition.value.instance) {
			INSTANCE_REGISTER => addition.value.(RegisterHandle).register,
			else => none as Register
		}
	}

	get_index() {
		=> when(multiplicand.value.instance) {
			INSTANCE_REGISTER => multiplicand.value.(RegisterHandle).register,
			else => none as Register
		}
	}

	get_offset() {
		offset = number

		if addition != none {
			offset += when(addition.value.instance) {
				INSTANCE_CONSTANT => addition.value.(ConstantHandle).value,
				else => 0
			}
		}

		offset += when(multiplicand.value.instance) {
			INSTANCE_CONSTANT => multiplicand.value.(ConstantHandle).value * multiplier,
			else => 0
		}

		=> offset
	}

	string_x64() {
		expression = String.empty
		postfix = number

		if multiplicand.is_constant {
			postfix += multiplicand.value.(ConstantHandle).value * multiplier
		}
		else {
			expression = multiplicand.value.string()
			if multiplier > 1 { expression = expression + '*' + to_string(multiplier) }
		}

		if addition != none {
			if addition.is_constant {
				postfix += addition.value.(ConstantHandle).value
			}
			else expression.length != 0 {
				expression = expression + '+' + addition.value.string()
			}
			else {
				expression = expression + addition.value.string()
			}
		}

		is_empty = expression.length == 0

		if postfix != 0 or is_empty {
			if postfix > 0 and not is_empty { expression = expression + '+' + to_string(postfix) }
			else { expression = expression + to_string(postfix) }
		}

		=> String('[') + expression + ']'
	}

	string_arm64() {
		=> none as String
	}

	override string() {
		validate()
		if settings.is_x64 => string_x64()
		=> string_arm64()
	}

	override get_register_dependent_results() {
		all = List<Result>()

		if not multiplicand.is_constant all.add(multiplicand)
		if addition != none and not (settings.is_x64 and addition.is_constant) all.add(addition)

		=> all
	}

	override get_inner_results() {
		all = List<Result>()
		all.add(multiplicand)

		if addition != none all.add(addition)

		=> all
	}

	override finalize() {
		validate()

		if addition == none {
			handle = ExpressionHandle(Result(multiplicand.value, multiplicand.format), multiplier, none as Result, number)
			handle.format = format
			=> handle
		}

		handle = ExpressionHandle(Result(multiplicand.value, multiplicand.format), multiplier, Result(addition.value, addition.format), number)
		handle.format = format
		=> handle
	}

	override equals(other: Handle) {
		if this.instance != other.instance => false
		if not this.multiplicand.value.equals(other.(ExpressionHandle).multiplicand.value) => false
		if this.multiplier != other.(ExpressionHandle).multiplier => false
		if not this.addition.value.equals(other.(ExpressionHandle).addition.value) => false
		=> this.number == other.(ExpressionHandle).number
	}
}

Handle StackAllocationHandle {
	unit: Unit
	offset: large
	bytes: large
	identity: String

	get_absolute_offset() {
		=> unit.stack_offset + offset
	}

	init(unit: Unit, bytes: large, identity: String) {
		this.unit = unit
		this.offset = 0
		this.bytes = bytes
		this.identity = identity
		this.type = HANDLE_EXPRESSION
		this.instance = INSTANCE_STACK_ALLOCATION
	}

	init(unit: Unit, offset: large, bytes: large, identity: String) {
		this.unit = unit
		this.offset = offset
		this.bytes = bytes
		this.identity = identity
		this.type = HANDLE_EXPRESSION
		this.instance = INSTANCE_STACK_ALLOCATION
	}

	override finalize() {
		handle = StackAllocationHandle(unit, offset, bytes, identity)
		handle.format = format
		=> handle
	}

	override string() {
		stack_pointer = unit.get_stack_pointer()
		offset: large = get_absolute_offset()

		if not settings.is_x64 => stack_pointer[SYSTEM_BYTES] + ', #' + to_string(offset)

		if offset > 0 => String('[') + stack_pointer[SYSTEM_BYTES] + '+' + to_string(offset) + ']'
		else offset < 0 => String('[') + stack_pointer[SYSTEM_BYTES] + to_string(offset) + ']'

		=> String('[') + stack_pointer[SYSTEM_BYTES] + ']'
	}

	override equals(other: Handle) {
		if this.instance != other.instance => false
		=> this.format == other.format and this.offset == other.(StackAllocationHandle).offset and this.bytes == other.(StackAllocationHandle).bytes and this.identity == other.(StackAllocationHandle).identity
	}
}

pack DisposablePackMember {
	member: Variable
	value: Result
}

Handle DisposablePackHandle {
	members: Map<String, DisposablePackMember> = Map<String, DisposablePackMember>()

	init(unit: Unit, type: Type) {
		this.type = HANDLE_EXPRESSION
		this.instance = INSTANCE_DISPOSABLE_PACK

		# Initialize the members
		loop iterator in type.variables {
			member = iterator.value
			value = Result()

			if member.type.is_pack {
				value.value = DisposablePackHandle(unit, member.type)
			}

			members[member.name] = pack { member: member, value: value } as DisposablePackMember
		}
	}

	override use(instruction: Instruction) {
		loop iterator in members {
			member = iterator.value.value
			member.use(instruction)
		}
	}

	override get_inner_results() {
		all = List<Result>()

		loop iterator in members {
			member = iterator.value.value
			all.add(member)
		}

		=> all
	}
}