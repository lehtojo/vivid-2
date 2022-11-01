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
		write_uleb128(1) # Code alignment factor
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

		return section
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
		components = folder.split(`\\`)
		string(String.join("\\\\", components)) # Terminated folder path
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

		folder = io.path.folder(file)
		if folder != none add_folder(folder)

		write(0) # Indicate that now begins the last (only the compilation folder is added) included folder

		add_file(io.path.basename(file), 1)

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
		if this.line >= 0 {
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

		return DataEncoderModule.build()
	}
}

Debug {
	constant DEBUG_ABBREVIATION_TABLE = 'debug_abbrev'
	constant DEBUG_INFORMATION_TABLE = 'debug_info'
	constant DEBUG_LINE_TABLE = 'debug_line'

	constant STRING_TYPE_IDENTIFIER = 'String'
	constant STRING_TYPE_DATA_VARIABLE = 'data'

	constant ARRAY_TYPE_POSTFIX = '_array'
	constant ARRAY_TYPE_ELEMENTS: small = 10000

	constant DWARF_PRODUCER_TEXT = 'Vivid version 1.0'
	constant DWARF_LANGUAGE_IDENTIFIER: small = 0x7777

	constant DWARF_VERSION: small = 4

	constant DWARF_ENCODING_ADDRESS: byte = 1
	constant DWARF_ENCODING_BOOL: byte = 2

	constant DWARF_ENCODING_DECIMAL: byte = 4

	constant DWARF_ENCODING_SIGNED: byte = 5
	constant DWARF_ENCODING_UNSIGNED: byte = 7

	constant DWARF_ENCODING_SIGNED_CHAR: byte = 6
	constant DWARF_ENCODING_UNSIGNED_CHAR: byte = 8

	constant DWARF_CALLING_CONVENTION_PASS_BY_REFERENCE: byte = 4

	constant DWARF_ACCESS_PUBLIC: byte = 1
	constant DWARF_ACCESS_PROTECTED: byte = 2
	constant DWARF_ACCESS_PRIVATE: byte = 3

	constant DWARF_OP_BASE_POINTER_OFFSET: byte = 145
	constant DWARF_OP_DEREFERENCE: byte = 6
	constant DWARF_OP_ADD_BYTE_CONSTANT: byte = 35

	constant DWARF_REGISTER_ZERO: byte = 80

	constant X64_DWARF_STACK_POINTER_REGISTER: byte = 87
	constant ARM64_DWARF_STACK_POINTER_REGISTER: byte = 111

	constant DWARF_TAG_COMPILE_UNIT: byte = 17
	constant DWARF_HAS_CHILDREN: byte = 1
	constant DWARF_HAS_NO_CHILDREN: byte = 0
	constant DWARF_PRODUCER: byte = 37
	constant DWARF_LANGUAGE: byte = 19
	constant DWARF_NAME: byte = 3
	constant DWARF_LINE_NUMBER_INFORMATION: byte = 16
	constant DWARF_COMPILATION_FOLDER: byte = 27
	constant DWARF_LOW_PC: byte = 17
	constant DWARF_HIGH_PC: byte = 18
	constant DWARF_FRAME_BASE: byte = 64
	constant DWARF_DECLARATION_FILE: byte = 58
	constant DWARF_DECLARATION_LINE: byte = 59
	constant DWARF_CALLING_CONVENTION: byte = 54

	constant DWARF_FUNCTION: byte = 46
	constant DWARF_BASE_TYPE_DECLARATION: byte = 36
	constant DWARF_OBJECT_TYPE_DECLARATION: byte = 2
	constant DWARF_POINTER_TYPE_DECLARATION: byte = 15
	constant DWARF_MEMBER_DECLARATION: byte = 13
	constant DWARF_MEMBER_LOCATION: byte = 56
	constant DWARF_ACCESSIBILITY: byte = 50

	constant DWARF_TYPE: byte = 73
	constant DWARF_EXPORTED: byte = 63
	constant DWARF_VARIABLE: byte = 52
	constant DWARF_PARAMETER: byte = 5
	constant DWARF_INHERITANCE: byte = 28
	constant DWARF_LOCATION: byte = 2
	constant DWARF_ENCODING: byte = 62
	constant DWARF_BYTE_SIZE: byte = 11

	constant DWARF_ARRAY_TYPE: byte = 1
	constant DWARF_SUBRANGE_TYPE: byte = 33
	constant DWARF_COUNT: byte = 55

	constant DWARF_STRING_POINTER: byte = 14
	constant DWARF_STRING: byte = 8
	constant DWARF_DATA_8: byte = 11
	constant DWARF_DATA_16: byte = 5
	constant DWARF_DATA_32: byte = 6
	constant DWARF_ADDRESS: byte = 1
	constant DWARF_REFERENCE_32: byte = 19
	constant DWARF_DATA_SECTION_OFFSET: byte = 23
	constant DWARF_EXPRESSION: byte = 24
	constant DWARF_PRESENT: byte = 25

	constant DWARF_END: byte = 0

	information: Table
	abbreviation: Table

	start: TableLabel
	end: TableLabel

	index: large = 1

	file_abbreviation: byte = 0
	object_type_with_members_abbreviation: byte = 0
	object_type_without_members_abbreviation: byte = 0
	base_type_abbreviation: byte = 0
	pointer_type_abbreviation: byte = 0
	member_variable_abbreviation: byte = 0
	parameter_variable_abbreviation: byte = 0
	local_variable_abbreviation: byte = 0
	array_type_abbreviation: byte = 0
	subrange_type_abbreviation: byte = 0
	inheritance_abbreviation: byte = 0

	string_type: Type

	shared get_debug_file_start_label(file_index: large) {
		return "debug_file_" + to_string(file_index) + '_start'
	}

	shared get_debug_file_end_label(file_index: large) {
		return "debug_file_" + to_string(file_index) + '_end'
	}

	shared get_offset(from: TableLabel, to: TableLabel) {
		return LabelOffset(from, to)
	}

	begin_file(file: SourceFile) {
		information.add(file_abbreviation) # DW_TAG_compile_unit
		information.add(DWARF_PRODUCER_TEXT) # DW_AT_producer
		information.add(DWARF_LANGUAGE_IDENTIFIER) # DW_AT_language

		fullname = file.fullname.replace(`\\`, `/`)
		working_folder = io.get_process_working_folder().replace(`\\`, `/`)

		if fullname.starts_with(working_folder) {
			local_path = fullname.slice(working_folder.length)
			fullname = io.path.join("./", local_path)
		}

		information.add(fullname) # DW_AT_name

		debug_line_table_reference_label = TableLabel(String(DEBUG_LINE_TABLE), 4, false)
		debug_line_table_reference_label.is_section_relative = settings.is_x64 and settings.is_target_windows
		information.add(debug_line_table_reference_label) # DW_AT_stmt_list

		information.add(working_folder) # DW_AT_comp_dir

		file_start = TableLabel(get_debug_file_start_label(file.index), false)
		file_end = TableLabel(get_debug_file_end_label(file.index), false)

		information.add(file_start) # DW_AT_low_pc
		information.add(get_offset(file_start, file_end)) # DW_AT_high_pc
	}

	shared get_end(implementation: FunctionImplementation) {
		return TableLabel(implementation.get_fullname() + '_end', 8, false)
	}

	shared get_file(implementation: FunctionImplementation) {
		return implementation.metadata.start.file.index as normal
	}

	shared get_line(implementation: FunctionImplementation) {
		return implementation.metadata.start.friendly_line as normal
	}

	shared get_file(type: Type) {
		return type.position.file.index as normal
	}

	shared get_line(type: Type) {
		return type.position.friendly_line as normal
	}

	shared get_file(variable: Variable) {
		return variable.position.file.index as normal
	}

	shared get_line(variable: Variable) {
		return variable.position.friendly_line as normal
	}

	shared get_type_label_name(type: Type) {
		return get_type_label_name(type, false)
	}

	shared get_type_label_name(type: Type, pointer: bool) {
		if primitives.is_primitive(type, primitives.LINK) return type.get_fullname()

		if type.is_primitive {
			require(not pointer, 'Debug information label to primitive link type must be requested with a link type')
			return String(Mangle.VIVID_LANGUAGE_TAG) + type.identifier
		}

		# NOTE: Since the type is a user defined type, it must have a pointer symbol in its fullname. It must be removed, if the pointer flag is set to true.
		fullname = type.get_fullname()

		if pointer return fullname.insert(length_of(Mangle.VIVID_LANGUAGE_TAG), Mangle.POINTER_COMMAND)
		return fullname
	}

	shared get_type_label(type: Type, types: Map<String, Type>) {
		return get_type_label(type, types, false)
	}

	shared get_type_label(type: Type, types: Map<String, Type>, pointer: bool) {
		label = get_type_label_name(type, pointer)
		types[label] = type

		return TableLabel(label, 8, false)
	}

	add_operation(command: byte) {
		information.add(1 as byte) # Length of the operation
		information.add(command)
	}

	add_operation(command: byte, p1: byte) {
		information.add(2 as byte) # Length of the operation
		information.add(command)
		information.add(p1)
	}

	add_operation(command: byte, p1: byte, p2: byte) {
		information.add(3 as byte) # Length of the operation
		information.add(command)
		information.add(p1)
		information.add(p2)
	}

	add_operation(command: byte, p1: byte, p2: byte, p3: byte) {
		information.add(4 as byte) # Length of the operation
		information.add(command)
		information.add(p1)
		information.add(p2)
		information.add(p3)
	}

	add_operation(command: byte, parameters: List<byte>) {
		information.add((parameters.size + 1) as byte) # Length of the operation
		information.add(command)

		loop (i = 0, i < parameters.size, i++) {
			information.add(parameters[i])
		}
	}

	add_function(implementation: FunctionImplementation, types: Map<String, Type>) {
		file = get_file(implementation)
		function_abbreviation = to_uleb128(index++) # DW_TAG_subprogram

		loop value in function_abbreviation {
			information.add(value)
		}

		function_start = TableLabel(implementation.get_fullname(), 8, false)
		information.add(function_start) # DW_AT_low_pc

		information.add(get_offset(function_start, get_end(implementation))) # DW_AT_high_pc

		operation = ARM64_DWARF_STACK_POINTER_REGISTER
		if settings.is_x64 { operation = X64_DWARF_STACK_POINTER_REGISTER }

		add_operation(operation) # DW_AT_frame_base
		information.add(implementation.get_header()) # DW_AT_name
		information.add(file) # DW_AT_decl_file
		information.add(get_line(implementation)) # DW_AT_decl_line

		has_children = implementation.self != none or implementation.parameters.size > 0 or implementation.locals.size > 0

		loop value in function_abbreviation {
			abbreviation.add(value)
		}

		abbreviation.add(DWARF_FUNCTION)

		has_children_value = DWARF_HAS_NO_CHILDREN
		if has_children { has_children_value = DWARF_HAS_CHILDREN }
		abbreviation.add(has_children_value)

		abbreviation.add(DWARF_LOW_PC)
		abbreviation.add(DWARF_ADDRESS)

		abbreviation.add(DWARF_HIGH_PC)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_FRAME_BASE)
		abbreviation.add(DWARF_EXPRESSION)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		if implementation.metadata.is_exported {
			abbreviation.add(DWARF_EXPORTED)
			abbreviation.add(DWARF_PRESENT)
		}

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		if implementation.return_type != none {
			information.add(get_offset(start, get_type_label(implementation.return_type, types))) # DW_AT_type
		}

		loop local in implementation.locals {
			add_local_variable(local, types, file, implementation.size_of_local_memory)
		}

		self = implementation.get_self_pointer()

		if self != none {
			add_parameter_variable(self, types, file, implementation.size_of_local_memory)
		}

		loop parameter in implementation.parameters {
			add_parameter_variable(parameter, types, file, implementation.size_of_local_memory)
		}

		if has_children {
			information.add(DWARF_END) # End Of Children Mark
		}
	}

	add_file_abbreviation() {
		abbreviation.add(index as byte) # Define the current abbreviation code

		abbreviation.add(DWARF_TAG_COMPILE_UNIT) # This is a compile unit and it has children
		abbreviation.add(DWARF_HAS_CHILDREN)

		abbreviation.add(DWARF_PRODUCER) # The producer is identified with a pointer
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_LANGUAGE) # The language is identified with a short integer
		abbreviation.add(DWARF_DATA_16)

		abbreviation.add(DWARF_NAME) # The name of the file is added with a pointer
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_LINE_NUMBER_INFORMATION) # The line number information is added with a section offset
		abbreviation.add(DWARF_DATA_SECTION_OFFSET)

		abbreviation.add(DWARF_COMPILATION_FOLDER) # The compilation folder is added with a pointer
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_LOW_PC)
		abbreviation.add(DWARF_ADDRESS)

		abbreviation.add(DWARF_HIGH_PC)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		file_abbreviation = index++
	}

	add_object_type_with_members_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_OBJECT_TYPE_DECLARATION)
		abbreviation.add(DWARF_HAS_CHILDREN)

		abbreviation.add(DWARF_CALLING_CONVENTION)
		abbreviation.add(DWARF_DATA_8)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_BYTE_SIZE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		object_type_with_members_abbreviation = index++
	}

	add_object_type_without_members_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_OBJECT_TYPE_DECLARATION)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_CALLING_CONVENTION)
		abbreviation.add(DWARF_DATA_8)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_BYTE_SIZE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		object_type_without_members_abbreviation = index++
	}

	add_base_type_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_BASE_TYPE_DECLARATION)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_ENCODING)
		abbreviation.add(DWARF_DATA_8)

		abbreviation.add(DWARF_BYTE_SIZE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		base_type_abbreviation = index++
	}

	add_pointer_type_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_POINTER_TYPE_DECLARATION)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		pointer_type_abbreviation = index++
	}

	add_member_variable_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_MEMBER_DECLARATION)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_MEMBER_LOCATION)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_ACCESSIBILITY)
		abbreviation.add(DWARF_DATA_8)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		member_variable_abbreviation = index++
	}

	add_local_variable_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_VARIABLE)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_LOCATION)
		abbreviation.add(DWARF_EXPRESSION)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		local_variable_abbreviation = index++
	}

	add_parameter_variable_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_PARAMETER)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_LOCATION)
		abbreviation.add(DWARF_EXPRESSION)

		abbreviation.add(DWARF_NAME)
		abbreviation.add(DWARF_STRING)

		abbreviation.add(DWARF_DECLARATION_FILE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_DECLARATION_LINE)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		parameter_variable_abbreviation = index++
	}

	add_array_type_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_ARRAY_TYPE)
		abbreviation.add(DWARF_HAS_CHILDREN)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		array_type_abbreviation = index++
	}

	add_subrange_type_abbreviation() {
		abbreviation.add(index as byte)
		abbreviation.add(DWARF_SUBRANGE_TYPE)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_COUNT)
		abbreviation.add(DWARF_DATA_16)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		subrange_type_abbreviation = index++
	}

	add_inheritance_abbreviation() {
		abbreviation.add(index as byte)

		abbreviation.add(DWARF_INHERITANCE)
		abbreviation.add(DWARF_HAS_NO_CHILDREN)

		abbreviation.add(DWARF_TYPE)
		abbreviation.add(DWARF_REFERENCE_32)

		abbreviation.add(DWARF_MEMBER_LOCATION)
		abbreviation.add(DWARF_DATA_32)

		abbreviation.add(DWARF_ACCESSIBILITY)
		abbreviation.add(DWARF_DATA_8)

		abbreviation.add(DWARF_END)
		abbreviation.add(DWARF_END)

		inheritance_abbreviation = index++
	}

	shared is_pointer_type(type: Type) {
		return not type.is_primitive and not type.is_pack
	}

	add_member_variable(variable: Variable, types: Map<String, Type>) {
		if variable.type.is_array_type return
		
		information.add(member_variable_abbreviation)
		information.add(variable.name.replace('.', ''))
		information.add(get_offset(start, get_type_label(variable.type, types, is_pointer_type(variable.type))))
		information.add(get_file(variable))
		information.add(get_line(variable))

		alignment = variable.get_alignment(variable.parent as Type)
		if alignment < 0 abort('Missing member variable alignment')
	
		information.add(alignment as normal)

		if has_flag(variable.modifiers, MODIFIER_PRIVATE) {
			information.add(DWARF_ACCESS_PRIVATE)
		}
		else has_flag(variable.modifiers, MODIFIER_PROTECTED) {
			information.add(DWARF_ACCESS_PROTECTED)
		}
		else {
			information.add(DWARF_ACCESS_PUBLIC)
		}
	}

	add_object_type(type: Type, types: Map<String, Type>) {
		members = type.variables.get_values().filter(i -> not i.is_static and not i.is_constant)
		has_members = type.supertypes.size > 0 or members.size > 0

		abbreviation_value = object_type_without_members_abbreviation
		if has_members { abbreviation_value = object_type_with_members_abbreviation }

		information.add(abbreviation_value)
		information.add(DWARF_CALLING_CONVENTION_PASS_BY_REFERENCE)
		information.add(type.name)
		information.add(type.content_size as normal)
		information.add(get_file(type))
		information.add(get_line(type))

		# Include the supertypes
		loop supertype in type.supertypes {
			information.add(inheritance_abbreviation)
			information.add(get_offset(start, get_type_label(supertype, types)))

			if type.get_supertype_base_offset(supertype) has not supertype_base_offset abort('Could not resolve supertype base offset')

			information.add(supertype_base_offset as normal)
			information.add(DWARF_ACCESS_PUBLIC)
		}

		loop member in members {
			# NOTE: This is a bit hacky, but it should not cause any harm and is a temporary feature
			hidden = member.is_generated
			if hidden { member.position = type.position }

			add_member_variable(member, types)

			# Remove the temporary position
			if hidden { member.position = none }
		}

		if has_members information.add(DWARF_END)

		information.add(TableLabel(get_type_label_name(type, true), 8, true))
		information.add(pointer_type_abbreviation)
		information.add(get_offset(start, get_type_label(type, types)))
	}
	
	# Summary:
	# Appends a link type which enables the user to see its elements
	add_array_link(type: Type, element: Type, types: Map<String, Type>) {
		# Create the array type
		is_pointer = is_pointer_type(element)
		name = get_type_label_name(type, is_pointer) + ARRAY_TYPE_POSTFIX
		subrange = TableLabel(name, 8, true)

		information.add(subrange)
		information.add(array_type_abbreviation) # Abbreviation code
		information.add(get_offset(start, get_type_label(element, types, is_pointer))) # DW_AT_type

		information.add(subrange_type_abbreviation) # Abbreviation code
		information.add(get_offset(start, get_type_label(element, types, is_pointer))) # DW_AT_type
		information.add(ARRAY_TYPE_ELEMENTS) # DW_AT_count

		information.add(DWARF_END) # End of children

		information.add(TableLabel(get_type_label_name(type, true), 8, true))
		information.add(pointer_type_abbreviation)
		information.add(get_offset(start, subrange))

		types[element.identity] = element
	}

	add_link(type: Type, types: Map<String, Type>) {
		element = type.get_accessor_type()
		if element == none abort('Missing link offset type')

		if not primitives.is_primitive(element, primitives.BYTE) and not primitives.is_primitive(element, primitives.CHAR) and not primitives.is_primitive(element, primitives.U8) {
			add_array_link(type, element, types)
			return
		}

		information.add(TableLabel(get_type_label_name(type, true), 8, true))
		information.add(pointer_type_abbreviation)
		information.add(get_offset(start, get_type_label(element, types, is_pointer_type(element))))

		types[element.identity] = element
	}

	add_type(type: Type, types: Map<String, Type>) {
		if primitives.is_primitive(type, primitives.LINK) {
			add_link(type, types)
			return
		}

		information.add(TableLabel(get_type_label_name(type), 8, true))

		encoding = 0

		if type.is_primitive {
			encoding = when(type.name) {
				primitives.U8 => DWARF_ENCODING_UNSIGNED_CHAR,
				primitives.BYTE => DWARF_ENCODING_UNSIGNED_CHAR,
				primitives.DECIMAL => DWARF_ENCODING_DECIMAL,
				primitives.BOOL => DWARF_ENCODING_BOOL,
				primitives.UNIT => DWARF_ENCODING_SIGNED,
				else => 0
			}

			if encoding == 0 and type.is_number {
				if type.(Number).unsigned {
					encoding = DWARF_ENCODING_UNSIGNED
				}
				else {
					encoding = DWARF_ENCODING_SIGNED
				}
			}
			else encoding == 0 and type.is_array_type {
				encoding = DWARF_ENCODING_SIGNED_CHAR
			}
		}

		if encoding == 0 {
			add_object_type(type, types)
			return
		}

		information.add(base_type_abbreviation)
		information.add(type.name)

		information.add(encoding as byte)
		information.add(type.allocation_size as normal)
	}

	shared to_uleb128(value: large) {
		bytes = List<byte>()

		loop {
			x = value & 0x7F
			value = value |> 7

			if value != 0 {
				x |= (1 <| 7)
			}
	
			bytes.add(x)

			if value == 0 stop
		}

		return bytes
	}

	shared to_sleb128(value: large) {
		bytes = List<byte>()

		more = true
		negative = value < 0

		loop (more)  {
			x = value & 0x7F
			value = value |> 7

			# Sign bit of byte is second high order bit (0x40)
			if (value == 0 and ((x & 0x40) == 0)) or (value == -1 and ((x & 0x40) == 0x40)) {
				more = false
			}
			else {
				x |= (1 <| 7)
			}

			bytes.add(x)
		}

		return bytes
	}

	add_local_variable(variable: Variable, types: Map<String, Type>, file: normal, local_memory_size: normal) {
		if variable.is_generated or variable.type.is_array_type return

		# Before adding the local variable, it must have a stack alignment
		alignment = variable.alignment
		if not variable.is_aligned return

		information.add(local_variable_abbreviation) # DW_TAG_variable

		type = variable.type
		local_variable_alignment = to_sleb128(local_memory_size + alignment)

		if variable.type === string_type {
			# Get the member variable that points to the actual characters
			data = type.get_variable(String(STRING_TYPE_DATA_VARIABLE))

			alignment = data.alignment
			type = data.type

			data_variable_alignment = to_sleb128(alignment)
			if data_variable_alignment.size != 1 abort('String member variable has too large offset')

			local_variable_alignment.add(DWARF_OP_DEREFERENCE)
			local_variable_alignment.add(DWARF_OP_ADD_BYTE_CONSTANT)
			local_variable_alignment.add(data_variable_alignment[])

			add_operation(DWARF_OP_BASE_POINTER_OFFSET, local_variable_alignment) # DW_AT_location
		}
		else {
			add_operation(DWARF_OP_BASE_POINTER_OFFSET, local_variable_alignment) # DW_AT_location
		}

		information.add(variable.name) # DW_AT_name

		information.add(file) # DW_AT_decl_file
		information.add(get_line(variable)) # DW_AT_decl_line

		information.add(get_offset(start, get_type_label(type, types, is_pointer_type(type)))) # DW_AT_type
	}

	add_parameter_variable(variable: Variable, types: Map<String, Type>, file: normal, local_memory_size: normal) {
		# Do not add generated variables
		if variable.is_generated or variable.type.is_array_type return

		# Before adding the local variable, it must have a stack alignment
		alignment = variable.alignment
		if not variable.is_aligned return

		information.add(parameter_variable_abbreviation) # DW_TAG_variable

		type = variable.type
		parameter_alignment = to_sleb128(local_memory_size + alignment)

		if variable.type === string_type {
			# Get the member variable which points to the actual data in the type
			data = type.get_variable(String(STRING_TYPE_DATA_VARIABLE))
			if data == none abort('Missing data variable')
			
			alignment = data.alignment
			type = data.type

			data_variable_alignment = to_sleb128(alignment)
			if data_variable_alignment.size != 1 abort('String member variable has too large offset')

			parameter_alignment.add(DWARF_OP_DEREFERENCE)
			parameter_alignment.add(DWARF_OP_ADD_BYTE_CONSTANT)
			parameter_alignment.add(data_variable_alignment[])

			add_operation(DWARF_OP_BASE_POINTER_OFFSET, parameter_alignment) # DW_AT_location
		}
		else {
			add_operation(DWARF_OP_BASE_POINTER_OFFSET, parameter_alignment) # DW_AT_location
		}

		information.add(variable.name) # DW_AT_name

		information.add(file) # DW_AT_decl_file
		information.add(get_line(variable)) # DW_AT_decl_line

		information.add(get_offset(start, get_type_label(type, types, is_pointer_type(type)))) # DW_AT_type
	}

	init(context: Context) {
		abbreviation = Table(String(DEBUG_ABBREVIATION_TABLE))
		information = Table(String(DEBUG_INFORMATION_TABLE))
		abbreviation.is_section = true
		information.is_section = true

		start = TableLabel("debug_info_start", 8, true)
		end = TableLabel("debug_info_end", 8, true)

		version_number_label = TableLabel("debug_info_version", 8, true)

		information.add(start)
		information.add(get_offset(version_number_label, end))
		information.add(version_number_label)
		information.add(DWARF_VERSION)

		debug_abbreviation_table_reference_label = TableLabel(String(DEBUG_ABBREVIATION_TABLE), 4, false)
		debug_abbreviation_table_reference_label.is_section_relative = settings.is_x64 and settings.is_target_windows
		information.add(debug_abbreviation_table_reference_label)

		information.add(SYSTEM_BYTES as byte)

		add_file_abbreviation()
		add_object_type_with_members_abbreviation()
		add_object_type_without_members_abbreviation()
		add_base_type_abbreviation()
		add_pointer_type_abbreviation()
		add_member_variable_abbreviation()
		add_parameter_variable_abbreviation()
		add_local_variable_abbreviation()
		add_array_type_abbreviation()
		add_subrange_type_abbreviation()
		add_inheritance_abbreviation()

		register_default_string_type(context)
	}

	register_default_string_type(context: Context) {
		type = context.get_type(String(STRING_TYPE_IDENTIFIER))
		if type === none or not type.parent.is_global return

		# Verify the type has an internal data pointer
		data_pointer = type.get_variable(String(STRING_TYPE_DATA_VARIABLE))
		if data_pointer === none or data_pointer.type === none or not data_pointer.type.is_link return

		# Register the found type as the default string type
		string_type = type
	}

	end_file() {
		information.add(DWARF_END)
	}

	build(file: SourceFile) {
		information.add(DWARF_END)
		abbreviation.add(DWARF_END)

		information.add(end)

		builder = AssemblyBuilder()
		assembler.add_table(builder, abbreviation, TABLE_MARKER_TEXTUAL_ASSEMBLY)
		assembler.add_table(builder, information, TABLE_MARKER_TEXTUAL_ASSEMBLY)

		if settings.is_debugging_enabled {
			abbreviation_section = builder.get_data_section(file, abbreviation.name)
			information_section = builder.get_data_section(file, information.name)

			# The abbreviation and information sections must be tightly packed and the start of these sections will be at least multiple of 8 bytes (this is guaranteed by the linker).s
			abbreviation_section.alignment = 1
			information_section.alignment = 1

			data_encoder.add_table(builder, abbreviation_section, abbreviation, TABLE_MARKER_DATA_ENCODER)
			data_encoder.add_table(builder, information_section, information, TABLE_MARKER_DATA_ENCODER)
		}

		return builder
	}
}