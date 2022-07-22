BINARY_SECTION_TYPE_NONE = 0
BINARY_SECTION_TYPE_TEXT = 1
BINARY_SECTION_TYPE_DATA = 2
BINARY_SECTION_TYPE_STRING_TABLE = 3
BINARY_SECTION_TYPE_SYMBOL_TABLE = 4
BINARY_SECTION_TYPE_RELOCATION_TABLE = 5
BINARY_SECTION_TYPE_DYNAMIC = 6
BINARY_SECTION_TYPE_HASH = 7

BINARY_SECTION_FLAGS_WRITE = 1
BINARY_SECTION_FLAGS_EXECUTE = 2
BINARY_SECTION_FLAGS_ALLOCATE = 4

BinarySection {
	name: String
	index: large = 0
	flags: large = 0
	type: large
	data: Array<byte>
	virtual_size: large = 0
	load_size: large = 0
	alignment: large = 1
	margin: large = 0
	offset: large = 0
	virtual_address: large = 0
	base_virtual_address: large = 0
	symbols: Map<String, BinarySymbol> = Map<String, BinarySymbol>()
	relocations: List<BinaryRelocation> = List<BinaryRelocation>()
	offsets: List<BinaryOffset> = List<BinaryOffset>()

	init(name: String, type: large, data: Array<byte>) {
		this.name = name
		this.type = type
		this.data = data
		this.virtual_size = data.size
		this.load_size = data.size
	}

	init(name: String, type: large, data: link, data_size: large) {
		this.name = name
		this.type = type
		this.data = Array<byte>(data, data_size)
		this.virtual_size = data_size
		this.load_size = data_size
	}

	init(name: String, flags: large, type: large, alignment: large, data: Array<byte>, margin: large, size: large) {
		this.name = name
		this.flags = flags
		this.type = type
		this.data = data
		this.virtual_size = size
		this.load_size = size
		this.alignment = alignment
		this.margin = margin
	}
}

BinarySymbol {
	name: String
	offset: large
	external: bool
	exported: bool = false
	index: large = 0
	section: BinarySection = none

	init(name: String, offset: large, external: bool) {
		this.name = name
		this.offset = offset
		this.external = external
	}

	init(name: String, offset: large, external: bool, section: BinarySection) {
		this.name = name
		this.offset = offset
		this.external = external
		this.section = section
	}

	equals(other: BinarySymbol) {
		return this.name == other.name
	}
}

BinaryOffset {
	position: large
	offset: LabelOffset
	bytes: large

	init(position: large, offset: LabelOffset, bytes: large) {
		this.position = position
		this.offset = offset
		this.bytes = bytes
	}
}

BINARY_RELOCATION_TYPE_ABSOLUTE64 = 1
BINARY_RELOCATION_TYPE_ABSOLUTE32 = 2
BINARY_RELOCATION_TYPE_SECTION_RELATIVE_32 = 3
BINARY_RELOCATION_TYPE_SECTION_RELATIVE_64 = 4
BINARY_RELOCATION_TYPE_PROCEDURE_LINKAGE_TABLE = 5
BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE = 6
BINARY_RELOCATION_TYPE_FILE_OFFSET_64 = 7
BINARY_RELOCATION_TYPE_BASE_RELATIVE_64 = 8
BINARY_RELOCATION_TYPE_BASE_RELATIVE_32 = 9

data_access_modifier_to_relocation_type(modifier: large) {
	return when(modifier) {
		DATA_SECTION_MODIFIER_NONE => BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE,
		DATA_SECTION_MODIFIER_GLOBAL_OFFSET_TABLE => BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE,
		DATA_SECTION_MODIFIER_PROCEDURE_LINKAGE_TABLE => BINARY_RELOCATION_TYPE_PROCEDURE_LINKAGE_TABLE,
		else => 0
	}
}

BinaryRelocation {
	symbol: BinarySymbol
	offset: large
	addend: large
	bytes: large
	type: large
	section: BinarySection

	init(symbol: BinarySymbol, offset: large, addend: large, type: large) {
		this.symbol = symbol
		this.offset = offset
		this.addend = addend
		this.bytes = sizeof(normal)
		this.type = type
	}

	init(symbol: BinarySymbol, offset: large, addend: large, type: large, bytes: large) {
		this.symbol = symbol
		this.offset = offset
		this.addend = addend
		this.bytes = bytes
		this.type = type
	}

	init(symbol: BinarySymbol, offset: large, addend: large, type: large, section: BinarySection) {
		this.symbol = symbol
		this.offset = offset
		this.addend = addend
		this.bytes = sizeof(normal)
		this.type = type
		this.section = section
	}

	init(symbol: BinarySymbol, offset: large, addend: large, type: large, section: BinarySection, bytes: large) {
		this.symbol = symbol
		this.offset = offset
		this.addend = addend
		this.bytes = bytes
		this.type = type
		this.section = section
	}
}

BinaryObjectFile {
	name: String
	index: large = 0
	sections: List<BinarySection> = List<BinarySection>()
	exports: Set<String> = Set<String>()

	init(name: String, sections: List<BinarySection>) {
		this.name = name
		this.sections = sections
	}

	init(name: String, sections: List<BinarySection>, exports: List<String>) {
		this.name = name
		this.sections = sections
		this.exports = Set<String>(exports)
	}

	init(name: String, sections: List<BinarySection>, exports: Set<String>) {
		this.name = name
		this.sections = sections
		this.exports = exports
	}
}

BinaryStringTable {
	items: List<String> = List<String>()
	position: large = 0
	size: bool = false

	init() {}

	init(size: bool) {
		this.size = size
		if size { this.position = sizeof(normal) }
	}

	add(item: String) {
		start = position
		items.add(item)
		position += item.length + 1
		return start
	}

	build() {
		payload = String.join(0 as char, items)
		result = none as Array<byte>

		if size {
			# Since the size of the String table is included, we must insert a 4-byte integer before the String table, which contains the size of the String table.
			bytes = sizeof(normal) + payload.length + 1
			result = Array<byte>(bytes)
			
			# Insert the size of the String table
			result.data.(normal*)[] = bytes

			# Copy the payload
			if payload.length > 0 {
				copy(payload.data, payload.length, result.data + sizeof(normal))
			}
		}
		else {
			result = Array<byte>(payload.length + 1)

			# Copy the payload
			if payload.length > 0 {
				copy(payload.data, payload.length, result.data)
			}
		}

		return result
	}
}

namespace binary_utility

# Summary:
# Goes through all the relocations from the specified sections and connects them to the local symbols if possible
update_relocations(relocations: List<BinaryRelocation>, symbols: Map<String, BinarySymbol>) {
	loop relocation in relocations {
		symbol = relocation.symbol

		# If the relocation is not external, the symbol is already resolved
		if not symbol.external continue

		# Try to find the actual symbol
		if not symbols.contains_key(symbol.name) continue

		relocation.symbol = symbols[symbol.name]
	}
}

# Summary:
# Goes through all the relocations from the specified sections and connects them to the local symbols if possible
update_relocations(sections: List<BinarySection>, symbols: Map<String, BinarySymbol>) {
	loop section in sections {
		update_relocations(section.relocations, symbols)
	}
}

# Summary:
# Exports the specified symbols
apply_exports(symbols: Map<String, BinarySymbol>, exports: Set<String>) {
	loop symbol in exports {
		if symbols.contains_key(symbol) {
			symbols[symbol].exported = true
			continue
		}

		abort("Exporting of symbol " + symbol + ' is requested, but it does not exist')
	}
}

# Summary:
# Returns a list of all symbols in the specified sections
get_all_symbols_from_sections(sections: List<BinarySection>) {
	symbols = Map<String, BinarySymbol>()

	loop section in sections {
		loop iterator in section.symbols {
			symbol = iterator.value

			# 1. Just continue, if the symbol can be added
			# 2. If this is executed, it means that some version of the current symbol is already added.
			# However, if the current symbol is external, it does not matter.
			if symbols.try_add(symbol.name, symbol) or symbol.external continue

			# If the version of the current symbol in the dictionary is not external, the current symbol is defined at least twice
			conflict = symbols[symbol.name]
			if not conflict.external abort("Symbol " + symbol.name + ' is created at least twice')

			# Since the version of the current symbol in the dictionary is external, it can be replaced with the actual definition (current symbol)
			symbols[symbol.name] = symbol
		}
	}

	return symbols
}

# Summary:
# Computes all offsets in the specified sections. If any of the offsets can not computed, this function throws an exception.
compute_offsets(sections: List<BinarySection>, symbols: Map<String, BinarySymbol>) {
	loop section in sections {
		loop offset in section.offsets {
			# Try to find the 'from'-symbol
			symbol = offset.offset.from.name
			if not symbols.contains_key(symbol) abort("Can not compute an offset, because symbol " + symbol + ' can not be found')
			from = symbols[symbol]

			# Try to find the 'to'-symbol
			symbol = offset.offset.to.name
			if not symbols.contains_key(symbol) abort("Can not compute an offset, because symbol " + symbol + ' can not be found')
			to = symbols[symbol]

			# Ensure both symbols are defined locally
			if from.section == none or to.section == none abort('Both symbols in offsets must be local')

			# Compute the offset between the symbols
			value = (to.section.virtual_address + to.offset) - (from.section.virtual_address + from.offset)

			when(offset.bytes) {
				8 => { write_int64(section.data, offset.position, value) }
				4 => { write_int32(section.data, offset.position, value) }
				2 => { write_int16(section.data, offset.position, value) }
				1 => { write(section.data, offset.position, value) }
				else => abort('Unsupported offset size')
			}
		}
	}
}

# Summary:
# Writes the specified source to the specified destination to the specified offset
write<T>(destination: Array<byte>, offset: large, source: T) {
	copy(source as link, capacityof(T), destination.data + offset)
	return offset + capacityof(T)
}

# Summary:
# Writes all the specified sources sequentially to the specified destination to the specified offset
write_all<T>(destination: Array<byte>, offset: large, sources: List<T>) {
	loop source in sources {
		offset = write<T>(destination, offset, source)
	}
}

# Summary:
# Reads the specified type from the specified bytes to the specified offset
read<T>(container: Array<byte>, offset: large) {
	return (container.data + offset).(T*)[]
}

# Summary:
# Reads the specified type from the specified bytes to the specified offset
read<T>(container: link, offset: large) {
	return (container + offset).(T*)[]
}

# Summary:
# Reads the specified type from the specified bytes to the specified offset
read_object<T>(container: Array<byte>, offset: large) {
	return (container.data + offset) as T
}

# Summary:
# Reads the specified type from the specified bytes to the specified offset
read_object<T>(container: link, offset: large) {
	return (container + offset) as T
}

# Summary:
# Writes the specified value to the specified offset
write(container: Array<byte>, offset: large, value: large) {
	container.data[offset] = value
}

# Summary:
# Writes the specified value to the specified offset
write(container: List<byte>, offset: large, value: large) {
	container.data[offset] = value
}

# Summary:
# Writes the specified value to the specified offset
write(container: link, offset: large, value: large) {
	container[offset] = value
}

# Summary:
# Writes the specified value to the specified offset
write_int16(container: Array<byte>, offset: large, value: large) {
	(container.data + offset).(small*)[] = value as small
}

# Summary:
# Writes the specified value to the specified offset
write_int16(container: List<byte>, offset: large, value: large) {
	(container.data + offset).(small*)[] = value as small
}

# Summary:
# Writes the specified value to the specified offset
write_int16(container: link, offset: large, value: large) {
	(container + offset).(small*)[] = value as small
}

# Summary:
# Writes the specified value to the specified offset
write_int32(container: Array<byte>, offset: large, value: large) {
	(container.data + offset).(normal*)[] = value as normal
}

# Summary:
# Writes the specified value to the specified offset
write_int32(container: List<byte>, offset: large, value: large) {
	(container.data + offset).(normal*)[] = value as normal
}

# Summary:
# Writes the specified value to the specified offset
write_int32(container: link, offset: large, value: large) {
	(container + offset).(normal*)[] = value as normal
}

# Summary:
# Writes the specified value to the specified offset
write_int64(container: Array<byte>, offset: large, value: large) {
	(container.data + offset).(large*)[] = value as large
}

# Summary:
# Writes the specified value to the specified offset
write_int64(container: List<byte>, offset: large, value: large) {
	(container.data + offset).(large*)[] = value as large
}

# Summary:
# Writes the specified value to the specified offset
write_int64(container: link, offset: large, value: large) {
	(container + offset).(large*)[] = value as large
}

# Summary:
# Swaps the endianness of the specified 32-bit integer
swap_endianness_int32(value: normal) {
	a = value & 0xFF
	b = (value |> 8) & 0xFF
	c = (value |> 16) & 0xFF
	d = (value |> 24) & 0xFF

	return (a <| 24) | (b <| 16) | (c <| 8) | d
}

# Summary:
# Copies the specified number of bytes from the source array to the destination address at the specified offset
write_bytes(source: Array<byte>, destination: link, offset: large, bytes: large) {
	require(source.size >= bytes, 'Source array is not large enough')

	if source.size == 0 return
	copy(source.data, bytes, destination + offset)
}

# Summary:
# Copies the specified number of bytes from the source array to the destination address
write_bytes(source: Array<byte>, destination: link, bytes: large) {
	write_bytes(source, destination, 0, bytes)
}

# Summary:
# Copies all the bytes from the source array to the destination address
write_bytes(source: Array<byte>, destination: link) {
	write_bytes(source, destination, 0, source.size)
}

# Summary:
# Copies the specified number of bytes from the source array to the destination array at the specified offset
write_bytes(source: Array<byte>, destination: Array<byte>, offset: large, bytes: large) {
	require(destination.size - offset >= bytes, 'Destination array can not contain the copy')
	write_bytes(source, destination.data, offset, bytes)
}


# Summary:
# Copies all the bytes from the source array to the destination array
write_bytes(source: Array<byte>, destination: Array<byte>) {
	require(destination.size >= source.size, 'Destination array can not contain the copy')
	write_bytes(source, destination.data, 0, source.size)
}