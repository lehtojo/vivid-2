DEBUG_FRAME_OPERATION_ADVANCE1 = 0x02
DEBUG_FRAME_OPERATION_ADVANCE2 = 0x03
DEBUG_FRAME_OPERATION_ADVANCE4 = 0x04
DEBUG_FRAME_OPERATION_SET_FRAME_OFFSET = 0x0E

DataEncoderModule DebugFrameEncoderModule {
	constant SECTION_NAME = 'eh_frame'

	private active_entry_start: large = 0
	private machine_code_start: large = 0

	init(identity: large) {
		write_int32(20)
		write_int32(identity) # CIE ID
		write(1) # Version
		write(`z`)
		write(`R`)
		write(0) # Augmentation
		write_uleb128(1) # Code aligment factor
		write_sleb128(-8) # Data alignment factor
		write_uleb128(16) # Return address register
		write(1)
		write(0x1B)

		# Default rules:
		# DW_CFA_def_cfa: r7 (rsp) offset 8
		# DW_CFA_offset: r16 (rip) at cfa - 8
		# DW_CFA_nop
		# DW_CFA_nop
		write([ 0x0C as byte, 0x07 as byte, 0x08 as byte, 0x90 as byte, 0x01 as byte, 0x00 as byte, 0x00 as byte ])
	}

	write_operation(operation: large) {
		write(operation)
	}

	start(name: String, offset: large) {
		active_entry_start = position
		machine_code_start = offset

		write_int32(0) # Set the length to zero for now
		write_int32(position) # write current offset

		symbol = BinarySymbol(name, 0, true)
		relocations.add(BinaryRelocation(symbol, position, 0, BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE))

		write_int32(offset) # Offset to the start of the function machine code
		write_int32(0) # Number of bytes in the machine code
		write(0) # Padding?
	}

	set_frame_offset(offset: large) {
		write_operation(DEBUG_FRAME_OPERATION_SET_FRAME_OFFSET)
		write_uleb128(offset)
	}

	move(delta: large) {
		if delta == 0 return

		if delta >= TINY_MIN and delta <= TINY_MAX {
			write_operation(DEBUG_FRAME_OPERATION_ADVANCE1)
			write(delta)
			return
		}

		if delta >= SMALL_MIN and delta <= SMALL_MAX {
			write_operation(DEBUG_FRAME_OPERATION_ADVANCE2)
			write_int16(delta)
			return
		}

		write_operation(DEBUG_FRAME_OPERATION_ADVANCE4)
		write_int32(delta)
		return
	}

	end(offset: large) {
		write_int32(active_entry_start, position - active_entry_start - 4) # Compute the entry length now
		write_int32(active_entry_start + 12, offset - machine_code_start)
	}

	build() {
		name = String(`.`) + SECTION_NAME

		section = DataEncoderModule.build()
		section.flags = BINARY_SECTION_FLAGS_ALLOCATE
		section.alignment = 1

		=> section
	}
}

DEBUG_LINE_OPERATION_NONE = 0
DEBUG_LINE_OPERATION_COPY = 1
DEBUG_LINE_OPERATION_ADVANCE_PROGRAM_COUNTER = 2
DEBUG_LINE_OPERATION_ADVANCE_LINE = 3
DEBUG_LINE_OPERATION_SET_FILE = 4
DEBUG_LINE_OPERATION_SET_COLUMN = 5
DEBUG_LINE_OPERATION_NEGATE_STATEMENT = 6
DEBUG_LINE_OPERATION_SET_BASIC_BLOCK = 7
DEBUG_LINE_OPERATION_CONSTANT_ADD_PROGRAM_COUNTER = 8
DEBUG_LINE_OPERATION_FIXED_ADVANCE_PROGRAM_COUNTER = 9
DEBUG_LINE_OPERATION_SET_PROLOGUE_END = 10
DEBUG_LINE_OPERATION_SET_PROLOGUE_BEGIN = 11
DEBUG_LINE_OPERATION_SET_ISA = 12
DEBUG_LINE_OPERATION_COUNT = 13

DEBUG_LINE_EXTENDED_OPERATION_NONE = 0
DEBUG_LINE_EXTENDED_OPERATION_END_OF_SEQUENCE = 1
DEBUG_LINE_EXTENDED_OPERATION_SET_ADDRESS = 2
DEBUG_LINE_EXTENDED_OPERATION_DEFINE_FILE = 3
DEBUG_LINE_EXTENDED_OPERATION_SET_DISCRIMINATOR = 4

# Summary:
# Encodes the DWARF debug line section (.debug_line)
DataEncoderModule DebugLineEncoderModule {
	constant SECTION_NAME = 'debug_line'
	constant DEBUG_CODE_START_SYMBOL = '.debug_code_start'
	constant PROLOGUE_LENGTH_FIELD_OFFSET = 6

	line: large = -1
	character: large = -1
	offset: large = -1

	private add_folder(folder: String) {
		components = folder.split(`\\`).to_list()
		string(String.join(String('\\\\'), components)) # Terminated folder path
	}

	private add_file(name: String, folder: large) {
		string(name) # Terminated file name
		write_uleb128(folder) # Folder index
		write_uleb128(0) # Time
		write_uleb128(0) # Size
	}

	init(file: String) {
		write_int32(0) # Set the length of this unit to zero initially
		write_int16(4) # Dwarf version 4
		write_int32(0) # Prologue length
		write(1) # Minimum instruction length
		write(1) # Maximum operations per instruction
		write(1) # Default 'is statement' flag
		write(1) # Line base
		write(1) # Line range
		write(DEBUG_LINE_OPERATION_COUNT) # Operation code base

		# Specify the number of arguments for each standard operation
		write(0) # DEBUG_LINE_OPERATION_COPY
		write(1) # DEBUG_LINE_OPERATION_ADVANCE_PROGRAM_COUNTER
		write(1) # DEBUG_LINE_OPERATION_ADVANCE_LINE
		write(1) # DEBUG_LINE_OPERATION_SET_FILE
		write(1) # DEBUG_LINE_OPERATION_SET_COLUMN
		write(0) # DEBUG_LINE_OPERATION_NEGATE_STATEMENT
		write(0) # DEBUG_LINE_OPERATION_SET_BASIC_BLOCK
		write(0) # DEBUG_LINE_OPERATION_CONSTANT_ADD_PROGRAM_COUNTER
		write(1) # DEBUG_LINE_OPERATION_FIXED_ADVANCE_PROGRAM_COUNTER
		write(0) # DEBUG_LINE_OPERATION_SET_PROLOGUE_END
		write(0) # DEBUG_LINE_OPERATION_SET_PROLOGUE_BEGIN
		write(1) # DEBUG_LINE_OPERATION_SET_ISA

		folder = path.folder(file)
		if folder != none add_folder(folder)

		write(0) # Indicate that now begins the last (only the compilation folder is added) included folder

		add_file(path.basename(file), 1)

		write(0) # End of included files

		# Compute the length of this header after the 'Prologue length'-field
		write_int32(PROLOGUE_LENGTH_FIELD_OFFSET, position - (PROLOGUE_LENGTH_FIELD_OFFSET + 4))
	}

	private write_operation(operation: large) {
		write(operation)
	}

	private write_extended_operation(operation: large, parameter_bytes: large) {
		write(0) # Begin extended operation code
		write(parameter_bytes + 1) # write the number of bytes to read
		write(operation)
	}

	move(section: BinarySection, line: large, character: large, offset: large) {
		if line >= 0 {
			# Move to the specified line
			write_operation(DEBUG_LINE_OPERATION_ADVANCE_LINE)
			write_sleb128(line - this.line)

			# Move to the specified column
			write_operation(DEBUG_LINE_OPERATION_SET_COLUMN)
			write_sleb128(character)

			# Move to the specified binary offset
			write_operation(DEBUG_LINE_OPERATION_ADVANCE_PROGRAM_COUNTER)
			write_sleb128(offset - this.offset)

			write_operation(DEBUG_LINE_OPERATION_COPY)

			this.character = character
			this.offset = offset
			this.line = line
			return
		}

		if line > 1 {
			# Move to the specified line
			write_operation(DEBUG_LINE_OPERATION_ADVANCE_LINE)
			write_sleb128(line - 1)
		}

		# Move to the specified column
		write_operation(DEBUG_LINE_OPERATION_SET_COLUMN)
		write_sleb128(character)

		write_extended_operation(DEBUG_LINE_EXTENDED_OPERATION_SET_ADDRESS, 8)
		
		# Add a symbol to the text section, which represents the start of the debuggable code.
		# This is done, because now the machine code offset is not correct, since after linking the code will probably be loaded to another address.
		# By inserting a symbol into the text section and adding a relocation using the symbol to this section, the offset will be corrected by the linker.
		symbol = BinarySymbol(String(DEBUG_CODE_START_SYMBOL), offset, false)
		symbol.section = section

		section.symbols.add(String(DEBUG_CODE_START_SYMBOL), symbol)
		relocations.add(BinaryRelocation(symbol, this.position, 0, BINARY_RELOCATION_TYPE_ABSOLUTE64, 8))

		write_int64(offset)

		write_operation(DEBUG_LINE_OPERATION_COPY)

		this.character = character
		this.offset = offset
		this.line = line
	}

	build() {
		write_extended_operation(DEBUG_LINE_EXTENDED_OPERATION_END_OF_SEQUENCE, 0)
		write_int32(0, position - 4) # Compute the length now

		name = String(`.`) + SECTION_NAME
		alignment = 1

		=> DataEncoderModule.build()
	}
}