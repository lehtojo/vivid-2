namespace pe_format {
	constant FileSectionAlignment = 0x200
	constant VirtualSectionAlignment = 0x1000

	constant NumberOfDataDirectories = 16

	constant ExporterSectionIndex = 0
	constant ImporterSectionIndex = 1
	constant BaseRelocationSectionIndex = 5
	constant ImportAddressSectionIndex = 12

	constant SharedLibraryBaseAddress = 0x10000000

	constant RelocationSectionPrefix = '.r'
	constant NoneSection = '.'
	constant TextSection = '.text'
	constant DataSection = '.data'
	constant SymbolTableSection = '.symtab'
	constant StringTableSection = '.strtab'
	constant ImporterSection = '.idata'
	constant ExporterSection = '.edata'
	constant BaseRelocationSection = '.reloc'

	# Summary: Encodes the specified name into a 64-bit integer (zero padded from the end)
	encode_integer_name(name: String) {
		bytes: char[8]
		zero(bytes as link, 8)

		loop (i = 0, i < name.length, i++) {
			bytes[i] = name[i]
		}

		=> bytes.(link<large>)[0]
	}

	# Summary: Converts the encoded 64-bit integer name into a string
	decode_integer_name(encoded: large) {
		name: char[9] # Size = sizeof(large) + 1
		zero(name as link, 9)
		binary_utility.write_int64(name as link, 0, encoded)

		=> String(name as link)
	}
	
	# Summary:
	# Loads the offset of the PE header in the image file
	get_header_offset(bytes: Array<byte>) {
		=> (bytes.data + PeLegacyHeader.PeHeaderPointerOffset).(link<normal>)[0]
	}

	# Summary:
	# Computes the file offset corresponding to the specified virtual address
	relative_virtual_address_to_file_offset(module: PeMetadata, relative_virtual_address: large) {
		loop section in module.sections {
			# Find the section, which contains the specified virtual address
			end = section.virtual_address + section.virtual_size
			if relative_virtual_address > end continue

			# Calculate the offset in the section
			offset = relative_virtual_address - section.virtual_address

			# Calculate the file offset
			=> section.pointer_to_raw_data + offset
		}

		=> -1
	}

	# Summary:
	# Loads all the data directories from the specified image file bytes starting from the specified offset
	load_data_directories(bytes: Array<byte>, start: large, count: large) {
		if count == 0 => List<PeDataDirectory>()

		directories = List<PeDataDirectory>()
		length = PeDataDirectory.Size
		end = false

		loop (start + length <= bytes.count) {
			if count-- <= 0 {
				end = true
				stop
			}

			directories.add(binary_utility.read_object<PeDataDirectory>(bytes, start))
			start += length
		}

		if end => directories
		=> none as List<PeDataDirectory>
	}

	# Summary:
	# Loads the specified number of section tables from the specified image file bytes starting from the specified offset
	load_section_tables(bytes: Array<byte>, start: large, count: large) {
		if count == 0 => List<PeSectionTable>()

		directories = List<PeSectionTable>()
		length = PeSectionTable.Size
		end = false

		loop (start + length <= bytes.count) {
			if count-- <= 0 {
				end = true
				stop
			}

			directories.add(binary_utility.read_object<PeSectionTable>(bytes, start))
			start += length
		}

		if end => directories
		=> none as List<PeSectionTable>
	}

	# Summary:
	# Loads library metadata including the PE-header, data directories and section tables
	load_library_metadata(file: String) {
		# Load the image file and determine the PE header offset
		if not (io.read_file(file) has bytes) => none as PeMetadata
		header_offset = get_header_offset(bytes)

		if header_offset < 0 or header_offset + PeHeader.Size > bytes.count => none as PeMetadata

		# Read the PE-header
		header = binary_utility.read_object<PeHeader>(bytes, header_offset)

		# Load the data directories, which come after the header
		data_directories_offset = header_offset + PeHeader.Size
		data_directories = load_data_directories(bytes, data_directories_offset, header.data_directories)

		if data_directories == none or header.number_of_sections < 0 => none as PeMetadata

		# Load the section tables, which come after the data directories
		section_table_offset = header_offset + PeHeader.OptionalHeaderOffset + header.size_of_optional_headers

		sections = load_section_tables(bytes, section_table_offset, header.number_of_sections)
		if sections == none => none as PeMetadata

		=> PeMetadata(bytes, header, data_directories, sections)
	}

	# Summary:
	# Finds a section with the specified name from the specified metadata.
	# Ensure the specified name is exactly eight characters long, padded with none characters if necessary.
	find_section(module: PeMetadata, name: String) {
		encoded_name = encode_integer_name(name)
		=> module.sections.find_or(i -> i.name == encoded_name, none)
	}

	# Summary:
	# Loads strings the specified amount starting from the specified position.
	load_number_of_strings(bytes: Array<byte>, position: large, count: large) {
		if position < 0 => none as List<String>

		strings = List<String>(count, true)

		loop (i = 0, i < count, i++) {
			end = position
			loop (end < bytes.count and bytes[end] != 0, end++) { }

			strings[i] = String.from(bytes.data + position, end - position)

			position = end + 1
		}

		=> strings
	}

	# Summary:
	# Loads strings starting from the specified position until the limit is reached.
	load_strings_until(bytes: Array<byte>, position: large, limit: large) {
		if position < 0 => none as List<String>

		strings = List<String>()

		loop (position < limit) {
			end = position
			loop (end < limit and bytes[end] != 0, end++) { }

			strings.add(String.from(bytes.data + position, end - position))

			position = end + 1
		}

		=> strings
	}

	# Summary:
	# Extracts the exported symbols from the specified export section.
	load_exported_symbols(module: PeMetadata) {
		# Check if the library has an export table
		export_data_directory = module.data_directories[ExporterSectionIndex]
		if export_data_directory.relative_virtual_address == 0 => none as List<String>

		export_data_directory_file_offset = relative_virtual_address_to_file_offset(module, export_data_directory.relative_virtual_address)
		if export_data_directory_file_offset < 0 => none as List<String>

		export_directory_table = binary_utility.read_object<PeExportDirectoryTable>(module.bytes, export_data_directory_file_offset)

		# Skip the export directory table, the export address table, the name pointer table and the ordinal table
		export_directory_table_size = PeExportDirectoryTable.Size
		export_address_table_size = export_directory_table.number_of_addresses * sizeof(normal)
		name_pointer_table_size = export_directory_table.number_of_name_pointers * sizeof(normal)
		ordinal_table_size = export_directory_table.number_of_name_pointers * sizeof(normal)

		start = export_data_directory_file_offset + export_directory_table_size + export_address_table_size + name_pointer_table_size + ordinal_table_size

		# Load one string more since the first name is the name of the module and it is not counted
		strings = load_strings_until(module.bytes, start, export_data_directory_file_offset + export_data_directory.physical_size)

		# Skip the name of the module if the load was successful
		=> strings.slice(1)
	}

	# Summary:
	# Loads the exported symbols from the specified library.
	load_exported_symbols(library: String) {
		metadata = load_library_metadata(library)
		if metadata == none => none as List<String>

		=> load_exported_symbols(metadata)
	}

	# Summary:
	# Converts the relocation type to corresponding PE relocation type
	get_relocation_type(type: large) {
		=> when(type) {
			BINARY_RELOCATION_TYPE_PROCEDURE_LINKAGE_TABLE => PE_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE_32,
			BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE => PE_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE_32,
			BINARY_RELOCATION_TYPE_ABSOLUTE64 => PE_RELOCATION_TYPE_ABSOLUTE64,
			BINARY_RELOCATION_TYPE_ABSOLUTE32 => PE_RELOCATION_TYPE_ABSOLUTE32,
			else => 0
		}
	}
	
	# Summary:
	# Determines appropriate section flags loop the specified section
	get_section_characteristics(section: BinarySection) {
		type = section.type
		characteristics = PE_SECTION_CHARACTERISTICS_READ

		if type == BINARY_SECTION_TYPE_TEXT {
			characteristics |= PE_SECTION_CHARACTERISTICS_EXECUTE
			characteristics |= PE_SECTION_CHARACTERISTICS_CODE
		}
		else type == BINARY_SECTION_TYPE_DATA or type == BINARY_SECTION_TYPE_RELOCATION_TABLE {
			characteristics |= PE_SECTION_CHARACTERISTICS_WRITE
			characteristics |= PE_SECTION_CHARACTERISTICS_INITIALIZED_DATA
		}

		# Now, compute the alignment flag
		# 1-byte alignment:    0x00100000
		# 2-byte alignment:    0x00200000
		#                          .
		#                          .
		#                          .
		# 8192-byte alignment: 0x00E00000
		characteristics |= (PE_SECTION_CHARACTERISTICS_ALIGN_1 + common.integer_log2(section.alignment)) <| 20

		=> characteristics
	}

	# Summary:
	# Creates the symbol table and the relocation table based on the specified symbols
	create_symbol_related_sections(symbol_name_table: BinaryStringTable, sections: List<BinarySection>, fragments: List<BinarySection>, symbols: Map<String, BinarySymbol>, file_position: large) {
		symbol_entries = List<PeSymbolEntry>()

		# Index the sections since the symbols need that
		loop (i = 0, i < sections.size, i++) {
			section = sections[i]
			section.index = i

			if fragments == none continue
			
			# Index the section fragments as well according to the overlay section index
			# Store the virtual address of the first fragment into all the fragments (base virtual address)
			loop fragment in fragments {
				if not (fragment.name == section.name) continue
				fragment.base_virtual_address = section.virtual_address
				fragment.index = i
			}
		}

		loop iterator in symbols {
			symbol = iterator.value

			base_virtual_address = 0
			virtual_address = 0

			if symbol.section != none {
				base_virtual_address = symbol.section.base_virtual_address
				virtual_address = symbol.section.virtual_address
			}

			symbol_entry = PeSymbolEntry()
			symbol_entry.value = virtual_address + symbol.offset - base_virtual_address # Symbol locations are relative to the start of the section

			if symbol.external {
				symbol_entry.section_number = 0
				symbol_entry.storage_class = PE_STORAGE_CLASS_EXTERNAL
			}
			else symbol.exported {
				symbol_entry.section_number = symbol.section.index + 1
				symbol_entry.storage_class = PE_STORAGE_CLASS_EXTERNAL
			}
			else {
				symbol_entry.section_number = symbol.section.index + 1
				symbol_entry.storage_class = PE_STORAGE_CLASS_LABEL
			}

			# Now we need to attach the symbol name to the symbol entry
			# If the length of the name is greater than 8, we need to create a string table entry
			# Otherwise, we can just store the name in the symbol entry
			if symbol.name.length > 8 {
				# Add the symbol name into the string table and receive its offset
				offset = symbol_name_table.add(symbol.name)

				# Set the name offset in the symbol entry
				# The offset must start after four zero bytes so that it can be distinguished from an inlined name (see the other branch below)
				symbol_entry.name = offset <| 32
			}
			else {
				# Store the characters inside a 64-bit integer
				symbol_entry.name = encode_integer_name(symbol.name)
			}

			symbol.index = symbol_entries.size
			symbol_entries.add(symbol_entry)
		}

		# Create the relocation section loop all sections that have relocations
		n = sections.size

		loop (i = 0, i < n, i++) {
			section = sections[i]
			relocation_entries = List<PeRelocationEntry>()

			loop relocation in section.relocations {
				relocation_entry = PeRelocationEntry()
				relocation_entry.virtual_address = relocation.offset
				relocation_entry.symbol_table_index = relocation.symbol.index
				relocation_entry.type = get_relocation_type(relocation.type)

				relocation_entries.add(relocation_entry)
			}

			# Determine the name of the relocation section
			relocation_table_name = String(RelocationSectionPrefix) + section.name.slice(1)

			# Create a section loop the relocation table
			relocation_table_section_data = Array<byte>(PeRelocationEntry.Size * relocation_entries.size)
			relocation_table_section = BinarySection(relocation_table_name, BINARY_SECTION_TYPE_RELOCATION_TABLE, relocation_table_section_data)
			relocation_table_section.offset = file_position
			binary_utility.write_all<PeRelocationEntry>(relocation_table_section_data, 0, relocation_entries)

			sections.add(relocation_table_section) # Add the relocation table section to the list of sections

			# Update the file position
			file_position += relocation_table_section_data.count
		}

		# Export the data from the generated string table, since it has to come directly after the symbol table
		symbol_name_table_data = symbol_name_table.build()

		# Create the symbol table section
		symbol_table_section_data = Array<byte>(PeSymbolEntry.Size * symbol_entries.size + symbol_name_table_data.count)
		symbol_table_section = BinarySection(String(SymbolTableSection), BINARY_SECTION_TYPE_SYMBOL_TABLE, symbol_table_section_data)
		symbol_table_section.offset = file_position

		# Write the symbol table entries
		binary_utility.write_all<PeSymbolEntry>(symbol_table_section_data, 0, symbol_entries)

		# Store the string table data into the symbol table section as well
		copy(symbol_name_table_data.data, symbol_name_table_data.count, symbol_table_section_data.data + symbol_entries.size * PeSymbolEntry.Size)

		sections.add(symbol_table_section) # Add the symbol table section to the list of sections

		=> symbol_table_section
	}

	# Summary:
	# Fills all the empty section in the specified list of sections with one byte.
	# Instead of just removing these sections, this is done to preserve all the properties of these sections such as symbols.
	# If these sections would have a size of zero, then overlapping sections could emerge.
	fill_empty_sections(sections: List<BinarySection>) {
		loop section in sections {
			if section.data.count > 0 continue
			section.data = Array<byte>(1)
		}
	}

	# Summary:
	# Creates an object file from the specified sections
	create_object_file(name: String, sections: List<BinarySection>, exports: Set<String>) {
		fill_empty_sections(sections)

		# Load all the symbols from the specified sections
		symbols = binary_utility.get_all_symbols_from_sections(sections)

		# Export the specified symbols
		binary_utility.apply_exports(symbols, exports)

		# Update all the relocations before adding them to binary sections
		binary_utility.update_relocations(sections, symbols)

		# Add symbols and relocations of each section needing that
		create_symbol_related_sections(BinaryStringTable(true), sections, none as List<BinarySection>, symbols, 0)

		# Now that section positions are set, compute offsets
		binary_utility.compute_offsets(sections, symbols)

		=> BinaryObjectFile(name, sections, symbols.get_values().filter(i -> i.exported).map<String>((i: BinarySymbol) -> i.name))
	}

	# Summary:
	# Creates an object file from the specified sections
	build(sections: List<BinarySection>, exports: Set<String>) {
		fill_empty_sections(sections)

		# Load all the symbols from the specified sections
		symbols = binary_utility.get_all_symbols_from_sections(sections)

		# Filter out the none-section if it is present
		if sections.size > 0 and sections[0].type == BINARY_SECTION_TYPE_NONE sections.remove_at(0)

		# Export the specified symbols
		binary_utility.apply_exports(symbols, exports)

		# Update all the relocations before adding them to binary sections
		binary_utility.update_relocations(sections, symbols)

		symbol_name_table = BinaryStringTable(true)

		# Create initial versions of section tables and finish them later when section offsets are known
		section_tables = List<PeSectionTable>()

		loop section in sections {
			section_name = section.name

			# If the section name is too long, move it into the string table and point to that name by using the pattern '/<Section name offset in the string table>'
			if section.name.length > 8 {
				section_name = String('/') + to_string(symbol_name_table.add(section.name))
			}

			section_table = PeSectionTable()
			section_table.name = encode_integer_name(section_name)
			section_table.virtual_address = 0
			section_table.virtual_size = section.virtual_size
			section_table.size_of_raw_data = section.virtual_size
			section_table.pointer_to_raw_data = 0 # Fill in later when the section offsets are decided
			section_table.pointer_to_relocations = 0 # Fill in later when the section offsets are decided
			section_table.pointer_to_linenumbers = 0 # Not used
			section_table.number_of_relocations = 0 # Fill in later
			section_table.number_of_linenumbers = 0 # Not used
			section_table.characteristics = get_section_characteristics(section)

			section_tables.add(section_table)
		}

		# Exclude the sections created below and go with the existing ones, since the ones created below are not needed in the section tables
		header = PeObjectFileHeader()
		header.number_of_sections = sections.size
		header.machine = PE_MACHINE_X64
		header.timestamp = 0
		header.characteristics = PE_IMAGE_CHARACTERISTICS_LARGE_ADDRESS_AWARE | PE_IMAGE_CHARACTERISTICS_LINENUMBERS_STRIPPED | PE_IMAGE_CHARACTERISTICS_DEBUG_STRIPPED

		# Add symbols and relocations of each section needing that
		create_symbol_related_sections(symbol_name_table, sections, none as List<BinarySection>, symbols, 0)

		if sections.find_or((i: BinarySection) -> i.type == BINARY_SECTION_TYPE_RELOCATION_TABLE, none as BinarySection) == none {
			header.characteristics |= PE_IMAGE_CHARACTERISTICS_RELOCATIONS_STRIPPED
		}

		header.size_of_optional_headers = 0

		# Decide section offsets
		file_position = PeObjectFileHeader.Size + section_tables.size * PeSectionTable.Size

		loop section in sections {
			section.offset = file_position
			file_position += section.data.count
		}

		# Now, finish the section tables
		loop (i = 0, i < section_tables.size, i++) {
			section_table = section_tables[i]
			section = sections[i]

			section_table.pointer_to_raw_data = section.offset

			# Skip relocations if there are none
			if section.relocations.size == 0 continue

			# Why does PE-format restrict the number of relocations to 2^16 in a single section...
			if section.relocations.size > U16_MAX abort('Too many relocations')

			# Find the relocation table loop this section
			relocation_table_name = String(RelocationSectionPrefix) + section.name.slice(1)
			relocation_table = sections.find_or(i -> i.name == relocation_table_name, none as BinarySection)
			if relocation_table == none abort('Missing relocation section')

			section_table.pointer_to_relocations = relocation_table.offset
			section_table.number_of_relocations = section.relocations.size
		}

		# Now that section positions are set, compute offsets
		binary_utility.compute_offsets(sections, symbols)

		# Store the location of the symbol table
		symbol_table = sections.find_or(i -> i.name == SymbolTableSection, none as BinarySection)

		if symbol_table != none {
			header.number_of_symbols = symbols.size
			header.pointer_to_symbol_table = symbol_table.offset
		}

		# Create the binary file
		binary = Array<byte>(file_position)

		# Write the file header
		binary_utility.write<PeObjectFileHeader>(binary, 0, header)

		# Write the section tables
		binary_utility.write_all<PeSectionTable>(binary, PeObjectFileHeader.Size, section_tables)

		# Write the sections
		loop section in sections {
			section_data = section.data

			# Write the section data
			copy(section_data.data, section_data.count, binary.data + section.offset)
		}

		=> binary
	}

	align_sections(section: BinarySection, file_position: large) {
		# Determine the virtual address alignment to use, since the section can request loop larger alignment than the default.
		alignment = max(section.alignment, VirtualSectionAlignment)

		# Align the file position
		file_position = (file_position + alignment - 1) & !(alignment - 1)

		# Update the section virtual address and file offset
		section.virtual_address = file_position
		section.offset = file_position

		# Update the section size
		section.virtual_size = section.data.count
		section.load_size = section.data.count

		=> file_position + section.data.count
	}

	align_sections(overlays: List<BinarySection>, fragments: List<BinarySection>, file_position: large) {
		# Align the file positions and virtual addresses of the overlays.
		loop section in overlays {
			# Determine the virtual address alignment to use, since the section can request loop larger alignment than the default.
			alignment = max(section.alignment, VirtualSectionAlignment)

			# Align the file position
			file_position = (file_position + alignment - 1) & !(alignment - 1)

			section.virtual_address = file_position
			section.offset = file_position

			# Now, decide the file position and virtual address loop the fragments
			loop fragment in fragments {
				if not (fragment.name == section.name) continue

				# Align the file position with the fragment alignment
				file_position = (file_position + fragment.alignment - 1) & !(fragment.alignment - 1)

				fragment.virtual_address = file_position
				fragment.offset = file_position

				# Move to the next fragment
				file_position += fragment.data.count
			}

			# Update the overlay size
			section.virtual_size = file_position - section.offset
			section.load_size = section.virtual_size
		}

		=> file_position
	}

	create_exporter_section(sections: List<BinarySection>, relocations: List<BinaryRelocation>, symbols: List<BinarySymbol>, output_name: String) {
		# The exported symbols must be sorted by name (ascending)
		symbols = symbols.filter(i -> i.exported and not i.external)

		# The sort function must be done manually, because loop some reason the default one prefers lower case characters over upper case characters even though it is the opposite if you use the UTF-8 table
		symbols.order((a: BinarySymbol, b: BinarySymbol) -> {
			n = a.name
			m = b.name

			loop (i = 0, i < min(n.length, m.length), i++) {
				x = n[i]
				y = m[i]

				if x < y => -1
				if x > y => 1
			}

			=> n.length - m.length
		})

		# Compute the number of bytes needed loop the export section excluding the string table
		string_table_start = PeExportDirectoryTable.Size + symbols.size * (sizeof(normal) + sizeof(normal) + sizeof(normal))
		string_table = BinaryStringTable()

		exporter_section_data = Array<byte>(string_table_start)
		exporter_section = BinarySection(String(ExporterSection), BINARY_SECTION_TYPE_DATA, exporter_section_data)

		export_address_table_position = PeExportDirectoryTable.Size
		name_pointer_table_position = PeExportDirectoryTable.Size + symbols.size * sizeof(normal)
		ordinal_table_position = PeExportDirectoryTable.Size + symbols.size * (sizeof(normal) + sizeof(normal))

		# Create symbols, which represent the start of the tables specified above
		export_address_table_symbol = BinarySymbol(String('.export-address-table'), export_address_table_position, false, exporter_section)
		name_pointer_table_symbol = BinarySymbol(String('.name-pointer-table'), name_pointer_table_position, false, exporter_section)
		ordinal_table_symbol = BinarySymbol(String('.ordinal-table'), ordinal_table_position, false, exporter_section)

		loop (i = 0, i < symbols.size, i++) {
			# NOTE: None of the virtual addresses can be written at the moment, since section virtual addresses are not yet known. Therefore, they must be completed with relocations.
			symbol = symbols[i]

			# Write the virtual address of the exported symbol to the export address table
			exporter_section.relocations.add(BinaryRelocation(symbol, export_address_table_position, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))

			# Write the name virtual address to the export section data using a relocation
			name_pointer = string_table_start + string_table.add(symbol.name)
			name_symbol = BinarySymbol(String('.string.') + symbol.name, name_pointer, false, exporter_section)
			exporter_section.relocations.add(BinaryRelocation(name_symbol, name_pointer_table_position, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))

			# Write the ordinal to the export section data
			binary_utility.write_int16(exporter_section_data, ordinal_table_position, i)

			# Move all of the positions to the next entry
			export_address_table_position += sizeof(normal)
			name_pointer_table_position += sizeof(normal)
			ordinal_table_position += sizeof(normal)
		}

		# Store the output name of this shared library in the string table
		library_name_symbol = BinarySymbol(String('.library'), string_table_start + string_table.add(output_name), false, exporter_section)

		# Add the string table inside the exporter section
		string_table_data = string_table.build()
		exporter_section.data = Array<byte>(exporter_section_data.count + string_table_data.count)
		copy(exporter_section_data.data, exporter_section_data.count, exporter_section.data.data)
		copy(string_table_data.data, string_table_data.count, exporter_section.data.data + exporter_section_data.count)

		# Update the exporter section size
		exporter_section.virtual_size = exporter_section.data.count
		exporter_section.load_size = exporter_section.data.count

		#warning Fix the timestamp
		export_directory_table = PeExportDirectoryTable()
		export_directory_table.timestamp = 0
		export_directory_table.major_version = 0
		export_directory_table.minor_version = 0
		export_directory_table.ordinal_base = 1
		export_directory_table.number_of_addresses = symbols.size
		export_directory_table.number_of_name_pointers = symbols.size

		# Write the export directory table to the exporter section data
		binary_utility.write<PeExportDirectoryTable>(exporter_section.data, 0, export_directory_table)

		# Store the name of the library to the export directory table using a relocation
		exporter_section.relocations.add(BinaryRelocation(library_name_symbol, PeExportDirectoryTable.NameAddressOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))

		# Write the virtual addresses of the tables to the export directory table using relocations
		exporter_section.relocations.add(BinaryRelocation(export_address_table_symbol, PeExportDirectoryTable.ExportAddressTableAddressOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))
		exporter_section.relocations.add(BinaryRelocation(name_pointer_table_symbol, PeExportDirectoryTable.NamePointerTableAddressOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))
		exporter_section.relocations.add(BinaryRelocation(ordinal_table_symbol, PeExportDirectoryTable.OrdinalTableAddressOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, exporter_section))

		# Export the created section and its relocations
		sections.add(exporter_section)
		relocations.add_range(exporter_section.relocations)

		=> exporter_section
	}

	# Summary:
	# Generates dynamic linkage information loop the specified imported symbols. This function generates the following structures:
	#
	# .section .idata
	# <Directory table 1>:
	# <import-lookup-table-1> (4 bytes)
	# Timestamp: 0x00000000
	# Forwarded chain: 0x00000000
	# <library-name-1> (4 bytes)
	# <import-address-table-1> (4 bytes)
	#
	# <Directory table 2>:
	# <import-lookup-table-2> (4 bytes)
	# Timestamp: 0x00000000
	# Forwarded chain: 0x00000000
	# <library-name-2> (4 bytes)
	# <import-address-table-2> (4 bytes)
	# 
	# ...
	#
	# <Directory table n>:
	# Import lookup table: 0x00000000
	# Timestamp: 0x00000000
	# Forwarded chain: 0x00000000
	# Name: 0x00000000
	# Import address table: 0x00000000
	#
	# <import-lookup-table-1>:
	# 0x00000000 <.string.<function-1>>
	# 0x00000000 <.string.<function-2>>
	# 0x0000000000000000
	# <import-lookup-table-2>:
	# 0x00000000 <.string.<function-3>>
	# 0x00000000 <.string.<function-4>>
	# 0x0000000000000000
	#
	# ...
	#
	# <import-lookup-table-n>:
	# 0x00000000 <.string.<function-(n-1)>>
	# 0x00000000 <.string.<function-n>>
	# 0x0000000000000000
	#
	# <library-name-1>: ... 0
	# <library-name-2>: ... 0
	#
	# ...
	#
	# <library-name-n>: ... 0
	#
	# <.string.<function-1>>: ... 0
	# <.string.<function-2>>: ... 0
	#
	# ...
	#
	# <.string.<function-n>>: ... 0
	#
	# .section .text
	# <imports-1>:
	# <function-1>: jmp qword [.import.<function-1>]
	# <function-2>: jmp qword [.import.<function-2>]
	#
	# ...
	#
	# <function-n>: jmp qword [.import.<function-n>]
	#
	# <imports-2>:
	# ...
	# <imports-n>:
	# 
	# .section .data
	# <import-address-table-1>:
	# <.import.<function-1>>: .qword 0
	# <.import.<function-2>>: .qword 0
	# ...
	# <.import.<function-n>>: .qword 0
	#
	# <import-address-table-2>:
	# ...
	# <import-address-table-n>:
	create_dynamic_linkage(relocations: List<BinaryRelocation>, imports: List<String>, fragments: List<BinarySection>) {
		# Only dynamic libraries are inspected here
		extension = shared_library_extension()
		imports = imports.filter(i -> i.ends_with(extension))

		externals = relocations.filter(i -> i.symbol.external)
		exports = imports.map<List<String>>((i: String) -> load_exported_symbols(i))

		# There can be multiple relocations, which refer to the same symbol but the symbol object instances are different (relocations can be in different objects).
		# Therefore, we need to create a dictionary, which we will use to connect all the relocations into shared symbols.
		relocation_symbols = Map<String, BinarySymbol>()
		importer_section = BinarySection(String(ImporterSection), BINARY_SECTION_TYPE_DATA, Array<byte>())
		import_section_instructions = List<Instruction>()
		import_address_section_builder = DataEncoderModule()
		import_lists = Map<String, List<String>>()
		string_table = DataEncoderModule()

		import_address_section_builder.name = String(ImporterSection)

		loop relocation in externals {
			# If the relocation symbol can be found from the import section symbols, the library which defines the symbol is already found
			if relocation_symbols.contains_key(relocation.symbol.name) {
				relocation.symbol = relocation_symbols[relocation.symbol.name] # Connect the relocation to the shared symbol
				continue
			}

			# Go through all the libraries and find the one which has the external symbol
			library = none as String

			loop (i = 0, i < imports.size, i++) {
				symbols = exports[i]

				# Not being able to load the exported symbols is not fatal, so we can continue, however we should notify the user
				if symbols == none {
					println(String('Warning: Could not load exported symbols from library: ') + imports[i])
					continue
				}

				if not symbols.contains(relocation.symbol.name) continue

				# Ensure the external symbol is not defined in multiple libraries, because this could cause weird behavior depending on the order of the imported libraries
				if library != none abort(String('Symbol ') + relocation.symbol.name + ' is defined in both ' + library + ' and ' + imports[i])

				library = imports[i]
			}

			# Ensure the library was found
			if library === none abort(String('Symbol ') + relocation.symbol.name + ' is not defined locally or externally')

			# Add the symbol to the import list linked to the library
			if import_lists.contains_key(library) { import_lists[library].add(relocation.symbol.name) }
			else { import_lists[library] = [ relocation.symbol.name ] }

			# Make the symbol local, since it will be defined below as an indirect jump to the actual implementation
			relocation.symbol.external = false

			relocation_symbols[relocation.symbol.name] = relocation.symbol
			importer_section.symbols.add(relocation.symbol.name, relocation.symbol)
		}

		# Compute where the string table starts. This is also the amount of bytes needed for the other importer data.
		string_table_start = (import_lists.size + 1) * PeImportDirectoryTable.Size

		loop iterator in import_lists {
			symbols = iterator.value
			string_table_start += (symbols.size + 1) * sizeof(large)
		}

		importer_section.data = Array<byte>(string_table_start)

		import_lookup_table_starts = Array<BinarySymbol>(import_lists.size)
		import_address_table_starts = Array<BinarySymbol>(import_lists.size)
		position = 0

		# Write the directory tables
		loop (i = 0, i < import_lists.size, i++) {
			import_library = imports[i]
			import_list = import_lists[import_library]

			# Create symbols for the import lookup table, library name and import address table that describe their virtual addresses
			import_lookup_table_start = BinarySymbol(String('.lookup.') + to_string(i), 0, false, importer_section)
			import_library_name_start = BinarySymbol(String('.library.') + to_string(i), 0, false, importer_section)
			import_address_table_start = BinarySymbol(String('.imports.') + to_string(i), 0, false)

			# Add the library name to the string table and compute its offset
			string_table.write_int16(0)
			import_library_name_start.offset = string_table_start + string_table.position

			library_filename = io.path.basename(import_library)
			string_table.string(library_filename)

			# Align the next entry on an even boundary
			if string_table.position % 2 != 0 string_table.write(0)

			import_lookup_table_starts[i] = import_lookup_table_start
			import_address_table_starts[i] = import_address_table_start

			# Fill the locations of the symbols into the import directory when their virtual addresses have been decided
			relocations.add(BinaryRelocation(import_lookup_table_start, position, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, importer_section))
			relocations.add(BinaryRelocation(import_library_name_start, position + PeImportDirectoryTable.NameOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, importer_section))
			relocations.add(BinaryRelocation(import_address_table_start, position + PeImportDirectoryTable.ImportAddressTableOffset, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, importer_section))

			# Move to the next directory table
			position += PeImportDirectoryTable.Size
		}

		position += PeImportDirectoryTable.Size # Skip the empty directory table at the end

		# Populate the string table with the imported symbols and create the import lookup tables
		loop (i = 0, i < import_lists.size, i++) {
			import_list = import_lists[imports[i]]

			# Store the relative offset of the import address table in the import address table section (Imports)
			import_address_table_starts[i].offset = import_address_section_builder.position

			# Store the location of this import lookup table in the symbol, which represents it (Importer)
			import_lookup_table_starts[i].offset = position

			loop import_symbol_name in import_list {
				# Create a symbol for the import so that a relocation can be made
				import_symbol_offset = string_table_start + string_table.position
				string_table.write_int16(0) # This 16-bit index is used for quick lookup of the symbol in the imported library, do not care about it for now
				string_table.string(import_symbol_name)

				# Align the next entry on an even boundary
				if string_table.position % 2 != 0 string_table.write(0)

				import_symbol = BinarySymbol(String('.string.') + import_symbol_name, import_symbol_offset, false, importer_section)

				# Fill in the location of the imported symbol when its virtual address is decided
				relocations.add(BinaryRelocation(import_symbol, position, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32, importer_section))
				position += sizeof(large)

				# Reserve space for the address of the imported function when it is loaded, also create a symbol which represents the location of the address
				import_address_symbol = import_address_section_builder.create_local_symbol(String('.import.') + import_symbol_name, import_address_section_builder.position, false)
				import_address_section_builder.relocations.add(BinaryRelocation(import_symbol, import_address_section_builder.position, 0, BINARY_RELOCATION_TYPE_BASE_RELATIVE_32))
				import_address_section_builder.write_int64(0)

				#warning Support Arm64
				if not settings.is_x64 abort('Import code generation is not implemented loop Arm64')

				# Create a label, which defines the imported function so that the other code can jump indirectly to the actual implementation
				# Instruction: <function>:
				import_section_instructions.add(LabelInstruction(none as Unit, Label(import_symbol_name)))

				# Create an instruction, which jumps to the location of the imported function address
				# Instruction: jmp qword [.import.<function>]
				instruction = Instruction(none as Unit, INSTRUCTION_JUMP)
				instruction.operation = String(platform.x64.JUMP)

				# Create a handle, which the instruction uses refer to the imported function
				import_address_handle = DataSectionHandle(import_address_symbol.name, false)
				instruction.parameters.add(InstructionParameter(import_address_handle, FLAG_NONE))

				import_section_instructions.add(instruction)
			}

			position += sizeof(large) # Skip the none-symbol at the end of each import lookup table
		}

		# Build the import address section
		import_address_section = import_address_section_builder.build()

		# Build the import section
		import_section_build = instruction_encoder.encode(import_section_instructions, none as String)
		import_section = import_section_build.section

		# Connect the indirect jump instruction relocations to the import address section
		binary_utility.update_relocations(import_section_build.relocations, import_address_section.symbols)

		# Export the relocation needed by the import section. The relocations point to import address tables.
		relocations.add_range(import_section_build.relocations)
		relocations.add_range(import_address_section.relocations)

		# Now, currently the relocations which use the imported functions, have symbols which basically point to nothing. We need to connect them to the indirect jumps.
		loop relocation_symbol in relocation_symbols {
			indirect_jump_symbol = import_section.symbols[relocation_symbol.key]

			# Copy the properties of the indirect jump symbol to the relocation symbol
			relocation_symbol.value.offset = indirect_jump_symbol.offset
			relocation_symbol.value.section = indirect_jump_symbol.section
		}

		# Connect the import address table symbols to the import address section
		loop import_address_table_start in import_address_table_starts { import_address_table_start.section = import_address_section }

		# Mesh the importer data with the string table
		string_table_data = string_table.build().data

		new_importer_section_data = Array<byte>(importer_section.data.count + string_table_data.count)
		copy(importer_section.data.data, importer_section.data.count, new_importer_section_data.data)
		copy(string_table_data.data, string_table_data.count, new_importer_section_data.data + importer_section.data.count)

		importer_section.data = new_importer_section_data

		# Export the generated sections
		fragments.add(importer_section)
		fragments.add(import_section)
		fragments.add(import_address_section)

		=> import_address_section
	}

	constant RelocationSectionAlignment = 4
	constant PageSize = 0x1000
	constant AbsoluteRelocationType = 0xA

	# Summary:
	# Creates a relocation section, which describes how to fix absolute addresses when the binary is loaded as a shared library.
	# This is needed, because shared libraries are loaded at random addresses.
	create_relocation_section_for_absolute_addresses(sections: List<BinarySection>, relocations: List<BinaryRelocation>) {
		# Find all absolute relocations and order them by their virtual addresses
		relocations = relocations
			.filter((i: BinaryRelocation) -> i.section != none and (i.type == BINARY_RELOCATION_TYPE_ABSOLUTE32 or i.type == BINARY_RELOCATION_TYPE_ABSOLUTE64))
			.order((a: BinaryRelocation, b: BinaryRelocation) -> (a.section.virtual_address + a.offset) - (b.section.virtual_address + b.offset))

		builder = DataEncoderModule()
		builder.name = String(BaseRelocationSection)
		builder.alignment = RelocationSectionAlignment

		page_descriptor_start = -1
		page = NORMAL_MIN

		loop relocation in relocations {
			relocation_virtual_address = relocation.section.virtual_address + relocation.offset
			relocation_page = relocation_virtual_address & !(PageSize - 1)

			if relocation_page != page {
				# Store the size of the current page descriptor before moving to the next one
				if page_descriptor_start >= 0 {
					builder.write_int32(page_descriptor_start + sizeof(normal), builder.position - page_descriptor_start)
				}

				# Save the position of the page descriptor so that its size can be stored later
				page_descriptor_start = builder.position

				# Create a page descriptor (base relocation block)
				builder.write_int32(relocation_page) # Page address
				builder.write_int32(0) # Size of the block

				page = relocation_page
			}

			# Create a relocation entry:
			# 4 bits: Type of relocation
			# 12 bits: Offset in the block
			builder.write_int16((AbsoluteRelocationType <| 12) | (relocation_virtual_address - page))
		}

		# Store the size of the last page descriptor
		if page_descriptor_start >= 0 {
			builder.write_int32(page_descriptor_start + sizeof(normal), builder.position - page_descriptor_start)
		}

		# Build the relocation section and align it after the last section
		relocation_section = builder.build()
		relocation_section.type = BINARY_SECTION_TYPE_RELOCATION_TABLE

		last_section = sections[sections.size - 1]
		file_position = align_sections(relocation_section, last_section.offset + last_section.load_size)

		# Add the relocation section to the list of sections
		sections.add(relocation_section)
		=> file_position
	}

	# Summary:
	# Creates an object file from the specified sections
	link(objects: List<BinaryObjectFile>, imports: List<String>, entry: String, output_name: String, executable: bool) {
		# Index all the specified object files
		loop (i = 0, i < objects.size, i++) { objects[i].index = i }

		# Make all hidden symbols unique by using their object file indices
		linker.make_local_symbols_unique(objects)

		header = PeHeader()
		header.machine = PE_MACHINE_X64
		header.timestamp = 0
		header.file_alignment = FileSectionAlignment
		header.section_alignment = VirtualSectionAlignment
		header.characteristics = PE_IMAGE_CHARACTERISTICS_LARGE_ADDRESS_AWARE | PE_IMAGE_CHARACTERISTICS_LINENUMBERS_STRIPPED | PE_IMAGE_CHARACTERISTICS_EXECUTABLE | PE_IMAGE_CHARACTERISTICS_DEBUG_STRIPPED
		header.data_directories = NumberOfDataDirectories
		header.size_of_optional_headers = PeHeader.Size - PeHeader.OptionalHeaderOffset + PeDataDirectory.Size * NumberOfDataDirectories

		if executable { header.characteristics |= PE_IMAGE_CHARACTERISTICS_RELOCATIONS_STRIPPED }
		else { header.characteristics |= PE_IMAGE_CHARACTERISTICS_DLL }

		# Resolves are unresolved symbols and returns all symbols as a list
		symbols = linker.resolve_symbols(objects)

		# Ensure sections are ordered so that sections of same type are next to each other
		fragment_sections = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections)
		fragments = fragment_sections.filter((i: BinarySection) -> i.type != BINARY_SECTION_TYPE_NONE and linker.is_loadable_section(i))

		fill_empty_sections(fragments)

		# Load all the relocations from all the sections
		relocations = objects.flatten<BinarySection>((i: BinaryObjectFile) -> i.sections).flatten<BinaryRelocation>((i: BinarySection) -> i.relocations)

		# Create the exporter section
		exporter_section = none as BinarySection

		if not executable {
			# Collect all the symbols from the symbol map
			exporter_section_symbols = List<BinarySymbol>(symbols.size, false)
			loop iterator in symbols { exporter_section_symbols.add(iterator.value) }

			exporter_section = create_exporter_section(fragments, relocations, exporter_section_symbols, output_name)
		}

		# Create the importer section
		import_address_section = create_dynamic_linkage(relocations, imports, fragments)

		# Create sections, which cover the fragmented sections
		overlays = linker.create_loadable_sections(fragments)

		# Decide section offsets and virtual addresses
		file_position = PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * NumberOfDataDirectories + PeSectionTable.Size * overlays.size
		file_position = align_sections(overlays, fragments, file_position)

		# Relocations are needed loop absolute relocations when creating a shared library, because the shared library is loaded at a random address
		if not executable { file_position = create_relocation_section_for_absolute_addresses(overlays, relocations) }

		# Store the size of the data
		header.size_of_initialized_data = 0

		loop overlay in overlays {
			if overlay.type == BINARY_SECTION_TYPE_TEXT continue
			header.size_of_initialized_data += overlay.virtual_size
		}

		# Determine the image base
		header.image_base = SharedLibraryBaseAddress
		if executable { header.image_base = linker.DefaultBaseAddress }

		# Section tables:
		# Create initial versions of section tables and finish them later when section offsets are known
		symbol_name_table = BinaryStringTable(true)
		section_tables = List<PeSectionTable>()

		loop overlay in overlays {
			overlay_name = overlay.name

			# If the section name is too long, move it into the string table and point to that name by using the pattern '/<Section name offset in the string table>'
			if overlay.name.length > 8 {
				overlay_name = String(`/`) + to_string(symbol_name_table.add(overlay.name))
			}

			section_table = PeSectionTable()
			section_table.name = encode_integer_name(overlay_name)
			section_table.virtual_address = overlay.virtual_address
			section_table.virtual_size = overlay.virtual_size
			section_table.size_of_raw_data = overlay.virtual_size
			section_table.pointer_to_raw_data = 0 # Fill in later when the section offsets are decided
			section_table.pointer_to_relocations = 0 # Fill in later when the section offsets are decided
			section_table.pointer_to_linenumbers = 0 # Not used
			section_table.number_of_relocations = 0 # Fill in later
			section_table.number_of_linenumbers = 0 # Not used
			section_table.characteristics = get_section_characteristics(overlay)

			section_tables.add(section_table)
		}

		# Store the number of sections to the header
		# Exclude the sections created below and go with the existing ones, since the ones created below are not needed in the section tables
		header.number_of_sections = overlays.size

		# Add symbols and relocations of each section needing that
		symbol_table_section = create_symbol_related_sections(symbol_name_table, overlays, fragments, symbols, file_position)
		file_position = symbol_table_section.offset + symbol_table_section.virtual_size

		# Section table pointers:
		# Now, finish the section tables
		loop (i = 0, i < section_tables.size, i++) {
			section_table = section_tables[i]
			section = overlays[i]

			section_table.pointer_to_raw_data = section.offset
			section_table.virtual_address = section.virtual_address

			# Skip relocations if there are none
			if section.relocations.size == 0 continue

			# Why does PE-format restrict the number of relocations to 2^16 in a single section...
			if section.relocations.size > U16_MAX abort('Too many relocations')

			# Find the relocation table loop this section
			relocation_table_name = String(RelocationSectionPrefix) + section.name.slice(1)
			relocation_table = overlays.find_or(i -> i.name == relocation_table_name, none as BinarySection)
			if relocation_table == none abort('Missing relocation section')

			section_table.pointer_to_relocations = relocation_table.offset
			section_table.number_of_relocations = section.relocations.size
		}

		# Now that sections have their virtual addresses relocations can be computed
		linker.compute_relocations(relocations, header.image_base)

		# Compute the entry point location
		entry_point_symbol = symbols[entry]
		header.address_of_entry_point = entry_point_symbol.section.virtual_address + entry_point_symbol.offset

		# Store the size of the code
		text_section = overlays.find_or(i -> i.type == BINARY_SECTION_TYPE_TEXT, none as BinarySection)
		if text_section != none { header.size_of_code = text_section.virtual_size }

		# Register the symbol table to the PE-header
		if symbol_table_section != none {
			header.number_of_symbols = symbols.size
			header.pointer_to_symbol_table = symbol_table_section.offset
		}

		# Compute the image size, which is the memory needed to load all the sections in place
		last_loaded_section = overlays.find_max(i -> i.virtual_address)
		if last_loaded_section == none abort('At least one section should be loaded')

		image_size = last_loaded_section.virtual_address + last_loaded_section.virtual_size

		# The actual stored image size must be multiple of section alignment
		header.size_of_image = (image_size + header.section_alignment - 1) & !(header.section_alignment - 1)

		# Compute the total size of all headers
		headers_size = PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * NumberOfDataDirectories + PeSectionTable.Size * overlays.size

		# The actual stored size of headers must be multiple of file alignments
		header.size_of_headers = (headers_size + header.file_alignment - 1) & !(header.file_alignment - 1)

		# Create the binary file
		binary = Array<byte>(file_position)

		# Write the legacy header
		binary_utility.write<PeLegacyHeader>(binary, 0, PeLegacyHeader())

		# Write the pointer to the PE-header
		binary_utility.write_int32(binary, PeLegacyHeader.PeHeaderPointerOffset, PeLegacyHeader.Size)

		# Write the file header
		binary_utility.write<PeHeader>(binary, PeLegacyHeader.Size, header)

		# Write the data directories
		importer_section = overlays.find_or(i -> i.name == ImporterSection, none as BinarySection)
		base_relocation_section = overlays.find_or(i -> i.name == BaseRelocationSection, none as BinarySection)

		if exporter_section != none binary_utility.write<PeDataDirectory>(binary, PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * ExporterSectionIndex, PeDataDirectory(exporter_section.virtual_address, exporter_section.virtual_size))
		if importer_section != none binary_utility.write<PeDataDirectory>(binary, PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * ImporterSectionIndex, PeDataDirectory(importer_section.virtual_address, importer_section.virtual_size))
		if base_relocation_section != none binary_utility.write<PeDataDirectory>(binary, PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * BaseRelocationSectionIndex, PeDataDirectory(base_relocation_section.virtual_address, base_relocation_section.virtual_size))
		if import_address_section != none binary_utility.write<PeDataDirectory>(binary, PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * ImportAddressSectionIndex, PeDataDirectory(import_address_section.virtual_address, import_address_section.virtual_size))

		# Write the section tables
		binary_utility.write_all<PeSectionTable>(binary, PeLegacyHeader.Size + PeHeader.Size + PeDataDirectory.Size * NumberOfDataDirectories, section_tables)

		# Write the section overlays
		loop section in overlays {
			# Loadable sections are handled with the fragments
			if linker.is_loadable_section(section) continue

			copy(section.data.data, section.data.count, binary.data + section.offset)
		}

		# Write the loadable sections
		loop fragment in fragments {
			copy(fragment.data.data, fragment.data.count, binary.data + fragment.offset)
		}

		=> binary
	}

	# Summary:
	# Determines shared section flags from the specified section characteristics
	get_shared_section_flags(characteristics: large) {
		flags = 0

		if has_flag(characteristics, PE_SECTION_CHARACTERISTICS_WRITE) { flags |= BINARY_SECTION_FLAGS_WRITE }
		if has_flag(characteristics, PE_SECTION_CHARACTERISTICS_EXECUTE) { flags |= BINARY_SECTION_FLAGS_EXECUTE }

		if has_flag(characteristics, PE_SECTION_CHARACTERISTICS_CODE) { flags |= BINARY_SECTION_FLAGS_ALLOCATE }
		else has_flag(characteristics, PE_SECTION_CHARACTERISTICS_INITIALIZED_DATA) { flags |= BINARY_SECTION_FLAGS_ALLOCATE }

		=> flags
	}

	# Summary:
	# Extracts the section alignment from the specified section characteristics
	get_section_alignment(characteristics: large) {
		# Alignment flags are stored as follows:
		# 1-byte alignment:    0x00100000
		# 2-byte alignment:    0x00200000
		#                          .
		#                          .
		#                          .
		# 8192-byte alignment: 0x00E00000
		exponent = (characteristics |> 20) & 15 # Take out the first four bits: 15 = 0b1111
		if exponent == 0 => 1

		=> 2 <| (exponent - 1) # 2^(exponent - 1)
	}

	# Summary:
	# Converts the PE-format relocation type to shared relocation type
	get_shared_relocation_type(type: large) {
		=> when(type) {
			PE_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE_32 => BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE,
			PE_RELOCATION_TYPE_ABSOLUTE64 => BINARY_RELOCATION_TYPE_ABSOLUTE64,
			PE_RELOCATION_TYPE_ABSOLUTE32 => BINARY_RELOCATION_TYPE_ABSOLUTE32,
			else => 0
		}
	}

	# Summary:
	# Imports all symbols and relocations from the represented object file
	import_symbols_and_relocations(header: PeObjectFileHeader, sections: List<BinarySection>, section_tables: List<PeSectionTable>, bytes: link) {
		file_position = bytes + header.pointer_to_symbol_table
		symbol_name_table_start = file_position + header.number_of_symbols * PeSymbolEntry.Size

		# NOTE: This is useful loop the relocation table below
		symbols = List<BinarySymbol>()

		loop (i = 0, i < header.number_of_symbols, i++) {
			# Load the next symbol entry
			symbol_entry = binary_utility.read_object<PeSymbolEntry>(file_position, 0)
			symbol_name = none as String
			
			# If the section number is a positive integer, the symbol is defined locally inside some section
			section = none as BinarySection
			if symbol_entry.section_number >= 0 { section = sections[symbol_entry.section_number] }

			# Extract the symbol name:
			# If the first four bytes are zero, the symbol name is located in the string table
			# Otherwise, the symbol name is stored inside the integer
			if (symbol_entry.name & 0xFFFFFFFF) == 0 {
				symbol_name_offset = symbol_entry.name |> 32
				symbol_name = String(symbol_name_table_start + symbol_name_offset)
			}
			else {
				# Extract the symbol name from the integer
				symbol_name = decode_integer_name(symbol_entry.name)
			}

			symbol = BinarySymbol(symbol_name, symbol_entry.value, symbol_entry.section_number == 0)
			symbol.exported = symbol_entry.section_number != 0 and symbol_entry.storage_class == PE_STORAGE_CLASS_EXTERNAL
			symbol.section = section

			# Define the symbol inside its section, if it has a section
			if section != none section.symbols.try_add(symbol.name, symbol)

			symbols.add(symbol)

			file_position += PeSymbolEntry.Size
		}

		# Import relocations
		loop (i = 0, i < sections.size, i++) {
			section = sections[i]
			section_table = section_tables[i]

			# Skip sections, which do not have relocations
			if section_table.pointer_to_relocations == 0 continue

			# Determine the location of the first relocation
			file_position = bytes + section_table.pointer_to_relocations

			loop (j = 0, j < section_table.number_of_relocations, j++) {
				# Load the relocation entry from raw bytes
				relocation_entry = binary_utility.read_object<PeRelocationEntry>(file_position, 0)

				symbol = symbols[relocation_entry.symbol_table_index]
				relocation_type = get_shared_relocation_type(relocation_entry.type)
				relocation = BinaryRelocation(symbol, relocation_entry.virtual_address, -(sizeof(normal)), relocation_type)
				relocation.section = section

				# Set the default addend if the relocation type is program counter relative
				if relocation_type == BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE { relocation.addend = -(sizeof(normal)) }

				section.relocations.add(relocation)
				file_position += PeRelocationEntry.Size
			}
		}

		# Now, fix section names that use the pattern '/<Section name offset in the string table>'
		loop section in sections {
			if not section.name.starts_with(`/`) continue

			# Extract the section offset in the string table
			section_name_offset = to_number(section.name.slice(1, section.name.length))

			# Load the section name from the string table
			section.name = String(symbol_name_table_start + section_name_offset)
		}

		=> symbols
	}

	# Summary:
	# Load the specified object file and constructs a object structure that represents it
	import_object_file(name: String, bytes: Array<byte>) {
		# Load the file header
		header = binary_utility.read_object<PeObjectFileHeader>(bytes, 0)

		# Load all the section tables
		file_position = bytes.data + PeObjectFileHeader.Size
		sections = List<BinarySection>()

		# Add none-section to the list
		none_section = BinarySection(String(NoneSection), BINARY_SECTION_TYPE_NONE, Array<byte>())
		sections.add(none_section)

		# Store the section tables loop usage after the loop
		section_tables = List<PeSectionTable>()
		
		none_section_table = PeSectionTable()
		section_tables.add(none_section_table)

		loop (i = 0, i < header.number_of_sections, i++) {
			# Load the section table in order to load the actual section
			section_table = binary_utility.read_object<PeSectionTable>(file_position, 0)

			# Create a pointer, which points to the start of the section data in the file
			section_data_start = bytes.data + section_table.pointer_to_raw_data

			# Now load the section data into a buffer
			section_data = Array<byte>(section_table.size_of_raw_data)
			copy(section_data_start, section_data.count, section_data.data)

			# Extract the section name from the section table
			section_name = decode_integer_name(section_table.name)

			# Determine the section type
			section_type = when(section_name) {
				TextSection => BINARY_SECTION_TYPE_TEXT,
				DataSection => BINARY_SECTION_TYPE_DATA,
				SymbolTableSection => BINARY_SECTION_TYPE_SYMBOL_TABLE,
				StringTableSection => BINARY_SECTION_TYPE_STRING_TABLE,
				else => BINARY_SECTION_TYPE_NONE
			}

			# Detect relocation table sections
			if section_name.starts_with(RelocationSectionPrefix) { section_type = BINARY_SECTION_TYPE_RELOCATION_TABLE }

			section = BinarySection(section_name, section_type, section_data)
			section.flags = get_shared_section_flags(section_table.characteristics)
			section.alignment = get_section_alignment(section_table.characteristics)
			section.offset = section_table.pointer_to_raw_data
			section.virtual_size = section_table.size_of_raw_data

			section_tables.add(section_table)
			sections.add(section)

			# Move to the next section table
			file_position += PeSectionTable.Size
		}

		symbols = import_symbols_and_relocations(header, sections, section_tables, bytes.data)

		# Collect all exported symbols
		exports = Set<String>()

		loop symbol in symbols {
			if not symbol.exported continue
			exports.add(symbol.name)
		}

		=> BinaryObjectFile(name, sections, exports)
	}

	# Summary:
	# Load the specified object file and constructs a object structure that represents it
	import_object_file(path: String) {
		if not (io.read_file(path) has bytes) => Optional<BinaryObjectFile>()
		=> Optional<BinaryObjectFile>(import_object_file(path, bytes))
	}
}

PE_MACHINE_X64 = 0x8664
PE_MACHINE_ARM64 = 0xAA64

PE_STORAGE_CLASS_EXTERNAL = 2
PE_STORAGE_CLASS_LABEL = 6

plain PeSymbolEntry {
	constant Size = 18

	name: u64
	value: u32
	section_number: small
	type: u16 = 0
	storage_class: byte = 0
	number_of_auxiliary_symbols: byte = 0
}

PE_RELOCATION_TYPE_ABSOLUTE64 = 0x1
PE_RELOCATION_TYPE_ABSOLUTE32 = 0x2
PE_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE_32 = 0x4

plain PeRelocationEntry {
	constant Size = 10

	virtual_address: u32
	symbol_table_index: u32
	type: u16
}

PE_SECTION_CHARACTERISTICS_CODE = 0x20
PE_SECTION_CHARACTERISTICS_INITIALIZED_DATA = 0x40
PE_SECTION_CHARACTERISTICS_ALIGN_1 = 0x00100000
PE_SECTION_CHARACTERISTICS_EXECUTE = 0x20000000
PE_SECTION_CHARACTERISTICS_READ = 0x40000000
PE_SECTION_CHARACTERISTICS_WRITE = 0x80000000

PE_IMAGE_CHARACTERISTICS_RELOCATIONS_STRIPPED = 0x0001
PE_IMAGE_CHARACTERISTICS_EXECUTABLE = 0x0002
PE_IMAGE_CHARACTERISTICS_LINENUMBERS_STRIPPED = 0x0004
PE_IMAGE_CHARACTERISTICS_LARGE_ADDRESS_AWARE = 0x0020
PE_IMAGE_CHARACTERISTICS_DEBUG_STRIPPED = 0x0200
PE_IMAGE_CHARACTERISTICS_DLL = 0x2000

plain PeLegacyHeader {
	constant Size = 64
	constant PeHeaderPointerOffset = 60

	signature: normal = 0x5A4D
}

plain PeImportDirectoryTable {
	constant Size = 20
	constant NameOffset = 12
	constant ImportAddressTableOffset = 16

	import_lookup_table: u32 # List of all the importers
	timestamp: u32 = 0
	forwarder_chain: u32 = 0
	name: u32
	import_address_table: u32 # List of all the function pointer to the imported functions
}

plain PeHeader {
	constant Size = 136
	constant OptionalHeaderOffset = 0x18

	signature: normal = 0x00004550 # 'PE\0\0'
	machine: u16
	number_of_sections: small
	timestamp: u32
	pointer_to_symbol_table: u32 = 0
	number_of_symbols: normal = 0
	size_of_optional_headers: small
	characteristics: small

	magic: small = 0x20B
	major_linker_version: byte = 2
	minor_linker_version: byte = 30
	size_of_code: normal
	size_of_initialized_data: normal
	size_of_uninitialized_data: normal
	address_of_entry_point: normal
	base_of_code: normal

	image_base: large
	section_alignment: normal
	file_alignment: normal
	major_operating_system_version: small = 4
	minor_operating_system_version: small = 0
	major_image_system_version: small = 0
	minor_image_system_version: small = 0
	major_subsystem_version: small = 5
	minor_subsystem_version: small = 2
	private windows_api_version: normal = 0
	size_of_image: normal
	size_of_headers: normal
	checksum: normal = 0
	subsystem: small = 3
	dll_characteristics: small = 0
	size_of_stack_reserve: large = 0x200000
	size_of_stack_commit: large = 0x1000
	size_of_heap_reserve: large = 0x100000
	size_of_heap_commit: large = 0x1000
	loader_version: normal = 0
	data_directories: normal
}

plain PeObjectFileHeader {
	constant Size = 0x14

	machine: u16
	number_of_sections: small
	timestamp: u32
	pointer_to_symbol_table: u32 = 0
	number_of_symbols: normal = 0
	size_of_optional_headers: small
	characteristics: small
}

plain PeDataDirectory {
	constant Size = 8

	relative_virtual_address: normal = 0
	physical_size: normal = 0

	init() {}

	init(relative_virtual_address: normal, physical_size: normal) {
		this.relative_virtual_address = relative_virtual_address
		this.physical_size = physical_size
	}
}

plain PeSectionTable {
	constant Size = 40

	name: u64
	virtual_size: normal
	virtual_address: u32
	size_of_raw_data: normal
	pointer_to_raw_data: u32
	pointer_to_relocations: u32
	pointer_to_linenumbers: normal
	number_of_relocations: u16
	number_of_linenumbers: small
	characteristics: u32
}

plain PeMetadata {
	bytes: Array<byte>
	header: PeHeader
	data_directories: List<PeDataDirectory>
	sections: List<PeSectionTable>

	init(bytes: Array<byte>, header: PeHeader, data_directories: List<PeDataDirectory>, sections: List<PeSectionTable>) {
		this.bytes = bytes
		this.header = header
		this.data_directories = data_directories
		this.sections = sections
	}
}

plain PeExportDirectoryTable {
	constant Size = 40
	constant NameAddressOffset = 16
	constant ExportAddressTableAddressOffset = 28
	constant NamePointerTableAddressOffset = 32
	constant OrdinalTableAddressOffset = 36

	private export_flags: normal = 0
	timestamp: normal
	major_version: small
	minor_version: small
	name_address: normal
	ordinal_base: normal
	number_of_addresses: normal
	number_of_name_pointers: normal
	export_address_table_relative_virtual_address: normal
	name_pointer_relative_virtual_address: normal
	ordinal_table_relative_virtual_address: normal
}