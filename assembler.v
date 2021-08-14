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
	is_stack_allocation => value.instance == INSTANCE_STACK_ALLOCATION

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

VariableUsageDescriptor {
	variable: Variable
	result: Result
	usages: large

	init(variable: Variable, usages: large) {
		this.variable = variable
		this.usages = usages
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

	static get_non_local_variable_usage_descriptors(unit: Unit, root: Node, context: Context) {
		descriptors = List<VariableUsageDescriptor>()
		variables: List<Node> = root.find_all(NODE_VARIABLE)

		loop iterator in variables {
			variable = iterator.(VariableNode).variable

			# 1. Analyze only variables, which are not declared inside the specified context
			# 2. Analyze only predictable variables
			if variable.parent.is_inside(context) or not variable.is_predictable continue

			merged = false

			# Try to find an existing descriptor with the same variable and merge them by summing their usage counts
			loop descriptor in descriptors {
				if descriptor.variable != variable continue
				descriptor.usages++
				merged = true
				stop
			}

			if merged continue

			# If the descriptor was not merged, add it to the descriptors
			descriptors.add(VariableUsageDescriptor(variable, 1))
		}

		=> descriptors
	}

	# Summary: Returns information about variable usage in the specified loop
	static get_all_variable_usages(unit: Unit, roots: List<Node>, contexts: List<Context>) {
		if roots.size != contexts.size abort('Each root must have a corresponding context')

		result = List<VariableUsageDescriptor>()

		loop (i = 0, i < roots.size, i++) {
			# Get all non-local variables in the loop and their number of usages
			descriptors = get_non_local_variable_usage_descriptors(unit, roots[i], contexts[i])

			loop descriptor in descriptors {
				merged = false

				# Try to find an existing descriptor with the same variable and merge them by summing their usage counts
				loop other in result {
					if descriptor.variable != other.variable continue
					other.usages += descriptor.usages
					merged = true
					stop
				}

				# If the descriptor was not merged, add it to the result
				if not merged result.add(descriptor)
			}
		}

		# Now, take only the variables, which have been initialized
		loop (i = result.size - 1, i >= 0, i--) {
			descriptor = result[i]
			if unit.is_initialized(descriptor.variable) continue
			result.remove_at(i)
		}

		# Sort the variables based on their number of usages, most used variables first
		sort<VariableUsageDescriptor>(result, (a: VariableUsageDescriptor, b: VariableUsageDescriptor) -> b.usages - a.usages)

		=> result
	}

	# Summary: Tries to move most used variables in the specified loop into registers
	static cache(unit: Unit, root: LoopNode) {
		roots = List<Node>(1, false)
		roots.add(root)
		contexts = List<Context>(1, false)
		contexts.add(root.body.context)
		variables: List<VariableUsageDescriptor> = get_all_variable_usages(unit, roots, contexts)

		# If the the loop contains at least one function, the variables should be cached into non-volatile registers
		non_volatile_mode = root.find(NODE_CALL | NODE_FUNCTION) != none

		unit.add(CacheVariablesInstruction(unit, roots, variables, non_volatile_mode))
	}

	# Summary: Tries to move most used variables in the specified roots into registers
	static cache(unit: Unit, roots: List<Node>, contexts: List<Context>, current: Context) {
		variables: List<VariableUsageDescriptor> = get_all_variable_usages(unit, roots, contexts)

		# Ensure the variables are declared in the current context or in one of its parents
		loop (i = variables.size - 1, i >= 0, i--) {
			if current.is_inside(variables[i].variable.parent) continue
			variables.remove_at(i)
		}

		# If the the roots contain at least one function, the variables should be cached into non-volatile registers
		non_volatile_mode = false

		loop root in roots {
			if root.find(NODE_CALL | NODE_FUNCTION) == none continue
			non_volatile_mode = true
			stop
		}

		unit.add(CacheVariablesInstruction(unit, roots, variables, non_volatile_mode))
	}

	init(unit: Unit, root: Node) {
		this.unit = unit
		this.root = root
		enter()
	}

	init(unit: Unit, root: Node, actives: List<Variable>) {
		this.unit = unit
		this.root = root
		this.actives = List<Variable>(actives)
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
			set_or_create_transition_handle(parameter, references.create_variable_handle(unit, parameter, ACCESS_WRITE), parameter.type.get_register_format())
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

		instruction.reindex()

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
		builder.append(`\n`)
	}

	release(register: Register) {
		value = register.value
		if value == none => register

		if value.is_releasable(this) {
			loop iterator in scope.variables {
				if iterator.value != value continue

				# Get the default handle of the variable
				handle = references.create_variable_handle(this, iterator.key, ACCESS_WRITE)

				# The handle must be a memory handle, otherwise anything can happen
				if handle.type != HANDLE_MEMORY { handle = TemporaryMemoryHandle(this) }

				destination = Result(handle, iterator.key.type.format)

				instruction = MoveInstruction(this, destination, value)
				instruction.description = String('Releases the value into local memory')
				instruction.type = MOVE_RELOCATE

				add(instruction)
				stop
			}
		}
		else {
			destination = Result(TemporaryMemoryHandle(this), value.format)
			instruction = MoveInstruction(this, destination, value)
			instruction.description = String('Releases the value into local memory')
			instruction.type = MOVE_RELOCATE

			add(instruction)
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

	# Summary: Tries to find an available register without releasing a register to memory, while excluding the specified registers
	get_next_register_without_releasing(denylist: List<Register>) {
		loop register in volatile_standard_registers {
			if not denylist.contains(register) and register.is_available() => register
		}

		loop register in non_volatile_standard_registers {
			if not denylist.contains(register) and register.is_available() => register
		}

		=> none as Register
	}

	# Summary: Tries to find an available media register without releasing a register to memory
	get_next_media_register_without_releasing() {
		loop register in media_registers { if register.is_available() => register }
		=> none as Register
	}

	# Summary: Tries to find an available media register without releasing a register to memory, while excluding the specified registers
	get_next_media_register_without_releasing(denylist: List<Register>) {
		loop register in media_registers {
			if not denylist.contains(register) and register.is_available() => register
		}

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

	get_next_string() {
		=> function.get_fullname() + '_S' + to_string(indexer.string)
	}

	get_next_label() {
		=> Label(function.get_fullname() + '_L' + to_string(indexer.label))
	}

	get_next_constant() {
		=> function.get_fullname() + '_C' + to_string(indexer.constant_value)
	}

	get_next_identity() {
		=> function.identity + '.' + to_string(indexer.identity)
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

	get_return_address_register() {
		loop register in registers { if has_flag(register.flags, REGISTER_RETURN_ADDRESS) => register }
		abort('Architecture did not have return address register')
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

	add_debug_position(node: Node) {
		=> add_debug_position(node.start)
	}

	add_debug_position(position: Position) {
		if not settings.is_debugging_enabled => true
		if position as link == none => false

		add(AddDebugPositionInstruction(this, position))

		=> true
	}

	string() {
		=> builder.string()
	}
}

namespace assembler

# Summary: Goes through the specified instructions and returns all non-volatile registers
get_all_used_non_volatile_registers(instructions: List<Instruction>) {
	registers = List<Register>()

	loop instruction in instructions {
		loop parameter in instruction.parameters {
			if not parameter.is_any_register continue

			register = parameter.value.(RegisterHandle).register
			if register.is_volatile or registers.contains(register) continue

			registers.add(register)
		}
	}

	=> registers
}

get_all_handles(results: List<Result>) {
	handles = List<Handle>()

	loop result in results {
		handles.add(result.value)
		handles.add_range(get_all_handles(result.value.get_inner_results()))
	}

	=> handles
}

get_all_handles(instructions: List<Instruction>) {
	handles = List<Handle>()

	loop instruction in instructions {
		loop parameter in instruction.parameters {
			handles.add(parameter.value)
			handles.add_range(get_all_handles(parameter.value.get_inner_results()))
		}
	}

	=> handles
}

# Summary: Collects all variables which are saved using stack memory handles
get_all_saved_local_variables(handles: List<Handle>) {
	variables = List<Variable>()

	loop handle in handles {
		if handle.instance != INSTANCE_STACK_VARIABLE continue
		variables.add(handle.(StackVariableHandle).variable)
	}

	=> variables.distinct()
}

# Summary: Collects all temporary memory handles from the specified handle list
get_all_temporary_handles(handles: List<Handle>) {
	temporary_handles = List<TemporaryMemoryHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_TEMPORARY_MEMORY temporary_handles.add(handle as TemporaryMemoryHandle)
	}

	=> temporary_handles
}

# Summary: Collects all stack allocation handles from the specified handle list
get_all_stack_allocation_handles(handles: List<Handle>) {
	stack_allocation_handles = List<StackAllocationHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_STACK_ALLOCATION stack_allocation_handles.add(handle as StackAllocationHandle)
	}

	=> stack_allocation_handles
}

# Summary: Collects all constant data section handles from the specified handle list
get_all_constant_data_section_handles(handles: List<Handle>) {
	constant_data_section_handles = List<ConstantDataSectionHandle>()

	loop handle in handles {
		if handle.instance == INSTANCE_CONSTANT_DATA_SECTION constant_data_section_handles.add(handle as ConstantDataSectionHandle)
	}

	=> constant_data_section_handles
}

align_function(function: FunctionImplementation) {
	if not settings.is_target_windows {
		standard_register_count = calls.get_standard_parameter_register_count()
		media_register_count = calls.get_decimal_parameter_register_count()

		if standard_register_count == 0 abort('There were no standard registers reserved for parameter passage')

		# The self pointer uses one standard register
		if function.variables.contains_key(String(SELF_POINTER_IDENTIFIER)) or function.variables.contains_key(String(LAMBDA_SELF_POINTER_IDENTIFIER)) {
			standard_register_count--
		}

		position = 0
		if settings.is_x64 { position = SYSTEM_BYTES }

		loop parameter in function.parameters {
			if not parameter.is_parameter continue

			type = parameter.type
			if (type.format == FORMAT_DECIMAL and media_register_count-- > 0) or (type.format != FORMAT_DECIMAL and standard_register_count-- > 0) continue

			parameter.alignment = position
			parameter.is_aligned = true
			position += SYSTEM_BYTES
		}
	}
	else {
		position = SYSTEM_BYTES
		if function.metadata.is_member and not function.metadata.is_static { position += SYSTEM_BYTES }
	
		self = none as Variable

		# Align the this pointer if it exists
		if function.variables.contains_key(String(SELF_POINTER_IDENTIFIER)) {
			self = function.variables[String(SELF_POINTER_IDENTIFIER)]
			self.alignment = position
			self.is_aligned = true
			position += SYSTEM_BYTES
		}
		else function.variables.contains_key(String(LAMBDA_SELF_POINTER_IDENTIFIER)) {
			self = function.variables[String(LAMBDA_SELF_POINTER_IDENTIFIER)]
			self.alignment = position - SYSTEM_BYTES
			position += SYSTEM_BYTES
		}

		# Align the other parameters
		loop parameter in function.parameters {
			if not parameter.is_parameter continue

			parameter.alignment = position
			parameter.is_aligned = true
			position += SYSTEM_BYTES
		}
	}
}

align(context: Context) {
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

# Summary: Align all used local variables and allocate memory for other kinds of local memory such as temporary handles and stack allocation handles
align_local_memory(local_variables: List<Variable>, temporary_handles: List<TemporaryMemoryHandle>, stack_allocation_handles: List<StackAllocationHandle>, top: normal) {
	position = -top

	# Used local variables:
	loop variable in local_variables {
		if variable.is_aligned continue

		position -= variable.type.reference_size
		variable.alignment = position
	}

	# Temporary handles:
	loop (temporary_handles.size > 0) {
		handle = temporary_handles[0]
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
		handle = stack_allocation_handles[0]
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
allocate_constant_data_section_handles(unit: Unit, constant_data_section_handles: List<ConstantDataSectionHandle>) {
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

get_text_section(implementation: FunctionImplementation, constant_section: List<ConstantDataSectionHandle>) {
	builder = StringBuilder()

	fullname = implementation.get_fullname()

	analysis.load_variable_usages(implementation)

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
		required_local_memory += local_variable.type.reference_size
	}

	loop temporary_handle in temporary_handles { required_local_memory += temporary_handle.size }
	loop stack_allocation_handle in stack_allocation_handles { required_local_memory += stack_allocation_handle.bytes }

	# Append a return instruction at the end if there is no return instruction present
	if instructions.size == 0 or instructions[instructions.size - 1].type != INSTRUCTION_RETURN {
		if settings.is_debugging_enabled and unit.function.metadata.end != none {
			instructions.add(AddDebugPositionInstruction(unit, unit.function.metadata.end))
		}

		instructions.add(ReturnInstruction(unit, none as Result, none as Type))
	}

	# If debug information is being generated, append a debug information label at the end
	if settings.is_debugging_enabled {
		# TODO: Support debug end labels
		#end = LabelInstruction(unit, Label(debug.get_end(unit.function).name))
		#end.on_build()

		#instructions.add(end)

		# Find sequential position instructions and separate them using debug break instructions
		loop (i = instructions.size - 2, i >= 0, i--) {
			if instructions[i].type != INSTRUCTION_ADD_DEBUG_POSITION continue
			if instructions[i + 1].type != INSTRUCTION_ADD_DEBUG_POSITION continue

			instructions.insert(i + 1, DebugBreakInstruction(unit))
		}
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
		instruction.(ReturnInstruction).build(non_volatile_registers, local_memory_top)
	}

	# Align all used local variables and allocate memory for other kinds of local memory such as temporary handles and stack allocation handles
	align_local_memory(local_variables, temporary_handles, stack_allocation_handles, local_memory_top)

	# Allocate all constant data section handles
	allocate_constant_data_section_handles(unit, constant_data_section_handles)

	loop instruction in instructions {
		instruction.finish()
	}

	builder.append(unit.string())
	builder.append(`\n`)

	# Export all constant data section handles
	constant_section.add_range(constant_data_section_handles)

	=> builder.string()
}

constant EXPORT_DIRECTIVE = '.global'
constant BYTE_ALIGNMENT_DIRECTIVE = '.balign'
constant POWER_OF_TWO_ALIGNMENT_DIRECTIVE = '.align'
constant STRING_ALLOCATION_DIRECTIVE = '.ascii'
constant BYTE_ZERO_ALLOCATOR = '.zero'
constant SECTION_RELATIVE_DIRECTIVE = '.secrel'
constant SECTION_DIRECTIVE = '.section'
constant TEXT_SECTION_DIRECTIVE = '.section .text'
constant DATA_SECTION_DIRECTIVE = '.section .data'
constant SYNTAX_REQUIREMENT_DIRECTIVE = '.intel_syntax noprefix'

constant X64_ASSEMBLER = 'x64-as'
constant ARM64_ASSEMBLER = 'arm64-as'

constant X64_LINKER = 'x64-ld'
constant ARM64_LINKER = 'arm64-ld'

add_linux_x64_header(entry_function_call: String) {
	builder = StringBuilder()
	builder.append_line('.global _start')
	builder.append_line('_start:')
	builder.append_line(entry_function_call)
	builder.append_line('mov rdi, rax')
	builder.append_line('mov rax, 60')
	builder.append_line('syscall')
	builder.append(`\n`)
	=> builder.string()
}

add_windows_x64_header(entry_function_call: String) {
	builder = StringBuilder()
	builder.append_line('.global main')
	builder.append_line('main:')
	builder.append_line(entry_function_call)
	builder.append(`\n`)
	=> builder.string()
}

add_linux_arm64_header(entry_function_call: String) {
	builder = StringBuilder()
	builder.append_line('.global _start')
	builder.append_line('_start:')
	builder.append_line(entry_function_call)
	builder.append_line('mov x8, #93')
	builder.append_line('svc #0')
	builder.append(`\n`)
	=> builder.string()
}

add_windows_arm64_header(entry_function_call: String) {
	builder = StringBuilder()
	builder.append_line('.global main')
	builder.append_line('main:')
	builder.append_line(entry_function_call)
	builder.append(`\n`)
	=> builder.string()
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

	=> groups
}

get_static_variables(type: Type) {
	builder = StringBuilder()

	loop iterator in type.variables {
		variable = iterator.value
		if not variable.is_static continue

		name = variable.get_static_name()
		size = variable.type.reference_size

		builder.append(EXPORT_DIRECTIVE)
		builder.append(` `)
		builder.append_line(name)

		if not settings.is_x64 {
			builder.append(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
			builder.append_line(' 3')
		}

		builder.append(name)
		builder.append(': ')
		builder.append(BYTE_ZERO_ALLOCATOR)
		builder.append(` `)
		builder.append_line(to_string(size))
	}

	=> builder.string()
}

add_table_label(label: TableLabel) {
	if label.declare => label.name + `:`
	if label.is_section_relative => String(SECTION_RELATIVE_DIRECTIVE) + to_string(label.size * 8) + ` ` + label.name
	=> String(to_data_section_allocator(label.size)) + ` ` + label.name
}

add_table(builder: StringBuilder, table: Table) {
	if table.is_built return
	table.is_built = true

	if table.is_section {
		builder.append(SECTION_DIRECTIVE)
		builder.append(` `)
		builder.append_line(table.name)
	}
	else {
		builder.append_line(String(EXPORT_DIRECTIVE) + ` ` + table.name)

		if not settings.is_x64 {
			builder.append(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
			builder.append_line(' 3')
		}

		builder.append(table.name)
		builder.append(':\n')
	}

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

		builder.append_line(result)

		if item.type == TABLE_ITEM_TABLE_REFERENCE {
			subtable = item.(TableReferenceTableItem).value
			if not subtable.is_built subtables.add(subtable)
		}
	}

	builder.append('\n\n')
	
	# Build the subtables
	loop subtable in subtables { add_table(builder, subtable) }
}

# Summary: Returns a list of directives, which allocate the specified string
allocate_string(text: String) {
	builder = StringBuilder()
	position = 0

	loop (position < text.length) {
		end = position

		loop (end < text.length and text[end] != `\\`, end++) {}

		buffer = text.slice(position, end)
		position += buffer.length

		if buffer.length > 0 {
			builder.append(STRING_ALLOCATION_DIRECTIVE)
			builder.append(' \"')
			builder.append(buffer)
			builder.append_line(`\"`)
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
			builder.append(`\\` as large)
			continue
		}
		else {
			abort(String('Can not understand string command ') + String(command))
		}

		hexadecimal = text.slice(position, position + length)

		if not (hexadecimal_to_integer(hexadecimal) has value) abort(error)

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

	=> builder.string()
}

# Summary: Returns the bytes which represent the specified value
get_bytes<T>(value: T) {
	bytes = List<byte>()

	# Here we loop over each byte of the value and add them into the list
	loop (i = 0, i < sizeof(T), i++) {
		slide = i * 8
		mask = 255 <| slide
		bytes.add([value & mask] |> slide)
	}

	=> bytes
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
			text = String.join(String(', '), values)
			allocator = BYTE_ALLOCATOR
		}
		else {
			text = to_string(item.(NumberDataSectionHandle).value)
			allocator = QUAD_ALLOCATOR
		}

		if settings.is_x64 { builder.append_line(String(BYTE_ALIGNMENT_DIRECTIVE) + ' 16') }
		else { builder.append_line(String(POWER_OF_TWO_ALIGNMENT_DIRECTIVE) + ' 3') }

		builder.append(name)
		builder.append_line(`:`)
		builder.append(allocator)
		builder.append(` `)
		builder.append_line(text)
	}

	=> builder.string()
}

# Summary: Constructs file specific data sections based on the specified context
get_data_sections(context: Context) {
	sections = Map<SourceFile, StringBuilder>()
	
	all_types = common.get_all_types(context)
	loop (i = all_types.size - 1, i >= 0, i--) { if all_types[i].position as link == none all_types.remove_at(i) }
	types = group_by<Type, SourceFile>(all_types, (i: Type) -> i.position.file)

	# Add static variables
	loop iterator in types {
		builder = StringBuilder()

		loop type in iterator.value {
			builder.append_line(get_static_variables(type))
			builder.append('\n\n')
		}

		sections.add(iterator.key, builder)
	}

	# Add runtime type information
	loop iterator in types {
		builder = sections[iterator.key]

		loop type in iterator.value {
			# 1. Skip if the runtime configuration has not been created
			# 2. Imported types are already exported
			# 3. The template type must be a variant
			if type.configuration == none or type.is_imported or (type.is_template_type and not type.is_template_type_variant) continue
			add_table(builder, type.configuration.entry)
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
			nodes.add_range(implementation.node.find_all(NODE_STRING) as List<StringNode>)
		}

		builder = none as StringBuilder

		if sections.contains_key(iterator.key) { builder = sections[iterator.key] }
		else { builder = StringBuilder() }

		loop node in nodes {
			if node.identifier as link == none continue

			if settings.is_x64 {
				builder.append(BYTE_ALIGNMENT_DIRECTIVE)
				builder.append_line(' 16')
			}
			else {
				builder.append(POWER_OF_TWO_ALIGNMENT_DIRECTIVE)
				builder.append_line(' 3')
			}

			builder.append(node.identifier)
			builder.append(':\n')
			builder.append_line(allocate_string(node.text))
		}

		sections[iterator.key] = builder
	}

	=> sections
}

get_text_sections(context: Context, constant_sections: Map<SourceFile, List<ConstantDataSectionHandle>>) {
	sections = Map<SourceFile, String>()

	all = common.get_all_function_implementations(context)

	loop (i = all.size - 1, i >= 0, i--) {
		implementation = all[i]
		if implementation.metadata.is_imported or implementation.metadata.start as link == none all.remove_at(i)
	}

	implementations = group_by<FunctionImplementation, SourceFile>(all, (i: FunctionImplementation) -> i.metadata.start.file)

	loop iterator in implementations {
		constant_section = List<ConstantDataSectionHandle>()
		builder = StringBuilder()

		loop implementation in iterator.value {
			builder.append(get_text_section(implementation, constant_section))
			builder.append('\n\n')
		}

		sections.add(iterator.key, builder.string())
		constant_sections.add(iterator.key, constant_section)
	}

	=> sections
}

# Summary: Removes unnecessary line endings
beautify(text: String) {
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

	=> builder.string()
}

# Summary: Creates an assembler header for the specified file from the specified context. Depending on the situation, the header might be empty or it might have a entry function call and other directives.
create_header(context: Context, file: SourceFile) {
	header = StringBuilder()
	header.append_line(TEXT_SECTION_DIRECTIVE)

	if settings.is_x64 header.append_line(SYNTAX_REQUIREMENT_DIRECTIVE)

	selector = context.get_function(String('init'))
	if selector == none or selector.overloads.size == 0 abort('Missing entry function')

	overload = selector.overloads[0]
	if overload.implementations.size == 0 abort('Missing entry function')

	# Now, if an internal initialization function is defined, we need to call it and it is its responsibility to call the user defined entry function
	entry_function_implementation = overload.implementations[0]

	implementation = entry_function_implementation
	if settings.initialization_function != none { implementation = settings.initialization_function }

	# Add the entry function call only into the file, which contains the actual entry function
	if implementation.metadata.start.file != file => header.string()

	if settings.is_x64 {
		if settings.is_target_windows { header.append(add_windows_x64_header(String(instructions.x64.JUMP) + ` ` + implementation.get_fullname())) }
		else { header.append(add_linux_x64_header(String(instructions.x64.CALL) + ` ` + implementation.get_fullname())) }
	}
	else {
		if settings.is_target_windows { header.append(add_windows_arm64_header(String(instructions.arm64.JUMP_LABEL) + ` ` + implementation.get_fullname())) }
		else { header.append(add_linux_arm64_header(String(instructions.arm64.CALL) + ` ` + implementation.get_fullname())) }
	}

	=> header.string()
}

run(executable: link, arguments: List<String>) {
	command = String(executable) + ` ` + String.join(` `, arguments)
	pid = io.shell(command)
	io.wait_for_exit(pid)
	=> Status()
}

assemble(context: Context, files: List<SourceFile>, output_type: large) {
	align(context)

	constant_sections = Map<SourceFile, List<ConstantDataSectionHandle>>()
	text_sections = get_text_sections(context, constant_sections)
	data_sections = get_data_sections(context)

	assemblies = Map<SourceFile, String>()

	loop file in files {
		header = create_header(context, file)

		text_section = String.empty
		if text_sections.contains_key(file) { text_section = text_sections[file] }

		data_section = String.empty
		if data_sections.contains_key(file) {  data_section = String(DATA_SECTION_DIRECTIVE) + `\n` + data_sections[file].string() }

		constant_section = String.empty
		if constant_sections.contains_key(file) { constant_section = get_constant_section(constant_sections[file]) }

		result = header + '\n\n' + text_section + '\n\n' + data_section + '\n\n' + constant_section
		assemblies.add(file, beautify(result))
	}

	=> assemblies
}

# Summary: Compiles the specified input file and exports the result with the specified output filename
compile_assembly(bundle: Bundle, input_file: String, output_file: String) {
	keep_assembly = bundle.get_bool(String(BUNDLE_ASSEMBLY), false)
	arguments = List<String>()

	# Add output file, input file and enable debug information using the arguments
	arguments.add(String('-o'))
	arguments.add(output_file)
	arguments.add(input_file)
	arguments.add(String('--gdwarf2'))

	# Now determine the assembler to use
	assembler = ARM64_ASSEMBLER
	if settings.is_x64 { assembler = X64_ASSEMBLER }

	status = run(assembler, arguments)

	# Delete the assembly file if it was not requested to keep it
	# TODO: Enable
	# if not keep_assembly io.delete(input_file)

	=> status
}

# Summary: Links the specified input file with necessary system files and produces an executable with the specified output filename
link_object_files(bundle: Bundle, input_files: List<String>, output_file: String, output_type: large) {
	arguments = List<String>()

	# Determine the standard library object file to use
	standard_library = 'libv.o'
	if settings.is_target_windows { standard_library = 'libv.obj' }

	if output_type != BINARY_TYPE_EXECUTABLE {
		extension = '.so'
		if settings.is_target_windows { extension = '.dll' }

		arguments.add(String('--shared'))
		arguments.add(String('-o'))
		arguments.add(output_file + extension)
	}
	else {
		if settings.is_target_windows { output_file = output_file + '.exe' }
		arguments.add(String('-o'))
		arguments.add(output_file)
	}

	# If the target is Windows, we need to add some default system libraries
	if settings.is_target_windows {
		arguments.add(String('-lkernel32'))
		arguments.add(String('-luser32'))
		arguments.add(String('-L C:/Windows/System32'))
		arguments.add(String('-e main'))
	}

	arguments.add(String(standard_library))
	arguments.add_range(input_files)

	# Determine the linker to use
	linker = ARM64_LINKER
	if settings.is_x64 { linker = X64_LINKER }

	=> run(linker, arguments)
}

assemble(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_PARSE)) as Optional<Parse> has parse) => Status('Nothing to assemble')
	if not (bundle.get_object(String(BUNDLE_FILES)) as Optional<Array<SourceFile>> has files) => Status('Missing files')
	if not (bundle.get_object(String(BUNDLE_OBJECTS)) as Optional<List<String>> has objects) => Status('Missing object files')

	output_type = bundle.get_integer(String(BUNDLE_OUTPUT_TYPE), BINARY_TYPE_EXECUTABLE)
	output_name = bundle.get_object(String(BUNDLE_OUTPUT_NAME), String('v') as link) as String

	assemblies = assemble(parse.context, files.to_list(), output_type)

	# Output the assemblies into their own files
	loop iterator in assemblies {
		assembly_file = String('./') + output_name + `.` + iterator.key.filename_without_extension() + '.asm'
		io.write_file(assembly_file, iterator.value)
	}

	# Determine the object file extension based on the current platform
	object_file_extension = '.o'
	if settings.is_target_windows { object_file_extension = '.obj' }

	object_files = List<String>(objects)

	loop iterator in assemblies {
		assembly_file = String('./') + output_name + `.` + iterator.key.filename_without_extension() + '.asm'
		object_file = String('./') + output_name + `.` + iterator.key.filename_without_extension() + object_file_extension
		object_files.add(object_file)

		# Compile the assembly file into an object file
		status = compile_assembly(bundle, assembly_file, object_file)

		# If the compilation failed, we need to abort
		if status.problematic => status
	}

	# Finally, we need to link all the object files into a single executable
	=> link_object_files(bundle, object_files, output_name, output_type)
}