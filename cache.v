RegisterOccupationInfo {
	information: VariableUsageDescriptor
	register: Register

	init(information: VariableUsageDescriptor, register: Register) {
		this.information = information
		this.register = register
	}
}

CacheState {
	unit: Unit
	available_standard_registers: List<Register>
	available_media_registers: List<Register>
	occupied_standard_registers: List<RegisterOccupationInfo> = List<RegisterOccupationInfo>()
	occupied_media_registers: List<RegisterOccupationInfo> = List<RegisterOccupationInfo>()
	remaining_variables: List<VariableUsageDescriptor> = List<VariableUsageDescriptor>()

	# Summary: Occupies the specified register with the specified variable and stores its usage information
	occupy(register: Register, usage: VariableUsageDescriptor) {
		if register.is_media_register {
			available_media_registers.remove(register)
			occupied_media_registers.add(RegisterOccupationInfo(usage, register))
		}
		else {
			available_standard_registers.remove(register)
			occupied_standard_registers.add(RegisterOccupationInfo(usage, register))
		}
	}

	# Summary: occupies the specified register with the specified variable and stores its usage information
	init(register: Register, usage: VariableUsageDescriptor) {
		if register.is_media_register {
			available_media_registers.remove(register)
			occupied_media_registers.add(RegisterOccupationInfo(usage, register))
		}
		else {
			available_standard_registers.remove(register)
			occupied_standard_registers.add(RegisterOccupationInfo(usage, register))
		}
	}

	init(unit: Unit, usages: List<VariableUsageDescriptor>, non_volatile_only: bool) {
		this.unit = unit

		# Retrieve available registers matching the configured mode
		available_standard_registers = none as List<Register>
		available_media_registers = none as List<Register>

		if non_volatile_only {
			available_standard_registers = List<Register>(unit.non_volatile_standard_registers)
		}
		else {
			available_standard_registers = List<Register>(unit.volatile_standard_registers)
			available_standard_registers.add_range(unit.non_volatile_standard_registers)
		}

		if non_volatile_only {
			available_media_registers = List<Register>(unit.non_volatile_media_registers)
		}
		else {
			available_media_registers = List<Register>(unit.volatile_media_registers)
			available_media_registers.add_range(unit.non_volatile_media_registers)
		}

		# Pack all register together for simple iteration
		registers = List<Register>(available_standard_registers)
		registers.add_range(available_media_registers)

		remaining_variables = List<VariableUsageDescriptor>(usages)

		# Find all the usages which are already cached
		loop usage in usages {
			# Try to find a register that contains the current variable
			register = none as Register

			loop iterator in registers {
				if iterator.value != usage.result continue
				register = iterator
				stop
			}

			if register == none continue

			# Remove this variable from the remaining variables list since it is in a correct location
			remaining_variables.remove(usage)

			# The current variable occupies the register so it is not available
			occupy(register, usage)
		}

		# Sort the variables based on their number of usages (the least used variables first)
		sort<RegisterOccupationInfo>(occupied_standard_registers, (a: RegisterOccupationInfo, b: RegisterOccupationInfo) -> a.information.usages - b.information.usages)
		sort<RegisterOccupationInfo>(occupied_media_registers, (a: RegisterOccupationInfo, b: RegisterOccupationInfo) -> a.information.usages - b.information.usages)

		# Sort the variables based on their number of usages (the most used variables first)
		sort<VariableUsageDescriptor>(remaining_variables, (a: VariableUsageDescriptor, b: VariableUsageDescriptor) -> b.usages - a.usages)
	}

	# Summary: Moves the specified variable to memory
	release(usage: VariableUsageDescriptor) {
		if not usage.result.is_any_register return
		unit.release(usage.result.value.(RegisterHandle).register)
	}

	try_get_next_register(usage: VariableUsageDescriptor) {
		use_media_register = usage.result.format == FORMAT_DECIMAL

		registers = available_standard_registers
		if use_media_register { registers = available_media_registers }

		# Try to find a register which holds a value but it is not important anymore
		loop register in registers {
			if register.is_available() => register
		}

		# Try to get the next register
		if registers.size > 0 {
			register = registers.pop_or(none as Register)

			# Clear the register safely, if it holds something
			unit.release(register)
			=> register
		}

		occupied = occupied_standard_registers
		if use_media_register { occupied = occupied_media_registers }

		if occupied.size == 0 => none as Register

		# The current variable is only allowed to take over the used register if it will be more used
		index = -1

		loop (i = 0, i < occupied.size, i++) {
			iterator = occupied[i]
			if iterator.information.usages < usage.usages { index = i }
		}

		if index < 0 => none as Register

		target = occupied[index]

		# Release the removed variable since its register will used with the current variable
		release(target.information)

		occupied.remove_at(index)

		=> target.register
	}
}

# Summary:
# Prepares the specified variables by loading them in priority order
# This instruction is works on all architectures
Instruction CacheVariablesInstruction {
	usages: List<VariableUsageDescriptor>
	roots: List<Node>
	non_volatile_mode: bool

	init(unit: Unit, roots: List<Node>, variables: List<VariableUsageDescriptor>, non_volatile_mode: bool) {
		Instruction.init(unit, INSTRUCTION_CACHE_VARIABLES)
		this.usages = variables
		this.roots = roots
		this.non_volatile_mode = non_volatile_mode
		this.description = String('Prepares the stored variables based on their usage')
		this.is_abstract = true

		# Load all the variables before caching
		loop usage in usages {
			usage.result = references.get_variable(unit, usage.variable, ACCESS_READ)
		}
	}

	# <summary>
	# Summary: Removes all usages which should not be cached
	# </summary>
	filter() {
		# Remove all readonly constants
		loop (i = usages.size - 1, i >= 0, i--) {
			usage = usages[i]

			# If there is no reference, the usage should be skipped and removed
			if usage.result == none {
				usages.remove_at(i)
				continue
			}

			# There is no need to move a constant variable into register if it is not edited inside any of the roots
			edited = false

			loop root in roots {
				if not usage.variable.is_edited_inside(root) continue
				edited = true
				stop
			}

			if not edited and usage.result.is_constant {
				usages.remove_at(i)
				continue
			}
		}

		# Do not load or release variables that have empty values.
		# Scopes will decide the locations of such variables.
		loop (i = usages.size - 1, i >= 0, i--) {
			value = usages[i].result.value
			if value.instance == INSTANCE_NONE usages.remove_at(i)
		}

		# Removed linked variables since they will be handled by the branching system
		loop (i = usages.size - 1, i >= 0, i--) {
			usage = usages[i]

			# The current usage should be removed if it is linked to another variable since it would cause unnecessary move instructions
			loop (j = 0, j < i, j++) {
				if usages[j].result == usage.result {
					usages.remove_at(i)
					stop
				}
			}
		}
	}

	override on_build() {
		# Removes all usages which should not be cached
		filter()

		# Inspect the current state of the unit
		cache = CacheState(unit, usages, non_volatile_mode)
		i = 0

		loop (i < cache.remaining_variables.size, i++) {
			# Try to find a justified register for the variable
			current = cache.remaining_variables[i]
			register = cache.try_get_next_register(current)

			if register == none {
				# There is no register left for the current variable
				continue
			}

			# Relocate the variable to the register
			destination = Result(RegisterHandle(register), current.result.format)
			source = current.result

			instruction = MoveInstruction(unit, destination, source)
			instruction.type = MOVE_RELOCATE
			instruction.description = String('Loads a variable into a register, which supports its future usage')
			unit.add(instruction)
		}

		# Release the remaining variables
		loop (j = i, j < cache.remaining_variables.size, j++) {
			cache.release(cache.remaining_variables[j])
		}
	}
}