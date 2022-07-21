AssemblyParser {
	constant TEXT_SECTION = '.text'

	constant BYTE_SPECIFIER = 'byte'
	constant WORD_SPECIFIER = 'word'
	constant DWORD_SPECIFIER = 'dword'
	constant QWORD_SPECIFIER = 'qword'
	constant XWORD_SPECIFIER = 'xword'
	constant OWORD_SPECIFIER = 'oword'
	constant SECTION_RELATIVE_SPECIFIER = 'section_relative'

	constant ALIGN_DIRECTIVE = 'align'
	constant EXPORT_DIRECTIVE = 'export'
	constant SECTION_DIRECTIVE = 'section'
	constant STRING_DIRECTIVE = 'string'
	constant CHARACTERS_DIRECTIVE = 'characters'
	constant LINE_DIRECTIVE = 'loc'
	constant DEBUG_FILE_DIRECTIVE = 'debug_file'
	constant DEBUG_START_DIRECTIVE = 'debug_start'
	constant DEBUG_FRAME_OFFSET_DIRECTIVE = 'debug_frame_offset'
	constant DEBUG_END_DIRECTIVE = 'debug_end'

	unit: Unit
	registers: Map<String, RegisterHandle> = Map<String, RegisterHandle>()
	instructions: List<Instruction> = List<Instruction>()
	sections: Map<String, DataEncoderModule> = Map<String, DataEncoderModule>()
	exports: Set<String> = Set<String>()
	data: DataEncoderModule = none
	debug_file: String = none
	section: String = String(TEXT_SECTION)

	init() {
		unit = Unit()

		# Add every standard register partition as a register handle
		n = common.integer_log2(SYSTEM_BYTES) + 1

		loop (i = 0, i < n, i++) {
			size = to_format(1 <| (n - 1 - i))

			loop register in unit.registers {
				if register.is_media_register continue

				handle = RegisterHandle(register)
				handle.format = size
				registers.add(register.partitions[i], handle)
			}
		}

		# Add every media register as a register handle
		loop register in unit.media_registers {
			if not register.is_media_register continue
			handle = RegisterHandle(register)
			registers.add(register.partitions[1], handle)
		}
	}

	# Summary:
	# Handles offset directives: . $allocator $to - $from
	private execute_offset_allocator(tokens: List<Token>) {
		# Pattern: . $allocator $to - $from
		if tokens.size < 5 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_IDENTIFIER or not tokens[3].match(Operators.SUBTRACT) or tokens[4].type != TOKEN_TYPE_IDENTIFIER return false

		to = tokens[2].(IdentifierToken).value
		from = tokens[4].(IdentifierToken).value

		bytes = when(tokens[1].(IdentifierToken).value) {
			BYTE_SPECIFIER => 1, # Pattern: .byte $to - $from
			WORD_SPECIFIER => 2, # Pattern: .word $to - $from
			DWORD_SPECIFIER => 4, # Pattern: .dword $to - $from
			QWORD_SPECIFIER => 8, # Pattern: .qword $to - $from
			XWORD_SPECIFIER => abort('Please use smaller allocators') as large,
			OWORD_SPECIFIER => abort('Please use smaller allocators') as large,
			else => abort('Unknown allocator') as large
		}

		offset = LabelOffset(TableLabel(from, false), TableLabel(to, false))

		data.offsets.add(BinaryOffset(data.position, offset, bytes))
		data.zero(bytes)
		return true
	}

	# Summary:
	# Handles symbol reference allocators: . $allocator $symbol
	private execute_symbol_reference_allocator(tokens: List<Token>) {
		# Pattern: . $allocator $symbol
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_IDENTIFIER return false

		symbol = tokens[2].(IdentifierToken).value
		allocator = tokens[1].(IdentifierToken).value

		bytes = when(allocator) {
			BYTE_SPECIFIER => abort('Only 32-bit and 64-bit symbol references are currently supported') as large,
			WORD_SPECIFIER => abort('Only 32-bit and 64-bit symbol references are currently supported') as large,
			DWORD_SPECIFIER => 4, # Pattern: .dword $symbol
			QWORD_SPECIFIER => 8, # Pattern: .qword $symbol
			XWORD_SPECIFIER => abort('Only 32-bit and 64-bit symbol references are currently supported') as large,
			OWORD_SPECIFIER => abort('Only 32-bit and 64-bit symbol references are currently supported') as large,
			else => abort('Unknown allocator') as large
		}

		relocation_type = when(allocator) {
			DWORD_SPECIFIER => BINARY_RELOCATION_TYPE_ABSOLUTE32,
			QWORD_SPECIFIER => BINARY_RELOCATION_TYPE_ABSOLUTE64,
			SECTION_RELATIVE_SPECIFIER => BINARY_RELOCATION_TYPE_SECTION_RELATIVE_32,
			else => BINARY_RELOCATION_TYPE_ABSOLUTE64,
		}

		data.relocations.add(BinaryRelocation(data.get_local_or_create_external_symbol(symbol), data.position, 0, relocation_type, bytes))
		data.zero(bytes)
		return true
	}

	# Summary:
	# Executes the specified directive, if it represents a section directive.
	# Section directive switches the active section.
	private execute_section_directive(tokens: List<Token>) {
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_IDENTIFIER return false

		# Pattern: .section $section
		if not (tokens[1].(IdentifierToken).value == SECTION_DIRECTIVE) return false

		# Switch the active section
		section: String = "." + tokens[2].(IdentifierToken).value

		if section == TEXT_SECTION {
			# Save the current data section, if it is not saved already
			if data != none and not sections.contains_key(section) {
				sections[section] = data
			}

			data = none
			section = section
			return true
		}

		this.section = section

		# All non-text sections are data sections, create a data section if no previous data section has the specified name
		if sections.contains_key(section) {
			data = sections[section]
			return true
		}

		data = DataEncoderModule()
		data.name = section
		sections[section] = data
		return true
	}

	# Summary:
	# Executes the specified directive, if it exports a symbol.
	private export_export_directive(tokens: List<Token>) {
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_IDENTIFIER return false

		# Pattern: .export $symbol
		if not (tokens[1].(IdentifierToken).value == EXPORT_DIRECTIVE) return false

		exports.add(tokens[2].(IdentifierToken).value)
		return true
	}

	# Summary:
	# Executes the specified directive, if it controls debug information.
	private execute_debug_directive(tokens: List<Token>) {
		if tokens.size < 2 or tokens[1].type != TOKEN_TYPE_IDENTIFIER return false

		directive = tokens[1].(IdentifierToken).value

		if directive == LINE_DIRECTIVE {
			# Pattern: .line $file $line $character
			if tokens.size < 5 or tokens[2].type != TOKEN_TYPE_NUMBER or tokens[3].type != TOKEN_TYPE_NUMBER or tokens[4].type != TOKEN_TYPE_NUMBER return false

			file = tokens[2].(NumberToken).data
			line = tokens[3].(NumberToken).data - 1
			character = tokens[4].(NumberToken).data - 1

			instructions.add(DebugBreakInstruction(unit, Position(none as SourceFile, line, character)))
			return true
		}

		if directive == DEBUG_FILE_DIRECTIVE {
			# Pattern: .debug_file $file
			if tokens.size < 3 or tokens[2].type != TOKEN_TYPE_STRING return false

			debug_file = tokens[2].(StringToken).text
			return true
		}

		if directive == DEBUG_START_DIRECTIVE {
			# Pattern: .debug_start $symbol
			if tokens.size < 3 or tokens[2].type != TOKEN_TYPE_IDENTIFIER return false

			symbol = tokens[2].(IdentifierToken).value

			instruction = Instruction(unit, INSTRUCTION_DEBUG_START)
			handle = DataSectionHandle(symbol, false) as Handle
			instruction.parameters.add(InstructionParameter(handle, FLAG_NONE))
			instructions.add(instruction)
			return true
		}

		if directive == DEBUG_FRAME_OFFSET_DIRECTIVE {
			# Pattern: .debug_start $symbol
			if tokens.size < 3 or tokens[2].type != TOKEN_TYPE_NUMBER return false

			offset = tokens[2].(NumberToken).data

			instruction = Instruction(Unit, INSTRUCTION_DEBUG_FRAME_OFFSET)
			handle = ConstantHandle(offset)
			instruction.parameters.add(InstructionParameter(handle, FLAG_NONE))
			instructions.add(instruction)
			return true
		}

		if directive == DEBUG_END_DIRECTIVE {
			# Pattern: .debug_end
			instructions.add(Instruction(unit, INSTRUCTION_DEBUG_END))
			return true
		}

		return false
	}

	# Summary:
	# Executes the specified directive, if it allocates some primitive type such as byte or word.
	private execute_constant_allocator(tokens: List<Token>) {
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_NUMBER return false

		directive = tokens[1].(IdentifierToken).value
		value = tokens[2].(NumberToken).data

		if directive == BYTE_SPECIFIER data.write(value) # Pattern: .byte $value
		else directive == WORD_SPECIFIER data.write_int16(value) # Pattern: .word $value
		else directive == DWORD_SPECIFIER data.write_int32(value) # Pattern: .dword $value
		else directive == QWORD_SPECIFIER data.write_int64(value) # Pattern: .qword $value
		else directive == XWORD_SPECIFIER or directive == OWORD_SPECIFIER abort('Please use smaller allocators')
		else {
			return false
		}

		return true
	}

	# Summary:
	# Allocates a string, if the specified tokens represent a allocator
	private execute_string_allocator(tokens: List<Token>) {
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_STRING return false

		allocator = tokens[1].(IdentifierToken).value

		if allocator == STRING_DIRECTIVE {
			# Pattern: .'...'
			data.string(tokens[2].(StringToken).text)
		}
		else allocator == CHARACTERS_DIRECTIVE {
			# Pattern: .characters '...'
			data.string(tokens[2].(StringToken).text, false)
		}
		else {
			return false
		}

		return true
	}

	# Summary:
	# Align the current data section, if the specified tokens represent an alignment directive
	private execute_alignment(tokens: List<Token>) {
		# Pattern: .align $alignment
		if tokens.size < 3 or tokens[1].type != TOKEN_TYPE_IDENTIFIER or tokens[2].type != TOKEN_TYPE_NUMBER return false
		if not (tokens[1].(IdentifierToken).value == ALIGN_DIRECTIVE) return false

		alignment = tokens[2].(NumberToken).data
		data_encoder.align(data, pow(2, alignment))
		return true
	}

	# Summary:
	# Applies a directive if the specified tokens represent a directive.
	# Pattern: . $directive $1 $2 ... $n
	private parse_directive(tokens: List<Token>) {
		# Directives start with a dot
		if not tokens[0].match(Operators.DOT) return false

		# The second token must be the identifier of the directive
		if tokens.size == 1 or not tokens[1].match(TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_KEYWORD) return false

		if execute_section_directive(tokens) return true
		if export_export_directive(tokens) return true
		if execute_debug_directive(tokens) return true

		# The executors below are only executed if we are in the data section
		if data == none return false

		if execute_offset_allocator(tokens) return true
		if execute_symbol_reference_allocator(tokens) return true
		if execute_constant_allocator(tokens) return true
		if execute_string_allocator(tokens) return true
		if execute_alignment(tokens) return true

		return false
	}

	# Summary:
	# Forms a label if the specified tokens represent a label.
	# Pattern: $name :
	private parse_label(tokens: List<Token>) {
		# Labels must begin with an identifier
		if not tokens[0].match(TOKEN_TYPE_IDENTIFIER) return false

		# Labels must end with a colon
		if tokens.size == 1 or not tokens[1].match(Operators.COLON) return false

		name = tokens[0].(IdentifierToken).value

		if data == none {
			instructions.add(LabelInstruction(unit, Label(name)))
		}
		else {
			data.create_local_symbol(name, data.position)
		}

		return true
	}

	# Summary:
	# Tries to form a instruction parameter handle from the specified tokens starting at the specified offset.
	# Instruction parameters are registers, memory addresses and numbers for instance.
	private parse_instruction_parameter(all: List<Token>, i: large) {
		parameter = all[i]

		if parameter.type == TOKEN_TYPE_IDENTIFIER {
			value = parameter.(IdentifierToken).value

			# Return a register handle, if the token represents one
			if registers.contains_key(value) return registers[value]

			# If the identifier represents a size specifier, determine how many bytes it represents
			bytes = when(value) {
				BYTE_SPECIFIER => 1,
				WORD_SPECIFIER => 2,
				DWORD_SPECIFIER => 4,
				QWORD_SPECIFIER => 8,
				XWORD_SPECIFIER => 16,
				OWORD_SPECIFIER => 32,
				else => 0
			}

			# If the variable 'bytes' is positive, it means the current identifier is a size specified and a memory address should follow it
			if bytes > 0 {
				# Ensure the next token represents a memory address
				if ++i >= all.size or all[i].type != TOKEN_TYPE_PARENTHESIS abort('Expected a memory address after this size specifier')

				memory_address = parse_instruction_parameter(all, i) as Handle
				memory_address.format = to_format(bytes)

				return memory_address
			}

			# Since the identifier is not a register or a size specifier, it must be a symbol
			return DataSectionHandle(value, true)
		}

		if parameter.type == TOKEN_TYPE_NUMBER {
			number = parameter.(NumberToken)
			return ConstantHandle(number.data, number.format)
		}

		if parameter.type == TOKEN_TYPE_PARENTHESIS {
			tokens = parameter.(ParenthesisToken).tokens

			if tokens.size == 1 {
				# Patterns: $register / $symbol / $number
				start = parse_instruction_parameter(tokens, 0) as Handle
				
				if start.instance == INSTANCE_DATA_SECTION {
					start.(DataSectionHandle).address = false
					return start
				}

				return MemoryHandle(unit, Result(start, SYSTEM_SIGNED), 0)
			}
			else tokens.size == 2 {
				# Patterns: - $number
				offset = 0

				# Ensure the last operator is a plus or minus operator
				# Also handle the negation of the integer offset.
				if tokens[0].match(Operators.SUBTRACT) {
					offset = -tokens[1].(NumberToken).data
				}
				else tokens[0].match(Operators.ADD) {
					offset = tokens[1].(NumberToken).data
				}
				else {
					abort('Expected the first token to be a plus or minus operator')
				}

				return MemoryHandle(unit, Result(ConstantHandle(offset), SYSTEM_SIGNED), 0)
			}
			else tokens.size == 3 {
				# Patterns: $register + $register / $register + $number / $symbol + $number
				if tokens[1].match(Operators.ADD) {
					start = parse_instruction_parameter(tokens, 0) as Handle
					offset = parse_instruction_parameter(tokens, 2) as Handle

					if start.instance == INSTANCE_DATA_SECTION {
						if offset.instance != INSTANCE_CONSTANT abort('Expected an integer offset')

						# Apply the offset
						start.(DataSectionHandle).offset += offset.(ConstantHandle).value
						start.(DataSectionHandle).address = false

						return start
					}

					return ComplexMemoryHandle(Result(start, SYSTEM_SIGNED), Result(offset, SYSTEM_SIGNED), 1, 0)
				}

				# Patterns: $register - $number / $symbol - $number
				if tokens[1].match(Operators.SUBTRACT) {
					start = parse_instruction_parameter(tokens, 0) as Handle
					offset = -tokens[2].(NumberToken).data

					if start.instance == INSTANCE_DATA_SECTION {
						# Apply the offset
						start.(DataSectionHandle).offset += offset
						start.(DataSectionHandle).address = false

						return start
					}

					return MemoryHandle(none as Unit, Result(start, SYSTEM_FORMAT), offset)
				}

				# Pattern: $register * $number
				if tokens[1].match(Operators.MULTIPLY) and tokens[2].type == TOKEN_TYPE_NUMBER {
					first = Result(ConstantHandle(0), SYSTEM_SIGNED)
					second = Result(parse_instruction_parameter(tokens, 0) as Handle, SYSTEM_SIGNED)
					stride = tokens[2].(NumberToken).data

					return ComplexMemoryHandle(first, second, stride, 0)
				}
			}
			else tokens.size == 5 {
				first = Result(parse_instruction_parameter(tokens, 0) as Handle, SYSTEM_SIGNED)

				# Patterns: $register + $register + $number / $register + $register - $number
				if tokens[1].match(Operators.ADD) {
					# Ensure the last token is a number
					if tokens[4].type != TOKEN_TYPE_NUMBER {
						abort('Expected the last token to be an integer number')
					}

					offset = 0

					# Ensure the last operator is a plus or minus operator
					# Also handle the negation of the integer offset.
					if tokens[3].match(Operators.SUBTRACT) {
						offset = -tokens[4].(NumberToken).data
					}
					else tokens[3].match(Operators.ADD) {
						offset = tokens[4].(NumberToken).data
					}

					second = Result(parse_instruction_parameter(tokens, 2) as Handle, SYSTEM_SIGNED)

					return ComplexMemoryHandle(first, second, 1, offset)
				}

				# Patterns: $register * $number + $register / $register * $number + $number / $register * $number - $number
				if tokens[1].match(Operators.MULTIPLY) {
					stride = tokens[2].(NumberToken).data

					if tokens[tokens.size - 1].type == TOKEN_TYPE_NUMBER {
						# Patterns: $register * $number + $number / $register * $number - $number
						offset = parse_instruction_parameter(tokens, 3).(ConstantHandle).value

						# NOTE: This is redundant, but the external assembler encodes differently if this code is not present
						if stride == 1 return MemoryHandle(none as Unit, first, offset)

						return ComplexMemoryHandle(Result(), first, stride, offset)
					}
					else {
						# Pattern: $register * $number + $register
						offset = Result(parse_instruction_parameter(tokens, 4) as Handle, SYSTEM_SIGNED)

						# NOTE: This is redundant, but the external assembler encodes differently if this code is not present
						if stride == 1 return ComplexMemoryHandle(first, offset, 1, 0)

						return ComplexMemoryHandle(offset, first, stride, 0)
					}
				}
			}
			else tokens.size == 7 {
				# Ensure the last token is a number
				if tokens[6].type != TOKEN_TYPE_NUMBER {
					abort('Expected the last token to be an integer number')
				}

				offset = 0

				# Ensure the last operator is a plus or minus operator
				# Also handle the negation of the integer offset.
				if tokens[5].match(Operators.SUBTRACT) {
					offset = -tokens[6].(NumberToken).data
				}
				else tokens[5].match(Operators.ADD) {
					offset = tokens[6].(NumberToken).data
				}
				else {
					abort('Expected the second last token to be a plus or minus operator')
				}

				# Patterns: $register * $number + $register + $number
				first = Result(parse_instruction_parameter(tokens, 0) as Handle, SYSTEM_SIGNED)
				stride = tokens[2].(NumberToken).data
				second = Result(parse_instruction_parameter(tokens, 4) as Handle, SYSTEM_SIGNED)

				# NOTE: This is redundant, but the external assembler encodes differently if this code is not present
				if stride == 1 return ComplexMemoryHandle(first, second, 1, offset)

				return ComplexMemoryHandle(second, first, stride, offset)
			}
		}

		# Pattern: - $number
		if parameter.match(Operators.SUBTRACT) {
			if i + 1 >= all.size abort('Expected an integer number')

			# Parse the number and negate it
			number = parse_instruction_parameter(all, i + 1) as Handle
			number.(ConstantHandle).value = -number.(ConstantHandle).value

			return number
		}

		# Pattern: + $number
		if parameter.match(Operators.ADD) {
			if i + 1 >= all.size abort('Expected an integer number')

			# Parse the number and negate it
			number = parse_instruction_parameter(all, i + 1) as Handle
			number.(ConstantHandle).value = number.(ConstantHandle).value

			return number
		}

		abort("Can not understand: " + to_string(all))
	}

	# Summary:
	# Returns whether the specified operation represents a jump instruction
	static is_jump(operation) {
		return operation == platform.x64.JUMP or
			operation == platform.x64.JUMP_ABOVE or
			operation == platform.x64.JUMP_ABOVE_OR_EQUALS or
			operation == platform.x64.JUMP_BELOW or
			operation == platform.x64.JUMP_BELOW_OR_EQUALS or
			operation == platform.x64.JUMP_EQUALS or
			operation == platform.x64.JUMP_GREATER_THAN or
			operation == platform.x64.JUMP_GREATER_THAN_OR_EQUALS or
			operation == platform.x64.JUMP_LESS_THAN or
			operation == platform.x64.JUMP_LESS_THAN_OR_EQUALS or
			operation == platform.x64.JUMP_NOT_EQUALS or
			operation == platform.x64.JUMP_NOT_ZERO or
			operation == platform.x64.JUMP_ZERO
	}

	# Summary:
	# Tries to create an instruction from the specified tokens
	parse_instruction(tokens: List<Token>) {
		if tokens[0].type != TOKEN_TYPE_IDENTIFIER return false
		operation = tokens[0].(IdentifierToken).value

		parameters = List<InstructionParameter>()
		position = 1 # Start after the operation identifier

		loop (position < tokens.size) {
			# Parse the next parameter
			parameter = parse_instruction_parameter(tokens, position)
			parameters.add(InstructionParameter(parameter, FLAG_NONE))

			# Try to find the next comma, which marks the start of the next parameter
			loop (position < tokens.size) {
				token = tokens[position++]
				if token.match(Operators.COMMA) stop # NOTE: We have already stepped over the comma above
			}
		}

		# Determine the instruction type
		instruction_type = INSTRUCTION_NORMAL
		if is_jump(operation) { instruction_type = INSTRUCTION_JUMP }

		instruction = Instruction(unit, instruction_type)
		instruction.parameters.add_all(parameters)
		instruction.operation = operation

		instructions.add(instruction)
		return true
	}

	# Summary: Finds instruction prefixes and merges them into the instruction
	join_instruction_prefixes(tokens: List<Token>) {
		loop (i = tokens.size - 2, i >= 0, i--) {
			# Find adjacent identifier tokens
			current = tokens[i]
			next = tokens[i + 1]
			if current.type != TOKEN_TYPE_IDENTIFIER or next.type != TOKEN_TYPE_IDENTIFIER continue

			# Ensure the current token is an instruction prefix
			identifier = current.(IdentifierToken).value
			if not (identifier == platform.x64.LOCK_PREFIX) continue

			# Merge the prefix into the instruction
			next.(IdentifierToken).value = identifier + ` ` + next.(IdentifierToken).value
			tokens.remove_at(i)
		}
	}

	parse(file: SourceFile, assembly: String) {
		lines = assembly.split(`\n`)
		position = Position(file, -1, 0) # Start from line -1, because the loop moves to the next line at the beginning

		loop line in lines {
			position.next_line()

			# Tokenize the current line
			if get_tokens(line, position, false) has not tokens abort('Could not understand a line of assembly')
			register_file(tokens, file)

			# Skip empty lines
			if tokens.size == 0 continue

			# Preprocess
			join_instruction_prefixes(tokens)

			# Parse directives here, because all sections have some directives
			if parse_directive(tokens) continue

			# Parse labels here, because all sections have labels
			if parse_label(tokens) continue

			if section == TEXT_SECTION {
				if parse_instruction(tokens) continue
			}

			abort('Can not understand')
		}

		# Save the current data section, if it is not saved already
		if data != none and not sections.contains_key(section) {
			sections[section] = data
		}
	}

	reset() {
		instructions.clear()
		sections.clear()

		if data != none data.reset()
		data = none

		section = String(TEXT_SECTION)
	}
}