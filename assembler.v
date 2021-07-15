constant EXPORT_DIRECTIVE = '.global'

constant REGISTER_NONE = 0
constant REGISTER_VOLATILE = 1
constant REGISTER_RESERVED = 2
constant REGISTER_RETURN = 4
constant REGISTER_STACK_POINTER = 8
constant REGISTER_NUMERATOR = 16
constant REGISTER_REMAINDER = 32
constant REGISTER_MEDIA = 64
constant REGISTER_DECIMAL_RETURN = 128
constant REGISTER_SHIFT = 256
constant REGISTER_BASE_POINTER = 512
constant REGISTER_ZERO = 1024
constant REGISTER_RETURN_ADDRESS = 2048

Register {
	partitions: Array<String>
	value: Result
	flags: large
	is_locked: bool

	is_volatile => has_flag(flags, REGISTER_VOLATILE)
	is_reserved => has_flag(flags, REGISTER_RESERVED)
	is_media_register => has_flag(flags, REGISTER_MEDIA)

	format() => {
		if is_media_register => FORMAT_DECIMAL
		=> SYSTEM_FORMAT
	}

	init(partitions: String, flags: large) {
		this.partitions = partitions.split(` `)
		this.flags = flags
	}

	lock() {
		is_locked = true
	}

	unlock() {
		is_locked = false
	}

	is_value_copy() {
		=> value != none and not [value.value.instance == INSTANCE_REGISTER and value.value.(RegisterHandle).register == this]
	}

	is_available() {
		=> not is_locked and [value == none or not value.is_active() or is_value_copy()]
	}

	is_deactivating() {
		=>  not is_locked and value != none and value.is_deactivating()
	}

	is_releasable(unit: Unit) {
		=> not is_locked and [value == none or value.is_releasable(unit)]
	}

	get(size: large) {
		i = 1
		count = partitions.count

		loop (j = 0, j < count, j++) {
			if size == i => partitions[count - 1 - j]
			i *= 2
		}

		abort('Could not find a register partition with the specified size')
	}

	reset() {
		value = none
	}
}

Lifetime {
	usages: List<Instruction> = List<Instruction>()

	reset() {
		usages.clear()
	}

	# Summary: Returns whether this lifetime is active
	is_active() {
		started = false

		loop (i = 0, i < usages.size, i++) {
			state = usages[i].state

			# If one of the usages is being built, the lifetime must be active
			if state == INSTRUCTION_STATE_BUILDING => true

			# If one of the usages is built, the lifetime must have started already
			if state == INSTRUCTION_STATE_BUILT {
				started = true
				stop
			}
		}

		# If the lifetime has not started, it can not be active
		if not started => false

		loop (i = 0, i < usages.size, i++) {
			# Since the lifetime has started, if any of the usages is not built, this lifetime must be active 
			if usages[i].state != INSTRUCTION_STATE_BUILT => true
		}

		=> false
	}

	# Summary: Returns true if the lifetime is active and is not starting or ending
	is_only_active() {
		started = false

		loop (i = 0, i < usages.size, i++) {
			# If one of the usages is built, the lifetime must have started already
			if usages[i].state == INSTRUCTION_STATE_BUILT {
				started = true
				stop
			}
		}

		# If the lifetime has not started, it can not be only active
		if not started => false

		loop (i = 0, i < usages.size, i++) {
			# Look for usage, which has not been built and is not being built
			if usages[i].state == INSTRUCTION_STATE_NOT_BUILT => true
		}

		=> false
	}

	# Summary: Returns true if the lifetime is expiring
	is_deactivating() {
		building = false

		loop (i = 0, i < usages.size, i++) {
			# Look for usage, which is being built
			if INSTRUCTION_STATE_BUILDING {
				building = true
				stop
			}
		}

		# If none of usages is being built, the lifetime can not be expiring
		if not building => false

		loop (i = 0, i < usages.size, i++) {
			# If one of the usages is not built, the lifetime can not be expiring
			if usages[i].state == INSTRUCTION_STATE_NOT_BUILT => false
		}

		=> true
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

	is_releasable(unit: Unit) {
		=> unit.is_variable_value(this)
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
	is_inline => value.instance == INSTANCE_INLINE

	is_unsigned => is_unsigned(format)

	use(instruction: Instruction) {
		contains = false

		loop usage in lifetime.usages {
			if usage != instruction continue
			contains = true
			stop
		}

		if not contains { lifetime.usages.add(instruction) }

		value.use(instruction)
	}

	use(instructions: List<Instruction>) {
		loop instruction in instructions { use(instruction) }
	}
}

Scope {
	unit: Unit
	outer: Scope
	root: Node
	end: Instruction

	actives: List<Variable> = List<Variable>()
	variables: Map<Variable, Result> = Map<Variable, Result>()
	transferers: Map<Variable, Result> = Map<Variable, Result>()

	loads: List<Pair<Variable, Result>>
	activators: bool = false
	deactivators: bool = false

	static get_top_local_contexts(root: Node) {
		nodes = root.find_top(i -> i.instance == NODE_INLINE and i.(InlineNode).is_context) as List<ContextInlineNode>
		result = List<Context>(nodes.size, false)
		loop node in nodes { result.add(node.context) }
		=> result
	}

	# Summary: Returns true if the variable is not defined inside any of the specified contexts
	static is_non_local_variable(variable: Variable, local_contexts: List<Context>) {
		loop context in local_contexts {
			if variable.parent.is_inside(context) => false
		}

		=> true
	}

	# Summary: Returns all variables in the given node tree that are not declared in the given local context
	static get_all_non_local_variables(roots: List<Node>, local_contexts: List<Context>) {
		result = List<Variable>()

		loop root in roots {
			loop usage in root.find_all(NODE_VARIABLE) {
				variable = usage.(VariableNode).variable
				if not (variable.is_predictable and is_non_local_variable(variable, local_contexts)) continue
				result.add(variable)
			}
		}

		=> result
	}

	# Summary: Loads constants which might be edited inside the specified root
	static load_constants(unit: Unit, root: Node, contexts: List<Context>) {
		local_contexts = get_top_local_contexts(root)
		local_contexts.add_range(contexts)

		# Find all variables inside the root node which are edited
		edited = List<Variable>()
		roots = List<Node>(1, false)
		roots.add(root)

		loop variable in get_all_non_local_variables(roots, local_contexts) {
			if not variable.is_edited_inside(root) continue
			edited.add(variable)
		}

		# All edited variables that are constants must be moved into registers or into memory
		loop variable in edited { unit.add(SetModifiableInstruction(unit, variable)) }
	}

	# Summary: Loads constants which might be edited inside the specified root
	static load_constants(unit: Unit, root: IfNode) {
		edited = List<Variable>()
		iterator = root
		local_contexts = get_top_local_contexts(root)

		roots = List<Node>(1, true)

		loop (iterator != none) {
			# Find all variables inside the root node which are edited
			roots[0] = iterator

			loop variable in get_all_non_local_variables(roots, local_contexts) {
				if not variable.is_edited_inside(iterator) continue
				edited.add(variable)
			}

			if iterator.instance == NODE_ELSE_IF {
				iterator = root.(IfNode).successor

				# Retrieve the contexts of the successor
				if iterator.instance != none { local_contexts = get_top_local_contexts(iterator) }
			}
			else {
				stop
			}
		}

		# Remove duplicates
		loop (i = 0, i < edited.size, i++) {
			current = edited[i]

			loop (j = i + 1, j < edited.size, j++) {
				if current != edited[j] continue
				edited.remove_at(j)
			}
		}

		# All edited variables that are constants must be moved into registers or into memory
		loop variable in edited { unit.add(SetModifiableInstruction(unit, variable)) }
	}

	# Summary: Returns all variables that the scope must take care of
	static get_all_active_variables(unit: Unit, roots: List<Node>) {
		result = List<Variable>()

		loop iterator in unit.scope.variables {
			variable = iterator.key
			added = false

			# 1. If the variable is used inside any of the roots, it must be included
			loop root in roots {
				loop usage in variable.usages {
					if not usage.is_under(root) continue
					result.add(variable)
					added = true
					stop
				}
			}

			if added continue

			# 2. If the variable is used after any of the roots, it must be included
			loop root in roots {
				if not analysis.is_used_later(variable, root) continue
				result.add(variable)
				stop
			}
		}

		=> result
	}

	# Summary: Returns all variables that the scope must take care of
	static get_all_active_variables(unit: Unit, root: Node) {
		roots = List<Node>()
		roots.add(root)
		=> get_all_active_variables(unit, roots)
	}

	init(unit: Unit, root: Node) {
		this.unit = unit
		this.root = root
		enter()
	}

	init(unit: Unit, root: Node, actives: List<Variable>) {
		this.unit = unit
		this.root = root
		this.actives = actives
		enter()
	}

	set_or_create_transition_handle(variable: Variable, handle: Handle, format: large) {
		if not variable.is_predictable abort('Tried to create transition handle for an unpredictable variable')

		handle = handle.finalize()
		transferer = none as Result

		if transferers.contains_key(variable) {
			transferer = transferers[variable]
			transferer.value = handle
			transferer.format = format
		}
		else {
			transferer = Result(handle, format)
			transferers.add(variable, transferer)
		}

		# Update the current handle to the variable
		variables[variable] = transferer

		# If the transferrer is a register, the transferrer value must be attached there
		if transferer.value.instance == INSTANCE_REGISTER {
			transferer.value.(RegisterHandle).register.value = transferer
		}

		=> transferer
	}

	# Summary: Assigns a register or a stack address for the specified parameter depending on the situation
	receive_parameter(standard_parameter_registers: List<Register>, decimal_parameter_registers: List<Register>, parameter: Variable) {
		register = none as Register

		if parameter.type.format == FORMAT_DECIMAL {
			if decimal_parameter_registers.size > 0 { register = decimal_parameter_registers.take_first() }
		}
		else {
			if standard_parameter_registers.size > 0 { register = standard_parameter_registers.take_first() }
		}

		if register != none {
			register.value = set_or_create_transition_handle(parameter, RegisterHandle(register), parameter.type.get_register_format())
		}
		else {
			set_or_create_transition_handle(parameter, references.create_variable_handle(unit, parameter), parameter.type.get_register_format())
		}
	}

	enter() {
		# Reset variable data
		reset()

		# Save the outer scope so that this scope can be exited later
		if unit.scope != this { outer = unit.scope }

		# Detect if there are new variables to load
		if loads == none {
			loads = List<Pair<Variable, Result>>()

			if actives.size != 0 {
				instruction = RequireVariablesInstruction(unit, actives)
				instruction.description = String('Requires variables to enter a scope')
				unit.add(instruction)

				loop (i = 0, i < instruction.variables.size, i++) {
					loads.add(Pair<Variable, Result>(instruction.variables[i], instruction.dependencies[i]))
				}
			}
		}

		if unit.mode == UNIT_MODE_BUILD {
			# Load all memory handles into registers which do not use the stack
			loop load in loads {
				result = load.value
				if not result.is_memory_address continue

				instance = result.value.instance
				if instance == INSTANCE_STACK_MEMORY or instance == INSTANCE_STACK_VARIABLE or instance == INSTANCE_TEMPORARY_MEMORY continue

				memory.move_to_register(unit, result, SYSTEM_BYTES, result.format == FORMAT_DECIMAL, trace.for(unit, result))
			}
		}

		# Switch the current unit scope to be this scope
		unit.scope = this

		if outer != none {
			loop (i = 0, i < actives.size, i++) {
				variable = actives[i]
				result = loads[i].value

				set_or_create_transition_handle(variable, result.value, result.format)
			}

			if not activators {
				activators = true

				instruction = RequireVariablesInstruction(unit, actives)
				instruction.description = String('Initializes outer scope variables')
				unit.add(instruction)
			}

			# Get all the register which hold any active variable
			denylist = List<Register>()

			loop iterator in variables {
				value = iterator.value.value
				if value.instance != INSTANCE_REGISTER continue
				denylist.add(value.(RegisterHandle).register)
			}

			# All register which do not hold active variables must be reset since they would disturb the execution of the scope
			loop register in unit.non_reserved_registers {
				if denylist.contains(register) continue
				register.reset()
			}
		}
		else not settings.is_debugging_enabled {
			# Move all parameters to their expected registers since this is the first scope
			decimal_parameter_registers = calls.get_decimal_parameter_registers(unit)
			standard_parameter_registers = calls.get_standard_parameter_registers(unit)

			if (unit.function.is_member and not unit.function.is_static) or unit.function.is_lambda_implementation {
				receive_parameter(standard_parameter_registers, decimal_parameter_registers, unit.self)
			}

			loop parameter in unit.function.parameters {
				receive_parameter(standard_parameter_registers, decimal_parameter_registers, parameter)
			}
		}
	}

	# Summary: Returns the current handle of the specified variable, if one is present
	get_variable_value(variable: Variable, recursive: bool) {
		# When debugging is enabled, all variables should be stored in stack, which is the default location if this function returns null
		if settings.is_debugging_enabled => none as Result

		# Only predictable variables are allowed to be stored
		if not variable.is_predictable => none as Result

		# First check if the variable handle list already exists
		if variables.contains_key(variable) => variables[variable]

		if recursive and outer != none {
			value = outer.get_variable_value(variable, recursive) as Result
			if value != none { variables.add(variable, value) }
			=> value
		}

		=> none as Result
	}

	exit() {
		if not deactivators {
			deactivators = true
			requirements = List<Variable>()

			loop active in actives {
				if not analysis.is_used_later(active, root) continue
				requirements.add(active)
			}

			instruction = RequireVariablesInstruction(unit, requirements)
			instruction.description = String('Keeps outer scope variables active across the scope')
			unit.add(instruction)
		}

		if end == none {
			end = Instruction(unit, INSTRUCTION_NORMAL)
			end.description = String('Marks the end of a scope')
			end.is_abstract = true
			unit.add(end)
		}

		# Exit to the outer scope
		unit.scope = outer
		if outer == none { unit.scope = this }

		# Reset all registers
		loop register in unit.registers { register.reset() }

		# Attach all the variables before entering back to their registers
		loop load in loads {
			result = load.value
			if not result.is_any_register continue
			result.value.(RegisterHandle).register.value = result
		}
	}

	reset() {
		variables = Map<Variable, Result>()
	}
}

UNIT_MODE_NONE = 0
UNIT_MODE_ADD = 1
UNIT_MODE_BUILD = 2

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
	anchor: Instruction
	position: large
	stack_offset: large = 0
	builder: StringBuilder
	mode: large

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

		non_reserved_registers.add_range(volatile_registers)
		non_reserved_registers.add_range(non_volatile_registers)
	}

	load_architecture_x64() {
		volatility_flag = REGISTER_VOLATILE
		if settings.is_target_windows { volatility_flag = REGISTER_NONE }

		base_pointer_flags = REGISTER_NONE
		if settings.is_debugging_enabled { base_pointer_flags = REGISTER_RESERVED | REGISTER_STACK_POINTER }

		registers.add(Register(String('rax eax ax al'), REGISTER_VOLATILE | REGISTER_RETURN | REGISTER_NUMERATOR))
		registers.add(Register(String('rbx ebx bx bl'), REGISTER_NONE))
		registers.add(Register(String('rcx ecx cx cl'), REGISTER_VOLATILE | REGISTER_SHIFT))
		registers.add(Register(String('rdx edx dx dl'), REGISTER_VOLATILE | REGISTER_REMAINDER))
		registers.add(Register(String('rsi esi si sil'), volatility_flag))
		registers.add(Register(String('rdi edi di dil'), volatility_flag))
		registers.add(Register(String('rbp ebp bp bpl'), base_pointer_flags))
		registers.add(Register(String('rsp esp sp spl'), REGISTER_RESERVED | REGISTER_STACK_POINTER))

		registers.add(Register(String('ymm0 xmm0 xmm0 xmm0 xmm0'), REGISTER_MEDIA | REGISTER_VOLATILE | REGISTER_DECIMAL_RETURN))
		registers.add(Register(String('ymm1 xmm1 xmm1 xmm1 xmm1'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm2 xmm2 xmm2 xmm2 xmm2'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm3 xmm3 xmm3 xmm3 xmm3'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm4 xmm4 xmm4 xmm4 xmm4'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm5 xmm5 xmm5 xmm5 xmm5'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm6 xmm6 xmm6 xmm6 xmm6'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm7 xmm7 xmm7 xmm7 xmm7'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm8 xmm8 xmm8 xmm8 xmm8'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm9 xmm9 xmm9 xmm9 xmm9'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm10 xmm10 xmm10 xmm10 xmm10'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm11 xmm11 xmm11 xmm11 xmm11'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm12 xmm12 xmm12 xmm12 xmm12'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm13 xmm13 xmm13 xmm13 xmm13'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm14 xmm14 xmm14 xmm14 xmm14'), REGISTER_MEDIA | REGISTER_VOLATILE))
		registers.add(Register(String('ymm15 xmm15 xmm15 xmm15 xmm15'), REGISTER_MEDIA | REGISTER_VOLATILE))

		registers.add(Register(String('r8 r8d r8w r8b'), REGISTER_VOLATILE))
		registers.add(Register(String('r9 r9d r9w r9b'), REGISTER_VOLATILE))
		registers.add(Register(String('r10 r10d r10w r10b'), REGISTER_VOLATILE))
		registers.add(Register(String('r11 r11d r11w r11b'), REGISTER_VOLATILE))
		registers.add(Register(String('r12 r12d r12w r12b'), REGISTER_NONE))
		registers.add(Register(String('r13 r13d r13w r13b'), REGISTER_NONE))
		registers.add(Register(String('r14 r14d r14w r14b'), REGISTER_NONE))
		registers.add(Register(String('r15 r15d r15w r15b'), REGISTER_NONE))
	}

	load_architecture_arm64() {

	}

	add(instruction: Instruction) {
		=> add(instruction, false)
	}

	add(instruction: Instruction, after: bool) {
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

		instruction.scope = scope
		instruction.result.use(instruction)

		if mode != UNIT_MODE_BUILD or after return

		destination = anchor
		anchor = instruction

		instruction.build()
		instruction.on_simulate()

		# Return to the previous instruction by iterating forward, since it must be ahead
		loop (anchor != destination) {
			if anchor.state != INSTRUCTION_STATE_BUILT {
				iterator = anchor
				iterator.build()
				iterator.on_simulate()
			} 

			anchor = instructions[++position]
		}
	}

	write(instruction: String) {
		builder.append(instruction)
		# TODO: Enhance
		builder.append('\n')
	}

	release(register: Register) {
		value = register.value
		if value == none => register

		if value.is_releasable(this) {
			loop iterator in scope.variables {
				if iterator.value != value continue

				# Get the default handle of the variable
				handle = references.create_variable_handle(this, iterator.key)

				# The handle must be a memory handle, otherwise anything can happen
				if handle.type != HANDLE_MEMORY {
					# TODO: Temporary release
					#handle = TemporaryMemoryHandle(this)
				}

				destination = Result(handle, iterator.key.type.format)

				instruction = MoveInstruction(this, destination, value)
				instruction.description = String('Releases the value into local memory')
				instruction.type = MOVE_RELOCATE

				add(instruction)
				stop
			}
		}
		else {
			# TODO: Temporary release
			#destination = Result(TemporaryMemoryHandle(this), value.format)
			#instruction = MoveInstruction(this, destination, value)
			#instruction.description = String('Releases the value into local memory')
			#instruction.type = MOVE_RELOCATE

			#add(instruction)
		}

		# Now the register is ready for use
		register.reset()
		=> register
	}

	# Summary: Retrieves the next available register, releasing a register to memory if necessary
	get_next_register() {
		# Try to find the next fully available volatile register
		loop register in volatile_standard_registers { if register.is_available() => register }
		# Try to find the next fully available non-volatile register
		loop register in non_volatile_standard_registers { if register.is_available() => register }
		# Try to find the next volatile register which contains a value that has a corresponding memory location
		loop register in volatile_standard_registers { if register.is_releasable(this) => release(register) }
		# Try to find the next non-volatile register which contains a value that has a corresponding memory location
		loop register in non_volatile_standard_registers { if register.is_releasable(this) => release(register) }

		# Since all registers contain intermediate values, one of them must be released to a temporary memory location
		# NOTE: Some registers may be locked which prevents them from being used, but not all registers should be locked, otherwise something very strange has happened

		# Find the next register which is not locked
		loop register in standard_registers {
			if register.is_locked continue
			=> release(register)
		}

		# NOTE: This usually happens when there is a flaw in the algorithm and the compiler does not know how to handle a value for example
		abort('All registers were locked or reserved, this should not happen')
	}

	# Summary: Retrieves the next available media register, releasing a media register to memory if necessary
	get_next_media_register() {
		# Try to find the next fully available media register
		loop register in media_registers { if register.is_available() => register }
		# Try to find the next media register which contains a value that has a corresponding memory location
		loop register in media_registers { if register.is_releasable(this) => release(register) }

		# Find the next media register which is not locked
		loop register in media_registers {
			if register.is_locked continue
			=> release(register)
		}

		# NOTE: This usually happens when there is a flaw in the algorithm and the compiler does not know how to handle a value for example
		abort('All media registers were locked or reserved, this should not happen')
	}

	# Summary: Tries to find an available standard register without releasing a register to memory
	get_next_register_without_releasing() {
		loop register in volatile_standard_registers { if register.is_available() => register }
		loop register in non_volatile_standard_registers { if register.is_available() => register }
		=> none as Register
	}

	# Summary: Tries to find an available media register without releasing a register to memory
	get_next_media_register_without_releasing() {
		loop register in media_registers { if register.is_available() => register }
		=> none as Register
	}

	get_next_non_volatile_register(media_register: bool, release: bool) {
		loop register in non_volatile_registers { if register.is_available() and register.is_media_register == media_register => register }
		if not release => none as Register

		loop register in non_volatile_registers {
			if register.is_releasable(this) and register.is_media_register == media_register {
				release(register)
				=> register
			}
		}

		=> none as Register
	}

	get_next_label() {
		=> Label(function.get_fullname() + '_L' + to_string(indexer.label))
	}

	get_stack_pointer() {
		loop register in registers { if has_flag(register.flags, REGISTER_STACK_POINTER) => register }
		abort('Architecture did not have stack pointer register')
	}

	get_standard_return_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_RETURN) => register }
		abort('Architecture did not have standard return register')
	}

	get_decimal_return_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_DECIMAL_RETURN) => register }
		abort('Architecture did not have decimal return register')
	}

	get_numerator_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_NUMERATOR) => register }
		abort('Architecture did not have numerator register')
	}

	get_remainder_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_REMAINDER) => register }
		abort('Architecture did not have remainder register')
	}

	get_shift_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_SHIFT) => register }
		abort('Architecture did not have shift register')
	}

	# Summary:  Returns whether a value has been assigned to the specified variable
	is_initialized(variable: Variable) {
		=> scope != none and scope.variables.contains_key(variable)
	}

	# Summary: Updates the value of the specified variable in the current scope
	set_variable_value(variable: Variable, value: Result) {
		if scope == none abort('Unit did not have an active scope')
		scope.variables[variable] = value
	}

	# Summary:
	# Tries to return the current value of the specified variable.
	# By default, this function goes through all scopes in order to return the value of the variable, but this can be turned off.
	get_variable_value(variable: Variable) {
		=> get_variable_value(variable, true)
	}

	# Summary: Tries to return the current value of the specified variable
	get_variable_value(variable: Variable, recursive: bool) {
		if scope == none => none as Result
		=> scope.get_variable_value(variable, recursive)
	}

	# Summary: Returns whether any variables owns the specified value
	is_variable_value(result: Result) {
		if scope == none => false
		loop iterator in scope.variables { if iterator.value == result => true }
		=> false
	}

	# Summary: Returns the variable which owns the specified value, if it is owned by any
	get_value_owner(value: Result) {
		if scope == none => none as Variable

		loop iterator in scope.variables {
			if iterator.value == value => iterator.key
		}

		=> none as Variable
	}

	string() {
		=> builder.string()
	}
}

namespace assembler

load_variable_usages(implementation: FunctionImplementation) {
	# Reset all local variables
	loop local in implementation.locals {
		local.usages.clear()
		local.writes.clear()
		local.reads.clear()
	}

	usages = implementation.node.find_all(NODE_VARIABLE)

	loop usage in usages {
		variable = usage.(VariableNode).variable
		if not variable.is_predictable continue
		
		if common.is_edited(usage) { variable.writes.add(usage) }
		else { variable.reads.add(usage) }
	}
}

get_text_section(implementation: FunctionImplementation) {
	builder = StringBuilder()

	fullname = implementation.get_fullname()

	load_variable_usages(implementation)

	# Ensure this function is visible to other units
	builder.append(EXPORT_DIRECTIVE)
	builder.append(` `)
	builder.append_line(fullname)

	unit = Unit(implementation)
	unit.mode = UNIT_MODE_ADD

	scope = Scope(unit, implementation.node)

	# Append the function name to the output as a label
	unit.add(LabelInstruction(unit, Label(fullname)))

	# Initialize this function
	unit.add(InitializeInstruction(unit))

	# Parameters are active from the start of the function, so they must be required now otherwise they would become active at their first usage
	parameters = unit.function.parameters

	if (unit.function.metadata.is_member and not unit.function.is_static) or implementation.is_lambda_implementation {
		self = unit.self
		if self == none abort('Missing self pointer in a member function')
		parameters.add(self)
	}

	unit.add(RequireVariablesInstruction(unit, parameters))

	if settings.is_debugging_enabled {
		# calls.move_parameters_to_stack(unit)
	}

	builders.build(unit, implementation.node)
	
	scope.exit()

	loop instruction in unit.instructions { instruction.reindex() }

	# Build:
	unit.scope = none
	unit.stack_offset = 0
	unit.mode = UNIT_MODE_BUILD

	# Reset all registers
	loop register in unit.registers { register.reset() }

	loop (unit.position = 0, unit.position < unit.instructions.size, unit.position++) {
		instruction = unit.instructions[unit.position]
		if instruction.scope == none abort('Missing instruction scope')

		unit.anchor = instruction
		if unit.scope != instruction.scope { instruction.scope.enter() }

		instruction.build()
		instruction.on_simulate()

		# Exit the current scope if its end is reached
		if instruction == unit.scope.end { unit.scope.exit() }
	}

	# Reset the state after this simulation
	unit.mode = UNIT_MODE_NONE

	non_volatile_registers = List<Register>()
	local_memory_top = 0

	loop instruction in unit.instructions {
		if instruction.type != INSTRUCTION_RETURN continue
		instruction.(ReturnInstruction).build(non_volatile_registers, local_memory_top)
	}

	loop instruction in unit.instructions {
		instruction.finish()
	}

	builder.append(unit.string())
	builder.append(`\n`)

	=> builder.string()
}

assemble(context: Context, output_type: large) {
	implementations = common.get_all_function_implementations(context)
	builder = StringBuilder()

	loop implementation in implementations {
		builder.append(get_text_section(implementation))
	}

	=> builder.string()
}

assemble(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_PARSE)) as Optional<Parse> has parse) => Status('Nothing to assemble')
	#if not (bundle.get_integer(String(BUNDLE_OUTPUT_TYPE)) has output_type) => Status('Output type was not specified')
	output_type = BINARY_TYPE_EXECUTABLE

	result = assemble(parse.context, output_type)

	io.write_file('./v.asm', result)

	=> Status()
}