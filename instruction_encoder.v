LABEL_USAGE_TYPE_LABEL = 0
LABEL_USAGE_TYPE_CALL = 1

LabelUsageItem {
	type: large
	position: large
	label: Label
	modifier: large

	init(type: large, position: large, label: Label) {
		this.type = type
		this.position = position
		this.label = label
		this.modifier = DATA_SECTION_MODIFIER_NONE
	}
}

LabelDescriptor {
	module: EncoderModule
	position: large
	absolute_position => module.start + position

	init(module: EncoderModule, position: large) {
		this.module = module
		this.position = position
	}
}

EncoderDebugLineInformation {
	offset: large
	line: large
	character: large

	init(offset: large, line: large, character: large) {
		this.offset = offset
		this.line = line
		this.character = character
	}
}

ENCODER_DEBUG_FRAME_INFORMATION_TYPE_START = 0
ENCODER_DEBUG_FRAME_INFORMATION_TYPE_SET_FRAME_OFFSET = 1
ENCODER_DEBUG_FRAME_INFORMATION_TYPE_ADVANCE = 2
ENCODER_DEBUG_FRAME_INFORMATION_TYPE_END = 3

EncoderDebugFrameInformation {
	type: large
	offset: large

	init(type: large, offset: large) {
		this.type = type
		this.offset = offset
	}
}

EncoderDebugFrameInformation EncoderDebugFrameStartInformation {
	symbol: String

	init(offset: large, symbol: String) {
		EncoderDebugFrameInformation.init(ENCODER_DEBUG_FRAME_INFORMATION_TYPE_START, offset)
		this.symbol = symbol
	}
}

EncoderDebugFrameInformation EncoderDebugFrameOffsetInformation {
	frame_offset: large

	init(offset: large, frame_offset: large) {
		EncoderDebugFrameInformation.init(ENCODER_DEBUG_FRAME_INFORMATION_TYPE_SET_FRAME_OFFSET, offset)
		this.frame_offset = frame_offset
	}
}

EncoderModule {
	index: large = 0
	jump: Label = none
	is_conditional_jump: bool = false
	is_short_jump: bool = false
	instructions: List<Instruction> = List<Instruction>()
	labels: List<LabelUsageItem> = List<LabelUsageItem>()
	calls: List<LabelUsageItem> = List<LabelUsageItem>()
	items: List<LabelUsageItem> = List<LabelUsageItem>()
	memory_address_relocations: List<BinaryRelocation> = List<BinaryRelocation>()
	debug_line_information: List<EncoderDebugLineInformation> = List<EncoderDebugLineInformation>()
	debug_frame_information: List<EncoderDebugFrameInformation> = List<EncoderDebugFrameInformation>()
	output: link
	position: large = 0
	start: large = 0

	init(jump: Label, is_conditional_jump: bool) {
		this.jump = jump
		this.is_conditional_jump = is_conditional_jump
		this.output = allocate(1)
	}

	init() {
		this.output = allocate(1)
	}

	get_max_instruction_buffer_size() {
		instruction_count = 0

		# Count the number of non-abstract instructions, that is, the number of instructions that can actually be encoded
		loop instruction in instructions {
			if instruction.operation.length == 0 continue
			instruction_count++
		}

		return instruction_count * instruction_encoder.MAX_INSTRUCTION_SIZE
	}

	deinit() {
		deallocate(output)
	}
}

EncoderOutput {
	section: BinarySection
	symbols: Map<String, BinarySymbol>
	relocations: List<BinaryRelocation>
	frames: DebugFrameEncoderModule
	lines: DebugLineEncoderModule

	init(section: BinarySection, symbols: Map<String, BinarySymbol>, relocations: List<BinaryRelocation>, frames: DebugFrameEncoderModule, lines: DebugLineEncoderModule) {
		this.section = section
		this.symbols = symbols
		this.relocations = relocations
		this.frames = frames
		this.lines = lines
	}
}

ENCODING_FILTER_TYPE_REGISTER = 1
ENCODING_FILTER_TYPE_STANDARD_REGISTER = 2
ENCODING_FILTER_TYPE_MEDIA_REGISTER = 4
ENCODING_FILTER_TYPE_SPECIFIC_REGISTER = 8
ENCODING_FILTER_TYPE_MEMORY_ADDRESS = 16
ENCODING_FILTER_TYPE_CONSTANT = 32
ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT = 64
ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT = 128
ENCODING_FILTER_TYPE_EXPRESSION = 256
ENCODING_FILTER_TYPE_LABEL = 512

ENCODING_ROUTE_NONE = 0
ENCODING_ROUTE_RMC = 1 # Register, Memory, Constant
ENCODING_ROUTE_RRC = 2 # Register, Register, Constant
ENCODING_ROUTE_DRC = 3 # Register, Constant => Register, Register, Constant
ENCODING_ROUTE_RR = 4 # Register, Register
ENCODING_ROUTE_RC = 5 # Register, Constant
ENCODING_ROUTE_RM = 6 # Register, Memory address
ENCODING_ROUTE_MR = 7 # Memory address, Register
ENCODING_ROUTE_OC = 8 # Operation code + Register, Constant
ENCODING_ROUTE_MC = 9 # Memory address, Constant
ENCODING_ROUTE_R = 10 # Register
ENCODING_ROUTE_M = 11 # Memory
ENCODING_ROUTE_C = 12 # Constant
ENCODING_ROUTE_O = 13 # Operation code + Register
ENCODING_ROUTE_D = 14 # Label offset
ENCODING_ROUTE_L = 15 # Label declaration
ENCODING_ROUTE_SC = 16 # Skip, Constant
ENCODING_ROUTE_SO = 17 # Skip, Operation code + Register

InstructionEncoding {
	prefix: byte
	is_64bit: bool
	operation: normal
	modifier: byte
	route: large
	filter_type_of_first: normal
	filter_of_first: small
	input_size_of_first: byte
	filter_type_of_second: normal
	filter_of_second: small
	input_size_of_second: byte
	filter_type_of_third: normal
	filter_of_third: small
	input_size_of_third: byte

	init(operation: normal) {
		this.prefix = 0
		this.is_64bit = false
		this.operation = operation
		this.modifier = 0
		this.route = ENCODING_ROUTE_NONE
		this.filter_type_of_first = 0
		this.filter_of_first = 0
		this.input_size_of_first = 0
		this.filter_type_of_second = 0
		this.filter_of_second = 0
		this.input_size_of_second = 0
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, route: normal, rex: bool) {
		this.prefix = 0
		this.is_64bit = rex
		this.operation = operation
		this.modifier = 0
		this.route = route
		this.filter_type_of_first = 0
		this.filter_of_first = 0
		this.input_size_of_first = 0
		this.filter_type_of_second = 0
		this.filter_of_second = 0
		this.input_size_of_second = 0
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte) {
		this.prefix = 0
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = 0
		this.filter_of_second = 0
		this.input_size_of_second = 0
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte, prefix: byte) {
		this.prefix = prefix
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = 0
		this.filter_of_second = 0
		this.input_size_of_second = 0
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte, filter_type_second: normal, filter_second: small, input_size_second: byte) {
		this.prefix = 0
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = filter_type_second
		this.filter_of_second = filter_second
		this.input_size_of_second = input_size_second
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte, filter_type_second: normal, filter_second: small, input_size_second: byte, prefix: byte) {
		this.prefix = prefix
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = filter_type_second
		this.filter_of_second = filter_second
		this.input_size_of_second = input_size_second
		this.filter_type_of_third = 0
		this.filter_of_third = 0
		this.input_size_of_third = 0
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte, filter_type_second: normal, filter_second: small, input_size_second: byte, filter_type_third: normal, filter_third: small, input_size_third: byte) {
		this.prefix = 0
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = filter_type_second
		this.filter_of_second = filter_second
		this.input_size_of_second = input_size_second
		this.filter_type_of_third = filter_type_third
		this.filter_of_third = filter_third
		this.input_size_of_third = input_size_third
	}

	init(operation: normal, modifier: byte, route: normal, rex: bool, filter_type_first: normal, filter_first: small, input_size_first: byte, filter_type_second: normal, filter_second: small, input_size_second: byte, filter_type_third: normal, filter_third: small, input_size_third: byte, prefix: byte) {
		this.prefix = prefix
		this.is_64bit = rex
		this.operation = operation
		this.modifier = modifier
		this.route = route
		this.filter_type_of_first = filter_type_first
		this.filter_of_first = filter_first
		this.input_size_of_first = input_size_first
		this.filter_type_of_second = filter_type_second
		this.filter_of_second = filter_second
		this.input_size_of_second = input_size_second
		this.filter_type_of_third = filter_type_third
		this.filter_of_third = filter_third
		this.input_size_of_third = input_size_third
	}
}

MemoryAddressDescriptor {
	start: Register
	index: Register
	stride: normal
	offset: normal
	relocation: BinaryRelocation

	init(start: Register, index: Register, stride: normal, offset: normal) {
		this.start = start
		this.index = index
		this.stride = stride
		this.offset = offset
		this.relocation = none
	}

	init(symbol: String, modifier: large, offset: normal) {
		this.start = none
		this.index = none
		this.stride = 0
		this.offset = 0
		this.relocation = BinaryRelocation(BinarySymbol(symbol, 0, true), 0, offset, data_access_modifier_to_relocation_type(modifier))
	}
}

namespace instruction_encoder {
	constant TEMPORARY_ASSEMBLY_FILE = 'temporary'

	constant MAX_INSTRUCTION_SIZE = 15

	constant LOCK_PREFIX = 240 # 0xf0
	constant OPERAND_SIZE_OVERRIDE = 102 # 0x66

	constant REX_PREFIX = 64 # 01000000
	constant REX_W = 8 # 00001000
	constant REX_R = 4 # 00000100
	constant REX_X = 2 # 00000010
	constant REX_B = 1 # 00000001

	constant MEMORY_OFFSET8_MODIFIER = 64 # 01000000
	constant MEMORY_OFFSET32_MODIFIER = 128 # 10000000
	constant REGISTER_DIRECT_ADDRESSING_MODIFIER = 192 # 11000000

	constant JUMP_OFFSET8_SIZE = 2
	constant CONDITIONAL_JUMP_OFFSET8_SIZE = 2
	constant JUMP_OFFSET32_SIZE = 5
	constant CONDITIONAL_JUMP_OFFSET32_SIZE = 6
	constant JUMP_OFFSET8_OPERATION_CODE = 0xEB

	constant TEXT_SECTION = '.text'

	# Summary:
	# Returns whether the specified register needs the REX-prefix
	is_extension_register(register: Register) {
		return register.identifier >= platform.x64.R8
	}

	# Summary:
	# Returns whether the specified register needs the REX-prefix
	is_extension_register(identifier: large) {
		return identifier >= platform.x64.R8
	}

	# Summary:
	# Returns whether the specified register can be overridden to represent another register using the REX-prefix
	is_overridable_register(register: large, size: large) {
		return size == 1 and register >= platform.x64.RSP and register <= platform.x64.RDI
	}

	# Summary:
	# Returns whether the specified register can be overridden to represent another register using the REX-prefix
	is_overridable_register(register: Register, size: large) {
		return is_overridable_register(register.identifier, size)
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write(module: EncoderModule, value: large) {
		module.output[module.position++] = value as byte
	}

	# Summary:
	# Writes the specified value to the specified position
	write(module: EncoderModule, position: normal, value: large) {
		module.output[position] = value as byte
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int16(module: EncoderModule, value: large) {
		(module.output + module.position).(small*)[0] = value as small
		module.position += sizeof(small)
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int32(module: EncoderModule, value: large) {
		(module.output + module.position).(normal*)[0] = value as normal
		module.position += sizeof(normal)
	}

	# Summary:
	# Writes the specified value to the specified position
	write_int32(module: EncoderModule, position: large, value: large) {
		(module.output + position).(normal*)[0] = value as normal
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int64(module: EncoderModule, value: large) {
		(module.output + module.position).(large*)[0] = value as large
		module.position += sizeof(large)
	}

	# Summary:
	# Writes the specified operation code
	write_operation(module: EncoderModule, operation: large) {
		next = operation & 0xFF
		write(module, next)

		next = operation & 0xFF00
		if next == 0 return
		write(module, next |> 8)

		next = operation & 0xFF0000
		if next == 0 return
		write(module, next |> 16)
	}

	# Summary:
	# Writes a REX-prefix if it is needed depending on the specified flags
	try_write_rex(module: EncoderModule, w: bool, r: bool, x: bool, b: bool, force: bool) {
		# Write the REX-prefix only if any of the flags in enabled
		flags = 0
		if w { flags |= REX_W }
		if r { flags |= REX_R }
		if x { flags |= REX_X }
		if b { flags |= REX_B }

		if flags == 0 and not force return

		write(module, REX_PREFIX | flags)
	}

	# Summary:
	# Writes a SIB-byte, which contains scale, index and base parameters
	write_sib(module: EncoderModule, scale: large, index: large, start: large) {
		write(module, (common.integer_log2(scale) <| 6) | (index <| 3) | start)
	}

	# Summary:
	# Writes a SIB-byte, which contains scale, index and base parameters
	write_sib(module: EncoderModule, scale: large, index: large, start: Register) {
		write_sib(module, scale, index, start.name)
	}

	# Summary:
	# Writes a SIB-byte, which contains scale, index and base parameters
	write_sib(module: EncoderModule, scale: large, index: Register, start: Register) {
		write_sib(module, scale, index.name, start.name)
	}

	# Summary:
	# Writes a register and a second register using the modrm-byte. Uses register-direct addressing mode. 
	write_register_and_register(module: EncoderModule, encoding: InstructionEncoding, first: Register, second: Register) {
		force = is_overridable_register(first, encoding.input_size_of_first) or is_overridable_register(second, encoding.input_size_of_second)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), false, is_extension_register(second), force)
		write_operation(module, encoding.operation)
		write(module, REGISTER_DIRECT_ADDRESSING_MODIFIER | (first.name <| 3) | second.name)
	}

	# Summary:
	# Writes a single register using the modrm-byte. Uses register-direct addressing mode. 
	write_single_register(module: EncoderModule, encoding: InstructionEncoding, first: Register) {
		force = is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, false, false, is_extension_register(first), force)
		write_operation(module, encoding.operation)
		write(module, REGISTER_DIRECT_ADDRESSING_MODIFIER | (encoding.modifier <| 3) | first.name)
	}

	# Summary:
	# Writes a register and a constant using the modrm-byte. The register is encoded into the rm-field.
	write_register_and_constant(module: EncoderModule, encoding: InstructionEncoding, first: Register, second: large, size: large) {
		force = is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, false, false, is_extension_register(first), force)

		write_operation(module, encoding.operation)
		write(module, REGISTER_DIRECT_ADDRESSING_MODIFIER | (encoding.modifier <| 3) | first.name)

		if size == 1 write(module, second)
		else size == 2 write_int16(module, second)
		else size == 4 write_int32(module, second)
		else size == 8 write_int64(module, second)
		else { abort('Invalid constant size') }
	}

	# Summary:
	# Writes a constant directly
	write_raw_constant(module: EncoderModule, value: large, size: large) {
		if size == 1 write(module, value)
		else size == 2 write_int16(module, value)
		else size == 4 write_int32(module, value)
		else size == 8 write_int64(module, value)
		else { abort('Invalid constant size') }
	}

	# Summary:
	# Defines the specified symbol and writes a modrm-byte which uses the symbol and the specified register 'first'
	private write_register_and_symbol(module: EncoderModule, encoding: InstructionEncoding, first: large, relocation: BinaryRelocation) {
		force = encoding.modifier == 0 and is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), false, false, force)

		write_operation(module, encoding.operation)
		write(module, ((first & 7) <| 3) | platform.x64.RBP) # Addressing: [rip+c32]

		relocation.offset = module.position
		module.memory_address_relocations.add(relocation)

		write_int32(module, 0) # Fill the offset with zero
	}

	# Summary:
	# Writes register and memory address operands
	write_register_and_memory_address(module: EncoderModule, encoding: InstructionEncoding, first: large, start: Register, offset: large) {
		#warning The register might also be the second operand
		force = encoding.modifier == 0 and is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), false, is_extension_register(start), force)

		write_operation(module, encoding.operation)

		# Convert [start+offset] => [start]
		# NOTE: Do not use this conversion if the start register is either RBP (0.101) or R13 (1.101)
		if offset == 0 and start.name != platform.x64.RBP and start.name != platform.x64.RSP {
			write(module, ((first & 7) <| 3) | start.name)
			return
		}

		if offset < TINY_MIN or offset > TINY_MAX {
			write(module, MEMORY_OFFSET32_MODIFIER | ((first & 7) <| 3) | start.name)

			# If the name of the register matches the name of the stack pointer, a SIB-byte is required to express the register
			if start.name == platform.x64.RSP write_sib(module, 0, platform.x64.RSP, platform.x64.RSP)

			write_int32(module, offset)
			return
		}

		write(module, MEMORY_OFFSET8_MODIFIER | ((first & 7) <| 3) | start.name)

		# If the name of the register matches the name of the stack pointer, a SIB-byte is required to express the register
		if start.name == platform.x64.RSP write_sib(module, 0, platform.x64.RSP, platform.x64.RSP)

		write(module, offset)
	}

	# Summary: Writes register and memory address operands
	write_register_and_memory_address(module: EncoderModule, encoding: InstructionEncoding, first: large, start: Register, index: Register, scale: large, offset: large) {
		# Convert [start+index*0+offset] => [start+offset]
		if scale == 0 {
			write_register_and_memory_address(module, encoding, first, start, offset)
			return
		}

		force = encoding.modifier == 0 and is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), is_extension_register(index), is_extension_register(start), force)

		write_operation(module, encoding.operation)

		# If the start register is RBP or R13, it is a special where the offset must be added even though it is zero
		if offset == 0 and start.name != platform.x64.RBP {
			write(module, ((first & 7) <| 3) | platform.x64.RSP)
			write_sib(module, scale, index, start)
			return
		}

		if offset < TINY_MIN or offset > TINY_MAX {
			write(module, MEMORY_OFFSET32_MODIFIER | ((first & 7) <| 3) | platform.x64.RSP)
			write_sib(module, scale, index, start)
			write_int32(module, offset)
			return
		}

		write(module, MEMORY_OFFSET8_MODIFIER | ((first & 7) <| 3) | platform.x64.RSP)
		write_sib(module, scale, index, start)
		write(module, offset)
	}

	# Summary:
	# Writes register and memory address operands
	write_register_and_memory_address(module: EncoderModule, encoding: InstructionEncoding, first: large, index: Register, scale: large, offset: large) {
		# Convert [index*0+offset] => [offset]
		if scale == 0 {
			write_register_and_memory_address(module, encoding, first, offset)
			return
		}

		# Convert [index*1+offset] => [index+offset]
		if scale == 1 {
			write_register_and_memory_address(module, encoding, first, index, offset)
			return
		}

		force = encoding.modifier == 0 and is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), is_extension_register(index), false, force)

		write_operation(module, encoding.operation)

		write(module, ((first & 7) <| 3) | platform.x64.RSP)
		write_sib(module, scale, index.name, platform.x64.RBP)
		write_int32(module, offset)
	}

	# Summary:
	# Writes register and memory address operands
	write_register_and_memory_address(module: EncoderModule, encoding: InstructionEncoding, first: large, offset: large) {
		force = encoding.modifier == 0 and is_overridable_register(first, encoding.input_size_of_first)
		try_write_rex(module, encoding.is_64bit, is_extension_register(first), false, false, force)

		write_operation(module, encoding.operation)
		write(module, ((first & 7) <| 3) | platform.x64.RSP)
		write_sib(module, 0, platform.x64.RSP, platform.x64.RBP)
		write_int32(module, offset)
	}

	# Summary:
	# Returns a object that describes the specified memory address
	get_memory_address_descriptor(handle: Handle) {
		return when(handle.instance) {
			INSTANCE_MEMORY => MemoryAddressDescriptor(handle.(MemoryHandle).get_start(), none as Register, 0, handle.(MemoryHandle).get_offset()),
			INSTANCE_COMPLEX_MEMORY => MemoryAddressDescriptor(handle.(ComplexMemoryHandle).get_start(), handle.(ComplexMemoryHandle).get_index(), handle.(ComplexMemoryHandle).stride, handle.(ComplexMemoryHandle).get_offset()),
			INSTANCE_EXPRESSION => MemoryAddressDescriptor(handle.(ExpressionHandle).get_start(), handle.(ExpressionHandle).get_index(), handle.(ExpressionHandle).multiplier, handle.(ExpressionHandle).get_offset()),
			INSTANCE_STACK_ALLOCATION => MemoryAddressDescriptor(handle.(StackAllocationHandle).unit.get_stack_pointer(), none as Register, 1, handle.(StackAllocationHandle).get_absolute_offset()),
			INSTANCE_STACK_MEMORY => MemoryAddressDescriptor(handle.(StackMemoryHandle).get_start(), none as Register, 1, handle.(StackMemoryHandle).get_offset()),
			INSTANCE_DATA_SECTION => MemoryAddressDescriptor(handle.(DataSectionHandle).identifier, handle.(DataSectionHandle).modifier, handle.(DataSectionHandle).offset),
			INSTANCE_CONSTANT_DATA_SECTION => MemoryAddressDescriptor(handle.(ConstantDataSectionHandle).identifier, handle.(DataSectionHandle).modifier, handle.(DataSectionHandle).offset),
			INSTANCE_STACK_VARIABLE => MemoryAddressDescriptor(handle.(StackVariableHandle).get_start(), none as Register, 1, handle.(StackVariableHandle).get_offset()),
			INSTANCE_TEMPORARY_MEMORY => MemoryAddressDescriptor(handle.(StackMemoryHandle).get_start(), none as Register, 1, handle.(StackMemoryHandle).get_offset()),
			else => abort('Unsupported handle') as MemoryAddressDescriptor
		}
	}

	# Summary:
	# Returns whether the specified handle passes the configured filter
	private passes_filter(type: large, filter: small, value: Handle) {
		return when(type) {
			ENCODING_FILTER_TYPE_REGISTER => value.instance == INSTANCE_REGISTER
			ENCODING_FILTER_TYPE_STANDARD_REGISTER => value.type == HANDLE_REGISTER
			ENCODING_FILTER_TYPE_MEDIA_REGISTER => value.type == HANDLE_MEDIA_REGISTER
			ENCODING_FILTER_TYPE_SPECIFIC_REGISTER => {
				if value.instance != INSTANCE_REGISTER return false
				filter == value.(RegisterHandle).register.identifier
			}
			ENCODING_FILTER_TYPE_MEMORY_ADDRESS => value.type == HANDLE_MEMORY
			ENCODING_FILTER_TYPE_CONSTANT => value.type == HANDLE_CONSTANT
			ENCODING_FILTER_TYPE_SPECIFIC_CONSTANT => {
				if value.instance != INSTANCE_CONSTANT return false
				filter == value.(ConstantHandle).value
			}
			ENCODING_FILTER_TYPE_SIGNLESS_CONSTANT => value.type == HANDLE_CONSTANT
			ENCODING_FILTER_TYPE_EXPRESSION => value.type == HANDLE_EXPRESSION
			ENCODING_FILTER_TYPE_LABEL => value.instance == INSTANCE_DATA_SECTION and value.(DataSectionHandle).address
			else => false
		}
	}

	# Summary:
	# Returns how many bits are required for encoding the specified integer
	get_number_of_bits_for_encoding(value: large) {
		if value == LARGE_MIN return 64

		x = value
		if x < 0 { x = -x }

		if x > U32_MAX return 64
		else x > U16_MAX return 32
		else x > U8_MAX return 16
		else return 8
	}

	# Summary:
	# Returns whether the specified handle passes the configured filter
	private passes_size(value: Handle, filter: large, size: small) {
		if value.instance == INSTANCE_CONSTANT {
			if filter == ENCODING_FILTER_TYPE_CONSTANT return value.(ConstantHandle).bits / 8 <= size

			# Do not care about the sign, just verify all the bits can be stored in the specified size
			return get_number_of_bits_for_encoding(value.(ConstantHandle).value) / 8 <= size
		}

		return value.size == size
	}

	# Summary:
	# Finds an instruction encoding that takes none parameters and matches the specified type
	find_encoding(type: large) {
		encodings = platform.x64.parameterless_encodings[type]
		if encodings.size == 0 abort('Could not find instruction encoding')

		return encodings[0]
	}

	# Summary:
	# Finds an instruction encoding that takes one parameter and is suitable for the specified handle
	find_encoding(type: large, first: Handle) {
		encodings = platform.x64.single_parameter_encodings[type]

		loop encoding in encodings {
			if not passes_size(first, encoding.filter_type_of_first, encoding.input_size_of_first) continue
			if passes_filter(encoding.filter_type_of_first, encoding.filter_of_first, first) return encoding
		}

		abort('Could not find instruction encoding')
	}

	# Summary:
	# Finds an instruction encoding that takes two parameters and is suitable for the specified handles
	find_encoding(type: large, first: Handle, second: Handle) {
		encodings = platform.x64.dual_parameter_encodings[type]

		loop encoding in encodings {
			if not passes_size(first, encoding.filter_type_of_first, encoding.input_size_of_first) or not passes_size(second, encoding.filter_type_of_second, encoding.input_size_of_second) continue
			if not passes_filter(encoding.filter_type_of_first, encoding.filter_of_first, first) or not passes_filter(encoding.filter_type_of_second, encoding.filter_of_second, second) continue
			return encoding
		}

		abort('Could not find instruction encoding')
	}

	# Summary:
	# Finds an instruction encoding that takes three parameters and is suitable for the specified handles
	find_encoding(type: large, first: Handle, second: Handle, third: Handle) {
		encodings = platform.x64.triple_parameter_encodings[type]

		loop encoding in encodings {
			if not passes_size(first, encoding.filter_type_of_first, encoding.input_size_of_first) or not passes_size(second, encoding.filter_type_of_second, encoding.input_size_of_second) or not passes_size(third, encoding.filter_type_of_third, encoding.input_size_of_third) continue
			if not passes_filter(encoding.filter_type_of_first, encoding.filter_of_first, first) or not passes_filter(encoding.filter_type_of_second, encoding.filter_of_second, second) or not passes_filter(encoding.filter_type_of_third, encoding.filter_of_third, third) continue
			return encoding
		}

		abort('Could not find instruction encoding')
	}

	# Summary:
	# Returns the unique operation index of the specified instruction.
	# This function will be removed, because instruction will use operation indices instead of text identifiers in the future.
	get_instruction_index(instruction: Instruction, operation: String) {
		#warning Optimize this function
		if instruction.type == INSTRUCTION_LABEL return platform.x64._LABEL

		# Parameterless instructions
		if operation == platform.shared.RETURN return platform.x64._RET
		if operation == platform.x64.EXTEND_QWORD return platform.x64._CQO
		if operation == platform.x64.SYSTEM_CALL return platform.x64._SYSCALL
		if operation == 'fld1' return platform.x64._FLD1
		if operation == 'fyl2x' return platform.x64._FYL2x
		if operation == 'f2xm1' return platform.x64._F2XM1
		if operation == 'faddp' return platform.x64._FADDP
		if operation == 'fcos' return platform.x64._FCOS
		if operation == 'fsin' return platform.x64._FSIN
		if operation == platform.shared.NOP return platform.x64._NOP

		# Single parameter instructions
		if operation == platform.x64.PUSH return platform.x64._PUSH
		if operation == platform.x64.POP return platform.x64._POP
		if operation == platform.x64.JUMP_ABOVE return platform.x64._JA
		if operation == platform.x64.JUMP_ABOVE_OR_EQUALS return platform.x64._JAE
		if operation == platform.x64.JUMP_BELOW return platform.x64._JB
		if operation == platform.x64.JUMP_BELOW_OR_EQUALS return platform.x64._JBE
		if operation == platform.x64.JUMP_EQUALS return platform.x64._JE
		if operation == platform.x64.JUMP_GREATER_THAN return platform.x64._JG
		if operation == platform.x64.JUMP_GREATER_THAN_OR_EQUALS return platform.x64._JGE
		if operation == platform.x64.JUMP_LESS_THAN return platform.x64._JL
		if operation == platform.x64.JUMP_LESS_THAN_OR_EQUALS return platform.x64._JLE
		if operation == platform.x64.JUMP return platform.x64._JMP
		if operation == platform.x64.JUMP_NOT_EQUALS return platform.x64._JNE
		if operation == platform.x64.JUMP_NOT_ZERO return platform.x64._JNZ
		if operation == platform.x64.JUMP_ZERO return platform.x64._JZ
		if operation == platform.x64.CALL return platform.x64._CALL
		if operation == 'fild' return platform.x64._FILD
		if operation == 'fld' return platform.x64._FLD
		if operation == 'fistp' return platform.x64._FISTP
		if operation == 'fstp' return platform.x64._FSTP
		if operation == platform.shared.NEGATE return platform.x64._NEG
		if operation == platform.x64.NOT return platform.x64._NOT
		if operation == platform.x64.CONDITIONAL_SET_ABOVE return platform.x64._SETA
		if operation == platform.x64.CONDITIONAL_SET_ABOVE_OR_EQUALS return platform.x64._SETAE
		if operation == platform.x64.CONDITIONAL_SET_BELOW return platform.x64._SETB
		if operation == platform.x64.CONDITIONAL_SET_BELOW_OR_EQUALS return platform.x64._SETBE
		if operation == platform.x64.CONDITIONAL_SET_EQUALS return platform.x64._SETE
		if operation == platform.x64.CONDITIONAL_SET_GREATER_THAN return platform.x64._SETG
		if operation == platform.x64.CONDITIONAL_SET_GREATER_THAN_OR_EQUALS return platform.x64._SETGE
		if operation == platform.x64.CONDITIONAL_SET_LESS_THAN return platform.x64._SETL
		if operation == platform.x64.CONDITIONAL_SET_LESS_THAN_OR_EQUALS return platform.x64._SETLE
		if operation == platform.x64.CONDITIONAL_SET_NOT_EQUALS return platform.x64._SETNE
		if operation == platform.x64.CONDITIONAL_SET_NOT_ZERO return platform.x64._SETNZ
		if operation == platform.x64.CONDITIONAL_SET_ZERO return platform.x64._SETZ

		# Dual parameter instructions
		if operation == platform.shared.MOVE return platform.x64._MOV
		if operation == platform.shared.ADD return platform.x64._ADD
		if operation == platform.shared.SUBTRACT return platform.x64._SUB
		if operation == platform.x64.SIGNED_MULTIPLY return platform.x64._IMUL
		if operation == platform.x64.UNSIGNED_MULTIPLY return platform.x64._MUL
		if operation == platform.x64.SIGNED_DIVIDE return platform.x64._IDIV
		if operation == platform.x64.UNSIGNED_DIVIDE return platform.x64._DIV
		if operation == platform.x64.SHIFT_LEFT return platform.x64._SAL
		if operation == platform.x64.SHIFT_RIGHT return platform.x64._SAR
		if operation == platform.x64.UNSIGNED_CONVERSION_MOVE return platform.x64._MOVZX
		if operation == platform.x64.SIGNED_CONVERSION_MOVE return platform.x64._MOVSX
		if operation == platform.x64.SIGNED_DWORD_CONVERSION_MOVE return platform.x64._MOVSXD
		if operation == platform.x64.EVALUATE return platform.x64._LEA
		if operation == platform.shared.COMPARE return platform.x64._CMP
		if operation == platform.x64.DOUBLE_PRECISION_ADD return platform.x64._ADDSD
		if operation == platform.x64.DOUBLE_PRECISION_SUBTRACT return platform.x64._SUBSD
		if operation == platform.x64.DOUBLE_PRECISION_MULTIPLY return platform.x64._MULSD
		if operation == platform.x64.DOUBLE_PRECISION_DIVIDE return platform.x64._DIVSD
		if operation == platform.x64.DOUBLE_PRECISION_MOVE return platform.x64._MOVSD
		if operation == platform.x64.RAW_MEDIA_REGISTER_MOVE return platform.x64._MOVQ
		if operation == platform.x64.CONVERT_INTEGER_TO_DOUBLE_PRECISION return platform.x64._CVTSI2SD
		if operation == platform.x64.CONVERT_DOUBLE_PRECISION_TO_INTEGER return platform.x64._CVTTSD2SI
		if operation == platform.shared.AND return platform.x64._AND
		if operation == platform.x64.XOR return platform.x64._XOR
		if operation == platform.x64.OR return platform.x64._OR
		if operation == platform.x64.DOUBLE_PRECISION_COMPARE return platform.x64._COMISD
		if operation == platform.x64.TEST return platform.x64._TEST
		if operation == platform.x64.UNALIGNED_XMMWORD_MOVE return platform.x64._MOVUPS
		if operation == 'sqrtsd' return platform.x64._SQRTSD
		if operation == platform.x64.EXCHANGE return platform.x64._XCHG
		if operation == platform.x64.MEDIA_REGISTER_BITWISE_XOR return platform.x64._PXOR
		if operation == platform.x64.SHIFT_RIGHT_UNSIGNED return platform.x64._SHR
		if operation == platform.x64.CONDITIONAL_MOVE_ABOVE return platform.x64._CMOVA
		if operation == platform.x64.CONDITIONAL_MOVE_ABOVE_OR_EQUALS return platform.x64._CMOVAE
		if operation == platform.x64.CONDITIONAL_MOVE_BELOW return platform.x64._CMOVB
		if operation == platform.x64.CONDITIONAL_MOVE_BELOW_OR_EQUALS return platform.x64._CMOVBE
		if operation == platform.x64.CONDITIONAL_MOVE_EQUALS return platform.x64._CMOVE
		if operation == platform.x64.CONDITIONAL_MOVE_GREATER_THAN return platform.x64._CMOVG
		if operation == platform.x64.CONDITIONAL_MOVE_GREATER_THAN_OR_EQUALS return platform.x64._CMOVGE
		if operation == platform.x64.CONDITIONAL_MOVE_LESS_THAN return platform.x64._CMOVL
		if operation == platform.x64.CONDITIONAL_MOVE_LESS_THAN_OR_EQUALS return platform.x64._CMOVLE
		if operation == platform.x64.CONDITIONAL_MOVE_NOT_EQUALS return platform.x64._CMOVNE
		if operation == platform.x64.CONDITIONAL_MOVE_NOT_ZERO return platform.x64._CMOVNZ
		if operation == platform.x64.CONDITIONAL_MOVE_ZERO return platform.x64._CMOVZ
		if operation == platform.x64.DOUBLE_PRECISION_XOR return platform.x64._XORPD
		if operation == platform.x64.EXCHANGE_ADD return platform.x64._XADD

		return -1
	}

	# Summary:
	# Handles debug line information instructions and other similar instructions
	process_debug_instructions(module: EncoderModule, instruction: Instruction) {
		if instruction.type == INSTRUCTION_DEBUG_BREAK {
			position = instruction.(DebugBreakInstruction).position
			module.debug_line_information.add(EncoderDebugLineInformation(module.position, position.friendly_line, position.friendly_character))
			module.debug_frame_information.add(EncoderDebugFrameInformation(ENCODER_DEBUG_FRAME_INFORMATION_TYPE_ADVANCE, module.position))
			return
		}

		if instruction.type == INSTRUCTION_DEBUG_START {
			symbol = instruction.parameters[0].value.(DataSectionHandle).identifier
			module.debug_frame_information.add(EncoderDebugFrameStartInformation(module.position, symbol))
			return
		}

		if instruction.type == INSTRUCTION_DEBUG_FRAME_OFFSET {
			offset = instruction.parameters[0].value.(ConstantHandle).value
			module.debug_frame_information.add(EncoderDebugFrameOffsetInformation(module.position, offset))
			return
		}

		if instruction.type == INSTRUCTION_DEBUG_END {
			module.debug_frame_information.add(EncoderDebugFrameInformation(ENCODER_DEBUG_FRAME_INFORMATION_TYPE_END, module.position))
			return
		}
	}

	# Summary: Returns the primary operation of the specified instruction by discarding any instruction prefixes
	get_primary_operation(instruction: Instruction) {
		i = instruction.operation.last_index_of(` `)
		if i < 0 return instruction.operation
		return instruction.operation.slice(i + 1)
	}

	write_instruction(module: EncoderModule, instruction: Instruction) {
		parameters = List<InstructionParameter>()

		loop parameter in instruction.parameters {
			if parameter.is_hidden continue
			parameters.add(parameter)
		}

		encoding = none as InstructionEncoding
		locked = instruction.operation.starts_with('lock ')
		operation = get_primary_operation(instruction)
		identifier = get_instruction_index(instruction, operation)

		if identifier < 0 {
			process_debug_instructions(module, instruction)
			return
		}

		# Find the correct encoding
		if parameters.size == 0 { encoding = find_encoding(identifier) }
		else parameters.size == 1 { encoding = find_encoding(identifier, parameters[0].value) }
		else parameters.size == 2 { encoding = find_encoding(identifier, parameters[0].value, parameters[1].value) }
		else parameters.size == 3 { encoding = find_encoding(identifier, parameters[0].value, parameters[1].value, parameters[2].value) }
		else { encoding = InstructionEncoding(0) }

		# Write the lock prefix if necessary
		if locked write(module, LOCK_PREFIX)

		# Write the instruction prefix if needed
		if encoding.prefix != 0 write(module, encoding.prefix)

		route = encoding.route

		if route == ENCODING_ROUTE_RRC {
			write_register_and_register(module, encoding, parameters[0].value.(RegisterHandle).register, parameters[1].value.(RegisterHandle).register)
			write_raw_constant(module, parameters[2].value.(ConstantHandle).value, encoding.input_size_of_third)
		}
		else route == ENCODING_ROUTE_RMC {
			destination = parameters[0].value.(RegisterHandle).register
			descriptor = get_memory_address_descriptor(parameters[1].value)

			if descriptor.relocation != none write_register_and_symbol(module, encoding, destination.identifier, descriptor.relocation)
			else descriptor.start != none and descriptor.index != none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.start, descriptor.index, descriptor.stride, descriptor.offset)
			else descriptor.start != none and descriptor.index == none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.start, descriptor.offset)
			else descriptor.start == none and descriptor.index != none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.index, descriptor.stride, descriptor.offset)
			else write_register_and_memory_address(module, encoding, destination.identifier, descriptor.offset)

			write_raw_constant(module, parameters[2].value.(ConstantHandle).value, encoding.input_size_of_third)

			# Symbol relocations are computed from the end of the instruction
			if descriptor.relocation != none { descriptor.relocation.addend -= module.position - descriptor.relocation.offset }
		}
		else route == ENCODING_ROUTE_DRC {
			write_register_and_register(module, encoding, parameters[0].value.(RegisterHandle).register, parameters[0].value.(RegisterHandle).register)
			write_raw_constant(module, parameters[1].value.(ConstantHandle).value, encoding.input_size_of_second)
		}
		else route == ENCODING_ROUTE_RR {
			write_register_and_register(module, encoding, parameters[0].value.(RegisterHandle).register, parameters[1].value.(RegisterHandle).register)
		}
		else route == ENCODING_ROUTE_RC {
			write_register_and_constant(module, encoding, parameters[0].value.(RegisterHandle).register, parameters[1].value.(ConstantHandle).value, encoding.input_size_of_second)
		}
		else route == ENCODING_ROUTE_RM {
			destination = parameters[0].value.(RegisterHandle).register
			descriptor = get_memory_address_descriptor(parameters[1].value)

			if descriptor.relocation != none write_register_and_symbol(module, encoding, destination.identifier, descriptor.relocation)
			else descriptor.start != none and descriptor.index != none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.start, descriptor.index, descriptor.stride, descriptor.offset)
			else descriptor.start != none and descriptor.index == none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.start, descriptor.offset)
			else descriptor.start == none and descriptor.index != none write_register_and_memory_address(module, encoding, destination.identifier, descriptor.index, descriptor.stride, descriptor.offset)
			else { write_register_and_memory_address(module, encoding, destination.identifier, descriptor.offset) }

			# Symbol relocations are computed from the end of the instruction
			if descriptor.relocation != none { descriptor.relocation.addend -= module.position - descriptor.relocation.offset }
		}
		else route == ENCODING_ROUTE_MR {
			source = parameters[1].value.(RegisterHandle).register
			descriptor = get_memory_address_descriptor(parameters[0].value)

			if descriptor.relocation != none write_register_and_symbol(module, encoding, source.identifier, descriptor.relocation)
			else descriptor.start != none and descriptor.index != none write_register_and_memory_address(module, encoding, source.identifier, descriptor.start, descriptor.index, descriptor.stride, descriptor.offset)
			else descriptor.start != none and descriptor.index == none write_register_and_memory_address(module, encoding, source.identifier, descriptor.start, descriptor.offset)
			else descriptor.start == none and descriptor.index != none write_register_and_memory_address(module, encoding, source.identifier, descriptor.index, descriptor.stride, descriptor.offset)
			else { write_register_and_memory_address(module, encoding, source.identifier, descriptor.offset) }

			# Symbol relocations are computed from the end of the instruction
			if descriptor.relocation != none { descriptor.relocation.addend -= module.position - descriptor.relocation.offset }
		}
		else route == ENCODING_ROUTE_MC {
			descriptor = get_memory_address_descriptor(parameters[0].value)

			if descriptor.relocation != none write_register_and_symbol(module, encoding, encoding.modifier, descriptor.relocation)
			else descriptor.start != none and descriptor.index != none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.start, descriptor.index, descriptor.stride, descriptor.offset)
			else descriptor.start != none and descriptor.index == none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.start, descriptor.offset)
			else descriptor.start == none and descriptor.index != none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.index, descriptor.stride, descriptor.offset)
			else { write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.offset) }

			write_raw_constant(module, parameters[1].value.(ConstantHandle).value, encoding.input_size_of_second)

			# Symbol relocations are computed from the end of the instruction
			if descriptor.relocation != none { descriptor.relocation.addend -= module.position - descriptor.relocation.offset }
		}
		else route == ENCODING_ROUTE_OC {
			first = parameters[0].value.(RegisterHandle).register
			force = is_overridable_register(first, encoding.input_size_of_first)
			try_write_rex(module, encoding.is_64bit, false, false, is_extension_register(first), force)
			write_operation(module, encoding.operation + first.name)
			write_raw_constant(module, parameters[1].value.(ConstantHandle).value, encoding.input_size_of_first)
		}
		else route == ENCODING_ROUTE_R {
			write_single_register(module, encoding, parameters[0].value.(RegisterHandle).register)
		}
		else route == ENCODING_ROUTE_M {
			destination = parameters[0].value
			descriptor = get_memory_address_descriptor(destination)

			if descriptor.relocation != none write_register_and_symbol(module, encoding, encoding.modifier, descriptor.relocation)
			else descriptor.start != none and descriptor.index != none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.start, descriptor.index, descriptor.stride, descriptor.offset)
			else descriptor.start != none and descriptor.index == none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.start, descriptor.offset)
			else descriptor.start == none and descriptor.index != none write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.index, descriptor.stride, descriptor.offset)
			else { write_register_and_memory_address(module, encoding, encoding.modifier, descriptor.offset) }

			# Symbol relocations are computed from the end of the instruction
			if descriptor.relocation != none { descriptor.relocation.addend -= module.position - descriptor.relocation.offset }
		}
		else route == ENCODING_ROUTE_SC {
			try_write_rex(module, encoding.is_64bit, false, false, false, false)
			write_operation(module, encoding.operation)
			write_raw_constant(module, parameters[1].value.(ConstantHandle).value, encoding.input_size_of_second)
		}
		else route == ENCODING_ROUTE_O {
			first = parameters[0].value.(RegisterHandle).register
			force = is_overridable_register(first, encoding.input_size_of_first)
			try_write_rex(module, encoding.is_64bit, false, false, is_extension_register(first), force)
			write_operation(module, encoding.operation + first.name)
		}
		else route == ENCODING_ROUTE_SO {
			second = parameters[1].value.(RegisterHandle).register
			force = is_overridable_register(second, encoding.input_size_of_second)
			try_write_rex(module, encoding.is_64bit, false, false, is_extension_register(second), force)
			write_operation(module, encoding.operation + second.name)
		}
		else route == ENCODING_ROUTE_D {
			write_operation(module, encoding.operation)

			if operation == platform.x64.CALL {
				label = Label(instruction.parameters[0].value.(DataSectionHandle).identifier)
				module.calls.add(LabelUsageItem(LABEL_USAGE_TYPE_CALL, module.position, label))
			}

			write_int32(module, 0)
		}
		else route == ENCODING_ROUTE_L {
			module.labels.add(LabelUsageItem(LABEL_USAGE_TYPE_LABEL, module.position, instruction.(LabelInstruction).label))
		}
		else route == ENCODING_ROUTE_NONE {
			try_write_rex(module, encoding.is_64bit, false, false, false, false)
			write_operation(module, encoding.operation)
		}
		else {
			abort('Unsupported encoding route')
		}
	}

	# Summary:
	# Creates modules from the specified instructions by giving each jump its own module.
	# Example:
	# [Start of module 1]
	# ...
	# Jump L0
	# [End of module 1]
	# [Start of module 2]
	# ...
	# L0:
	# ...
	# Jump L1
	# [End of module 2]
	create_modules(instructions: List<Instruction>) {
		modules = List<EncoderModule>()
		start = 0

		loop {
			#warning You might want to optimize the detection of a jump
			end = 0

			loop (i = start, i < instructions.size, i++) {
				instruction = instructions[i]

				# Verify that the instruction represents a jump
				if instruction.type != INSTRUCTION_JUMP and not AssemblyParser.is_jump(instruction.operation) continue

				# Now ensure that it jumps to a label instead of using registers or memory addresses
				destination = instruction.parameters[0].value
				if destination.instance != INSTANCE_DATA_SECTION continue

				end = i + 1
				stop
			}

			if end != 0 {
				label = Label(instructions[end - 1].parameters[0].value.(DataSectionHandle).identifier)
				is_conditional_jump = not (instructions[end - 1].operation == platform.x64.JUMP)

				module = EncoderModule(label, is_conditional_jump)
				module.instructions.add_all(instructions.slice(start, end))
				module.output = allocate(module.get_max_instruction_buffer_size())
				module.index = modules.size
				modules.add(module)
			}
			else {
				module = EncoderModule()
				module.instructions.add_all(instructions.slice(start, instructions.size))
				module.output = allocate(module.get_max_instruction_buffer_size())
				module.index = modules.size
				modules.add(module)
				stop
			}

			start = end
		}

		return modules
	}

	# Summary:
	# Encodes each module using tasks
	encode(modules: List<EncoderModule>) {
		file = SourceFile(String(TEMPORARY_ASSEMBLY_FILE), String.empty, 0)

		loop (i = 0, i < modules.size, i++) {
			module = modules[i]
			parser = AssemblyParser()

			# Single threaded version:
			loop instruction in module.instructions {
				if not instruction.is_manual {
					write_instruction(module, instruction)
					continue
				}

				# Parse the assembly code and then reset the parser for next use
				parser.parse(file, instruction.operation)

				loop subinstruction in parser.instructions {
					write_instruction(module, subinstruction)
				}

				parser.reset()
			}
		}
	}

	# Summary:
	# Finds all labels from the specified modules and gathers them into the specified label dictionary
	load_labels(modules: List<EncoderModule>, labels: Map<Label, LabelDescriptor>) {
		loop module in modules {
			loop item in module.labels {
				labels.add(item.label, LabelDescriptor(module, item.position))
			}
		}
	}

	# Summary:
	# Returns whether currently an extended jump is needed between the specified jump and its destination label
	is_long_jump_needed(modules: List<EncoderModule>, labels: Map<Label, LabelDescriptor>, module: EncoderModule, position: large) {
		# If the label does not exist in the specified labels, it must be an external label which are assumed to require long jumps
		if not labels.contains_key(module.jump) return true
		descriptor = labels[module.jump]

		if module.index == descriptor.module.index {
			difference = descriptor.position - position
			return difference < TINY_MIN or difference > TINY_MAX
		}
		else module.index < descriptor.module.index {
			start = module.index
			end = descriptor.module.index

			# Start             Distance 1         Distance n - 1      Distance n        End
			# [ ... Jump L0 ] [  Module 1  ] ... [  Module n - 1  ] [ ............ L0: ... ]
			distance = 0
			distance += descriptor.position # Distance n

			# Distances [1, n - 1]
			loop (i = start + 1, i < end, i++) { distance += modules[i].position }

			return distance < TINY_MIN or distance > TINY_MAX
		}
		else {
			start = descriptor.module.index
			end = module.index

			# Start          Distance 0    Distance 1         Distance n - 1      Distance n        End
			# [ ... L0: ...............] [  Module 1  ] ... [  Module n - 1  ] [ ............ Jump L0 ]
			distance = 0
			distance += descriptor.module.position - descriptor.position # Distance 0
			distance += position # Distance n

			# Distances [1, n - 1]
			loop (i = start + 1 ,i < end, i++) { distance += modules[i].position }

			distance = -distance
			return distance < TINY_MIN or distance > TINY_MAX
		}
	}

	# Summary:
	# Returns the distance that specified module jumps. The unit of distance is one module.
	# If the specified module does not have a jump, this function returns zero.
	# If the specified module jumps to an external label, this function returns int.MaxValue.
	private get_module_jump_distance(module: EncoderModule, labels: Map<Label, LabelDescriptor>) {
		if module.jump === none return 0
		if not labels.contains_key(module.jump) return NORMAL_MAX
		label = labels[module.jump]

		return abs(label.module.index - module.index)
	}

	# Summary:
	# Goes through the specified modules and decides the jump sizes
	complete_modules(modules: List<EncoderModule>, labels: Map<Label, LabelDescriptor>) {
		# Order the modules so that shorter jumps are completed first
		# NOTE: This should reduce the error of approximated jump distances, because if shorter jumps are completed first, there should be less uncompleted jumps between longer jumps
		sorted_modules = List<EncoderModule>(modules)
		sort<EncoderModule>(sorted_modules, (a: EncoderModule, b: EncoderModule) -> instruction_encoder.get_module_jump_distance(a, labels) - instruction_encoder.get_module_jump_distance(b, labels))

		loop module in sorted_modules {
			if module.jump === none continue

			# Express the current position as if the module jump was an 8-bit jump
			position = module.position - (JUMP_OFFSET32_SIZE - JUMP_OFFSET8_SIZE)
			if module.is_conditional_jump { position = module.position - (CONDITIONAL_JUMP_OFFSET32_SIZE - CONDITIONAL_JUMP_OFFSET8_SIZE) }

			if not is_long_jump_needed(modules, labels, module, position) {
				if module.is_conditional_jump {
					# Remove the 0x0F-byte
					# 32-bit conditional jumps: 0F $(Operation code) $(32-bit offset)
					# 8-bit conditional jumps:  $(Operation code - 0x10) $(8-bit offset)
					# NOTE: No need to worry about the offset, because it is not computed yet
					module.output[position - 2] = (module.output[position - 1] - 0x10) as byte
				}
				else {
					# Change the operation code in order to represent an 8-bit jump
					module.output[position - 2] = JUMP_OFFSET8_OPERATION_CODE
				}

				module.position = position
				module.is_short_jump = true
			}
		}
	}

	# Summary:
	# Computes the 'absolute positions' of all modules relative to the start of the first module
	complete_module_positions(modules: List<EncoderModule>) {
		# Align all modules
		position = 0

		loop module in modules {
			module.start = position
			position += module.position
		}
	}

	# Summary:
	# Finds all jumps and calls and write the their offsets to the binary output
	write_offsets(modules: List<EncoderModule>, labels: Map<Label, LabelDescriptor>) {
		# Jumps:
		loop module in modules {
			if module.jump === none or not labels.contains_key(module.jump) continue
			descriptor = labels[module.jump]

			from = module.start + module.position
			to = descriptor.absolute_position
			offset = to - from

			if module.is_short_jump write(module, module.position - sizeof(byte), offset)
			else { write_int32(module, module.position - sizeof(normal), offset) }
		}

		# Calls:
		loop module in modules {
			loop (i = module.calls.size - 1, i >= 0, i--) {
				call = module.calls[i]

				if not labels.contains_key(call.label) continue
				descriptor = labels[call.label]

				# Move the start to the end of the call instruction using the offset 'sizeof(normal)'
				from = module.start + call.position + sizeof(normal)
				to = descriptor.absolute_position
				offset = to - from

				write_int32(module, call.position, offset)

				# Remove the call since it is now resolved
				module.calls.remove_at(i)
			}
		}
	}

	# Summary:
	# Creates a text section and exports the specified labels as symbols
	build(modules: List<EncoderModule>, labels: Map<Label, LabelDescriptor>, debug_file: String) {
		# Mesh all the module binaries into one large binary
		bytes = 0
		loop module in modules { bytes += module.position }

		binary = Array<byte>(bytes)
		position = 0

		loop module in modules {
			copy(module.output, module.position, binary.data + position)
			position += module.position
		}

		# Create the text section objects
		symbols = Map<String, BinarySymbol>()
		relocations = List<BinaryRelocation>()

		section = BinarySection(String(TEXT_SECTION), BINARY_SECTION_TYPE_TEXT, binary)
		section.flags = BINARY_SECTION_FLAGS_EXECUTE | BINARY_SECTION_FLAGS_ALLOCATE
		section.symbols = symbols
		section.relocations = relocations

		# Add local labels
		loop iterator in labels {
			symbol = BinarySymbol(iterator.key.name, iterator.value.absolute_position, false)
			symbol.section = section
			symbols.add(symbol.name, symbol)
		}

		# Generate relocations for jumps, which use external symbols
		loop module in modules {
			if module.jump === none continue

			# Load the name of destination label
			name = module.jump.name
			symbol = none as BinarySymbol

			if symbols.contains_key(name) {
				symbol = symbols[name]
			}
			else {
				symbol = BinarySymbol(name, 0, true)
				symbol.section = section
				symbols.add(symbol.name, symbol)
			}

			# Skip local module jumps, because the offset is known and computed already, therefore relocation is not needed
			if not symbol.external continue

			# Use offset -4, because the jump offset is measured from the end of the jump instruction, which is four bytes after the start of the relocatable symbol
			relocation = BinaryRelocation(symbol, module.start + module.position - 4, -4, BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE)
			relocation.section = section

			relocations.add(relocation)
		}

		# Generate relocations for calls, which use external symbols
		# NOTE: At this stage all module calls use external symbols, because those which used local symbols were removed
		loop module in modules {
			loop call in module.calls {
				symbol = none as BinarySymbol

				if symbols.contains_key(call.label.name) {
					symbol = symbols[call.label.name]
				}
				else {
					symbol = BinarySymbol(call.label.name, 0, true)
					symbol.section = section
					symbols.add(symbol.name, symbol)
				}

				# Use offset -4, because the call offset is measured from the end of the call instruction, which is four bytes after the start of the relocatable symbol
				relocation = BinaryRelocation(symbol, module.start + call.position, -4, data_access_modifier_to_relocation_type(call.modifier))
				relocation.section = section

				relocations.add(relocation)
			}
		}

		# Generate relocations for memory addresses in the machine code
		loop module in modules {
			loop relocation in module.memory_address_relocations {
				# Try to find the local version of the relocation symbol, if it is not found, add the relocation symbol as an external symbol
				if symbols.contains_key(relocation.symbol.name) { relocation.symbol = symbols[relocation.symbol.name] }
				else { symbols.add(relocation.symbol.name, relocation.symbol) }

				relocation.offset += module.start
				relocation.section = section
				relocations.add(relocation)
			}
		}

		# Return now, if no debugging information is needed
		if debug_file === none return EncoderOutput(section, symbols, relocations, none as DebugFrameEncoderModule, none as DebugLineEncoderModule)

		lines = DebugLineEncoderModule(debug_file)
		frames = DebugFrameEncoderModule(0)

		# Generate debug line information
		loop module in modules {
			loop line in module.debug_line_information {
				# Compute the absolute offset of the current debug point and move to that position
				offset = module.start + line.offset
				lines.move(section, line.line, line.character, offset)
			}
		}

		position = 0

		# Generate debug frame information
		loop module in modules {
			loop information in module.debug_frame_information {
				# Compute the absolute offset of the current debug point and move to that position
				offset = module.start + information.offset

				if information.type == ENCODER_DEBUG_FRAME_INFORMATION_TYPE_START {
					frames.start(information.(EncoderDebugFrameStartInformation).symbol, offset)
					position = offset
				}
				else information.type == ENCODER_DEBUG_FRAME_INFORMATION_TYPE_SET_FRAME_OFFSET {
					frames.move(offset - position)
					frames.set_frame_offset(information.(EncoderDebugFrameOffsetInformation).frame_offset)
					position = offset
				}
				else information.type == ENCODER_DEBUG_FRAME_INFORMATION_TYPE_END {
					frames.end(offset)
				}
			}
		}

		return EncoderOutput(section, symbols, relocations, frames, lines)
	}

	# Summary:
	# Encodes the specified instructions
	encode(instructions: List<Instruction>, debug_file: String) {
		modules = create_modules(instructions)
		labels = Map<Label, LabelDescriptor>()

		encode(modules) # Encode each module

		load_labels(modules, labels) # Load all labels into a dictionary where information about their positions can be pulled
		complete_modules(modules, labels) # Decide jump sizes based on the loaded label information
		complete_module_positions(modules)
		write_offsets(modules, labels)

		output = build(modules, labels, debug_file)
		return output
	}
}