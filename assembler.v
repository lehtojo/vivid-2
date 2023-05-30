constant REGISTER_NONE = 0
constant REGISTER_VOLATILE = 1
constant REGISTER_RESERVED = 1 <| 1
constant REGISTER_RETURN = 1 <| 2
constant REGISTER_STACK_POINTER = 1 <| 3
constant REGISTER_NUMERATOR = 1 <| 4
constant REGISTER_REMAINDER = 1 <| 5
constant REGISTER_MEDIA = 1 <| 6
constant REGISTER_DECIMAL_RETURN = 1 <| 7
constant REGISTER_SHIFT = 1 <| 8
constant REGISTER_BASE_POINTER = 1 <| 9
constant REGISTER_ZERO = 1 <| 10
constant REGISTER_RETURN_ADDRESS = 1 <| 11

AssemblyBuilder {
	instructions: Map<SourceFile, List<Instruction>> = Map<SourceFile, List<Instruction>>()
	constants: Map<SourceFile, List<ConstantDataSectionHandle>> = Map<SourceFile, List<ConstantDataSectionHandle>>()
	modules: Map<SourceFile, List<DataEncoderModule>> = Map<SourceFile, List<DataEncoderModule>>()
	exports: Set<String> = Set<String>()
	text: StringBuilder

	init() {
		if settings.is_assembly_output_enabled { text = StringBuilder() }
	}

	init(text: String) {
		if settings.is_assembly_output_enabled { this.text = StringBuilder(text) }
	}

	add(file: SourceFile, instructions: List<Instruction>) {
		if this.instructions.contains_key(file) {
			this.instructions[file].add_all(instructions)
			return
		}

		this.instructions[file] = instructions
	}

	add(file: SourceFile, instruction: Instruction): _ {
		if instructions.contains_key(file) {
			instructions[file].add(instruction)
			return
		}

		instructions[file] = [ instruction ]
	}

	add(file: SourceFile, constants: List<ConstantDataSectionHandle>): _ {
		if this.constants.contains_key(file) {
			this.constants[file].add_all(constants)
			return
		}

		this.constants[file] = constants
	}

	add(file: SourceFile, modules: List<DataEncoderModule>): _ {
		if this.modules.contains_key(file) {
			this.modules[file].add_all(modules)
			return
		}

		this.modules[file] = modules
	}

	add(builder: AssemblyBuilder): _ {
		loop iterator in builder.instructions { add(iterator.key, iterator.value) }
		loop iterator in builder.constants { add(iterator.key, iterator.value) }
		loop iterator in builder.modules { add(iterator.key, iterator.value) }
		loop exported_symbol in builder.exports { export_symbol(exported_symbol) }

		if builder.text != none write(builder.text.string())
	}

	get_data_section(file: SourceFile, section: String): DataEncoderModule {
		if section.length > 0 and section[] != `.` { section = String(`.`) + section }

		file_modules = none as List<DataEncoderModule>

		if modules.contains_key(file) {
			file_modules = modules[file]

			loop module in file_modules {
				if module.name == section return module
			}
		}
		else {
			file_modules = List<DataEncoderModule>()
			modules[file] = file_modules
		}
		
		module = DataEncoderModule()
		module.name = section
		file_modules.add(module)
		return module
	}

	export_symbols(symbols: Array<String>) {
		loop symbol in symbols {
			export_symbol(symbol)
		}
	}

	export_symbols(symbols: List<String>): _ {
		loop symbol in symbols {
			export_symbol(symbol)
		}
	}

	export_symbol(symbol: String): _ {
		exports.add(symbol)
	}

	write(text: String): _ {
		if this.text == none return
		this.text.append(text)
	}

	write(text: link): _ {
		if this.text == none return
		this.text.append(text)
	}

	write(character: char): _ {
		if this.text == none return
		this.text.append(character)
	}

	write_line(text: String): _ {
		if this.text == none return
		this.text.append_line(text)
	}

	write_line(text: link): _ {
		if this.text == none return
		this.text.append_line(text)
	}

	write_line(character: char) {
		if this.text == none return
		this.text.append_line(character)
	}

	string(): String {
		if this.text == none return String.empty
		return this.text.string()
	}
}

Register {
	identifier: byte = 0
	name: byte = 0
	partitions: List<String>
	value: Result
	flags: large
	is_locked: bool

	is_volatile => has_flag(flags, REGISTER_VOLATILE)
	is_reserved => has_flag(flags, REGISTER_RESERVED)
	is_media_register => has_flag(flags, REGISTER_MEDIA)

	init(identifier: byte, partitions: String, flags: large) {
		this.identifier = identifier
		this.name = identifier & 7 # Take the first 3 bits
		this.partitions = partitions.split(` `)
		this.flags = flags
	}

	lock(): _ {
		is_locked = true
	}

	unlock(): _ {
		is_locked = false
	}

	is_value_copy(): bool {
		return value != none and not (value.value.instance == INSTANCE_REGISTER and value.value.(RegisterHandle).register == this)
	}

	is_available(): bool {
		return not is_locked and (value == none or not value.is_active() or is_value_copy())
	}

	is_deactivating(): bool {
		return not is_locked and value != none and value.is_deactivating()
	}

	is_releasable(unit: Unit): bool {
		return not is_locked and (value == none or value.is_releasable(unit))
	}

	get(size: large): String {
		i = 1
		count = partitions.size

		loop (j = 0, j < count, j++) {
			if size == i return partitions[count - 1 - j]
			i *= 2
		}

		abort('Could not find a register partition with the specified size')
	}

	reset(): _ {
		value = none as Result
	}

	string(): String {
		return partitions[]
	}
}

Lifetime {
	usages: List<Instruction> = List<Instruction>()

	reset() {
		usages.clear()
	}

	# Summary: Returns whether this lifetime is active
	is_active(): bool {
		started = false

		loop (i = 0, i < usages.size, i++) {
			state = usages[i].state

			# If one of the usages is being built, the lifetime must be active
			if state == INSTRUCTION_STATE_BUILDING return true

			# If one of the usages is built, the lifetime must have started already
			if state == INSTRUCTION_STATE_BUILT {
				started = true
				stop
			}
		}

		# If the lifetime has not started, it can not be active
		if not started return false

		loop (i = 0, i < usages.size, i++) {
			# Since the lifetime has started, if any of the usages is not built, this lifetime must be active 
			if usages[i].state != INSTRUCTION_STATE_BUILT return true
		}

		return false
	}

	# Summary: Returns true if the lifetime is active and is not starting or ending
	is_only_active(): bool {
		started = false

		loop (i = 0, i < usages.size, i++) {
			# If one of the usages is built, the lifetime must have started already
			if usages[i].state == INSTRUCTION_STATE_BUILT {
				started = true
				stop
			}
		}

		# If the lifetime has not started, it can not be only active
		if not started return false

		loop (i = 0, i < usages.size, i++) {
			# Look for usage, which has not been built and is not being built
			if usages[i].state == INSTRUCTION_STATE_NOT_BUILT return true
		}

		return false
	}

	# Summary: Returns true if the lifetime is expiring
	is_deactivating(): bool {
		building = false

		loop (i = 0, i < usages.size, i++) {
			# Look for usage, which is being built
			if usages[i].state == INSTRUCTION_STATE_BUILDING {
				building = true
				stop
			}
		}

		# If none of usages is being built, the lifetime can not be expiring
		if not building return false

		loop (i = 0, i < usages.size, i++) {
			# If one of the usages is not built, the lifetime can not be expiring
			if usages[i].state == INSTRUCTION_STATE_NOT_BUILT return false
		}

		return true
	}
}

Result {
	value: Handle
	format: large
	lifetime: Lifetime
	size => to_bytes(format)

	init(value: Handle, format: large) {
		this.value = value
		this.format = format
		this.lifetime = Lifetime()
	}

	init() {
		this.value = Handle()
		this.format = SYSTEM_FORMAT
		this.lifetime = Lifetime()
	}

	is_active => lifetime.is_active()
	is_only_active => lifetime.is_only_active()
	is_deactivating => lifetime.is_deactivating()

	register => value.(RegisterHandle).register

	is_releasable(unit: Unit): bool {
		return unit.is_variable_value(this)
	}

	is_expression => value.type == HANDLE_EXPRESSION
	is_constant => value.type == HANDLE_CONSTANT
	is_standard_register => value.type == HANDLE_REGISTER
	is_media_register => value.type == HANDLE_MEDIA_REGISTER
	is_any_register => value.type == HANDLE_REGISTER or value.type == HANDLE_MEDIA_REGISTER
	is_memory_address => value.type == HANDLE_MEMORY
	is_modifier => value.type == HANDLE_MODIFIER
	is_empty => value.type == HANDLE_NONE

	is_stack_variable => value.instance == INSTANCE_STACK_VARIABLE
	is_data_section_handle => value.instance == INSTANCE_DATA_SECTION or value.instance == INSTANCE_CONSTANT_DATA_SECTION
	is_stack_allocation => value.instance == INSTANCE_STACK_ALLOCATION

	is_unsigned => is_unsigned(format)

	use(instruction: Instruction): _ {
		contains = false

		loop usage in lifetime.usages {
			if usage != instruction continue
			contains = true
			stop
		}

		if not contains { lifetime.usages.add(instruction) }

		value.use(instruction)
	}

	use(instructions: List<Instruction>): _ {
		loop instruction in instructions { use(instruction) }
	}
}

Scope {
	constant ENTRY = '.entry'

	unit: Unit
	id: String
	index: large

	variables: Map<Variable, Result> = Map<Variable, Result>()
	inputs: Map<Variable, Result> = Map<Variable, Result>()
	outputs: Map<Variable, bool> = Map<Variable, bool>()

	inputter: RequireVariablesInstruction
	outputter: RequireVariablesInstruction

	init(unit: Unit, id: String) {
		this.unit = unit
		this.id = id
		this.index = unit.scopes.size
		this.inputter = RequireVariablesInstruction(unit, true)
		this.outputter = RequireVariablesInstruction(unit, false)

		# Register this scope
		unit.scopes[id] = this

		enter()

		unit.add(inputter)
	}

	set_or_create_input(variable: Variable, handle: Handle, format: large): Result {
		if not variable.is_predictable abort('Unpredictable variable can not be an input')

		handle = handle.finalize()
		input = none as Result

		if inputs.contains_key(variable) {
			input = inputs[variable]
			input.value = handle
			input.format = format
		}
		else {
			input = Result(handle, format)
			inputs.add(variable, input)
		}

		# Update the current handle to the variable
		variables[variable] = input

		# If the input is a register, the input value must be attached there
		if input.value.instance == INSTANCE_REGISTER {
			input.value.(RegisterHandle).register.value = input
		}

		return input
	}

	# Summary: Assigns a register or a stack address for the specified parameter depending on the situation
	receive_parameter(standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, parameter: Variable): _ {
		if parameter.type.is_pack {
			proxies = common.get_pack_proxies(parameter)

			loop proxy in proxies {
				receive_parameter(standard_parameter_registers, decimal_parameter_registers, proxy)
			}

			return
		}

		register = none as Register

		if parameter.type.format == FORMAT_DECIMAL {
			if decimal_parameter_registers.size > 0 { register = decimal_parameter_registers.pop_or(none as Register) }
		}
		else {
			if standard_parameter_registers.size > 0 { register = standard_parameter_registers.pop_or(none as Register) }
		}

		add_input(parameter)

		if register != none {
			register.value = set_or_create_input(parameter, RegisterHandle(register), parameter.type.get_register_format())
		}
		else {
			set_or_create_input(parameter, references.create_variable_handle(unit, parameter, ACCESS_WRITE), parameter.type.get_register_format())
		}
	}

	add_input(variable: Variable): Result {
		# If the variable is already in the input list, do nothing
		if inputs.contains_key(variable) return inputs[variable]

		# Create a placeholder handle for the variable
		handle = Handle()
		handle.format = variable.type.get_register_format()

		input = set_or_create_input(variable, Handle(), handle.format)
		inputter.dependencies.add(input)
		input.lifetime.usages.add(inputter)

		return input
	}

	add_output(variable: Variable, value: Result): _ {
		# If the variable is already in the output list, do nothing
		if outputs.contains_key(variable) return

		outputter.dependencies.add(value)
		value.lifetime.usages.add(outputter)

		# Register the variable as an output
		outputs[variable] = true
	}

	enter(): _ {
		# Exit the current scope before entering the new one
		if unit.scope !== none unit.scope.exit()

		# Reset variable data
		variables.clear()

		# Switch the current unit scope to be this scope
		unit.scope = this

		# Reset all registers
		loop register in unit.non_reserved_registers {
			register.reset()
		}

		# Set the inputs as initial values for the corresponding variables
		loop input in inputs {
			variable = input.key
			result = input.value

			# Reset the input value
			result.value = Handle()
			result.format = variable.type.get_register_format()

			variables[variable] = result
		}

		if id == ENTRY and not settings.is_debugging_enabled {
			# Move all parameters to their expected registers since this is the first scope
			decimal_parameter_registers = calls.get_decimal_parameter_registers(unit)
			standard_parameter_registers = calls.get_standard_parameter_registers(unit)

			if unit.self !== none {
				receive_parameter(standard_parameter_registers, decimal_parameter_registers, unit.self)
			}

			loop parameter in unit.function.parameters {
				receive_parameter(standard_parameter_registers, decimal_parameter_registers, parameter)
			}
		}
	}

	exit(): _ {
		if unit.mode == UNIT_MODE_ADD {
			unit.add(outputter)
		}
	}
}

UNIT_MODE_NONE = 0
UNIT_MODE_ADD = 1
UNIT_MODE_BUILD = 2

pack VariableState {
	variable: Variable
	handle: Handle

	shared create(variable: Variable, result: Result): VariableState {
		copy = result.value.finalize()
		copy.format = result.format

		return pack { variable: variable, handle: copy } as VariableState
	}
}

Unit {
	function: FunctionImplementation
	scope: Scope
	indexer: Indexer = Indexer()
	self: Variable

	registers: List<Register> = List<Register>()
	standard_registers: List<Register> = List<Register>()
	media_registers: List<Register> = List<Register>()
	volatile_registers: List<Register> = List<Register>()
	volatile_standard_registers: List<Register> = List<Register>()
	volatile_media_registers: List<Register> = List<Register>()
	non_volatile_registers: List<Register> = List<Register>()
	non_volatile_standard_registers: List<Register> = List<Register>()
	non_volatile_media_registers: List<Register> = List<Register>()
	non_reserved_registers: List<Register> = List<Register>()

	instructions: List<Instruction> = List<Instruction>()
	states: Map<String, List<VariableState>> = Map<String, List<VariableState>>()
	anchor: Instruction
	position: large
	stack_offset: large = 0
	builder: StringBuilder
	mode: large

	# All scopes indexed by their id
	scopes: Map<String, Scope> = Map<String, Scope>()

	# List of scopes (value) that enter the scope indicated by the id of a scope (key)
	arrivals: Map<String, List<Scope>> = Map<String, List<Scope>>()

	init(function: FunctionImplementation) {
		this.function = function
		this.self = function.get_self_pointer()
		this.builder = StringBuilder()

		if settings.is_x64 { load_architecture_x64() }
		else { load_architecture_arm64() }

		loop register in registers { if not register.is_media_register and not register.is_reserved { standard_registers.add(register) } }
		loop register in registers { if register.is_media_register and not register.is_reserved { media_registers.add(register) } }

		loop register in registers { if register.is_volatile and not register.is_reserved { volatile_registers.add(register) } }
		loop register in volatile_registers { if not register.is_media_register { volatile_standard_registers.add(register) } }
		loop register in volatile_registers { if register.is_media_register { volatile_media_registers.add(register) } }

		loop register in registers { if not register.is_volatile and not register.is_reserved { non_volatile_registers.add(register) } }
		loop register in non_volatile_registers { if not register.is_media_register { non_volatile_standard_registers.add(register) } }
		loop register in non_volatile_registers { if register.is_media_register { non_volatile_media_registers.add(register) } }

		non_reserved_registers.add_all(volatile_registers)
		non_reserved_registers.add_all(non_volatile_registers)
	}

	init() {
		this.function = none as FunctionImplementation
		this.self = none as Variable
		this.builder = StringBuilder()

		if settings.is_x64 { load_architecture_x64() }
		else { load_architecture_arm64() }

		loop register in registers { if not register.is_media_register and not register.is_reserved { standard_registers.add(register) } }
		loop register in registers { if register.is_media_register and not register.is_reserved { media_registers.add(register) } }

		loop register in registers { if register.is_volatile and not register.is_reserved { volatile_registers.add(register) } }
		loop register in volatile_registers { if not register.is_media_register { volatile_standard_registers.add(register) } }
		loop register in volatile_registers { if register.is_media_register { volatile_media_registers.add(register) } }

		loop register in registers { if not register.is_volatile and not register.is_reserved { non_volatile_registers.add(register) } }
		loop register in non_volatile_registers { if not register.is_media_register { non_volatile_standard_registers.add(register) } }
		loop register in non_volatile_registers { if register.is_media_register { non_volatile_media_registers.add(register) } }

		non_reserved_registers.add_all(volatile_registers)
		non_reserved_registers.add_all(non_volatile_registers)
	}

	load_architecture_x64(): _ {
		volatility_flag = REGISTER_VOLATILE
		if settings.is_target_windows { volatility_flag = REGISTER_NONE }

		base_pointer_flags = REGISTER_NONE
		if settings.is_debugging_enabled { base_pointer_flags = REGISTER_RESERVED }

		registers.add(Register(platform.x64.RAX, "rax eax ax al", REGISTER_VOLATILE | REGISTER_RETURN | REGISTER_NUMERATOR))
		registers.add(Register(platform.x64.RBX, "rbx ebx bx bl", REGISTER_NONE))
		registers.add(Register(platform.x64.RCX, "rcx ecx cx cl", REGISTER_VOLATILE | REGISTER_SHIFT))
		registers.add(Register(platform.x64.RDX, "rdx edx dx dl", REGISTER_VOLATILE | REGISTER_REMAINDER))
		registers.add(Register(platform.x64.RSI, "rsi esi si sil", volatility_flag))
		registers.add(Register(platform.x64.RDI, "rdi edi di dil", volatility_flag))
		registers.add(Register(platform.x64.RBP, "rbp ebp bp bpl", base_pointer_flags))
		registers.add(Register(platform.x64.RSP, "rsp esp sp spl", REGISTER_RESERVED | REGISTER_STACK_POINTER))

		registers.add(Register(platform.x64.YMM0, "ymm0 xmm0 xmm0 xmm0 xmm0", REGISTER_MEDIA | REGISTER_VOLATILE | REGISTER_DECIMAL_RETURN))
		registers.add(Register(platform.x64.YMM1, "ymm1 xmm1 xmm1 xmm1 xmm1", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM2, "ymm2 xmm2 xmm2 xmm2 xmm2", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM3, "ymm3 xmm3 xmm3 xmm3 xmm3", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM4, "ymm4 xmm4 xmm4 xmm4 xmm4", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM5, "ymm5 xmm5 xmm5 xmm5 xmm5", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM6, "ymm6 xmm6 xmm6 xmm6 xmm6", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM7, "ymm7 xmm7 xmm7 xmm7 xmm7", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM8, "ymm8 xmm8 xmm8 xmm8 xmm8", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM9, "ymm9 xmm9 xmm9 xmm9 xmm9", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM10, "ymm10 xmm10 xmm10 xmm10 xmm10", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM11, "ymm11 xmm11 xmm11 xmm11 xmm11", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM12, "ymm12 xmm12 xmm12 xmm12 xmm12", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM13, "ymm13 xmm13 xmm13 xmm13 xmm13", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM14, "ymm14 xmm14 xmm14 xmm14 xmm14", REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(platform.x64.YMM15, "ymm15 xmm15 xmm15 xmm15 xmm15", REGISTER_MEDIA | REGISTER_VOLATILE))

		registers.add(Register(platform.x64.R8, "r8 r8d r8w r8b", REGISTER_VOLATILE))
		registers.add(Register(platform.x64.R9, "r9 r9d r9w r9b", REGISTER_VOLATILE))
		registers.add(Register(platform.x64.R10, "r10 r10d r10w r10b", REGISTER_VOLATILE))
		registers.add(Register(platform.x64.R11, "r11 r11d r11w r11b", REGISTER_VOLATILE))
		registers.add(Register(platform.x64.R12, "r12 r12d r12w r12b", REGISTER_NONE))
		registers.add(Register(platform.x64.R13, "r13 r13d r13w r13b", REGISTER_NONE))
		registers.add(Register(platform.x64.R14, "r14 r14d r14w r14b", REGISTER_NONE))
		registers.add(Register(platform.x64.R15, "r15 r15d r15w r15b", REGISTER_NONE))
	}

	load_architecture_arm64(): _ {

	}

	# Summary:
	# Requests a value for the specified variable from all scopes that arrive to the specified scope.
	# Returns the input value for the specified variable.
	require_variable_from_arrivals(variable: Variable, scope: Scope): Result {
		# If we end up here, it means the specified scope does not have a value for the specified variable.
		# We need to require the variable from all scopes that arrive to specified one:
		input = scope.add_input(variable)

		if arrivals.contains_key(scope.id) {
			loop arrival in arrivals[scope.id] {
				require_variable(variable, arrival)
			}
		}

		return input
	}

	# Summary:
	# Requests a value for the specified variable from the specified scope.
	# If the specified scope does not have a value for the specified variable, it will be required from all scopes that arrive to it.
	require_variable(variable: Variable, scope: Scope): _ {
		# If the variable is already outputted, no need to do anything
		if scope.outputs.contains_key(variable) return

		# If the scope assigns a value for the specified variable, we can output it from the scope
		# In other words, no need to require the variable from other scopes entering the specified scope, since it has its own value for the variable
		if scope.variables.contains_key(variable) {
			scope.add_output(variable, scope.variables[variable])
			return
		}

		input = require_variable_from_arrivals(variable, scope)
		scope.add_output(variable, input)
	}

	# Summary: Tries to return the current value of the specified variable
	get_variable_value(variable: Variable): Result {
		if scope === none return none as Result

		# If the current scope has a value for the specified variable, we can return it
		if scope.variables.contains_key(variable) {
			return scope.variables[variable]
		}

		require(mode !== UNIT_MODE_BUILD, 'Can not require variable from other scopes in build mode')

		return require_variable_from_arrivals(variable, scope)
	}

	add_arrival(id: String, scope: Scope): _ {
		if arrivals.contains_key(id) {
			arrivals[id].add(scope)
		}
		else {
			arrivals[id] = [ scope ]
		}
	}

	add(instruction: JumpInstruction): _ {
		is_conditional = instruction.is_conditional
		destination_scope_id = instruction.label.name
		next_scope_id = get_next_scope()
		current_scope = scope

		# Arrive to the destination scope from the current scope
		add_arrival(destination_scope_id, current_scope)

		# Merge with the next scope as well, if we can fall through
		if is_conditional {
			add(LabelMergeInstruction(this, destination_scope_id, next_scope_id))
		}
		else {
			add(LabelMergeInstruction(this, destination_scope_id))
		}

		add(instruction, false)

		next_scope = Scope(this, next_scope_id)
		add(EnterScopeInstruction(this, next_scope_id))

		# If we can fall through the jump instruction, the current scope can arrive to the next scope
		if is_conditional {
			add_arrival(next_scope.id, current_scope)
		}
	}

	add(instruction: ReturnInstruction): _ {
		add(instruction, false)

		next_scope_id = get_next_scope()
		next_scope = Scope(this, next_scope_id)
		add(EnterScopeInstruction(this, next_scope_id))
	}

	add(instruction: LabelInstruction): _ {
		next_scope_id = instruction.label.name
		previous_scope = scope

		# Merge with the next scope, since we are falling through
		add(LabelMergeInstruction(this, next_scope_id))

		# Create the next scope
		next_scope = Scope(this, next_scope_id)
		add(instruction, false)
		add(EnterScopeInstruction(this, next_scope_id))

		# Arrive to the next scope from the previous scope
		add_arrival(next_scope_id, previous_scope)
	}

	add(instruction: Instruction): _ {
		if instruction.type === INSTRUCTION_JUMP return add(instruction as JumpInstruction)
		if instruction.type === INSTRUCTION_LABEL return add(instruction as LabelInstruction)
		if instruction.type === INSTRUCTION_RETURN return add(instruction as ReturnInstruction)

		return add(instruction, false)
	}

	add(instruction: Instruction, after: bool): _ {
		if after and (instruction.type === INSTRUCTION_JUMP or instruction.type === INSTRUCTION_LABEL or instruction.type === INSTRUCTION_RETURN) {
			abort('Can not add the instruction after the current instruction')
		}

		if mode == UNIT_MODE_ADD {
			instructions.add(instruction)
			anchor = instruction
		}
		else after {
			# TODO: Instructions could form a linked list?
			instructions.insert(position + 1, instruction)
		}
		else {
			instructions.insert(position, instruction)
		}

		instruction.reindex()

		instruction.scope = scope
		instruction.result.use(instruction)

		if mode != UNIT_MODE_BUILD or after return

		destination = anchor
		anchor = instruction

		instruction.build()

		# Return to the previous instruction by iterating forward, since it must be ahead
		loop (anchor != destination) {
			if anchor.state != INSTRUCTION_STATE_BUILT {
				iterator = anchor
				iterator.build()
			} 

			anchor = instructions[++position]
		}
	}

	write(instruction: String): _ {
		builder.append(instruction)
		builder.append(`\n`)
	}

	release(register: Register): Register {
		value = register.value
		if value == none return register

		if value.is_releasable(this) {
			loop iterator in scope.variables {
				if iterator.value != value continue

				# Get the default handle of the variable
				handle = references.create_variable_handle(this, iterator.key, ACCESS_WRITE)

				# The handle must be a memory handle, otherwise anything can happen
				if handle.type != HANDLE_MEMORY { handle = TemporaryMemoryHandle(this) }

				destination = Result(handle, iterator.key.type.format)

				instruction = MoveInstruction(this, destination, value)
				instruction.description = "Releases the value into local memory"
				instruction.type = MOVE_RELOCATE

				add(instruction)
				stop
			}
		}
		else {
			destination = Result(TemporaryMemoryHandle(this), value.format)
			instruction = MoveInstruction(this, destination, value)
			instruction.description = "Releases the value into local memory"
			instruction.type = MOVE_RELOCATE

			add(instruction)
		}

		# Now the register is ready for use
		register.reset()
		return register
	}

	# Summary: Retrieves the next available register, releasing a register to memory if necessary
	get_next_register(): Register {
		# Try to find the next fully available volatile register
		loop register in volatile_standard_registers { if register.is_available() return register }
		# Try to find the next fully available non-volatile register
		loop register in non_volatile_standard_registers { if register.is_available() return register }
		# Try to find the next volatile register which contains a value that has a corresponding memory location
		loop register in volatile_standard_registers { if register.is_releasable(this) return release(register) }
		# Try to find the next non-volatile register which contains a value that has a corresponding memory location
		loop register in non_volatile_standard_registers { if register.is_releasable(this) return release(register) }

		# Since all registers contain intermediate values, one of them must be released to a temporary memory location
		# NOTE: Some registers may be locked which prevents them from being used, but not all registers should be locked, otherwise something very strange has happened

		# Find the next register which is not locked
		loop register in standard_registers {
			if register.is_locked continue
			return release(register)
		}

		# NOTE: This usually happens when there is a flaw in the algorithm and the compiler does not know how to handle a value for example
		abort('All registers were locked or reserved, this should not happen')
	}

	# Summary: Retrieves the next available media register, releasing a media register to memory if necessary
	get_next_media_register(): Register {
		# Try to find the next fully available media register
		loop register in media_registers { if register.is_available() return register }
		# Try to find the next media register which contains a value that has a corresponding memory location
		loop register in media_registers { if register.is_releasable(this) return release(register) }

		# Find the next media register which is not locked
		loop register in media_registers {
			if register.is_locked continue
			return release(register)
		}

		# NOTE: This usually happens when there is a flaw in the algorithm and the compiler does not know how to handle a value for example
		abort('All media registers were locked or reserved, this should not happen')
	}

	# Summary: Tries to find an available standard register without releasing a register to memory
	get_next_register_without_releasing(): Register {
		loop register in volatile_standard_registers { if register.is_available() return register }
		loop register in non_volatile_standard_registers { if register.is_available() return register }
		return none as Register
	}

	# Summary: Tries to find an available register without releasing a register to memory, while excluding the specified registers
	get_next_register_without_releasing(denylist: List<Register>): Register {
		loop register in volatile_standard_registers {
			if not denylist.contains(register) and register.is_available() return register
		}

		loop register in non_volatile_standard_registers {
			if not denylist.contains(register) and register.is_available() return register
		}

		return none as Register
	}

	# Summary: Tries to find an available media register without releasing a register to memory
	get_next_media_register_without_releasing(): Register {
		loop register in media_registers { if register.is_available() return register }
		return none as Register
	}

	# Summary: Tries to find an available media register without releasing a register to memory, while excluding the specified registers
	get_next_media_register_without_releasing(denylist: List<Register>): Register {
		loop register in media_registers {
			if not denylist.contains(register) and register.is_available() return register
		}

		return none as Register
	}

	get_next_non_volatile_register(media_register: bool, release: bool): Register {
		loop register in non_volatile_registers { if register.is_available() and register.is_media_register == media_register return register }
		if not release return none as Register

		loop register in non_volatile_registers {
			if register.is_releasable(this) and register.is_media_register == media_register {
				release(register)
				return register
			}
		}

		return none as Register
	}

	get_next_string(): String {
		return function.get_fullname() + '_S' + to_string(indexer.string)
	}

	get_next_label(): Label {
		return Label(function.get_fullname() + '_L' + to_string(indexer.label))
	}

	get_next_constant(): String {
		return function.get_fullname() + '_C' + to_string(indexer.constant_value)
	}

	get_next_identity(): String {
		return function.identity + '.' + to_string(indexer.identity)
	}

	get_next_scope(): String {
		return to_string(indexer.scope)
	}

	get_stack_pointer(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_STACK_POINTER) return register }
		abort('Architecture did not have stack pointer register')
	}

	get_standard_return_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_RETURN) return register }
		abort('Architecture did not have standard return register')
	}

	get_decimal_return_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_DECIMAL_RETURN) return register }
		abort('Architecture did not have decimal return register')
	}

	get_numerator_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_NUMERATOR) return register }
		abort('Architecture did not have numerator register')
	}

	get_remainder_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_REMAINDER) return register }
		abort('Architecture did not have remainder register')
	}

	get_shift_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_SHIFT) return register }
		abort('Architecture did not have shift register')
	}

	get_return_address_register(): Register {
		loop register in registers { if has_flag(register.flags, REGISTER_RETURN_ADDRESS) return register }
		abort('Architecture did not have return address register')
	}

	# Summary: Returns whether a value has been assigned to the specified variable
	is_initialized(variable: Variable) {
		return scope != none and scope.variables.contains_key(variable)
	}

	# Summary: Updates the value of the specified variable in the current scope
	set_variable_value(variable: Variable, value: Result): _ {
		if scope == none abort('Unit did not have an active scope')
		scope.variables[variable] = value
	}

	# Summary: Returns whether any variables owns the specified value
	is_variable_value(result: Result): bool {
		if scope == none return false
		loop iterator in scope.variables { if iterator.value == result return true }
		return false
	}

	# Summary: Returns the variable which owns the specified value, if it is owned by any
	get_value_owner(value: Result): Variable {
		if scope == none return none as Variable

		loop iterator in scope.variables {
			if iterator.value == value return iterator.key
		}

		return none as Variable
	}

	add_debug_position(node: Node): bool {
		return add_debug_position(node.start)
	}

	add_debug_position(position: Position): bool {
		if not settings.is_debugging_enabled return true
		if position === none return false

		add(DebugBreakInstruction(this, position))

		return true
	}

	string(): String {
		return builder.string()
	}
}

namespace assembler

ParameterAligner {
	standard_registers: large
	decimal_registers: large
	position: large = 0

	init(position: large) {
		this.standard_registers = calls.get_standard_parameter_register_count()
		this.decimal_registers = calls.get_decimal_parameter_register_count()
		this.position = position
	}

	# Summary: Consumes the specified type while taking into account if it is a pack
	align(parameter: Variable): _ {
		type = parameter.type

		if type.is_pack {
			proxies = common.get_pack_proxies(parameter)
			loop proxy in proxies { align(proxy) }
			return
		}

		# First, try to consume a register for the parameter
		if (type.format == FORMAT_DECIMAL and decimal_registers-- > 0) or (type.format != FORMAT_DECIMAL and standard_registers-- > 0) {
			# On Windows even though the first parameters are passed in registers, they still need have their own stack alignment (shadow space)
			if not settings.is_target_windows return
		}

		# Normal parameters consume one stack unit
		parameter.alignment = position
		parameter.is_aligned = true
		position += SYSTEM_BYTES
	}

	# Summary: Aligns the specified parameters
	align(parameters: List<Variable>): _ {
		loop parameter in parameters { align(parameter) }
	}
}

# Summary: Goes through the specified instructions and returns all non-volatile registers
get_all_used_non_volatile_registers(instructions: List<Instruction>): List<Register> {
	registers = List<Register>()

	loop instruction in instructions {
		loop parameter in instruction.parameters {
			if not parameter.is_any_register continue

			register = parameter.value.(RegisterHandle).register
			if register.is_volatile or registers.contains(register) continue

			registers.add(register)
		}
	}

	return registers
}

get_all_handles(results: List<Result>): List<Handle> {
	handles = List<Handle>()

	loop result in results {
		handles.add(result.value)
		handles.add_all(get_all_handles(result.value.get_inner_results()))
	}

	return handles
}

get_all_handles(instructions: List<Instruction>): List<Handle> {
	handles = List<Handle>()

	loop instruction in instructions {
		loop parameter in instruction.parameters {
			handles.add(parameter.value)
			handles.add_all(get_all_handles(parameter.value.get_inner_results()))
		}
	}

	return handles
}

# Summary: Collects all variables which are saved using stack memory handles
get_all_saved_local_variables(handles: List<Handle>): List<Variable> {
	variables = List<Variable>()

	loop handle in handles {
		if handle.instance != INSTANCE_STACK_VARIABLE continue
		variables.add(handle.(StackVariableHandle).variable)
	}

	return variables.distinct()
}

# Summary: Collects all temporary memory handles from the specified handle list
get_all_temporary_handles(handles: List<Handle>): List<TemporaryMemoryHandle> {
	temporary_handles = List<TemporaryMemoryHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_TEMPORARY_MEMORY temporary_handles.add(handle as TemporaryMemoryHandle)
	}

	return temporary_handles
}

# Summary: Collects all stack allocation handles from the specified handle list
get_all_stack_allocation_handles(handles: List<Handle>): List<StackAllocationHandle> {
	stack_allocation_handles = List<StackAllocationHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_STACK_ALLOCATION stack_allocation_handles.add(handle as StackAllocationHandle)
	}

	return stack_allocation_handles
}

# Summary: Computes the amount of required stack memory from the specified stack allocation handles
compute_allocated_memory_by_handles<T>(handles: List<T>): large {
	result = 0
	allocated = Map<String, bool>()

	loop handle in handles {
		if allocated.contains_key(handle.identity) continue
		allocated[handle.identity] = true

		result += handle.bytes
	}

	return result
}

# Summary: Collects all constant data section handles from the specified handle list
get_all_constant_data_section_handles(handles: List<Handle>): List<ConstantDataSectionHandle> {
	constant_data_section_handles = List<ConstantDataSectionHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_CONSTANT_DATA_SECTION constant_data_section_handles.add(handle as ConstantDataSectionHandle)
	}

	return constant_data_section_handles
}

align_function(function: FunctionImplementation): _ {
	parameters = List<Variable>(function.parameters)

	# Align the self pointer as well, if it exists
	self_pointer_key = String(SELF_POINTER_IDENTIFIER)

	if function.variables.contains_key(self_pointer_key) {
		parameters.insert(0, function.variables[self_pointer_key])
	}
	else {
		self_pointer_key = String(LAMBDA_SELF_POINTER_IDENTIFIER)

		if function.variables.contains_key(self_pointer_key) {
			parameters.insert(0, function.variables[self_pointer_key])
		}
	}

	# Return address is passed before the first parameter on x64
	initial_position = 0
	if settings.is_x64 { initial_position = SYSTEM_BYTES }

	parameter_aligner = ParameterAligner(initial_position)
	parameter_aligner.align(parameters)
}

align(context: Context): _ {
	# Align all functions
	functions = common.get_all_function_implementations(context)

	loop function in functions {
		align_function(function)
	}

	# Align all types
	types = common.get_all_types(context)

	loop type in types {
		common.align_members(type)
	}
}

# Summary:
# Align all used local packs and their proxies sequentially.
# Returns the stack position after aligning.
# NOTE: Available only in debugging mode, because in optimized builds pack proxies might not be available
align_packs_for_debugging(local_variables: List<Variable>, position: large): large {
	# Do nothing if debugging mode is not enabled
	if not settings.is_debugging_enabled return position

	# Find all local variables that are packs
	local_packs = local_variables.filter(i -> i.type.is_pack)

	loop local_pack in local_packs {
		# Align the whole pack if it is used
		proxies = common.get_pack_proxies(local_pack)
		used = false

		loop proxy in proxies {
			if not local_variables.contains(proxy) continue
			used = true
			stop
		}

		if not used continue

		# Allocate stack memory for the whole pack
		position -= local_pack.type.allocation_size
		local_pack.alignment = position
		local_pack.is_aligned = true

		# Keep track of the position inside the pack, so that we can align the members properly
		subposition = position

		# Align the pack proxies inside the allocated stack memory
		loop proxy in proxies {
			proxy.alignment = subposition
			proxy.is_aligned = true
			subposition += proxy.type.allocation_size

			# Remove the proxy from the variable list that will be aligned later
			local_variables.remove(proxy)
		}
	}

	return position
}

# Summary: Align all used local variables and allocate memory for other kinds of local memory such as temporary handles and stack allocation handles
align_local_memory(local_variables: List<Variable>, temporary_handles: List<TemporaryMemoryHandle>, stack_allocation_handles: List<StackAllocationHandle>, top: normal): _ {
	position = -top

	position = align_packs_for_debugging(local_variables, position)

	# Used local variables:
	loop variable in local_variables {
		if variable.is_aligned continue

		position -= variable.type.allocation_size
		variable.alignment = position
		variable.is_aligned = true
	}

	# Temporary handles:
	loop (temporary_handles.size > 0) {
		handle = temporary_handles[]
		identity = handle.identity
		position -= handle.size

		# Find all instances of this temporary handle and align them to the same position, then remove them from the list
		loop (i = temporary_handles.size - 1, i >= 0, i--) {
			handle = temporary_handles[i]
			if not (handle.identity == identity) continue

			handle.offset = position
			temporary_handles.remove_at(i)
		}
	}

	# Stack allocation handles:
	loop (stack_allocation_handles.size > 0) {
		handle = stack_allocation_handles[]
		identity = handle.identity
		position -= handle.bytes

		# Find all instances of this stack allocation handle and align them to the same position, then remove them from the list
		loop (i = stack_allocation_handles.size - 1, i >= 0, i--) {
			handle = stack_allocation_handles[i]
			if not (handle.identity == identity) continue

			handle.offset = position
			stack_allocation_handles.remove_at(i)
		}
	}
}

# Summary: Allocates a data section identifier for each identical constant data section handle
allocate_constant_data_section_handles(unit: Unit, constant_data_section_handles: List<ConstantDataSectionHandle>): _ {
	loop (i = 0, i < constant_data_section_handles.size, i++) {
		handle = constant_data_section_handles[i]
		identifier = handle.identifier

		data_section_identifier = unit.get_next_constant()
		handle.identifier = data_section_identifier

		# Find all instances of this data section handle and give them the data section identifier as well
		loop (j = constant_data_section_handles.size - 1, j > i, j--) {
			handle = constant_data_section_handles[i]
			if not (handle.identifier == identifier) continue

			handle.identifier = data_section_identifier
			constant_data_section_handles.remove_at(j)
		}
	}
}

# Summary: Creates the virtual function entry label, which is used to convert the passed self pointer to a suitable type
add_virtual_function_header(unit: Unit, implementation: FunctionImplementation, fullname: String): _ {
	unit.add(LabelInstruction(unit, Label(fullname + Mangle.VIRTUAL_FUNCTION_POSTFIX)))

	# Do not try to convert the self pointer, if it is not used
	if unit.self.usages.size == 0 return

	# Cast the self pointer to the type, which contains the implementation of the virtual function
	from = implementation.virtual_function.find_type_parent()
	to = implementation.find_type_parent()

	# NOTE: The type 'from' must be one of the subtypes of 'to'
	if to.get_supertype_base_offset(from) has not alignment or alignment < 0 abort('Could not add virtual function header')

	if alignment != 0 {
		self = references.get_variable(unit, unit.self, ACCESS_WRITE)
		offset = GetConstantInstruction(unit, alignment, false, false).add()

		# Convert the self pointer to the type 'to' by offsetting it by the alignment
		unit.add(SubtractionInstruction(unit, self, offset, SYSTEM_SIGNED, true))
	}
}

# Summary: Finds sequential debug break instructions and separates them using NOP-instructions
separate_debug_breaks(unit: Unit, instructions: List<Instruction>): _ {
	i = 0

	loop (i < instructions.size) {
		# Find the next debug break instruction
		if instructions[i].type != INSTRUCTION_DEBUG_BREAK {
			i++
			continue
		}

		# Find the next hardware instruction or debug break instruction
		j = i + 1

		loop (j < instructions.size, j++) {
			instruction = instructions[j]

			if instruction.type == INSTRUCTION_LABEL continue
			if instruction.type == INSTRUCTION_DEBUG_BREAK or not instruction.is_abstract stop
		}

		# We need to insert a NOP-instruction in the following cases:
		# - We reached the end of the instruction list
		# - We found a debug break instruction
		# In the above cases, there are no hardware instructions where the debugger could stop after the debug break instruction.
		if j == instructions.size or instructions[j].type == INSTRUCTION_DEBUG_BREAK {
			instructions.insert(i + 1, NoOperationInstruction(unit))
			j++ # Update the index, because we inserted a new instruction
		}

		i = j
	}
}

# Summary: Removes unreachable instructions from the specified instructions.
remove_unreachable_instructions(instructions: List<Instruction>) {
	loop (i = 0, i < instructions.size, i++) {
		instruction = instructions[i]

		# Find the next unconditional jump or return instruction
		if instruction.type != INSTRUCTION_RETURN and (instruction.type != INSTRUCTION_JUMP or instruction.(JumpInstruction).is_conditional) continue

		# Find the index j of the next label
		j = i + 1

		loop (j < instructions.size, j++) {
			if instructions[j].type == INSTRUCTION_LABEL stop
		}

		# Instructions from i + 1 to j will never execute, they can be removed
		instructions.remove_all(i + 1, j)
	}
}

# Summary: Remove unnecessary jumps from the specified instructions.
remove_unnecessary_jumps(instructions: List<Instruction>) {
	# Look for jumps whose destination label is the next instruction
	loop (i = 0, i < instructions.size - 1, i++) {
		# Find the next jump instruction
		instruction = instructions[i]
		if instruction.type != INSTRUCTION_JUMP continue

		# The next instruction must be a label
		next = instructions[i + 1]
		if next.type != INSTRUCTION_LABEL continue

		destination = instruction.(JumpInstruction).label

		# If the destination is the next instruction, the jump can be removed
		if destination !== next.(LabelInstruction).label {
			i++ # Skip the label instruction
			continue
		}

		# Remove the jump instruction
		instructions.remove_at(i)
	}
}

# Summary: Performs some processing to the specified instructions such as removing unreachable instructions.
postprocess(instructions: List<Instruction>) {
	remove_unreachable_instructions(instructions)
	remove_unnecessary_jumps(instructions)
}

# Summary: Connects the specified scope to the destination scope.
connect_backwards_jump(unit: Unit, from: Scope, to: Scope): _ {
	# Require the input variables of the destination scope in the arrival scope
	loop iterator in to.inputs {
		unit.require_variable(iterator.key, from)
	}
}

# Summary:
# Finds all scopes that arrive to scopes before them and connects them.
connect_backwards_jumps(unit: Unit): _ {
	loop i in unit.arrivals {
		destination = unit.scopes[i.key]
		arrivals = i.value

		loop arrival in arrivals {
			if arrival.index < destination.index continue
			connect_backwards_jump(unit, arrival, destination)
		}
	}
}

get_text_section(implementation: FunctionImplementation): AssemblyBuilder {
	builder = AssemblyBuilder()

	fullname = implementation.get_fullname()

	# Ensure this function is visible to other units
	builder.write(EXPORT_DIRECTIVE)
	builder.write(` `)
	builder.write_line(fullname)
	builder.export_symbol(fullname)

	unit = Unit(implementation)
	unit.mode = UNIT_MODE_ADD

	scope = Scope(unit, String(Scope.ENTRY))

	# Update the variable usages before we start
	analysis.load_variable_usages(implementation)

	# Add virtual function header, if the implementation overrides a virtual function
	if implementation.virtual_function != none {
		builder.write(EXPORT_DIRECTIVE)
		builder.write(` `)
		builder.write(fullname)
		builder.write_line(Mangle.VIRTUAL_FUNCTION_POSTFIX)
		builder.export_symbol(fullname + Mangle.VIRTUAL_FUNCTION_POSTFIX)
		add_virtual_function_header(unit, implementation, fullname)
	}

	# Add the function name to the output as a label
	unit.add(LabelInstruction(unit, Label(fullname)))

	# Initialize this function
	unit.add(InitializeInstruction(unit))

	# Parameters are active from the start of the function, so they must be required now otherwise they would become active at their first usage
	parameters = List<Variable>(unit.function.parameters)

	if unit.self !== none {
		parameters.add(unit.self)
	}

	# Include pack proxies as well
	parameter_count = parameters.size

	loop (i = 0, i < parameter_count, i++) {
		parameter = parameters[i]
		if not parameter.type.is_pack continue

		parameters.add_all(common.get_pack_proxies(parameter))
	}

	if settings.is_debugging_enabled {
		calls.move_parameters_to_stack(unit)
	}

	builders.build(unit, implementation.node)

	# Connect scopes that jump backwards
	connect_backwards_jumps(unit)

	loop instruction in unit.instructions { instruction.reindex() }

	# Build:
	unit.scope = none as Scope
	unit.stack_offset = 0
	unit.mode = UNIT_MODE_BUILD

	# Reset all registers
	loop register in unit.registers { register.reset() }

	loop (unit.position = 0, unit.position < unit.instructions.size, unit.position++) {
		instruction = unit.instructions[unit.position]

		# All instructions must have a scope
		if instruction.scope == none abort('Missing instruction scope')

		unit.anchor = instruction

		# Switch between scopes
		if unit.scope != instruction.scope {
			instruction.scope.enter()
		}

		instruction.build()
	}

	# Reset the state after this simulation
	unit.mode = UNIT_MODE_NONE

	# Collect all instructions, which are not abstract
	instructions = List<Instruction>()

	loop instruction in unit.instructions {
		if instruction.is_abstract continue
		instructions.add(instruction)
	}

	all_handles = get_all_handles(instructions)
	local_variables = get_all_saved_local_variables(all_handles)
	temporary_handles = get_all_temporary_handles(all_handles)
	stack_allocation_handles = get_all_stack_allocation_handles(all_handles)
	constant_data_section_handles = get_all_constant_data_section_handles(all_handles)
	non_volatile_registers = get_all_used_non_volatile_registers(instructions)

	required_local_memory = 0

	loop local_variable in local_variables {
		if local_variable.is_aligned continue
		required_local_memory += local_variable.type.allocation_size
	}

	required_local_memory += compute_allocated_memory_by_handles<TemporaryMemoryHandle>(temporary_handles)
	required_local_memory += compute_allocated_memory_by_handles<StackAllocationHandle>(stack_allocation_handles)

	# Append a return instruction at the end if there is no return instruction present
	if instructions.size == 0 or instructions[instructions.size - 1].type != INSTRUCTION_RETURN {
		if settings.is_debugging_enabled and unit.function.metadata.end != none {
			instructions.add(DebugBreakInstruction(unit, unit.function.metadata.end))
		}

		instructions.add(ReturnInstruction(unit, none as Result, none as Type))
	}

	# If debug information is being generated, append a debug information label at the end
	if settings.is_debugging_enabled {
		end = LabelInstruction(unit, Label(Debug.get_end(unit.function).name))
		end.on_build()

		instructions.add(end)

		separate_debug_breaks(unit, instructions)
	}

	local_memory_top = 0

	# Build all initialization instructions
	loop instruction in instructions {
		if instruction.type != INSTRUCTION_INITIALIZE continue
		instruction.(InitializeInstruction).build(non_volatile_registers, required_local_memory)
		local_memory_top = instruction.(InitializeInstruction).local_memory_top
	}

	# The non-volatile registers must be recovered in reversed order
	non_volatile_registers.reverse()

	# Build all return instructions
	loop instruction in instructions {
		if instruction.type != INSTRUCTION_RETURN continue

		# Save the local memory size for later use
		unit.function.size_of_locals = unit.stack_offset - local_memory_top
		unit.function.size_of_local_memory = unit.function.size_of_locals + non_volatile_registers.size * SYSTEM_BYTES

		instruction.(ReturnInstruction).build(non_volatile_registers, local_memory_top)
	}

	# Align all used local variables and allocate memory for other kinds of local memory such as temporary handles and stack allocation handles
	align_local_memory(local_variables, temporary_handles, stack_allocation_handles, local_memory_top)

	# Allocate all constant data section handles
	allocate_constant_data_section_handles(unit, constant_data_section_handles)

	# Postprocess the instructions before giving them to the builder
	postprocess(instructions)

	file = unit.function.metadata.start.file

	if settings.is_assembly_output_enabled {
		loop instruction in instructions {
			instruction.finish()
		}

		builder.write(unit.string())

		# Add a directive, which tells the assembler to finish debugging information regarding the current function
		if settings.is_debugging_enabled builder.write_line(String(`.`) + AssemblyParser.DEBUG_END_DIRECTIVE)
	}

	builder.add(file, instructions)

	# Add a directive, which tells the assembler to finish debugging information regarding the current function
	builder.add(file, Instruction(unit, INSTRUCTION_DEBUG_END))

	# Export the generated constants as well
	builder.add(file, constant_data_section_handles.distinct())

	return builder
}

constant EXPORT_DIRECTIVE = '.export'
constant BYTE_ALIGNMENT_DIRECTIVE = '.balign'
constant POWER_OF_TWO_ALIGNMENT_DIRECTIVE = '.align'
constant CHARACTERS_ALLOCATION_DIRECTIVE = '.characters'
constant BYTE_ZERO_ALLOCATOR = '.zero'
constant SECTION_RELATIVE_DIRECTIVE = '.section_relative'
constant SECTION_DIRECTIVE = '.section'
constant TEXT_SECTION_DIRECTIVE = '.section .text'
constant DATA_SECTION_DIRECTIVE = '.section .data'
constant TEXT_SECTION_IDENTIFIER = 'text'
constant DATA_SECTION_IDENTIFIER = 'data'

get_default_entry_point(): String {
	if settings.is_target_windows return "main"
	return "_start"
}

add_linux_x64_header(entry_function_call: String): String {
	builder = StringBuilder()
	builder.append_line('.export _start')
	builder.append_line('_start:')
	builder.append_line('mov rdi, rsp')
	builder.append_line(entry_function_call)
	builder.append_line('mov rdi, rax')
	builder.append_line('mov rax, 60')
	builder.append_line('syscall')
	builder.append(`\n`)
	return builder.string()
}

add_windows_x64_header(entry_function_call: String): String {
	builder = StringBuilder()
	builder.append_line('.export main')
	builder.append_line('main:')
	builder.append_line(entry_function_call)
	builder.append(`\n`)
	return builder.string()
}

add_linux_arm64_header(entry_function_call: String): String {
	builder = StringBuilder()
	builder.append_line('.export _start')
	builder.append_line('_start:')
	builder.append_line('mov x0, sp')
	builder.append_line(entry_function_call)
	builder.append_line('mov x8, #93')
	builder.append_line('svc #0')
	builder.append(`\n`)
	return builder.string()
}

add_windows_arm64_header(entry_function_call: String): String {
	builder = StringBuilder()
	builder.append_line('.export main')
	builder.append_line('main:')
	builder.append_line(entry_function_call)
	builder.append(`\n`)
	return builder.string()
}

group_by<Ta, Tb>(items: List<Ta>, key_function: (Ta) -> Tb) {
	groups = Map<Tb, List<Ta>>()

	loop item in items {
		key = key_function(item)
		
		if groups.contains_key(key) {
			groups[key].add(item)
			continue
		}

		members = List<Ta>()
		members.add(item)
		groups.add(key, members)
	}

	return groups
}

# Summary:
# Allocates the specified static variable using assembly directives
allocate_static_variable(variable: Variable): String {
	builder = StringBuilder()

	name = variable.get_static_name()
	size = variable.type.allocation_size

	builder.append(EXPORT_DIRECTIVE)
	builder.append(` `)
	builder.append_line(name)

	if not settings.is_x64 {
		builder.append(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
		builder.append_line(' 4')
	}

	builder.append(name)
	builder.append_line(`:`)
	builder.append(BYTE_ZERO_ALLOCATOR)
	builder.append(` `)
	builder.append_line(size)

	return builder.string()
}

# Summary: Allocates the specified table label using assembly directives
add_table_label(label: TableLabel): String {
	if label.declare return label.name + `:`
	if label.is_section_relative return String(SECTION_RELATIVE_DIRECTIVE) + to_string(label.size * 8) + ` ` + label.name
	return String(to_data_section_allocator(label.size)) + ` ` + label.name
}

# Summary: Allocates the specified table using assembly directives
add_table(builder: AssemblyBuilder, table: Table, marker: large): _ {
	if (table.marker & marker) != 0 return
	table.marker |= marker

	if table.is_section {
		builder.write(SECTION_DIRECTIVE)
		builder.write(` `)
		builder.write_line(table.name)
	}
	else {
		builder.write_line(String(EXPORT_DIRECTIVE) + ` ` + table.name)

		if not settings.is_x64 {
			builder.write(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
			builder.write_line(' 4')
		}

		builder.write(table.name)
		builder.write(':\n')
	}

	# Take care of the table items
	subtables = List<Table>()

	loop item in table.items {
		result = when(item.type) {
			TABLE_ITEM_STRING => allocate_string(item.(StringTableItem).value)
			TABLE_ITEM_INTEGER => String(to_data_section_allocator(item.(IntegerTableItem).size)) + ` ` + to_string(item.(IntegerTableItem).value)
			TABLE_ITEM_TABLE_REFERENCE => String(to_data_section_allocator(SYSTEM_BYTES)) + ` ` + item.(TableReferenceTableItem).value.name
			TABLE_ITEM_LABEL => String(to_data_section_allocator(SYSTEM_BYTES)) + ` ` + item.(LabelTableItem).value.name
			TABLE_ITEM_LABEL_OFFSET => String(LONG_ALLOCATOR) + ` ` + item.(LabelOffsetTableItem).value.to.name + ' - ' + item.(LabelOffsetTableItem).value.from.name
			TABLE_ITEM_TABLE_LABEL => add_table_label(item.(TableLabelTableItem).value)
			else => abort('Invalid table item') as String
		}

		builder.write_line(result)

		if item.type == TABLE_ITEM_TABLE_REFERENCE {
			subtables.add(item.(TableReferenceTableItem).value)
		}
	}

	builder.write('\n\n')
	
	# Build the subtables
	loop subtable in subtables { add_table(builder, subtable, marker) }
}

# Summary: Returns a list of directives, which allocate the specified string
allocate_string(text: String): String {
	builder = StringBuilder()
	position = 0

	loop (position < text.length) {
		end = position

		loop (end < text.length and text[end] != `\\`, end++) {}

		buffer = text.slice(position, end)
		position += buffer.length

		if buffer.length > 0 {
			builder.append(CHARACTERS_ALLOCATION_DIRECTIVE)
			builder.append(' \'')
			builder.append(buffer)
			builder.append_line(`\'`)
		}

		if position >= text.length stop

		position++ # Skip character '\'

		command = text[position++]
		length = 0
		error = none as link

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
			builder.append(BYTE_ALLOCATOR)
			builder.append(` `)
			builder.append_line(`\\` as large)
			continue
		}
		else {
			abort("Can not understand string command " + String(command))
		}

		hexadecimal = text.slice(position, position + length)

		if hexadecimal_to_integer(hexadecimal) has not value abort(error)

		bytes = length / 2
		allocator = none as link

		if bytes == 1 { allocator = BYTE_ALLOCATOR }
		else bytes == 2 { allocator = SHORT_ALLOCATOR }
		else bytes == 4 { allocator = LONG_ALLOCATOR }
		else bytes == 8 { allocator = QUAD_ALLOCATOR }

		builder.append(allocator)
		builder.append(` `)
		builder.append_line(to_string(value))

		position += length
	}

	builder.append(BYTE_ALLOCATOR)
	builder.append(' 0')

	return builder.string()
}

# Summary: Allocates the specified constants using the specified data section builder
allocate_constants(builder: AssemblyBuilder, file: SourceFile, items: List<ConstantDataSectionHandle>): _ {
	module = builder.get_data_section(file, String(DATA_SECTION_IDENTIFIER))
	temporary: large[1]

	loop item in items {
		# Align the position and declare the constant
		name = item.identifier

		if settings.is_assembly_output_enabled {
			builder.write_line(String(POWER_OF_TWO_ALIGNMENT_DIRECTIVE) + ' 4')
			builder.write_line(name + `:`)
		}

		data_encoder.align(module, 16)
		module.create_local_symbol(name, module.position)

		data = none as link
		size = 0

		if item.value_type == CONSTANT_TYPE_BYTES {
			bytes = item.(ByteArrayDataSectionHandle).value
			data = bytes.data
			size = bytes.size
		}
		else item.value_type == CONSTANT_TYPE_INTEGER or item.value_type == CONSTANT_TYPE_DECIMAL {
			temporary[] = item.(NumberDataSectionHandle).value
			data = temporary as link
			size = strideof(large)
		}
		else {
			abort('Unsupported constant data')
		}

		module.write(data, size)

		loop (i = 0, i < size, i++) {
			builder.write_line(String(BYTE_ALLOCATOR) + ` ` + to_string(data[i] as large))
		}
	}
}

# Summary: Returns the bytes which represent the specified value
get_bytes<T>(value: T) {
	bytes = List<byte>()

	# Here we loop over each byte of the value and add them into the list
	loop (i = 0, i < strideof(T), i++) {
		slide = i * 8
		mask = 255 <| slide
		bytes.add((value & mask) |> slide)
	}

	return bytes
}

# Summary: Constructs data section for the specified constants
get_constant_section(items: List<ConstantDataSectionHandle>) {
	builder = StringBuilder()

	loop item in items {
		name = item.identifier

		allocator = none as link
		text = none as String

		if item.value_type == CONSTANT_TYPE_BYTES {
			values = List<String>()
			loop value in item.(ByteArrayDataSectionHandle).value { values.add(to_string(value)) }
			text = String.join(", ", values)
			allocator = BYTE_ALLOCATOR
		}
		else {
			text = to_string(item.(NumberDataSectionHandle).value)
			allocator = QUAD_ALLOCATOR
		}

		if settings.is_x64 { builder.append_line(String(BYTE_ALIGNMENT_DIRECTIVE) + ' 16') }
		else { builder.append_line(String(POWER_OF_TWO_ALIGNMENT_DIRECTIVE) + ' 4') }

		builder.append(name)
		builder.append_line(`:`)
		builder.append(allocator)
		builder.append(` `)
		builder.append_line(text)
	}

	return builder.string()
}

# Summary:
# Constructs debugging information for each of the files inside the context
get_debug_sections(context: Context, files: List<SourceFile>): Map<SourceFile, AssemblyBuilder> {
	builders = Map<SourceFile, AssemblyBuilder>()
	if not settings.is_debugging_enabled return builders

	all_implementations = common.get_all_function_implementations(context, false)
	loop (i = all_implementations.size - 1, i >= 0, i--) { if all_implementations[i].metadata.is_imported all_implementations.remove_at(i) }
	implementations = group_by<FunctionImplementation, SourceFile>(all_implementations, (i: FunctionImplementation) -> i.metadata.start.file)

	loop file in files {
		debug = Debug(context)
		debug.begin_file(file)

		types = Map<String, Type>()

		if implementations.contains_key(file) {
			loop implementation in implementations[file] {
				debug.add_function(implementation, types)
			}
		}

		# Save all processed types, so that types are not added multiple times
		denylist = Map<String, bool>()

		loop (types.size > 0) {
			# Load the next batch
			batch = types

			# Reset the types so that we can collect new types
			types = Map<String, Type>()

			loop iterator in batch {
				label = iterator.key
				type = iterator.value

				# Mark the current type as processed
				denylist[label] = true

				# Add the debugging information for the current type
				debug.add_type(type, types)
			}

			# Remove all the processed types from the collected types
			loop iterator in denylist {
				label = iterator.key
				types.remove(label)
			}
		}

		debug.end_file()
		builders.add(file, debug.build(file))
	}

	return builders
}

# Summary: Constructs file specific data sections based on the specified context
get_data_sections(context: Context): Map<SourceFile, AssemblyBuilder> {
	sections = Map<SourceFile, AssemblyBuilder>()
	
	all_types = common.get_all_types(context)
	loop (i = all_types.size - 1, i >= 0, i--) { if all_types[i].position === none all_types.remove_at(i) }
	types = group_by<Type, SourceFile>(all_types, (i: Type) -> i.position.file)

	data_section_identifier = String(SECTION_DIRECTIVE) + ` ` + DATA_SECTION_IDENTIFIER + `\n`

	# Add static variables
	loop iterator in types {
		builder = AssemblyBuilder(data_section_identifier)
		file = iterator.key

		loop type in iterator.value {
			# Skip imported types, because they are already exported
			if type.is_imported continue

			loop iterator in type.variables {
				variable = iterator.value
				if not variable.is_static continue

				builder.write_line(allocate_static_variable(variable))
				data_encoder.add_static_variable(builder.get_data_section(file, String(DATA_SECTION_IDENTIFIER)), variable)
			}

			builder.write('\n\n')
		}

		sections.add(file, builder)
	}

	# Add runtime type information
	loop iterator in types {
		builder = sections[iterator.key]

		loop type in iterator.value {
			# 1. Skip if the runtime configuration has not been created
			# 2. Skip imported types, because they are already exported
			# 3. The template type must be a variant
			# 4. Unnamed packs are not processed
			if type.configuration == none or type.is_imported or (type.is_template_type and not type.is_template_type_variant) or type.is_unnamed_pack continue
			add_table(builder, type.configuration.entry, TABLE_MARKER_TEXTUAL_ASSEMBLY)
			data_encoder.add_table(builder, builder.get_data_section(iterator.key, String(DATA_SECTION_IDENTIFIER)), type.configuration.entry, TABLE_MARKER_DATA_ENCODER)
		}
	}

	# Add strings
	all_implementations = common.get_all_function_implementations(context)
	loop (i = all_implementations.size - 1, i >= 0, i--) { if all_implementations[i].metadata.is_imported all_implementations.remove_at(i) }
	implementations = group_by<FunctionImplementation, SourceFile>(all_implementations, (i: FunctionImplementation) -> i.metadata.start.file)

	loop iterator in implementations {
		nodes = List<StringNode>()

		loop implementation in iterator.value {
			if implementation.node == none continue
			nodes.add_all(implementation.node.find_all(NODE_STRING) as List<StringNode>)
		}

		builder = none as AssemblyBuilder

		if sections.contains_key(iterator.key) { builder = sections[iterator.key] }
		else { builder = AssemblyBuilder(data_section_identifier) }

		loop node in nodes {
			if node.identifier === none continue

			builder.write(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
			builder.write_line(' 4')
			builder.write(node.identifier)
			builder.write(':\n')
			builder.write_line(allocate_string(node.text))

			module = builder.get_data_section(iterator.key, String(DATA_SECTION_IDENTIFIER))
			data_encoder.align(module, 16)

			module.create_local_symbol(node.identifier, module.position)
			module.string(node.text)
		}

		sections[iterator.key] = builder
	}

	return sections
}

get_text_sections(files: List<SourceFile>, context: Context): Map<SourceFile, AssemblyBuilder> {
	sections = Map<SourceFile, AssemblyBuilder>()

	all = common.get_all_function_implementations(context, false)

	# Remove all functions, which do not have start position
	loop (i = all.size - 1, i >= 0, i--) {
		if all[i].metadata.start === none all.remove_at(i)
	}

	implementations = group_by<FunctionImplementation, SourceFile>(all, (i: FunctionImplementation) -> i.metadata.start.file)

	# Store the number of assembled functions
	index = 0

	loop file in files {
		builder = AssemblyBuilder()

		# Add the debug label, which indicates the start of debuggable code
		if settings.is_debugging_enabled {
			label = "debug_file_" + to_string(file.index) + '_start'
			builder.write_line(label + `:`)
			builder.add(file, LabelInstruction(none as Unit, Label(label)))
		}

		if implementations.contains_key(file) {
			loop implementation in implementations[file] {
				if implementation.is_imported continue

				if settings.is_verbose_output_enabled {
					console.put(`[`)
					console.write(index + 1)
					console.put(`/`)
					console.write(all.size)
					console.put(`]`)
					console.write(' Assembling ')
					console.write_line(implementation.string())
				}

				builder.add(get_text_section(implementation))
				builder.write('\n\n')

				index++ # Increment the number of assembled functions
			}
		}

		# Add the debug label, which indicates the end of debuggable code
		if settings.is_debugging_enabled {
			label = "debug_file_" + to_string(file.index) + '_end'
			builder.write_line(label + `:`)
			builder.add(file, LabelInstruction(none as Unit, Label(label)))
		}

		sections.add(file, builder)
	}

	return sections
}

# Summary: Removes unnecessary line endings
beautify(text: String): String {
	builder = StringBuilder()
	builder.append(text)
	i = 0

	loop (i < builder.length) {
		if builder[i] != `\n` {
			i++
			continue
		}

		j = i + 1
		loop (j < builder.length and builder[j] == `\n`, j++) {}

		if j - i <= 2 {
			i++
			continue
		}

		builder.remove(i + 2, j)
	}

	return builder.string()
}

# Summary: Adds debug information to the header, if needed
add_debug_information_to_header(builder: AssemblyBuilder, file: SourceFile): _ {
	# Do nothing if debugging information is not requested
	if not settings.is_debugging_enabled return

	# Extract the full path to the source file, since we might have to modify it to a relative path
	fullname = file.fullname

	# Determine the current working folder, so that we can determine if full path can be expressed as a relative path
	current_folder = io.get_process_working_folder().replace(`\\`, `/`)
	if not current_folder.ends_with(`/`) { current_folder = current_folder + `/` }

	# Convert the full path to a relative path if possible
	if fullname.starts_with(current_folder) {
		fullname = "./" + fullname.slice(current_folder.length)
	}

	# Write a directive that stores the path to the specified source file, this is needed for debugging information
	builder.write('.')
	builder.write(AssemblyParser.DEBUG_FILE_DIRECTIVE)
	builder.write(' \'')
	builder.write(fullname)
	builder.write_line('\'')
}

# Summary: Creates an assembler header for the specified file from the specified context. Depending on the situation, the header might be empty or it might have a entry function call and other directives.
create_header(context: Context, file: SourceFile, output_type: large): AssemblyBuilder {
	builder = AssemblyBuilder()
	builder.write_line(TEXT_SECTION_DIRECTIVE)

	add_debug_information_to_header(builder, file)

	# Static libraries and object files do not have entry points
	is_entry_point_needed = output_type == BINARY_TYPE_EXECUTABLE or output_type == BINARY_TYPE_SHARED_LIBRARY
	if not is_entry_point_needed return builder

	selector = context.get_function("init")
	if selector == none or selector.overloads.size == 0 abort('Missing entry function')

	overload = selector.overloads[]
	if overload.implementations.size == 0 abort('Missing entry function')

	# Now, if an internal initialization function is defined, we need to call it and it is its responsibility to call the user defined entry function
	entry_function_implementation = overload.implementations[]

	implementation = entry_function_implementation
	if settings.initialization_function != none { implementation = settings.initialization_function }

	# Add the entry function call only into the file, which contains the actual entry function
	if implementation.metadata.start.file !== file or output_type === BINARY_TYPE_OBJECTS return builder

	header = none as String

	if settings.is_x64 {
		if settings.is_target_windows { header = add_windows_x64_header(String(platform.x64.JUMP) + ` ` + implementation.get_fullname()) }
		else { header = add_linux_x64_header(String(platform.x64.CALL) + ` ` + implementation.get_fullname()) }
	}
	else {
		if settings.is_target_windows { header = add_windows_arm64_header(String(platform.arm64.JUMP_LABEL) + ` ` + implementation.get_fullname()) }
		else { header = add_linux_arm64_header(String(platform.arm64.CALL) + ` ` + implementation.get_fullname()) }
	}

	builder.write_line(header)

	parser = AssemblyParser()
	parser.parse(file, header)

	builder.add(file, parser.instructions)
	builder.export_symbols(parser.exports.to_list())

	return builder
}

run(executable: link, arguments: List<String>) {
	command = String(executable) + ` ` + String.join(` `, arguments)
	pid = io.shell(command)
	io.wait_for_exit(pid)
	return Status()
}

# Summary: Builds an object file from the specified properties and writes it into a file
output_object_file(output: String, sections: List<BinarySection>, exports: Set<String>): _ {
	binary = none as Array<byte>

	if settings.is_target_windows {
		binary = pe_format.build(sections, exports)
	}
	else {
		binary = elf_format.build_object_file(sections, exports)
	}

	io.write_file(output, binary)
}

assemble(context: Context, files: List<SourceFile>, imports: List<String>, output_name: String, output_type: large): Map<SourceFile, String> {
	align(context)

	Keywords.all.clear() # Remove all keywords for parsing assembly

	text_sections = get_text_sections(files, context)
	data_sections = get_data_sections(context)
	debug_sections = get_debug_sections(context, files)

	assemblies = Map<SourceFile, String>()
	exports = Map<SourceFile, List<String>>()
	object_files = settings.object_files

	# Import user defined object files
	user_imported_object_files = settings.user_imported_object_files

	loop object_filename in user_imported_object_files {
		file = SourceFile(object_filename, String.empty, -1)

		if settings.is_target_windows {
			if pe_format.import_object_file(object_filename) has not object_file abort("Could not import object file " + object_filename)
			object_files.add(file, object_file)
		}
		else {
			if elf_format.import_object_file(object_filename) has not object_file abort("Could not import object file " + object_filename)
			object_files.add(file, object_file)
		}
	}

	loop file in files {
		logger.verbose.write_line("Building object file for " + file.fullname)

		builder = create_header(context, file, output_type)

		if text_sections.contains_key(file) {
			builder.add(text_sections[file])
			builder.write('\n\n')
		}

		if data_sections.contains_key(file) {
			data_section_builder = data_sections[file]

			if builder.constants.contains_key(file) allocate_constants(data_section_builder, file, builder.constants[file])

			builder.add(data_section_builder)
			builder.write('\n\n')
		}

		if debug_sections.contains_key(file) {
			builder.add(debug_sections[file])
			builder.write('\n\n')
		}

		# Register the exported symbols of the current file
		exports[file] = builder.exports.to_list()

		if settings.is_assembly_output_enabled {
			assemblies[file] = beautify(builder.string())
		}

		# Load all the section modules
		modules = none as List<DataEncoderModule>

		if builder.modules.contains_key(file) {
			modules = builder.modules[file]
		}
		else {
			modules = List<DataEncoderModule>()
		}

		encoder_debug_file = none as String
		if settings.is_debugging_enabled { encoder_debug_file = file.fullname }

		logger.verbose.write_line("- Encoding instructions...")
		encoder_output = instruction_encoder.encode(builder.instructions.try_get(file).value_or(List<Instruction>()), encoder_debug_file)

		logger.verbose.write_line("- Building data sections...")
		sections = List<BinarySection>()
		sections.add(encoder_output.section) # Add the text section
		sections.add_all(modules.map<BinarySection>((i: DataEncoderModule) -> i.build())) # Add the data sections

		if encoder_output.lines != none { sections.add(encoder_output.lines.build()) } # Add the debug lines
		if encoder_output.frames != none { sections.add(encoder_output.frames.build()) } # Add the debug frames

		logger.verbose.write_line("- Packing the object file...")

		if output_type == BINARY_TYPE_OBJECTS {
			output_object_file(file.filename_without_extension + object_file_extension, sections, builder.exports)
			continue
		}

		object_file = none as BinaryObjectFile

		if settings.is_target_windows {
			object_file = pe_format.create_object_file(file.fullname, sections, builder.exports)
		}
		else {
			object_file = elf_format.create_object_file(file.fullname, sections, builder.exports)
		}

		object_files.add(file, object_file)
	}

	if output_type == BINARY_TYPE_RAW {
		io.write_file(output_name, elf_format.build_binary_file(object_files.get_values()))
		return assemblies
	}

	if output_type == BINARY_TYPE_OBJECTS {
		return assemblies
	}

	if output_type == BINARY_TYPE_STATIC_LIBRARY {
		if static_library_format.build(context, object_files, output_name) return assemblies
		abort('Failed to create the static library')
	}

	# Determine the output file extension
	extension = none as link

	if settings.is_target_windows {
		if output_type == BINARY_TYPE_EXECUTABLE { extension = '.exe' }
		else { extension = '.dll' }
	}
	else {
		if output_type == BINARY_TYPE_EXECUTABLE { extension = '' }
		else { extension = '.so' }
	}

	output_filename = output_name + extension
	binary = none as Array<byte>

	logger.verbose.write_line("Linking...")

	if settings.is_target_windows {
		binary = pe_format.link(object_files.get_values(), imports, get_default_entry_point(), output_filename, output_type == BINARY_TYPE_EXECUTABLE)
	}
	else {
		binary = elf_format.link(object_files.get_values(), imports, get_default_entry_point(), output_type == BINARY_TYPE_EXECUTABLE)
	}

	io.write_file(output_filename, binary)
	return assemblies
}

assemble(): Status {
	parse = settings.parse
	files = settings.source_files
	imports = settings.libraries
	output_name = settings.output_name
	output_type = settings.output_type

	assemblies = assemble(parse.context, files, imports, output_name, output_type)

	if settings.is_assembly_output_enabled {
		loop file in files {
			assembly = assemblies[file]
			assembly_filename = output_name + `.` + file.filename_without_extension() + '.asm'

			io.write_file(assembly_filename, assembly)
		}
	}

	# Clean up
	parse.context.dispose()

	return Status()
}