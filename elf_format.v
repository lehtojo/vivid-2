namespace elf_format

constant ELF_OBJECT_FILE_TYPE_RELOCATABLE = 1
constant ELF_OBJECT_FILE_TYPE_EXECUTABLE = 2
constant ELF_OBJECT_FILE_TYPE_DYNAMIC = 3

constant ELF_MACHINE_TYPE_X64 = 0x3E
constant ELF_MACHINE_TYPE_ARM64 = 0xB7

constant ELF_SEGMENT_TYPE_LOADABLE = 1
constant ELF_SEGMENT_TYPE_DYNAMIC = 2
constant ELF_SEGMENT_TYPE_INTERPRETER = 3
constant ELF_SEGMENT_TYPE_PROGRAM_HEADER = 6

constant ELF_SEGMENT_FLAG_EXECUTE = 1
constant ELF_SEGMENT_FLAG_WRITE = 2
constant ELF_SEGMENT_FLAG_READ = 4

plain ElfFileHeader {
	magic_number: u32 = 0x464c457F
	class: byte = 2
	endianness: byte = 1
	version: byte = 1
	os_abi: byte = 0
	abi_version: byte = 0
	padding1: normal = 0
	padding2: small = 0
	padding3: byte = 0
	type: small
	machine: small
	version2: normal = 1
	entry: u64 = 0
	program_header_offset: u64
	section_header_offset: u64
	flags: normal
	file_header_size: small
	program_header_size: small
	program_header_entry_count: small
	section_header_size: small
	section_header_table_entry_count: small
	section_name_entry_index: small
}

plain ElfProgramHeader {
	type: normal
	flags: normal
	offset: u64
	virtual_address: u64
	physical_address: u64
	segment_file_size: u64
	segment_memory_size: u64
	alignment: u64
}

constant ELF_SECTION_TYPE_NONE = 0x00
constant ELF_SECTION_TYPE_PROGRAM_DATA = 0x1
constant ELF_SECTION_TYPE_SYMBOL_TABLE = 0x02
constant ELF_SECTION_TYPE_STRING_TABLE = 0x03
constant ELF_SECTION_TYPE_RELOCATION_TABLE = 0x04
constant ELF_SECTION_TYPE_HASH = 0x05
constant ELF_SECTION_TYPE_DYNAMIC = 0x06
constant ELF_SECTION_TYPE_DYNAMIC_SYMBOLS = 0x0B

constant ELF_SECTION_FLAG_NONE = 0x00
constant ELF_SECTION_FLAG_WRITE = 0x01
constant ELF_SECTION_FLAG_ALLOCATE = 0x02
constant ELF_SECTION_FLAG_EXECUTABLE = 0x04
constant ELF_SECTION_FLAG_INFO_LINK = 0x40

plain ElfSectionHeader {
	name: normal
	type: normal
	flags: u64
	virtual_address: u64 = 0
	offset: u64
	section_file_size: u64
	link: normal = 0
	info: normal = 0
	alignment: u64 = 1
	entry_size: u64 = 0
}

constant ELF_SYMBOL_BINDING_LOCAL = 0x00
constant ELF_SYMBOL_BINDING_GLOBAL = 0x01

plain ElfSymbolEntry {
	name: u32 = 0
	info: byte = 0
	other: byte = 0
	section_index: u16 = 0
	value: u64 = 0
	symbol_size: u64 = 0

	set_info(binding: normal, type: normal) {
		info = (binding <| 4) | type
	}

	is_exported => (info |> 4) === ELF_SYMBOL_BINDING_GLOBAL and section_index !== 0
}

constant ELF_SYMBOL_TYPE_NONE = 0x00
constant ELF_SYMBOL_TYPE_ABSOLUTE64 = 0x01
constant ELF_SYMBOL_TYPE_PROGRAM_COUNTER_RELATIVE = 0x02
constant ELF_SYMBOL_TYPE_PLT32 = 0x04
constant ELF_SYMBOL_TYPE_JUMP_SLOT = 0x07
constant ELF_SYMBOL_TYPE_BASE_RELATIVE_64 = 0x08
constant ELF_SYMBOL_TYPE_ABSOLUTE32 = 0x0A

plain ElfRelocationEntry {
	offset: u64
	info: u64 = 0
	addend: large

	symbol => (info |> 32) as normal
	type => (info & 0xFFFFFFFF) as normal

	init() {}

	init(offset: u64, addend: large) {
		this.offset = offset
		this.addend = addend
	}

	set_info(symbol: u64, type: u64) {
		info = (symbol <| 32) | type
	}
}

constant ELF_DYNAMIC_SECTION_TAG_NEEDED = 0x01
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_BYTES = 0x02
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_GLOBAL_OFFSET_TABLE = 0x03
constant ELF_DYNAMIC_SECTION_TAG_HASH_TABLE = 0x04
constant ELF_DYNAMIC_SECTION_TAG_STRING_TABLE = 0x05
constant ELF_DYNAMIC_SECTION_TAG_SYMBOL_TABLE = 0x06
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE = 0x07
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE_SIZE = 0x08
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_ENTRY_SIZE = 0x09
constant ELF_DYNAMIC_SECTION_TAG_STRING_TABLE_SIZE = 0x0A
constant ELF_DYNAMIC_SECTION_TAG_SYMBOL_ENTRY_SIZE = 0x0B
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TYPE = 0x14
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TABLE = 0x17
constant ELF_DYNAMIC_SECTION_TAG_BIND_NOW = 0x18
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_COUNT = 0x6ffffff9

plain ElfDynamicEntry {
	constant POINTER_OFFSET = 8

	tag: u64
	value: u64

	init(tag: u64, value: u64) {
		this.tag = tag
		this.value = value
	}
}

constant TEXT_SECTION = '.text'
constant DATA_SECTION = '.data'
constant SYMBOL_TABLE_SECTION = '.symtab'
constant STRING_TABLE_SECTION = '.strtab'
constant SECTION_HEADER_STRING_TABLE_SECTION = '.shstrtab'
constant DYNAMIC_SECTION = '.dynamic'
constant DYNAMIC_SYMBOL_TABLE_SECTION = '.dynsym'
constant DYNAMIC_STRING_TABLE_SECTION = '.dynstr'
constant HASH_SECTION = '.hash'
constant RELOCATION_TABLE_SECTION_PREFIX = '.rela'
constant DYNAMIC_RELOCATIONS_SECTION = '.rela.dyn'
constant GLOBAL_OFFSET_TABLE_SECTION = '.got'
constant FUNCTION_LINKAGE_TABLE_SECTION = '.plt'
constant INTERPRETER_SECTION = '.interp'
constant DYNAMIC_SECTION_START = '_DYNAMIC'
constant DEFAULT_INTERPRETER = '/lib/ld64.so.1'

constant GLOBAL_OFFSET_TABLE_SYMBOL_NAME = '_GLOBAL_OFFSET_TABLE_'
constant GLOBAL_OFFSET_TABLE_RESERVED_COUNT = 3

plain DynamicLinkingInformation {
	dynamic_section: BinarySection
	relocation_section: BinarySection = none as BinarySection
	entries: List<ElfSymbolEntry>
	symbols: List<BinarySymbol>
	relocations: List<BinaryRelocation> = List<BinaryRelocation>()

	init(section: BinarySection, entries: List<ElfSymbolEntry>, symbols: List<BinarySymbol>) {
		this.dynamic_section = section
		this.entries = entries
		this.symbols = symbols
	}
}

plain DynamicSectionBuilder {
	entries: List<ElfDynamicEntry> = List<ElfDynamicEntry>()
	relocations: List<BinaryRelocation> = List<BinaryRelocation>()
	symbols: List<BinarySymbol> = List<BinarySymbol>()
	symbol_entries: List<ElfSymbolEntry> = List<ElfSymbolEntry>()
	symbol_name_table: BinaryStringTable = BinaryStringTable()

	init() {
		# Add the none-entry
		symbols.add(BinarySymbol(String.empty, 0, false))
		symbol_name_table.add(String.empty)
		symbol_entries.add(ElfSymbolEntry())
	}

	add(tag: u64, value: u64) {
		entries.add(ElfDynamicEntry(tag, value))
	}

	add_symbol(name: String, section: BinarySection) {
		symbol = BinarySymbol(name, 0, false, section)
		symbol.exported = true

		# Add the symbol into its section, if it is not external
		if section !== none {
			section.symbols.add(symbol.name, symbol)
		}

		entry = ElfSymbolEntry()
		entry.name = symbol_name_table.add(symbol.name)
		entry.set_info(ELF_SYMBOL_BINDING_GLOBAL, 0)

		symbol.index = symbol_entries.size

		symbols.add(symbol)
		symbol_entries.add(entry)

		return symbol
	}

	add_symbols(symbols: List<BinarySymbol>) {
		loop symbol in symbols {
			entry = ElfSymbolEntry()
			entry.name = symbol_name_table.add(symbol.name)
			entry.set_info(ELF_SYMBOL_BINDING_GLOBAL, 0)

			symbol.index = symbol_entries.size

			this.symbols.add(symbol)
			this.symbol_entries.add(entry)
		}
	}

	set(tag: u64, symbol: BinarySymbol, relocation_type: large) {
		loop (i = 0, i < entries.size, i++) {
			if entries[i].tag !== tag continue

			relocations.add(BinaryRelocation(symbol, sizeof(ElfDynamicEntry) * i + ElfDynamicEntry.POINTER_OFFSET, 0, relocation_type))
			return
		}

		panic('Failed to add relocation for a dynamic section entry')
	}

	connect(section: BinarySection, relocations: List<BinaryRelocation>) {
		# Connect the relocations to the specified section
		loop relocation in this.relocations {
			if relocation.section !== none continue
			relocation.section = section
		}

		relocations.add_all(this.relocations)
	}
}

get_section_type(section: BinarySection) {
	if section.name == DYNAMIC_SYMBOL_TABLE_SECTION return ELF_SECTION_TYPE_DYNAMIC_SYMBOLS

	return when(section.type) {
		BINARY_SECTION_TYPE_DATA => ELF_SECTION_TYPE_PROGRAM_DATA,
		BINARY_SECTION_TYPE_NONE => ELF_SECTION_TYPE_NONE,
		BINARY_SECTION_TYPE_RELOCATION_TABLE => ELF_SECTION_TYPE_RELOCATION_TABLE,
		BINARY_SECTION_TYPE_STRING_TABLE => ELF_SECTION_TYPE_STRING_TABLE,
		BINARY_SECTION_TYPE_SYMBOL_TABLE => ELF_SECTION_TYPE_SYMBOL_TABLE,
		BINARY_SECTION_TYPE_TEXT => ELF_SECTION_TYPE_PROGRAM_DATA,
		BINARY_SECTION_TYPE_DYNAMIC => ELF_SECTION_TYPE_DYNAMIC,
		BINARY_SECTION_TYPE_HASH => ELF_SECTION_TYPE_HASH,
		else => ELF_SECTION_TYPE_PROGRAM_DATA
	}
}

get_section_flags(section: BinarySection) {
	result = ELF_SECTION_FLAG_NONE

	if section.type === BINARY_SECTION_TYPE_RELOCATION_TABLE and not (section.name == DYNAMIC_RELOCATIONS_SECTION) { result |= ELF_SECTION_FLAG_INFO_LINK }

	if has_flag(section.flags, BINARY_SECTION_FLAGS_WRITE) { result |= ELF_SECTION_FLAG_WRITE }
	if has_flag(section.flags, BINARY_SECTION_FLAGS_EXECUTE) { result |= ELF_SECTION_FLAG_EXECUTABLE }
	if has_flag(section.flags, BINARY_SECTION_FLAGS_ALLOCATE) { result |= ELF_SECTION_FLAG_ALLOCATE }

	return result
}

# Summary:
# Hashes the specified symbol name.
# Implementation is provided by the ELF specification.
get_symbol_hash(name: String) {
	h = 0 as u64

	loop (i = 0, i < name.length, i++) {
		h = (h <| 4) + name[i]
		g = h & 0xF0000000
		if g !== 0 { h ¤= g |> 24 }
		h &= !g
	}

	return h
}

# Summary:
# Generates a hash section from the specified symbols
create_hash_section(symbols: List<BinarySymbol>) {
	number_of_symbols = symbols.size
	buckets = allocate<normal>(number_of_symbols)
	chains = allocate<normal>(number_of_symbols)
	ends = allocate<normal>(number_of_symbols)

	# Initialize the chain end indices to match the beginning of the chain
	loop (i = 0, i < number_of_symbols, i++) { ends[i] = i }

	loop (i = 0, i < number_of_symbols, i++) {
		hash = get_symbol_hash(symbols[i].name)
		bucket = hash % number_of_symbols
		
		if buckets[bucket] === 0 {
			buckets[bucket] = i
			ends[bucket] = i
		}
		else {
			# Load the last symbol index in the chain
			end = ends[bucket]

			chains[end] = i # Set the next symbol index in the chain to point to the current symbol
			chains[i] = 0 # Set the chain to stop at the current symbol

			ends[bucket] = i # Set the end of the chain to be the current symbol
		}
	}

	# Structure of hash section:
	# [Number of buckets]
	# [Number of chains]
	# [Buckets]
	# [Chains]

	# Convert the buckets and chains to bytes
	data_size = (2 + number_of_symbols + number_of_symbols) * strideof(normal)
	data = allocate(data_size)

	binary_utility.write_int32(data, 0, number_of_symbols)
	binary_utility.write_int32(data, strideof(normal), number_of_symbols)

	# Copy the buckets and chains to the data
	copy(buckets, number_of_symbols * strideof(normal), data + strideof(normal) * 2)
	copy(chains, number_of_symbols * strideof(normal), data + strideof(normal) * (2 + number_of_symbols))

	return BinarySection(String(HASH_SECTION), BINARY_SECTION_TYPE_HASH, data, data_size)
}

create_section_headers(sections: List<BinarySection>, symbols: Map<String, BinarySymbol>) {
	return create_section_headers(sections, symbols, sizeof(ElfFileHeader))
}

create_section_headers(sections: List<BinarySection>, symbols: Map<String, BinarySymbol>, file_position: large) {
	string_table = BinaryStringTable()
	headers = List<ElfSectionHeader>()

	loop section in sections {
		# Apply the section margin before doing anything
		file_position += section.margin

		header = ElfSectionHeader()
		header.name = string_table.add(section.name)
		header.type = get_section_type(section)
		header.flags = get_section_flags(section)
		header.virtual_address = section.virtual_address
		header.section_file_size = section.load_size
		header.alignment = section.alignment

		if section.name == DYNAMIC_RELOCATIONS_SECTION {
			# The section header of relocation table should be linked to the dynamic symbol table
			header.link = sections.find_index(i -> i.name == DYNAMIC_SYMBOL_TABLE_SECTION)
			header.info = 0
			header.entry_size = sizeof(ElfRelocationEntry)
		}
		else section.type === BINARY_SECTION_TYPE_RELOCATION_TABLE {
			# The section header of relocation table should be linked to the symbol table and its info should point to the text section, since it describes it
			related_section_name = section.name.slice(5) # length_of(RELOCATION_TABLE_SECTION_PREFIX) = 5

			header.link = sections.find_index(i -> i.name == SYMBOL_TABLE_SECTION)
			header.info = sections.find_index(i -> i.name == related_section_name)
			header.entry_size = sizeof(ElfRelocationEntry)
		}
		else section.name == SYMBOL_TABLE_SECTION {
			# The section header of symbol table should be linked to the string table 
			header.link = sections.find_index(i -> i.name == STRING_TABLE_SECTION)
			header.info = symbols.get_values().count(i -> not i.external) + 1
			header.entry_size = sizeof(ElfSymbolEntry)
		}
		else section.name == DYNAMIC_SYMBOL_TABLE_SECTION {
			# The section header of dynamic symbol table should be linked to the dynamic string table
			header.link = sections.find_index(i -> i.name == DYNAMIC_STRING_TABLE_SECTION)
			header.info = 1
			header.entry_size = sizeof(ElfSymbolEntry)
		}
		else section.name == DYNAMIC_SECTION {
			header.link = sections.find_index(i -> i.name == DYNAMIC_STRING_TABLE_SECTION)
			header.info = 0
			header.entry_size = sizeof(ElfDynamicEntry)
		}
		else section.name == HASH_SECTION {
			header.link = sections.find_index(i -> i.name == DYNAMIC_SYMBOL_TABLE_SECTION)
			header.info = 0
			header.entry_size = 4
		}

		section.offset = file_position

		if section.type === BINARY_SECTION_TYPE_NONE {
			header.alignment = 0
			header.offset = 0
		}
		else {
			header.offset = file_position
		}

		file_position += section.virtual_size

		headers.add(header)
	}

	# Align the file position
	aligned_file_position = (file_position + 16 - 1) & !(16 - 1)

	string_table_section_name = string_table.add(String(SECTION_HEADER_STRING_TABLE_SECTION))

	string_table_section = BinarySection(String(SECTION_HEADER_STRING_TABLE_SECTION), BINARY_SECTION_TYPE_STRING_TABLE, string_table.build())
	string_table_section.margin = aligned_file_position - file_position
	string_table_section.offset = aligned_file_position

	string_table_header = ElfSectionHeader()
	string_table_header.name = string_table_section_name
	string_table_header.type = ELF_SECTION_TYPE_STRING_TABLE
	string_table_header.flags = 0
	string_table_header.offset = aligned_file_position
	string_table_header.section_file_size = string_table_section.data.size
	string_table_header.alignment = 16

	sections.add(string_table_section)
	headers.add(string_table_header)

	return headers
}

# Summary:
# Converts the specified relocation type into ELF symbol type
get_symbol_type(type: large) {
	return when(type) {
		BINARY_RELOCATION_TYPE_PROCEDURE_LINKAGE_TABLE => ELF_SYMBOL_TYPE_PROGRAM_COUNTER_RELATIVE, # Redirect to PC32 for now
		BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE => ELF_SYMBOL_TYPE_PROGRAM_COUNTER_RELATIVE,
		BINARY_RELOCATION_TYPE_ABSOLUTE64 => ELF_SYMBOL_TYPE_ABSOLUTE64,
		BINARY_RELOCATION_TYPE_ABSOLUTE32 => ELF_SYMBOL_TYPE_ABSOLUTE32,
		else => ELF_SYMBOL_TYPE_NONE
	}
}

# Summary:
# Converts the specified ELF symbol type to relocation type
get_relocation_type_from_symbol_type(type: large) {
	return when(type) {
		ELF_SYMBOL_TYPE_PROGRAM_COUNTER_RELATIVE => BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE,
		ELF_SYMBOL_TYPE_PLT32 => BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE,
		ELF_SYMBOL_TYPE_ABSOLUTE64 => BINARY_RELOCATION_TYPE_ABSOLUTE64,
		ELF_SYMBOL_TYPE_ABSOLUTE32 => BINARY_RELOCATION_TYPE_ABSOLUTE32,
		else => BINARY_RELOCATION_TYPE_ABSOLUTE32
	}
}

# Summary:
# Converts the specified ELF section flags to shared section flags
get_shared_section_flags(flags: large) {
	result = 0

	if has_flag(flags, ELF_SECTION_FLAG_WRITE) { result |= BINARY_SECTION_FLAGS_WRITE }
	if has_flag(flags, ELF_SECTION_FLAG_EXECUTABLE) { result |= BINARY_SECTION_FLAGS_EXECUTE }
	if has_flag(flags, ELF_SECTION_FLAG_ALLOCATE) { result |= BINARY_SECTION_FLAGS_ALLOCATE }

	return result
}

# Summary:
# Creates the symbol table and the relocation table based on the specified symbols
create_symbol_related_sections(sections: List<BinarySection>, fragments: List<BinarySection>, symbols: Map<String, BinarySymbol>) {
	# Create a string table that contains the names of the specified symbols
	symbol_name_table = BinaryStringTable()
	symbol_entries = List<ElfSymbolEntry>()
	relocation_sections = Map<BinarySection, List<ElfRelocationEntry>>()

	# Add a none-symbol
	none_symbol = ElfSymbolEntry()
	none_symbol.name = symbol_name_table.add(String.empty)
	symbol_entries.add(none_symbol)

	# Index the sections since the symbols need that
	loop (i = 0, i < sections.size, i++) {
		section = sections[i]
		section.index = i

		if fragments === none continue
		
		# Index the section fragments as well
		loop fragment in fragments {
			if not (fragment.name == section.name) continue
			fragment.index = i
		}
	}

	# Order the symbols so that local symbols are first and then the external ones
	local_symbols = symbols.get_values().filter(i -> not (i.external or i.exported))
	non_local_symbols = symbols.get_values().filter(i -> i.external or i.exported)
	ordered_symbols = local_symbols + non_local_symbols

	loop symbol in ordered_symbols {
		virtual_address = 0
		if symbol.section !== none { virtual_address = symbol.section.virtual_address }

		symbol_entry = ElfSymbolEntry()
		symbol_entry.name = symbol_name_table.add(symbol.name)
		symbol_entry.value = virtual_address + symbol.offset

		if symbol.external {
			symbol_entry.section_index = 0
		}
		else {
			symbol_entry.section_index = symbol.section.index
		}

		if symbol.external or symbol.exported {
			symbol_entry.set_info(ELF_SYMBOL_BINDING_GLOBAL, 0)
		}
		else {
			symbol_entry.set_info(ELF_SYMBOL_BINDING_LOCAL, 0)
		}

		symbol.index = symbol_entries.size
		symbol_entries.add(symbol_entry)
	}

	# Create the relocation entries
	loop section in sections {
		relocation_entries = List<ElfRelocationEntry>()

		loop relocation in section.relocations {
			relocation_entry = ElfRelocationEntry(relocation.offset, relocation.addend)
			relocation_entry.set_info(relocation.symbol.index, get_symbol_type(relocation.type))

			relocation_entries.add(relocation_entry)
		}

		relocation_sections[section] = relocation_entries
	}

	symbol_table_section = BinarySection(String(SYMBOL_TABLE_SECTION), BINARY_SECTION_TYPE_SYMBOL_TABLE, Array<byte>(sizeof(ElfSymbolEntry) * symbol_entries.size))
	binary_utility.write_all<ElfSymbolEntry>(symbol_table_section.data, 0, symbol_entries)
	sections.add(symbol_table_section)

	loop iterator in relocation_sections {
		# Add the relocation section if needed
		relocation_entries = iterator.value
		if relocation_entries.size === 0 continue

		relocation_table_section = BinarySection(String(RELOCATION_TABLE_SECTION_PREFIX) + iterator.key.name, BINARY_SECTION_TYPE_RELOCATION_TABLE, Array<byte>(sizeof(ElfRelocationEntry) * relocation_entries.size))
		binary_utility.write_all<ElfRelocationEntry>(relocation_table_section.data, 0, relocation_entries)
		sections.add(relocation_table_section)
	}

	string_table_section = BinarySection(String(STRING_TABLE_SECTION), BINARY_SECTION_TYPE_STRING_TABLE, symbol_name_table.build())
	sections.add(string_table_section)

	return symbol_name_table
}

# Summary:
# Creates an object file from the specified sections
create_object_file(name: String, sections: List<BinarySection>, exports: Set<String>) {
	# Create an empty section, so that it is possible to leave section index unspecified in symbols for example
	none_section = BinarySection(String.empty, BINARY_SECTION_TYPE_NONE, Array<byte>())
	sections.insert(0, none_section)

	symbols = binary_utility.get_all_symbols_from_sections(sections)

	# Export symbols
	binary_utility.apply_exports(symbols, exports)

	# Update all the relocations before adding them to binary sections
	binary_utility.update_relocations(sections, symbols)

	# Add symbols and relocations of each section needing that
	create_symbol_related_sections(sections, none as List<BinarySection>, symbols)

	create_section_headers(sections, symbols)

	# Now that section positions are set, compute offsets
	binary_utility.compute_offsets(sections, symbols)

	exports = Set<String>(symbols.get_values().filter(i -> i.exported).map<String>((i: BinarySymbol) -> i.name))
	return BinaryObjectFile(name, sections, exports)
}

# Summary: Aligns the specified sections
align_sections(sections: List<BinarySection>, file_position: large) {
	loop section in sections {
		if section.type === BINARY_SECTION_TYPE_NONE continue

		alignment = max(section.alignment, 16)
		aligned_file_position = (file_position + alignment - 1) & !(alignment - 1)

		section.margin = aligned_file_position - file_position
		section.alignment = alignment

		file_position = aligned_file_position + section.data.size
	}
}

# Summary:
# Creates an object file from the specified sections and converts it to binary format
build_object_file(sections: List<BinarySection>, exports: Set<String>) {
	if sections.size === 0 or sections[].type !== BINARY_SECTION_TYPE_NONE {
		# Create an empty section, so that it is possible to leave section index unspecified in symbols for example
		none_section = BinarySection(String.empty, BINARY_SECTION_TYPE_NONE, Array<byte>())
		sections.insert(0, none_section)
	}

	symbols = binary_utility.get_all_symbols_from_sections(sections)

	# Export symbols
	binary_utility.apply_exports(symbols, exports)

	# Update all the relocations before adding them to binary sections
	binary_utility.update_relocations(sections, symbols)

	# Add symbols and relocations of each section needing that
	create_symbol_related_sections(sections, none as List<BinarySection>, symbols)

	header = ElfFileHeader()
	header.type = ELF_OBJECT_FILE_TYPE_RELOCATABLE
	header.machine = ELF_MACHINE_TYPE_X64
	header.file_header_size = sizeof(ElfFileHeader)
	header.section_header_size = sizeof(ElfSectionHeader)

	align_sections(sections, sizeof(ElfFileHeader))
	section_headers = create_section_headers(sections, symbols)

	# Now that section positions are set, compute offsets
	binary_utility.compute_offsets(sections, symbols)

	# Compute the location of the first section header
	header.section_header_offset = sizeof(ElfFileHeader)

	loop section in sections {
		header.section_header_offset += section.margin + section.data.size
	}

	# Save the location of the section header table
	header.section_header_table_entry_count = section_headers.size
	header.section_header_size = sizeof(ElfSectionHeader)
	header.section_name_entry_index = section_headers.size - 1

	bytes = header.section_header_offset + section_headers.size * sizeof(ElfSectionHeader)
	result = Array<byte>(bytes)

	# Write the file header
	binary_utility.write<ElfFileHeader>(result, 0, header)

	# Write the actual program data
	loop section in sections {
		binary_utility.write_bytes(section.data, result, section.offset, section.data.size)
	}

	# Write the section header table now
	position = header.section_header_offset

	loop section_header in section_headers {
		binary_utility.write<ElfSectionHeader>(result, position, section_header)
		position += sizeof(ElfSectionHeader)
	}

	return result
}

# Summary:
# Creates symbol and relocation objects from the raw data inside the specified sections
import_symbols_and_relocations(sections: List<BinarySection>, section_intermediates: List<Pair<ElfSectionHeader, Array<byte>>>) {
	# Try to find the symbol table section
	symbol_table_index = sections.find_index(i -> i.type === BINARY_SECTION_TYPE_SYMBOL_TABLE)
	if symbol_table_index < 0 return

	symbol_table_section = sections[symbol_table_index]

	# Copy the symbol table into raw memory
	symbol_table = allocate(symbol_table_section.data.size)
	binary_utility.write_bytes(symbol_table_section.data, symbol_table)

	# Load all the symbol entries from the symbol table
	symbol_entries = List<ElfSymbolEntry>()
	position = 0

	loop (position < symbol_table_section.data.size) {
		symbol_entries.add(binary_utility.read_object<ElfSymbolEntry>(symbol_table, position))
		position += sizeof(ElfSymbolEntry)
	}

	# Determine the section, which contains the symbol names
	section_header = section_intermediates[symbol_table_index].first
	symbol_names = sections[section_header.link].data

	# Create the a list of the symbols, which contains the loaded symbols in the order in which they appear in the file
	# NOTE: This is useful for the relocation table below
	symbols = List<BinarySymbol>()

	# Convert the symbol entries into symbols
	loop symbol_entry in symbol_entries {
		# Load the section, which contains the current symbol
		section = sections[symbol_entry.section_index]

		# Determine the start and the end indices of the symbol name
		symbol_name = symbol_names.data + symbol_entry.name

		# Sometimes other assemblers give empty names for sections for instance, these are not supported (yet)
		if symbol_name[] === 0 continue

		symbol = BinarySymbol(String(symbol_name), symbol_entry.value, symbol_entry.section_index == 0)
		symbol.exported = symbol_entry.is_exported
		symbol.section = section

		# Add the symbol to the section, which contains it, unless the symbol is external
		if not symbol.external section.symbols.add(symbol.name, symbol)

		symbols.add(symbol)
	}

	# Now, import the relocations
	loop (i = 0, i < sections.size, i++) {
		# Ensure the section represents a relocation table
		relocation_section = sections[i]
		if relocation_section.type !== BINARY_SECTION_TYPE_RELOCATION_TABLE continue

		# Determine the section, which the relocations concern
		relocation_section_header = section_intermediates[i].first
		section = sections[relocation_section_header.info]

		# Copy the relocation table into raw memory
		relocation_table = allocate(relocation_section.data.size)
		binary_utility.write_bytes(relocation_section.data, relocation_table)

		# Load all the relocation entries
		relocation_entries = List<ElfRelocationEntry>()

		position = 0

		loop (position < relocation_section.data.size) {
			relocation_entries.add(binary_utility.read_object<ElfRelocationEntry>(relocation_table, position))
			position += sizeof(ElfSymbolEntry)
		}

		# Convert the relocation entries into relocation objects
		loop relocation_entry in relocation_entries {
			symbol = symbols[relocation_entry.symbol - 1] # Use -1 because the symbol index is 1-based
			type = get_relocation_type_from_symbol_type(relocation_entry.type)

			relocation = BinaryRelocation(symbol, relocation_entry.offset, relocation_entry.addend, type)
			relocation.section = section

			section.relocations.add(relocation)
		}

		deallocate(relocation_table)
	}

	deallocate(symbol_table)
}

# Summary:
# Load the specified object file and constructs a object structure that represents it
import_object_file(name: String, source: Array<byte>) {
	# Load the file into raw memory
	bytes = allocate(source.size)
	binary_utility.write_bytes(source, bytes)

	# Load the file header
	header = binary_utility.read_object<ElfFileHeader>(bytes, 0)

	# Create a pointer, which points to the start of the section headers
	section_headers_start = bytes + header.section_header_offset

	# Load section intermediates, that is section headers with corresponding section data
	section_intermediates = List<Pair<ElfSectionHeader, Array<byte>>>()

	loop (i = 0, i < header.section_header_table_entry_count, i++) {
		# Load the section header in order to load the actual section
		section_header = binary_utility.read_object<ElfSectionHeader>(section_headers_start, sizeof(ElfSectionHeader) * i)

		# Create a pointer, which points to the start of the section data in the file
		section_data_start = bytes + section_header.offset

		# Now load the section data into a buffer
		section_data = Array<byte>(section_data_start, section_header.section_file_size)
		section_intermediates.add(Pair<ElfSectionHeader, Array<byte>>(section_header, section_data))
	}

	# Now the section objects can be created, since all section intermediates have been loaded.
	# In order to create the section objects, section names are required and they must be loaded from one of the loaded intermediates
	sections = List<BinarySection>()

	# Determine the buffer, which contains the section names
	section_names = section_intermediates[header.section_name_entry_index].second

	loop section_intermediate in section_intermediates {
		section_intermediate_header = section_intermediate.first
		section_intermediate_content = section_intermediate.second

		# Determine the section name
		section_name = String(section_names.data + section_intermediate_header.name)

		# Determine the section type
		section_type = when(section_name) {
			TEXT_SECTION => BINARY_SECTION_TYPE_TEXT,
			DATA_SECTION => BINARY_SECTION_TYPE_DATA,
			SYMBOL_TABLE_SECTION => BINARY_SECTION_TYPE_SYMBOL_TABLE,
			STRING_TABLE_SECTION => BINARY_SECTION_TYPE_STRING_TABLE,
			else => BINARY_SECTION_TYPE_NONE
		}

		# Detect relocation table sections
		if section_name.starts_with(RELOCATION_TABLE_SECTION_PREFIX) { section_type = BINARY_SECTION_TYPE_RELOCATION_TABLE }

		section = BinarySection(section_name, section_type, section_intermediate_content)
		section.flags = get_shared_section_flags(section_intermediate_header.flags)
		section.alignment = section_intermediate_header.alignment
		section.offset = section_intermediate_header.offset
		section.virtual_size = section_intermediate_content.size

		sections.add(section)
	}

	import_symbols_and_relocations(sections, section_intermediates)

	deallocate(bytes)
	return BinaryObjectFile(name, sections)
}

# Summary:
# Load the specified object file and constructs a object structure that represents it
import_object_file(path: String) {
	if io.read_file(path) has not bytes return Optional<BinaryObjectFile>()
	return Optional<BinaryObjectFile>(import_object_file(path, bytes))
}

# Summary:
# Creates the program headers, meaning the specified section will get their own virtual addresses and be loaded into memory when the created executable is loaded
create_program_headers(sections: List<BinarySection>, fragments: List<BinarySection>, headers: List<ElfProgramHeader>, virtual_address: u64) {
	# Create the program header load segment
	return create_program_headers(sections, fragments, headers, virtual_address, true)
}

# Summary:
# Creates the program headers, meaning the specified section will get their own virtual addresses and be loaded into memory when the created executable is loaded
create_program_headers(sections: List<BinarySection>, fragments: List<BinarySection>, headers: List<ElfProgramHeader>, virtual_address: u64, executable: bool) {
	file_position = 0

	explicits = List<ElfProgramHeader>()

	# If we are building an executable, create a program header for the ELF-headers as well
	if executable {
		# Create an explicit header for the program header segment
		header = ElfProgramHeader()
		header.type = ELF_SEGMENT_TYPE_LOADABLE
		header.flags = ELF_SEGMENT_FLAG_READ
		header.offset = 0
		header.virtual_address = virtual_address
		header.physical_address = virtual_address
		header.segment_file_size = linker.SEGMENT_ALIGNMENT
		header.segment_memory_size = linker.SEGMENT_ALIGNMENT
		header.alignment = linker.SEGMENT_ALIGNMENT

		explicits.add(header)

		file_position = linker.SEGMENT_ALIGNMENT
		virtual_address += linker.SEGMENT_ALIGNMENT
	}

	loop section in sections {
		# Apply the section margin before doing anything
		file_position += section.margin
		virtual_address += section.margin

		if section.name.length !== 0 and not has_flag(section.flags, BINARY_SECTION_FLAGS_ALLOCATE) {
			# Restore the current virtual address after aligning the fragments
			previous_virtual_address = virtual_address

			# All non-allocated sections start from virtual address 0
			virtual_address = 0

			section.offset = file_position
			section.virtual_address = virtual_address

			# Align all the section fragments
			loop fragment in fragments.filter(i -> i.name == section.name) {
				fragment.offset = file_position
				fragment.virtual_address = virtual_address

				file_position += fragment.margin + fragment.data.size
				virtual_address += fragment.margin + fragment.data.size
			}

			# Restore the virtual address
			virtual_address = previous_virtual_address
			continue
		}

		# Determine the section flags
		flags = when(section.name) {
			DATA_SECTION => ELF_SEGMENT_FLAG_WRITE | ELF_SEGMENT_FLAG_READ,
			TEXT_SECTION => ELF_SEGMENT_FLAG_EXECUTE | ELF_SEGMENT_FLAG_READ,
			DYNAMIC_SECTION => ELF_SEGMENT_FLAG_WRITE | ELF_SEGMENT_FLAG_READ,
			FUNCTION_LINKAGE_TABLE_SECTION => ELF_SEGMENT_FLAG_EXECUTE | ELF_SEGMENT_FLAG_READ,
			GLOBAL_OFFSET_TABLE_SECTION => ELF_SEGMENT_FLAG_WRITE | ELF_SEGMENT_FLAG_READ,
			else => ELF_SEGMENT_FLAG_READ
		}

		header = ElfProgramHeader()
		header.type = ELF_SEGMENT_TYPE_LOADABLE
		header.flags = flags
		header.offset = file_position
		header.virtual_address = virtual_address
		header.physical_address = virtual_address
		header.segment_file_size = section.virtual_size
		header.segment_memory_size = section.virtual_size
		header.alignment = linker.SEGMENT_ALIGNMENT
		headers.add(header)

		# Dynamic and interpreter sections also need explicit headers
		if section.name == DYNAMIC_SECTION or section.name == INTERPRETER_SECTION {
			header = ElfProgramHeader()
			header.flags = flags
			header.offset = file_position
			header.virtual_address = virtual_address
			header.physical_address = virtual_address
			header.segment_file_size = section.virtual_size
			header.segment_memory_size = section.virtual_size
			header.alignment = 8
			header.type = when(section.name) {
				DYNAMIC_SECTION => ELF_SEGMENT_TYPE_DYNAMIC,
				INTERPRETER_SECTION => ELF_SEGMENT_TYPE_INTERPRETER,
				else => panic('Unhandled section type') as normal
			}

			explicits.add(header)
		}

		section.offset = file_position
		section.virtual_address = virtual_address

		# Align all the section fragments
		loop fragment in fragments.filter(i -> i.name == section.name) {
			# Apply the fragment margin before doing anything, so that the fragment is aligned
			file_position += fragment.margin
			virtual_address += fragment.margin

			fragment.offset = file_position
			fragment.virtual_address = virtual_address
			
			file_position += fragment.data.size
			virtual_address += fragment.data.size
		}
	}

	headers.insert_all(0, explicits)
	return file_position
}

# Summary:
# Searches for relocations that must be solved by the dynamic linker and removes them from the specified relocations.
# This function creates a dynamic relocation section if required.
create_dynamic_relocations(sections: List<BinarySection>, relocations: List<BinaryRelocation>, dynamic_linking_information: DynamicLinkingInformation) {
	# Find all relocations that are absolute
	absolute_relocations = relocations.filter(i -> i.type === BINARY_RELOCATION_TYPE_ABSOLUTE64)

	loop (i = relocations.size - 1, i >= 0, i--) {
		relocation = relocations[i]

		if relocation.type === BINARY_RELOCATION_TYPE_ABSOLUTE32 {
			abort('32-bit absolute relocations are not supported when building a shared library on 64-bit mode')
		}

		# Take only the 64-bit absolute relocations
		if relocation.type === BINARY_RELOCATION_TYPE_ABSOLUTE64 {
			absolute_relocations.add(relocation)
			relocations.remove_at(i) # Remove the relocation from the list, since now the dynamic linker is responsible for it
		}
	}

	if absolute_relocations.size === 0 return

	# Create a section for the dynamic relocations
	dynamic_relocations_data = Array<byte>(absolute_relocations.size * sizeof(ElfRelocationEntry))
	dynamic_relocations_section = BinarySection(String(DYNAMIC_RELOCATIONS_SECTION), BINARY_SECTION_TYPE_RELOCATION_TABLE, dynamic_relocations_data)
	dynamic_relocations_section.alignment = 8
	dynamic_relocations_section.flags = BINARY_SECTION_FLAGS_ALLOCATE

	# Finish the absolute relocations later, since they require virtual addresses for sections
	dynamic_linking_information.relocation_section = dynamic_relocations_section
	dynamic_linking_information.relocations = absolute_relocations

	# Add the dynamic relocations section to the list of sections
	sections.add(dynamic_relocations_section)
}

# Summary:
# Creates all the required dynamic sections needed in a shared library. This includes the dynamic section, the dynamic symbol table, the dynamic string table.
# The dynamic symbol table created by this function will only exported symbols.
create_dynamic_sections(sections: List<BinarySection>, symbols: Map<String, BinarySymbol>, relocations: List<BinaryRelocation>, dependencies: List<String>) {
	# Build the dynamic section data
	builder = DynamicSectionBuilder()

	# Add runtime library dependencies
	loop dependency in dependencies {
		builder.add(ELF_DYNAMIC_SECTION_TAG_NEEDED, builder.symbol_name_table.add(dependency))
	}

	builder.add(ELF_DYNAMIC_SECTION_TAG_HASH_TABLE, 0) # The address is filled in later using a relocation
	builder.add(ELF_DYNAMIC_SECTION_TAG_STRING_TABLE, 0)  # The address is filled in later using a relocation
	builder.add(ELF_DYNAMIC_SECTION_TAG_SYMBOL_TABLE, 0)  # The address is filled in later using a relocation
	builder.add(ELF_DYNAMIC_SECTION_TAG_SYMBOL_ENTRY_SIZE, sizeof(ElfSymbolEntry))

	# Dynamic section:
	dynamic_section = BinarySection(String(DYNAMIC_SECTION), BINARY_SECTION_TYPE_DYNAMIC, Array<byte>())
	dynamic_section.alignment = 8
	dynamic_section.flags = BINARY_SECTION_FLAGS_WRITE | BINARY_SECTION_FLAGS_ALLOCATE

	# Create a symbol, which represents the start of the dynamic section
	builder.add_symbol(String(DYNAMIC_SECTION_START), dynamic_section)

	# Add all exported symbols to the dynamic symbol table
	builder.add_symbols(symbols.get_values().filter(i -> i.exported))

	# Function linkage table:
	add_function_linkage_table(sections, relocations, builder)

	# Dynamic symbol table:
	dynamic_symbol_table = BinarySection(String(DYNAMIC_SYMBOL_TABLE_SECTION), BINARY_SECTION_TYPE_SYMBOL_TABLE, Array<byte>(sizeof(ElfSymbolEntry) * builder.symbol_entries.size))
	dynamic_symbol_table.alignment = 8
	dynamic_symbol_table.flags = BINARY_SECTION_FLAGS_ALLOCATE

	# Create a symbol, which represents the start of the dynamic symbol table
	# This symbol is used to fill the file offset of the dynamic symbol table in the dynamic section
	dynamic_symbol_table_start = BinarySymbol(dynamic_symbol_table.name, 0, false, dynamic_symbol_table)

	# Dynamic string table:
	dynamic_string_table = BinarySection(String(DYNAMIC_STRING_TABLE_SECTION), BINARY_SECTION_TYPE_STRING_TABLE, builder.symbol_name_table.build())
	dynamic_string_table.flags = BINARY_SECTION_FLAGS_ALLOCATE

	builder.add(ELF_DYNAMIC_SECTION_TAG_STRING_TABLE_SIZE, dynamic_string_table.data.size)

	# Create a symbol, which represents the start of the dynamic string table
	# This symbol is used to fill the file offset of the dynamic string table in the dynamic section
	dynamic_string_table_start = BinarySymbol(dynamic_string_table.name, 0, false, dynamic_string_table)

	# Hash section:
	# This section can be used to check efficiently whether a specific symbol exists in the dynamic symbol table
	hash_section = create_hash_section(builder.symbols)
	hash_section.alignment = 8
	hash_section.flags = BINARY_SECTION_FLAGS_ALLOCATE

	# Represent the start of the hash section with a symbol
	hash_section_start = BinarySymbol(hash_section.name, 0, false, hash_section)

	dynamic_linking_information = DynamicLinkingInformation(dynamic_symbol_table, builder.symbol_entries, builder.symbols)
	create_dynamic_relocations(sections, relocations, dynamic_linking_information)

	# Add relocations for hash, symbol and string tables in the dynamic section
	builder.set(ELF_DYNAMIC_SECTION_TAG_HASH_TABLE, hash_section_start, BINARY_RELOCATION_TYPE_ABSOLUTE64) # BINARY_RELOCATION_TYPE_FILE_OFFSET_64
	builder.set(ELF_DYNAMIC_SECTION_TAG_STRING_TABLE, dynamic_string_table_start, BINARY_RELOCATION_TYPE_ABSOLUTE64)
	builder.set(ELF_DYNAMIC_SECTION_TAG_SYMBOL_TABLE, dynamic_symbol_table_start, BINARY_RELOCATION_TYPE_ABSOLUTE64)

	if dynamic_linking_information.relocation_section !== none {
		# Create a symbol, which represents the start of the dynamic relocation table
		dynamic_relocations_section_start = BinarySymbol(dynamic_linking_information.relocation_section.name, 0, false)
		dynamic_relocations_section_start.section = dynamic_linking_information.relocation_section
		dynamic_linking_information.relocation_section.symbols.add(dynamic_relocations_section_start.name, dynamic_relocations_section_start)

		# Add a relocation table entry to the dynamic section entries so that the dynamic linker knows where to find the relocation table
		builder.add(ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE, 0)  # The address is filled in later using a relocation
		builder.add(ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE_SIZE, dynamic_linking_information.relocation_section.data.size)
		builder.add(ELF_DYNAMIC_SECTION_TAG_RELOCATION_ENTRY_SIZE, sizeof(ElfRelocationEntry))
		builder.add(ELF_DYNAMIC_SECTION_TAG_RELOCATION_COUNT, dynamic_linking_information.relocations.size)

		builder.set(ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE, dynamic_relocations_section_start, BINARY_RELOCATION_TYPE_ABSOLUTE64)
	}

	# Connect the relocations to the dynamic section
	builder.connect(dynamic_section, relocations)

	# Add the created sections
	sections.add(hash_section)
	sections.add(dynamic_section)
	sections.add(dynamic_symbol_table)
	sections.add(dynamic_string_table)

	# Output the dynamic section entries into the dynamic section
	dynamic_section.data = Array<byte>(sizeof(ElfDynamicEntry) * (builder.entries.size + 1)) # Allocate one more entry so that the last entry is a none-entry
	binary_utility.write_all<ElfDynamicEntry>(dynamic_section.data, 0, builder.entries)

	return dynamic_linking_information
}

# Summary:
# Adds an interpreter section that specifies the runtime linker that should be used
add_interpreter_section(sections: List<BinarySection>) {
	interpreter = String(DEFAULT_INTERPRETER)

	# Interpreter section must be the first one
	section = BinarySection(String(INTERPRETER_SECTION), BINARY_SECTION_TYPE_DATA, Array<byte>(interpreter.data, interpreter.length + 1))
	section.alignment = 8
	section.flags |= BINARY_SECTION_FLAGS_ALLOCATE

	sections.insert(0, section)
}

# Summary:
# Adds a section that contains relocations for the global offset table.
# These relocations define which symbols correspond to which GOT entries.
add_relocations_for_global_offset_table(sections: List<BinarySection>, externals: List<String>, builder: DynamicSectionBuilder, global_offset_table: BinarySymbol) {
	relocations = List<ElfRelocationEntry>(externals.size, false)

	loop (i = 0, i < externals.size, i++) {
		# Create a relocation that will write the address of the imported function into the global offset table.
		# Leave the offset to zero as it will be corrected with the actual virtual address later using another relocation.
		relocation = ElfRelocationEntry(0, 0)
		relocation.set_info(builder.symbols.size, ELF_SYMBOL_TYPE_JUMP_SLOT)
		relocations.add(relocation)

		# Add an entry for the imported function
		builder.add_symbol(externals[i], none as BinarySection)
	}

	data = Array<byte>(sizeof(ElfRelocationEntry) * relocations.size)
	binary_utility.write_all<ElfRelocationEntry>(data, 0, relocations)

	section = BinarySection(String(RELOCATION_TABLE_SECTION_PREFIX) + FUNCTION_LINKAGE_TABLE_SECTION, BINARY_SECTION_TYPE_DATA, data)
	section.alignment = 8
	section.flags |= BINARY_SECTION_FLAGS_ALLOCATE
	sections.add(section)

	# Create the relocations that will fill in the offsets of the dynamic relocations.
	# We must use relocations, because we do not know the virtual address of the global offset table yet.
	loop (i = 0, i < externals.size, i++) {
		offset = i * sizeof(ElfRelocationEntry)
		addend = (GLOBAL_OFFSET_TABLE_RESERVED_COUNT + i) * strideof(link)
		relocation = BinaryRelocation(global_offset_table, offset, addend, BINARY_RELOCATION_TYPE_ABSOLUTE64, section)

		builder.relocations.add(relocation)
	}

	section_symbol = BinarySymbol(section.name, 0, false, section)

	builder.add(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_BYTES, data.size)
	builder.add(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TYPE, 7)
	builder.add(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TABLE, 0)

	builder.set(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TABLE, section_symbol, BINARY_RELOCATION_TYPE_ABSOLUTE64)
}

# Summary:
# Adds the global offset table (GOT) that contains addresses of dynamic functions
add_global_offset_table(sections: List<BinarySection>, externals: List<String>, builder: DynamicSectionBuilder) {
	data = Array<byte>((externals.size + GLOBAL_OFFSET_TABLE_RESERVED_COUNT) * strideof(link))

	section = BinarySection(String(GLOBAL_OFFSET_TABLE_SECTION), BINARY_SECTION_TYPE_DATA, data)
	section.alignment = 8
	section.flags |= BINARY_SECTION_FLAGS_ALLOCATE | BINARY_SECTION_FLAGS_WRITE
	sections.add(section)

	# Create a symbol for the global offset table, so that it can be found
	global_offset_table = builder.add_symbol(String(GLOBAL_OFFSET_TABLE_SYMBOL_NAME), section)

	add_relocations_for_global_offset_table(sections, externals, builder, global_offset_table)

	builder.add(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_GLOBAL_OFFSET_TABLE, 0)
	builder.add(ELF_DYNAMIC_SECTION_TAG_BIND_NOW, 0)

	builder.set(ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_GLOBAL_OFFSET_TABLE, global_offset_table, BINARY_RELOCATION_TYPE_ABSOLUTE64)

	return global_offset_table
}

# Summary:
# Adds the function linkage table that supports calling dynamic functions.
# Dynamic functions mean functions that are inside shared objects.
add_function_linkage_table(sections: List<BinarySection>, relocations: List<BinaryRelocation>, builder: DynamicSectionBuilder) {
	external_relocations = relocations.filter(i -> i.symbol.external)
	externals = external_relocations
		.map<String>((i: BinaryRelocation) -> i.symbol.name)
		.distinct()

	# If there are no external symbols, no need create anything
	if externals.size == 0 return

	# Insert an interpreter section
	add_interpreter_section(sections)

	# Create the global offset table (GOT) that will store the addresses of the dynamic functions
	global_offset_table = add_global_offset_table(sections, externals, builder)

	instructions = List<Instruction>()

	###
	Function linkage table:
	push qword [rip+GOT+8]
	jmp qword [rip+GOT+16]
	nop
	nop

	.import.<Function 0>: jmp qword [rip+GOT+24+0]; nop x 10
	.import.<Function 1>: jmp qword [rip+GOT+24+8]; nop x 10
	.import.<Function 2>: jmp qword [rip+GOT+24+16]; nop x 10

	.
	.
	.
	###

	# Add: push qword [rip+GOT+8]
	global_offset_table_handle = DataSectionHandle(String(GLOBAL_OFFSET_TABLE_SYMBOL_NAME), 8, false, DATA_SECTION_MODIFIER_NONE)

	instruction = Instruction(String(platform.x64.PUSH), INSTRUCTION_NORMAL)
	instruction.parameters.add(InstructionParameter(global_offset_table_handle, FLAG_NONE))
	instructions.add(instruction)

	# Add: jmp qword [rip+GOT+16]
	global_offset_table_handle = DataSectionHandle(String(GLOBAL_OFFSET_TABLE_SYMBOL_NAME), 16, false, DATA_SECTION_MODIFIER_NONE)

	instruction = Instruction(String(platform.x64.JUMP), INSTRUCTION_JUMP)
	instruction.parameters.add(InstructionParameter(global_offset_table_handle, FLAG_NONE))
	instructions.add(instruction)

	# Pad the runtime linker entry to 16-byte boundary
	instructions.add(NoOperationInstruction(none as Unit))
	instructions.add(NoOperationInstruction(none as Unit))
	instructions.add(NoOperationInstruction(none as Unit))
	instructions.add(NoOperationInstruction(none as Unit))

	loop (i = 0, i < externals.size, i++) {
		import_name = ".import." + externals[i]

		# Load and jump to the address of the imported function using the global offset table as follows:
		# jmp qword [rip+GOT+(i+3)*8]
		global_offset_table_offset = (GLOBAL_OFFSET_TABLE_RESERVED_COUNT + i) * strideof(link)
		global_offset_table_handle = DataSectionHandle(String(GLOBAL_OFFSET_TABLE_SYMBOL_NAME), global_offset_table_offset, false, DATA_SECTION_MODIFIER_NONE)

		# Create the jump and mark it with a label, so the imported function can be accessed
		instructions.add(LabelInstruction(none as Unit, Label(import_name)))

		instruction = Instruction(String(platform.x64.JUMP), INSTRUCTION_JUMP)
		instruction.parameters.add(InstructionParameter(global_offset_table_handle, FLAG_NONE))
		instructions.add(instruction)

		# Pad the data to 16-byte boundary with 10 no-operation instructions
		loop (j = 0, j < 10, j++) { instructions.add(NoOperationInstruction(none as Unit)) }
	}

	# Encode the function linkage table
	function_linkage_table_build = instruction_encoder.encode(instructions, none as String)

	function_linkage_table = function_linkage_table_build.section
	function_linkage_table.alignment = 8
	function_linkage_table.name = String(FUNCTION_LINKAGE_TABLE_SECTION)

	# Connect the relocations inside the function linkage table section to the global offset table
	loop relocation in function_linkage_table.relocations {
		relocation.symbol = global_offset_table
	}

	# Connect the external relocations to the function linkage table entries that call the actual function using GOT
	loop relocation in external_relocations {
		import_name = ".import." + relocation.symbol.name
		relocation.symbol = function_linkage_table.symbols[import_name]
	}

	# Resolve all relocations inside the function linkage table as well
	relocations.add_all(function_linkage_table.relocations)

	sections.add(function_linkage_table)
}

# Summary:
# Finish the specified dynamic linking information by filling symbol section indices into the symbol entires and writing them to the dynamic symbol table.
finish_dynamic_linking_information(information: DynamicLinkingInformation) {
	# Fill in the symbol section indices
	loop (i = 0, i < information.symbols.size, i++) {
		symbol = information.symbols[i]
		symbol_entry = information.entries[i]

		# Fill in the virtual address and section index of the symbol
		if symbol.section !== none {
			symbol_entry.value = symbol.section.virtual_address + symbol.offset
			symbol_entry.section_index = symbol.section.index
		}
		else {
			symbol_entry.value = symbol.offset
		}
	}

	# Write the symbol entries into the dynamic symbol table
	binary_utility.write_all<ElfSymbolEntry>(information.dynamic_section.data, 0, information.entries)

	# Finish dynamic relocations if there are any
	if information.relocation_section === none return

	relocations_entries = List<ElfRelocationEntry>()

	# Generate relocations for all the collected absolute relocations
	# Absolute relocations in a shared library can be expressed as follows:
	# <Base address of the shared library> + <offset of the symbol in the shared library>
	# ELF-standard has a special relocation type for this, which is R_X86_64_RELATIVE.
	loop relocation in information.relocations {
		symbol = relocation.symbol

		# Determine the offset of the symbol in the shared library
		relocation_offset = relocation.section.virtual_address + relocation.offset

		# Now we need to compute the offset of the symbol in the shared library
		symbol_offset = symbol.section.virtual_address + symbol.offset

		# Create a ELF relocation entry for the relocation
		relocation_entry = ElfRelocationEntry(relocation_offset, symbol_offset)
		relocation_entry.set_info(0, ELF_SYMBOL_TYPE_BASE_RELATIVE_64)

		relocations_entries.add(relocation_entry)
	}

	# Write the modified absolute relocations into the dynamic relocation section
	binary_utility.write_all<ElfRelocationEntry>(information.relocation_section.data, 0, relocations_entries)
}

link(objects: List<BinaryObjectFile>, imports: List<String>, entry: String, executable: bool) {
	# Index all the specified object files
	loop (i = 0, i < objects.size, i++) { objects[i].index = i }

	# Make all hidden symbols unique by using their object file indices
	linker.make_local_symbols_unique(objects)

	header = ElfFileHeader()

	if executable {
		header.type = ELF_OBJECT_FILE_TYPE_EXECUTABLE
	}
	else {
		header.type = ELF_OBJECT_FILE_TYPE_DYNAMIC
	}

	header.machine = ELF_MACHINE_TYPE_X64
	header.file_header_size = sizeof(ElfFileHeader)
	header.section_header_size = sizeof(ElfSectionHeader)

	# Resolves are unresolved symbols and returns all symbols as a list
	symbols = linker.resolve_symbols(objects)

	# Create the program headers
	program_headers = List<ElfProgramHeader>()

	# Ensure sections are ordered so that sections of same type are next to each other
	fragments = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections).filter(i -> linker.is_loadable_section(i))

	# Load all the relocations from all the sections
	relocations = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections).flatten<BinaryRelocation>((i: BinarySection) -> i.relocations)

	# Add dynamic sections if needed
	dynamic_linking_information = none as DynamicLinkingInformation

	# 1. Add dynamic information if we have runtime imported symbols
	# 2. Runtime shared library dependencies require dynamic information
	# 3. Shared libraries must have dynamic information
	if relocations.any(i -> i.symbol.external) or imports.size > 0 or not executable {
		dynamic_linking_information = create_dynamic_sections(fragments, symbols, relocations, imports)
	}

	# Order the fragments so that allocated fragments come first
	allocated_fragments = fragments.filter(i -> i.type === BINARY_SECTION_TYPE_NONE or has_flag(i.flags, BINARY_SECTION_FLAGS_ALLOCATE))
	data_fragments = fragments.filter(i -> i.type !== BINARY_SECTION_TYPE_NONE and not has_flag(i.flags, BINARY_SECTION_FLAGS_ALLOCATE))

	fragments = allocated_fragments + data_fragments

	# Create sections, which cover the fragmented sections
	overlays = linker.create_loadable_sections(fragments)

	base_virtual_address = 0
	if executable { base_virtual_address = linker.DEFAULT_BASE_ADDRESS }

	create_program_headers(overlays, fragments, program_headers, base_virtual_address)

	# Now that sections have their virtual addresses relocations can be computed
	linker.compute_relocations(relocations, 0)

	# Create an empty section, so that it is possible to leave section index unspecified in symbols for example.
	# This section is used to align the first loadable section
	none_section = BinarySection(String.empty, BINARY_SECTION_TYPE_NONE, Array<byte>())
	overlays.insert(0, none_section)

	symbols_by_section_type = assembler.group_by<BinarySymbol, large>(symbols.get_values(), (i: BinarySymbol) -> i.section.type)

	# Group the symbols by their section types
	loop section_symbols in symbols_by_section_type {
		section = overlays.find(i -> i.type === section_symbols.key)
		if section === none panic('Symbol did not have a corresponding linker export section')

		loop symbol in section_symbols.value { section.symbols.add(symbol.name, symbol) }
	}

	# Form the symbol table
	create_symbol_related_sections(overlays, fragments, symbols)

	# Finish the specified dynamic linking information by filling symbol section indices into the symbol entires and writing them to the dynamic symbol table
	if dynamic_linking_information !== none finish_dynamic_linking_information(dynamic_linking_information)

	section_headers = create_section_headers(overlays, symbols, linker.SEGMENT_ALIGNMENT)

	# Compute the number of bytes sections take up
	section_bytes = 0
	loop overlay in overlays { section_bytes += overlay.margin + overlay.virtual_size }

	bytes = linker.SEGMENT_ALIGNMENT + section_bytes + section_headers.size * sizeof(ElfSectionHeader)

	# Save the location of the program header table
	header.program_header_offset = sizeof(ElfFileHeader)
	header.program_header_entry_count = program_headers.size
	header.program_header_size = sizeof(ElfProgramHeader)

	# Save the location of the section header table
	header.section_header_offset = linker.SEGMENT_ALIGNMENT + section_bytes
	header.section_header_table_entry_count = section_headers.size
	header.section_header_size = sizeof(ElfSectionHeader)
	header.section_name_entry_index = section_headers.size - 1

	# Compute the entry point location
	entry_point_symbol = symbols[entry]
	header.entry = entry_point_symbol.section.virtual_address + entry_point_symbol.offset

	result = Array<byte>(bytes)

	# Write the file header
	binary_utility.write<ElfFileHeader>(result, 0, header)

	# Write the program header table now
	position = header.program_header_offset

	loop program_header in program_headers {
		binary_utility.write<ElfProgramHeader>(result, position, program_header)
		position += sizeof(ElfProgramHeader)
	}

	loop section in overlays {
		# Loadable sections are handled with the fragments
		if linker.is_loadable_section(section) continue

		binary_utility.write_bytes(section.data, result.data, section.offset, section.data.size)
	}

	# Write the loadable sections
	loop fragment in fragments {
		binary_utility.write_bytes(fragment.data, result.data, fragment.offset, fragment.data.size)
	}

	# Write the section header table now
	position = header.section_header_offset

	loop section_header in section_headers {
		binary_utility.write<ElfSectionHeader>(result, position, section_header)
		position += sizeof(ElfSectionHeader)
	}

	return result
}

# Summary: Packs the sections of the specified objects into a raw binary file
build_binary_file(objects: List<BinaryObjectFile>) {
	# Index all the specified object files
	loop (i = 0, i < objects.size, i++) { objects[i].index = i }

	# Make all hidden symbols unique by using their object file indices
	linker.make_local_symbols_unique(objects)

	# Resolves are unresolved symbols and returns all symbols as a list
	symbols = linker.resolve_symbols(objects)

	# Ensure sections are ordered so that sections of same type are next to each other
	fragments = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections).filter(i -> linker.is_loadable_section(i))

	# Load all the relocations from all the sections
	relocations = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections).flatten<BinaryRelocation>((i: BinarySection) -> i.relocations)

	# Ensure are relocations are resolved
	loop relocation in relocations {
		if not relocation.symbol.external continue
		abort("Symbol " + relocation.symbol.name + " is not defined locally or externally")
	}

	# Create sections, which cover the fragmented sections
	overlays = linker.create_loadable_sections(fragments)

	# Compute virtual addresses for the sections
	create_program_headers(overlays, fragments, List<ElfProgramHeader>(), settings.base_address, false)

	# Now that sections have their virtual addresses relocations can be computed
	linker.compute_relocations(relocations, 0)

	# Compute the number of bytes sections take up
	bytes = 0
	loop overlay in overlays { bytes += overlay.margin + overlay.virtual_size }

	result = Array<byte>(bytes)

	# Write the fragments
	loop fragment in fragments {
		binary_utility.write_bytes(fragment.data, result.data, fragment.offset, fragment.data.size)
	}

	return result
}