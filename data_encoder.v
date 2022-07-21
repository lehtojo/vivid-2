DataEncoderModule {
	constant DATA_SECTION_NAME = '.data'
	constant DEFAULT_OUTPUT_SIZE = 100
	
	name: String = String(DATA_SECTION_NAME)
	output: link = allocate(DEFAULT_OUTPUT_SIZE)
	output_size: large = DEFAULT_OUTPUT_SIZE
	position: large = 0
	symbols: Map<String, BinarySymbol> = Map<String, BinarySymbol>()
	relocations: List<BinaryRelocation> = List<BinaryRelocation>()
	offsets: List<BinaryOffset> = List<BinaryOffset>()
	alignment: large = 8

	# Summary:
	# Ensures the internal buffer has the specified amount of bytes available
	reserve(bytes: large) {
		if output_size - position >= bytes return
		expanded_output_size = (output_size + bytes) * 2
		output = resize(output, output_size, expanded_output_size)
		output_size = expanded_output_size
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write(value: large) {
		reserve(1)
		binary_utility.write(output, position, value)
		position++
	}

	# Summary:
	# Writes the specified value to the specified position
	write(position: large, value: large) {
		output[position] = value
	}

	# Summary:
	# Writes the specified character to the current position and advances to the next position
	write(value: char) {
		output[position++] = value
	}

	# Summary:
	# Writes the specified character to the specified position
	write(position: large, value: char) {
		output[position] = value
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int16(value: large) {
		reserve(2)
		binary_utility.write_int16(output, position, value)
		position += sizeof(small)
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int32(value: large) {
		reserve(4)
		binary_utility.write_int32(output, position, value)
		position += sizeof(normal)
	}

	# Summary:
	# Writes the specified value to the specified position
	write_int32(position: large, value: large) {
		binary_utility.write_int32(output, position, value)
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int64(value: large) {
		reserve(8)
		binary_utility.write_int64(output, position, value)
		position += sizeof(large)
	}

	# Summary:
	# Writes the specified value to the current position and advances to the next position
	write_int64(position: large, value: large) {
		binary_utility.write_int64(output, position, value)
	}

	# Summary:
	# Expresses the specified value as a signed LEB128.
	to_uleb128(value: large) {
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

	# Summary:
	# Expresses the specified value as an unsigned LEB128.
	to_sleb128(value: large) {
		bytes = List<byte>()

		more = true
		negative = value < 0

		loop (more)  {
			x = value & 0x7F
			value = value |> 7

			# The following is only necessary if the implementation of |>= uses a logical shift rather than an arithmetic shift for a signed left operand
			# if negative {
			# 	value |= (~0 <| (sizeof(int) * 8 - 7)) # Sign extend
			# }

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

	# Summary:
	# Writes the specified integer as a SLEB128
	write_sleb128(value: large) {
		write(to_sleb128(value))
	}

	# Summary:
	# Writes the specified integer as a ULEB128
	write_uleb128(value: large) {
		write(to_uleb128(value))
	}

	# Summary:
	# Writes the specified bytes into this module
	write(bytes: Array<byte>) {
		reserve(bytes.size)
		copy(bytes.data, bytes.size, output + position)
		position += bytes.size
	}

	# Summary:
	# Writes the specified bytes into this module
	write(bytes: link, size: large) {
		reserve(size)
		copy(bytes, size, output + position)
		position += size
	}

	# Summary:
	# Writes the specified bytes into this module
	write(bytes: List<byte>) {
		reserve(bytes.size)
		copy(bytes.data, bytes.size, output + position)
		position += bytes.size
	}

	# Summary:
	# Writes the specified amount of zeroes into this module
	zero(amount: large) {
		reserve(amount)
		position += amount
	}

	# Summary:
	# Writes the specified into: String this module
	string(text: String) {
		return string(text, true)
	}

	# Summary:
	# Writes the specified into: String this module
	string(text: String, terminate: bool) {
		position: large = 0

		loop (position < text.length) {
			# Collect characters as long as a string command is not encountered
			end = text.index_of(`\\`, position)
			if end < 0 { end = text.length }

			# Extract all the characters before the next string command
			slice = text.slice(position, end)
			position += slice.length

			# Write the slice
			if slice.length > 0 write(Array<byte>(slice.data, slice.length))

			# Stop if the end has been reached
			if position >= text.length stop

			position++ # Skip the character '\'

			command = text[position++] as char
			length = 0
			error = 'Unknown error'

			if command == `x` {
				length = 2
				error = 'Can not understand hexadecimal value in a string'
			}
			else command == `u` {
				length = 4
				error = 'Can not understand Unicode character in a string'
			}
			else command == `U` {
				length = 8
				error = 'Can not understand Unicode character in a string'
			}
			else command == `\\` {
				write(`\\`)
				continue
			}
			else {
				abort("Can not understand command: " + command)
			}

			hexadecimal = text.slice(position, position + length)
			if not (hexadecimal_to_integer(hexadecimal) has value) abort(error)

			bytes = length / 2

			when(bytes) {
				1 => write(value)
				2 => write_int16(value)
				4 => write_int32(value)
				8 => write_int64(value)
				else => abort("Can not understand hexadecimal value: " + hexadecimal)
			}

			position += length
		}

		if terminate write(0)
	}

	# Summary:
	# Returns a local symbol with the specified name if such symbol exists, otherwise an external symbol with the specified name is created.
	get_local_or_create_external_symbol(name: String) {
		if symbols.contains_key(name) return symbols[name]

		# Create an external version of the specified symbol
		symbol = BinarySymbol(name, 0, true)
		symbols.add(name, symbol)
		return symbol
	}

	# Summary:
	# Creates a local symbol with the specified name at the specified offset.
	# This function converts an existing external version of the symbol to a local symbol if such symbol exists.
	create_local_symbol(name: String, offset: large) {
		symbol = none as BinarySymbol

		if symbols.contains_key(name) {
			symbol = symbols[name]

			# Ensure the properties are correct
			symbol.external = false
			symbol.offset = offset
			symbol.exported = false
		}
		else {
			# Create a local symbol with the specified properties
			symbol = BinarySymbol(name, offset, false)
			symbols.add(name, symbol)
			symbol.exported = false
		}

		return symbol
	}

	# Summary:
	# Creates a local symbol with the specified name at the specified offset.
	# This function converts an existing external version of the symbol to a local symbol if such symbol exists.
	create_local_symbol(name: String, offset: large, exported: bool) {
		symbol = none as BinarySymbol

		if symbols.contains_key(name) {
			symbol = symbols[name]

			# Ensure the properties are correct
			symbol.external = false
			symbol.offset = offset
			symbol.exported = exported
		}
		else {
			# Create a local symbol with the specified properties
			symbol = BinarySymbol(name, offset, false)
			symbols.add(name, symbol)
			symbol.exported = exported
		}

		return symbol
	}

	build() {
		# Shrink the output buffer to only fit the current size
		output = resize(output, output_size, position)
		output_size = position

		# Add a hidden symbol that has the name of this section without dot. It represents the start of this section.
		symbol_name = name

		# Remove the dot from the name, if it exists
		if symbol_name.length > 0 and symbol_name[0] == `.` {
			symbol_name = symbol_name.slice(1)
		}

		symbols.add(symbol_name, BinarySymbol(symbol_name, 0, false))

		section = BinarySection(name, BINARY_SECTION_TYPE_DATA, output, output_size)
		section.alignment = alignment
		section.relocations = relocations
		section.symbols = symbols
		section.offsets = offsets

		# If this section represents the primary data section, add the default flags
		if name == DATA_SECTION_NAME { section.flags = BINARY_SECTION_FLAGS_WRITE | BINARY_SECTION_FLAGS_ALLOCATE }

		loop symbol in symbols { symbol.value.section = section }
		loop relocation in relocations { relocation.section = section }

		return section
	}

	reset() {
		output = resize(output, position, DEFAULT_OUTPUT_SIZE)
		output_size = DEFAULT_OUTPUT_SIZE
		position = 0
		symbols.clear()
		relocations.clear()
	}

	deinit() {
		deallocate(output)
	}
}

namespace data_encoder {
	constant SYSTEM_ADDRESS_SIZE = 8

	# Summary:
	# Ensures the specified module is aligned as requested
	align(module: DataEncoderModule, alignment: large) {
		padding = alignment - module.position % alignment
		if padding == alignment return

		# By choosing the largest alignment, it is guaranteed that all the alignments are correct even after the linker relocates all sections
		module.alignment = max(module.alignment, alignment)
		module.zero(padding)
	}

	# Summary:
	# Adds the specified table label into the specified module
	add_table_label(module: DataEncoderModule, label: TableLabel) {
		if label.declare {
			# Define the table label as a symbol
			module.create_local_symbol(label.name, module.position)
			return
		}
		
		# Determine the relocation type
		bytes = label.size
		position = module.position
		type = BINARY_RELOCATION_TYPE_ABSOLUTE64

		if bytes == 4 {
			if label.is_section_relative {
				type = BINARY_RELOCATION_TYPE_SECTION_RELATIVE_32
			}
			else {
				type = BINARY_RELOCATION_TYPE_ABSOLUTE32
			}
		}
		else bytes == 8 {
			if label.is_section_relative {
				type = BINARY_RELOCATION_TYPE_SECTION_RELATIVE_64
			}
			else {
				type = BINARY_RELOCATION_TYPE_ABSOLUTE64
			}
		}
		else {
			abort('Table label must be either 4-bytes or 8-bytes')
		}

		# Allocate the table label
		module.zero(bytes)

		module.relocations.add(BinaryRelocation(module.get_local_or_create_external_symbol(label.name), position, 0, type, bytes))
	}

	# Summary:
	# Adds the specified table into the specified module
	add_table(builder: AssemblyBuilder, module: DataEncoderModule, table: Table, marker: large) {
		if (table.marker & marker) != 0 return
		table.marker |= marker

		if not table.is_section {
			builder.export_symbol(table.name) # Export the table

			# Align the table
			if not settings.is_x64 align(module, 16)

			# Define the table as a symbol
			module.create_local_symbol(table.name, module.position)
		}

		# Align tables if the platform is ARM
		if not settings.is_x64 align(module, 8)

		subtables = List<Table>()

		loop item in table.items {
			when (item.type) {
				TABLE_ITEM_STRING => {
					# Add the string to the module
					module.string(item.(StringTableItem).value)
				},
				TABLE_ITEM_INTEGER => {
					# Add the integer to the module
					integer_item = item as IntegerTableItem

					when(integer_item.size) {
						1 => module.write(integer_item.value),
						2 => module.write_int16(integer_item.value),
						4 => module.write_int32(integer_item.value),
						8 => module.write_int64(integer_item.value),
						else => abort('Invalid integer size')
					}
				},
				TABLE_ITEM_TABLE_REFERENCE => {
					# Add the table reference to the module
					table_item = item.(TableReferenceTableItem).value
					table_symbol = module.get_local_or_create_external_symbol(table_item.name)

					module.relocations.add(BinaryRelocation(table_symbol, module.position, 0, BINARY_RELOCATION_TYPE_ABSOLUTE64, SYSTEM_ADDRESS_SIZE))
					module.write_int64(0)

					# Add the table to the list of subtables
					subtables.add(table_item)
				},
				TABLE_ITEM_LABEL => {
					label_item = item.(LabelTableItem).value.name
					label_symbol = module.get_local_or_create_external_symbol(label_item)
					module.relocations.add(BinaryRelocation(label_symbol, module.position, 0, BINARY_RELOCATION_TYPE_ABSOLUTE64, SYSTEM_ADDRESS_SIZE))
					module.write_int64(0)
				},
				TABLE_ITEM_LABEL_OFFSET => {
					# NOTE: All binary offsets are 4-bytes for now
					module.offsets.add(BinaryOffset(module.position, item.(LabelOffsetTableItem).value, 4))
					module.write_int32(0)
				},
				TABLE_ITEM_TABLE_LABEL => {
					add_table_label(module, item.(TableLabelTableItem).value)
				},
				else => abort('Invalid table item type')
			}
		}

		# Add the subtables
		loop subtable in subtables {
			add_table(builder, module, subtable, marker)
		}
	}

	# Summary:
	# Defines the specified variable
	add_static_variable(module: DataEncoderModule, variable: Variable) {
		name = variable.get_static_name()
		size = variable.type.allocation_size

		# Define the variable as a symbol
		module.create_local_symbol(name, module.position, true)

		# Align tables if the platform is ARM
		if not settings.is_x64 align(module, 8)

		module.zero(size)
	}
}