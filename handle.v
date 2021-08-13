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

# Summary: Converts the specified size to corresponding size modifier
to_size_modifier(bytes: large) {
	=> when(bytes) {
		1 => 'byte'
		2 => 'word'
		4 => 'dword'
		8 => 'qword'
		16 => 'xmmword'
		32 => 'ymmword'
		else => {
			abort('Invalid size')
			'.?'
		}
	}
}

BYTE_ALLOCATOR = '.byte'
SHORT_ALLOCATOR = '.short'
LONG_ALLOCATOR = '.long'
QUAD_ALLOCATOR = '.quad'
XWORD_ALLOCATOR = '.xword'
YWORD_ALLOCATOR = '.yword'

# Summary: Converts the specified size to corresponding data section allocator
to_data_section_allocator(bytes: large) {
	=> when(bytes) {
		1 => '.byte'
		2 => '.short'
		4 => '.long'
		8 => '.quad'
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
	is_precise: bool = false
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

	init(is_precise: bool, format: large, size: large) {
		this.is_precise = is_precise
		this.format = format
		this.size = size
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
		=> this.instance == other.instance and this.format == other.format and this.register == other.(RegisterHandle).register
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

	default_string() {
		start: Handle = this.start.value
		offset: large = get_absolute_offset()

		if start.instance == INSTANCE_STACK_ALLOCATION {
			start = RegisterHandle(unit.get_stack_pointer())
			offset += start.(StackAllocationHandle).absolute_offset
		}

		postfix = String('')

		if settings.is_x64 {
			if offset > 0 { postfix = String('+') + to_string(offset) }
			else offset < 0 { postfix = to_string(offset) }
		}
		else {
			if offset != 0 { postfix = String(', #') + to_string(offset) }
		}

		if start.type == HANDLE_REGISTER or start.type == HANDLE_CONSTANT {
			address = String('[') + start.string() + postfix + ']'

			if is_precise and settings.is_x64 => String(to_size_modifier(size)) + ' ptr ' + address
			=> address
		}

		=> String.empty
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
DATA_SECTION_PROCEDURE_LINKAGE_TABLE = 2

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
				if modifier == DATA_SECTION_PROCEDURE_LINKAGE_TABLE => identifier + X64_PROCEDURE_LINKAGE_TABLE
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
				if is_precise => String(to_size_modifier(size)) + ' ptr [rip+' + identifier + X64_GLOBAL_OFFSET_TABLE + ']'
				=> String('[rip+') + identifier + X64_GLOBAL_OFFSET_TABLE + ']'
			}

			if modifier == DATA_SECTION_PROCEDURE_LINKAGE_TABLE {
				if is_precise => String(to_size_modifier(size)) + ' ptr [rip+' + identifier + X64_PROCEDURE_LINKAGE_TABLE + ']'
				=> String('[rip+') + identifier + X64_PROCEDURE_LINKAGE_TABLE + ']'
			}

			=> String.empty
		}

		# Apply the offset if it is not zero
		if offset != 0 {
			postfix = to_string(offset)

			if offset > 0 { postfix = String('+') + postfix }

			if is_precise => String(to_size_modifier(size)) + ' ptr [rip+' + identifier + postfix + ']'
			=> String('[rip+') + identifier + postfix + ']'
		}

		if is_precise => String(to_size_modifier(size)) + ' ptr [rip+' + identifier + ']'
		=> String('[rip+') + identifier + ']'
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

	init(identifier: String, address: bool) {
		DataSectionHandle.init(identifier, false)
		this.instance = INSTANCE_CONSTANT_DATA_SECTION
	}
}

ConstantDataSectionHandle NumberDataSectionHandle {
	value: large

	init(handle: ConstantHandle) {
		ConstantDataSectionHandle.init(handle.string(), false)
		this.value = handle.value

		if handle.format == FORMAT_DECIMAL { value_type = CONSTANT_TYPE_DECIMAL }
		else { value_type = CONSTANT_TYPE_INTEGER }
	}

	init(identifier: String, value: large, value_type: large) {
		ConstantDataSectionHandle.init(identifier, false)
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
		ConstantDataSectionHandle.init(String('{ ') + String.join(String(', '), values) + ' }', false)
		this.value = bytes
		this.value_type = CONSTANT_TYPE_BYTES
	}

	init(identifier: String, bytes: Array<byte>) {
		ConstantDataSectionHandle.init(identifier, false)
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

	override string() {
		postfix = String.empty

		if index.is_standard_register or index.is_modifier {
			if settings.is_x64 {
				postfix = String('+') + index.value.string()
				if stride != 1 { postfix = postfix + '*' + to_string(stride) }
			}
		}
		else index.value.instance == INSTANCE_CONSTANT {
			value = index.value.(ConstantHandle).value * stride

			if settings.is_x64 {
				if value > 0 { postfix = String('+') + to_string(value) }
				else value < 0 { postfix = to_string(value) }
			}
		}
		else {
			=> postfix
		}

		if offset != 0 {
			if settings.is_x64 {
				postfix = postfix + '+' + to_string(offset)
			}
			else {
				=> String.empty
			}
		}

		if start.is_standard_register or start.is_constant {
			address = String('[') + start.value.string() + postfix + ']'

			if is_precise and settings.is_x64 => String(to_size_modifier(size)) + ' ptr ' + address 
			=> address
		}

		=> String.empty
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
		if (multiplicand.is_standard_register or multiplicand.is_constant) and (addition == none or [addition.is_standard_register or addition.is_constant]) and multiplier > 0 return
		abort('Invalid expression handle')
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
			handle = ExpressionHandle(Result(multiplicand.value, SYSTEM_FORMAT), multiplier, none as Result, number)
			handle.format = format
			=> handle
		}

		handle = ExpressionHandle(Result(multiplicand.value, SYSTEM_FORMAT), multiplier, Result(addition.value, SYSTEM_FORMAT), number)
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

	absolute_offset => unit.stack_offset + offset

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
		offset: large = absolute_offset

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