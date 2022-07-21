namespace linker {
	constant DEFAULT_BASE_ADDRESS = 0x400000
	constant SEGMENT_ALIGNMENT = 0x1000

	# Summary:
	# Goes through all the symbols in the specified object files and makes their hidden symbols unique by adding their object file indices to their names.
	# This way, if multiple object files have hidden symbols with same names, their names are made unique using the object file indices.
	make_local_symbols_unique(objects: List<BinaryObjectFile>) {
		loop object in objects {
			loop section in object.sections {
				loop iterator in section.symbols {
					symbol = iterator.value

					if symbol.exported or symbol.external continue
					symbol.name = to_string(object.index) + '.' + symbol.name
				}
			}
			
		}
	}

	# Summary:
	# Returns whether the specified section should be loaded into memory when the application starts
	is_loadable_section(section: BinarySection) {
		=> section.type == BINARY_SECTION_TYPE_TEXT or section.type == BINARY_SECTION_TYPE_DATA
	}

	print_conflicting_symbols_and_abort(objects: List<BinaryObjectFile>, symbol: BinarySymbol) {
		# Find the objects that have the same symbol
		conflicting_objects = objects.filter(i -> i.exports.contains(symbol.name))
		abort("Symbol " + symbol.name + ' is exported by multiple object files: ' + String.join(", ", conflicting_objects.map<String>((i: BinaryObjectFile) -> i.name)))
	}

	# Summary:
	# Resolves all external symbols from the specified binary objects by connecting them to the real symbols.
	# This function throws an exception if no definition for an external symbol is found.
	resolve_symbols(objects: List<BinaryObjectFile>) {
		definitions = Map<String, BinarySymbol>()

		loop object in objects {
			loop section in object.sections {
				loop iterator in section.symbols {
					symbol = iterator.value

					if symbol.external or definitions.try_add(symbol.name, symbol) continue
					print_conflicting_symbols_and_abort(objects, symbol)
				}
			}
		}

		loop object in objects {
			loop section in object.sections {
				loop relocation in section.relocations {
					symbol = relocation.symbol

					# If the relocation is not external, the symbol is already resolved
					if not symbol.external continue

					# Try to find the actual symbol
					#warning Add dynamic symbols for Linux
					if not definitions.contains_key(symbol.name) continue

					relocation.symbol = definitions[symbol.name]
				}
			}
		}

		=> definitions
	}

	# Summary:
	# Combines the loadable sections of the specified object files
	create_loadable_sections(fragments: List<BinarySection>) {
		# Merge all sections that have the same type
		result = List<BinarySection>()

		# Group all fragments based on their section names
		#warning Group function should be moved out of the assembler namespace
		section_fragments = assembler.group_by<BinarySection, String>(fragments, (i: BinarySection) -> i.name)
		allocated_fragments = 0

		# Compute the amount of allocated section types
		loop iterator in section_fragments {
			inner_fragments = iterator.value
			inner_fragment = inner_fragments[0]

			if inner_fragment.type == BINARY_SECTION_TYPE_NONE or has_flag(inner_fragment.flags, BINARY_SECTION_FLAGS_ALLOCATE) { allocated_fragments++ }
		}

		file_position = SEGMENT_ALIGNMENT
		i = 0

		loop iterator in section_fragments {
			inner_fragments = iterator.value
			is_allocated_section = i + 1 <= allocated_fragments

			flags = inner_fragments[0].flags
			type = inner_fragments[0].type
			name = inner_fragments[0].name

			# Compute the margin needed to align the overlay section, this is different from the inner alignments
			alignment = SEGMENT_ALIGNMENT
			if not is_allocated_section { alignment = inner_fragments[0].alignment }

			overlay_margin = alignment - file_position % alignment

			# Apply the margin if it is needed for alignment
			if overlay_margin != alignment { file_position += overlay_margin }
			else { overlay_margin = 0 }

			# Save the current file position so that the size of the overlay section can be computed below
			start_file_position = file_position

			# Set the alignment to the alignment of the first inner fragment, so that it is the alignment for the whole section if there are no other inner fragments
			alignment = inner_fragments[0].alignment

			# Move over the first inner fragment
			file_position += inner_fragments[0].data.size

			# Skip the first fragment, since it is already part of the section
			loop (j = 1, j < inner_fragments.size, j++) {
				fragment = inner_fragments[j]

				# Compute the margin needed to align the fragment
				alignment = fragment.alignment

				margin = alignment - file_position % alignment

				# Apply the margin if it is needed for alignment
				if margin != alignment {
					fragment.margin = margin
					file_position += margin
				}

				file_position += fragment.data.size
			}

			overlay_size = file_position - start_file_position
			overlay_section = BinarySection(name, flags, type, alignment, Array<byte>(), overlay_margin, overlay_size)

			result.add(overlay_section)
			i++
		}

		=> result
	}

	# Summary:
	# Computes relocations inside the specified object files using section virtual addresses
	compute_relocations(relocations: List<BinaryRelocation>, base_address: large) {
		loop relocation in relocations {
			symbol = relocation.symbol
			symbol_section = symbol.section # ?? throw ApplicationException("Missing symbol definition section")
			relocation_section = relocation.section # ?? throw ApplicationException("Missing relocation section")

			if symbol_section == none or relocation_section == none continue

			if relocation.type == BINARY_RELOCATION_TYPE_PROGRAM_COUNTER_RELATIVE {
				from = relocation_section.virtual_address + relocation.offset
				to = symbol_section.virtual_address + symbol.offset
				binary_utility.write_int32(relocation_section.data, relocation.offset, to - from + relocation.addend)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_ABSOLUTE64 {
				binary_utility.write_int64(relocation_section.data, relocation.offset, (symbol_section.virtual_address + symbol.offset) + base_address)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_ABSOLUTE32 {
				binary_utility.write_int32(relocation_section.data, relocation.offset, (symbol_section.virtual_address + symbol.offset) + base_address)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_SECTION_RELATIVE_64 {
				binary_utility.write_int64(relocation_section.data, relocation.offset, (symbol_section.virtual_address + symbol.offset) - symbol_section.base_virtual_address)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_SECTION_RELATIVE_32 {
				binary_utility.write_int32(relocation_section.data, relocation.offset, (symbol_section.virtual_address + symbol.offset) - symbol_section.base_virtual_address)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_FILE_OFFSET_64 {
				binary_utility.write_int64(relocation_section.data, relocation.offset, symbol_section.offset + symbol.offset)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_BASE_RELATIVE_64 {
				binary_utility.write_int64(relocation_section.data, relocation.offset, symbol_section.virtual_address + symbol.offset)
			}
			else relocation.type == BINARY_RELOCATION_TYPE_BASE_RELATIVE_32 {
				binary_utility.write_int32(relocation_section.data, relocation.offset, symbol_section.virtual_address + symbol.offset)
			}
			else {
				abort('Unsupported relocation type')
			}
		}
	}
}