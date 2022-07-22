InstructionPrinterBuilder {
	constant MAX_CONTENT_LENGTH = 100
	constant MAX_LIFETIMES = 700

	line: link = none as link
	lines: List<link> = List<link>()
	position: large = 0

	# Instruction index to line number
	mappings: Map<large, large> = Map<large, large>()

	init() {
		end()
	}

	append(string: link) {
		length = length_of(string)

		# If the line is too long, truncate it
		if position + length > MAX_CONTENT_LENGTH {
			length = MAX_CONTENT_LENGTH - position
		}

		copy(string, length, line + position)

		position += length
	}

	append(character: char) {
		# If the line is too long, truncate it
		if position + 1 > MAX_CONTENT_LENGTH return

		line[position] = character
		position++
	}

	append(string: String) {
		append(string.data)
	}

	put(x: large, y: large, character: char) {
		lines[y][x] = character
	}

	start(index: large) {
		mappings[index] = lines.size - 1
	}

	lifetime(i: large, j: large) {
		from = mappings[i]
		to = mappings[j]
		x = MAX_CONTENT_LENGTH

		loop (x < MAX_CONTENT_LENGTH + MAX_LIFETIMES, x++) {
			available = true

			# Find space for the lifetime line by moving from the left to the right
			start = max(from - 1, 0) # Add one character of padding so that lines do not get connected
			end = min(to + 1, lines.size - 1) # Add one character of padding so that lines do not get connected

			loop (y = start, y <= end, y++) {
				if lines[y][x] == ` ` continue

				available = false
				stop
			}

			if available stop
		}

		if x == MAX_CONTENT_LENGTH + MAX_LIFETIMES {
			panic('Too many lifetimes')
		}

		loop (y = from, y <= to, y++) {
			put(x, y, `|`)
		}
	}

	end() {
		line = allocate(MAX_CONTENT_LENGTH + MAX_LIFETIMES + 1)
		position = 0

		fill(line, MAX_CONTENT_LENGTH + MAX_LIFETIMES, ` `)

		lines.add(line)
	}
}

InstructionPrinter {
	results: Map<Result, large> = Map<Result, large>()
	variables: List<Result> = List<Result>()
	verbose: bool = true

	name_of(result: Result) {
		if result.is_constant return String(`#`) + to_string(result.value.(ConstantHandle).value)
		if result.is_any_register return result.value.(RegisterHandle).register.partitions[]

		index = 0

		if results.contains_key(result) {
			index = results[result]
		}
		else {
			index = results.size
			results[result] = index
		}

		return String(`%`) + to_string(index)
	}

	name_of(variable: Variable) {
		return String(`<`) + variable.name + `>`
	}

	name_of(instruction: DualParameterInstruction) {
		return when(instruction.type) {
			INSTRUCTION_ADDITION => 'add',
			INSTRUCTION_SUBTRACT => 'subtract',
			INSTRUCTION_MULTIPLICATION => 'multiply',
			INSTRUCTION_COMPARE => 'compare',
			INSTRUCTION_DIVISION => 'divide'
			else => '?'
		}
	}

	name_of(handle: Handle){
		return handle.string()
	}

	print_result_assignment(builder: InstructionPrinterBuilder, instruction: Instruction) {
		builder.append(name_of(instruction.result))
		builder.append(' = ')
	}

	print_access_mode(builder: InstructionPrinterBuilder, mode: large) {
		if mode == ACCESS_WRITE {
			builder.append(' (write)')
		}
		else {
			builder.append(' (read)')
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: AdditionInstruction) {
		print(builder, instruction as DualParameterInstruction)
	}

	print(builder: InstructionPrinterBuilder, instruction: SubtractionInstruction) {
		print(builder, instruction as DualParameterInstruction)
	}

	print(builder: InstructionPrinterBuilder, instruction: MultiplicationInstruction) {
		print(builder, instruction as DualParameterInstruction)
	}

	print(builder: InstructionPrinterBuilder, instruction: LabelInstruction) {
		builder.append(instruction.label.name)
		builder.append(`:`)
	}

	print(builder: InstructionPrinterBuilder, instruction: RequireVariablesInstruction) {
		if not verbose return

		if instruction.is_inputter { builder.append('  input  ') }
		else { builder.append('  output ') }

		loop (i = 0, i < instruction.dependencies.size - 1, i++) {
			builder.append(name_of(instruction.dependencies[i]))
			builder.append(', ')
		}

		if instruction.dependencies.size > 0 {
			builder.append(name_of(instruction.dependencies[instruction.dependencies.size - 1]))
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: ReturnInstruction) {
		builder.append('return ')
		builder.append(name_of(instruction.object))
	}

	print(builder: InstructionPrinterBuilder, instruction: MoveInstruction) {
		builder.append(name_of(instruction.first))

		if instruction.type == MOVE_COPY {
			builder.append(' = ')
		}
		else instruction.type == MOVE_LOAD {
			builder.append(' := ')
		}
		else {
			builder.append(' <- ')
		}

		builder.append(name_of(instruction.second))
	}

	print(builder: InstructionPrinterBuilder, instruction: GetConstantInstruction) {
		# Do not print this instruction
	}

	print(builder: InstructionPrinterBuilder, instruction: GetVariableInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(name_of(instruction.variable))
		print_access_mode(builder, instruction.mode)
	}

	print(builder: InstructionPrinterBuilder, instruction: InitializeInstruction) {
		builder.append('initialize')
	}

	print(builder: InstructionPrinterBuilder, instruction: SetVariableInstruction) {
		if instruction.is_copied {
			builder.append(name_of(instruction.result))
			builder.append(' = ')
			builder.append(name_of(instruction.value))
			builder.end()

			builder.append(name_of(instruction.variable))
			builder.append(' = ')
			builder.append(name_of(instruction.result))
		}
		else {
			builder.append(name_of(instruction.variable))
			builder.append(' = ')
			builder.append(name_of(instruction.value))
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: CallInstruction) {
		print_result_assignment(builder, instruction)
		builder.append('call ')

		if instruction.function.is_data_section_handle {
			builder.append(instruction.function.value.(DataSectionHandle).identifier)
		}
		else {
			builder.append(name_of(instruction.function))
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: ReorderInstruction) {
		builder.append('reorder {')
		builder.end()

		loop (i = 0, i < instruction.destinations.size, i++) {
			destination = instruction.destinations[i]
			source = instruction.sources[i]

			builder.append('  ')
			builder.append(name_of(destination))
			builder.append(' <- ')
			builder.append(name_of(source))
			builder.end()
		}

		builder.append('}')
	}

	print(builder: InstructionPrinterBuilder, instruction: ExchangeInstruction) {
		builder.append(name_of(instruction.first))
		builder.append(' <-> ')
		builder.append(name_of(instruction.second))
	}

	print(builder: InstructionPrinterBuilder, instruction: LockStateInstruction) {
		builder.append('lock ')
		builder.append(instruction.register.partitions[])
	}

	print(builder: InstructionPrinterBuilder, instruction: EvacuateInstruction) {
		builder.append('evacuate')
	}

	print(builder: InstructionPrinterBuilder, instruction: GetObjectPointerInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(to_size_modifier(to_bytes(instruction.variable.type.format)))
		builder.append(` `)
		builder.append(`[`)
		builder.append(name_of(instruction.start))
		builder.append(`.`)
		builder.append(name_of(instruction.variable))
		builder.append(`]`)
		print_access_mode(builder, instruction.mode)
	}

	print(builder: InstructionPrinterBuilder, instruction: GetMemoryAddressInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(to_size_modifier(to_bytes(instruction.format)))
		builder.append(` `)
		builder.append(`[`)
		builder.append(name_of(instruction.start))
		builder.append(`+`)
		builder.append(name_of(instruction.offset))
		builder.append(`*`)
		builder.append(to_string(instruction.stride))
		builder.append(`]`)
		print_access_mode(builder, instruction.mode)
	}

	print(builder: InstructionPrinterBuilder, instruction: JumpInstruction) {
		operation = none as link

		if instruction.comparator == none {
			if settings.is_x64 { operation = platform.x64.JUMP }
		}
		else instruction.is_signed {
			operation = JumpInstruction.jumps[instruction.comparator].signed
		}
		else not instruction.is_signed {
			operation = JumpInstruction.jumps[instruction.comparator].unsigned
		}

		builder.append(operation)
		builder.append(` `)
		builder.append(instruction.label.name)
	}

	print(builder: InstructionPrinterBuilder, instruction: CompareInstruction) {
		builder.append(name_of(instruction))
		builder.append(` `)
		builder.append(name_of(instruction.first))
		builder.append(', ')
		builder.append(name_of(instruction.second))
	}

	print(builder: InstructionPrinterBuilder, instruction: DivisionInstruction) {
		print(builder, instruction as DualParameterInstruction)
	}

	print(builder: InstructionPrinterBuilder, instruction: ExtendNumeratorInstruction) {
		builder.append('extend-numerator')
	}

	print(builder: InstructionPrinterBuilder, instruction: BitwiseInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(instruction.instruction)
		builder.append(` `)
		builder.append(name_of(instruction.first))
		builder.append(', ')
		builder.append(name_of(instruction.second))
	}

	print(builder: InstructionPrinterBuilder, instruction: SingleParameterInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(instruction.instruction)
		builder.append(` `)
		builder.append(name_of(instruction.first))
	}

	print(builder: InstructionPrinterBuilder, instruction: DebugBreakInstruction) {
		builder.append('break')
	}

	print(builder: InstructionPrinterBuilder, instruction: ConvertInstruction) {
		print_result_assignment(builder, instruction)
		builder.append('convert')
		builder.append(` `)
		builder.append(name_of(instruction.number))
		builder.append(' (')

		if instruction.format == FORMAT_DECIMAL {
			builder.append('decimal')
		}
		else {
			builder.append(to_size_modifier(instruction.format))
		}

		builder.append(')')
	}

	print(builder: InstructionPrinterBuilder, instruction: AllocateStackInstruction) {
		print_result_assignment(builder, instruction)
		builder.append('allocate stack (')
		builder.append(instruction.identity)
		builder.append(`)`)
	}

	print(builder: InstructionPrinterBuilder, instruction: CreatePackInstruction) {
		print_result_assignment(builder, instruction)
		builder.append('pack ')

		loop (i = 0, i < instruction.values.size - 1, i++) {
			builder.append(name_of(instruction.values[i]))
			builder.append(', ')
		}

		if instruction.values.size > 0 {
			last = instruction.values[instruction.values.size - 1]
			builder.append(name_of(last))
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: CreatePackInstruction) {
		builder.append('nop')
	}

	print(builder: InstructionPrinterBuilder, instruction: LabelMergeInstruction) {
		if not verbose return

		builder.append('  merge $')
		builder.append(instruction.primary)

		if instruction.secondary !== none {
			builder.append(', $')
			builder.append(instruction.secondary)
		}
	}

	print(builder: InstructionPrinterBuilder, instruction: EnterScopeInstruction) {
		builder.append('enter $')
		builder.append(instruction.id)
		builder.append(' {')
		builder.end()

		loop iterator in instruction.scope.inputs {
			variable = iterator.key
			value = iterator.value

			builder.append('  ')
			builder.append(name_of(variable))
			builder.append(' <- ')
			builder.append(name_of(value))
			builder.end()
		}

		builder.append(`}`)
	}

	print(builder: InstructionPrinterBuilder, instruction: DualParameterInstruction) {
		print_result_assignment(builder, instruction)
		builder.append(name_of(instruction))
		builder.append(` `)
		builder.append(name_of(instruction.first))
		builder.append(', ')
		builder.append(name_of(instruction.second))
	}

	print(builder: InstructionPrinterBuilder) {
		builder.append('unknown')
	}

	print(builder: InstructionPrinterBuilder, instruction: Instruction) {
		when (instruction.type) {
			INSTRUCTION_ADDITION => print(builder, instruction as AdditionInstruction),
			INSTRUCTION_SUBTRACT => print(builder, instruction as SubtractionInstruction),
			INSTRUCTION_MULTIPLICATION => print(builder, instruction as MultiplicationInstruction),
			INSTRUCTION_LABEL => print(builder, instruction as LabelInstruction),
			INSTRUCTION_REQUIRE_VARIABLES => print(builder, instruction as RequireVariablesInstruction),
			INSTRUCTION_RETURN => print(builder, instruction as ReturnInstruction),
			INSTRUCTION_MOVE => print(builder, instruction as MoveInstruction),
			INSTRUCTION_GET_CONSTANT => print(builder, instruction as GetConstantInstruction),
			INSTRUCTION_GET_VARIABLE => print(builder, instruction as GetVariableInstruction),
			INSTRUCTION_INITIALIZE => print(builder, instruction as InitializeInstruction),
			INSTRUCTION_SET_VARIABLE => print(builder, instruction as SetVariableInstruction),
			INSTRUCTION_CALL => print(builder, instruction as CallInstruction),
			INSTRUCTION_REORDER => print(builder, instruction as ReorderInstruction),
			INSTRUCTION_LOCK_STATE => print(builder, instruction as LockStateInstruction),
			INSTRUCTION_EVACUATE => print(builder, instruction as EvacuateInstruction),
			INSTRUCTION_GET_OBJECT_POINTER => print(builder, instruction as GetObjectPointerInstruction),
			INSTRUCTION_GET_MEMORY_ADDRESS => print(builder, instruction as GetMemoryAddressInstruction),
			INSTRUCTION_JUMP => print(builder, instruction as JumpInstruction),
			INSTRUCTION_COMPARE => print(builder, instruction as CompareInstruction),
			INSTRUCTION_DIVISION => print(builder, instruction as DivisionInstruction),
			INSTRUCTION_EXTEND_NUMERATOR => print(builder, instruction as ExtendNumeratorInstruction),
			INSTRUCTION_BITWISE => print(builder, instruction as BitwiseInstruction),
			INSTRUCTION_SINGLE_PARAMETER => print(builder, instruction as SingleParameterInstruction),
			INSTRUCTION_DEBUG_BREAK => print(builder, instruction as DebugBreakInstruction),
			INSTRUCTION_CONVERT => print(builder, instruction as ConvertInstruction),
			INSTRUCTION_ALLOCATE_STACK => print(builder, instruction as AllocateStackInstruction),
			INSTRUCTION_NO_OPERATION => print(builder, instruction as NoOperationInstruction),
			INSTRUCTION_CREATE_PACK => print(builder, instruction as CreatePackInstruction),
			INSTRUCTION_LABEL_MERGE => print(builder, instruction as LabelMergeInstruction),
			INSTRUCTION_ENTER_SCOPE => print(builder, instruction as EnterScopeInstruction),
			else => print(builder)
		}
	}

	find_variable_results(unit: Unit) {
		loop instruction in unit.instructions {
			if instruction.type != INSTRUCTION_SET_VARIABLE continue

			if instruction.(SetVariableInstruction).is_copied {
				variables.add(instruction.result)
			}
			else {
				variables.add(instruction.(SetVariableInstruction).value)
			}
		}

		loop iterator in unit.scopes {
			scope = iterator.value

			loop iterator in scope.inputs {
				variables.add(iterator.value)
			}
		}
	}

	compute_lifetimes(unit: Unit, builder: InstructionPrinterBuilder) {
		lifetimes = Map<Result, Pair<large, large>>()

		loop result in variables {
			lifetimes[result] = Pair<large, large>(-1, -1)
		}

		loop (i = 0, i < unit.instructions.size, i++) {
			instruction = unit.instructions[i]

			loop result in variables {
				if not result.lifetime.usages.contains(instruction) continue

				lifetime = lifetimes[result]

				if lifetime.key == -1 {
					lifetime.key = i # Update the start of the lifetime
				}

				lifetime.value = i # Update the end of the lifetime
			}
		}

		loop iterator in lifetimes {
			lifetime = iterator.value
			builder.lifetime(lifetime.key, lifetime.value)
		}
	}

	print(unit: Unit) {
		builder = InstructionPrinterBuilder()

		loop (i = 0, i < unit.instructions.size, i++) {
			instruction = unit.instructions[i]
			builder.start(i)
			print(builder, instruction)
			builder.end()
		}

		find_variable_results(unit)
		compute_lifetimes(unit, builder)

		result = StringBuilder()

		max_index_length = to_string(builder.lines.size).length

		loop (i = 0, i < builder.lines.size, i++) {
			# Pad the indices
			index_string = to_string(i)
			padding = max_index_length - index_string.length

			loop (j = 0, j < padding, j++) {
				result.append(` `)
			}

			result.append(index_string)
			result.append(':   ')
			result.append_line(builder.lines[i])
		}

		console.write_line(result.string())
	}
}