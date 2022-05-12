namespace loops

# Summary: Builds a loop command such as continue and stop
build_command(unit: Unit, node: CommandNode) {
	# Add position of the command node as debug information
	unit.add_debug_position(node.start)

	if node.container == none abort('Loop command was not inside a loop')

	scope = node.container.scope

	if node.instruction == Keywords.STOP {
		# TODO: Support conditions
		#if node.condition != none arithmetic.build_condition(unit, node.condition)

		unit.add(MergeScopeInstruction(unit, scope))
		label = node.container.exit_label

		# TODO: Support conditions
		#if node.condition != none => JumpInstruction(unit, node.condition.operator, false, not node.condition.is_decimal, label).add()

		=> JumpInstruction(unit, label).add()
	}
	else node.instruction == Keywords.CONTINUE {
		statement = node.container
		start = statement.start_label

		if statement.is_forever_loop {
			unit.add(MergeScopeInstruction(unit, scope))
			=> JumpInstruction(unit, start).add()
		}

		# Build the nodes around the actual condition by disabling the condition temporarily
		instance = statement.condition.instance
		statement.condition.instance = NODE_DISABLED

		# Initialization of the condition might happen multiple times, therefore inner labels can duplicate
		inliner.localize_labels(unit.function, statement.initialization.next)

		builders.build(unit, statement.initialization.next)

		statement.condition.instance = instance

		# Prepare for starting the loop again potentially
		unit.add(MergeScopeInstruction(unit, scope))

		# Build the actual condition
		exit = statement.exit_label
		build_end_condition(unit, statement.condition, start, exit)

		=> Result()
	}

	abort('Unknown loop command')
}

# Summary: Builds the body of the specified loop without any of the steps
build_forever_loop_body(unit: Unit, statement: LoopNode, start: LabelInstruction) {
	active_variables = Scope.get_all_active_variables(unit, statement)

	result = none as Result

	scope = Scope(unit, statement.body, active_variables)
	statement.scope = scope

	# Append the label where the loop will start
	unit.add(start)

	# Build the loop body
	result = builders.build(unit, statement.body)

	unit.add_debug_position(statement.body.end)
	unit.add(MergeScopeInstruction(unit, scope))

	scope.exit()
	=> result
}

# Summary: Builds the body of the specified loop with its steps
build_loop_body(unit: Unit, statement: LoopNode, start: LabelInstruction, active_variables: List<Variable>) {
	result = none as Result

	scope = Scope(unit, statement.body, active_variables)

	statement.scope = scope

	# Append the label where the loop will start
	unit.add(start)

	# Build the loop body
	result = builders.build(unit, statement.body)
	
	unit.add_debug_position(statement.body.end)

	if not statement.is_forever_loop {
		# Build the loop action
		builders.build(unit, statement.action)
	}

	unit.add(MergeScopeInstruction(unit, scope))

	# Build the nodes around the actual condition by disabling the condition temporarily
	instance = statement.condition.instance
	statement.condition.instance = NODE_DISABLED

	# Initialization of the condition might happen multiple times, therefore inner labels can duplicate
	inliner.localize_labels(unit.function, statement.initialization.next)

	builders.build(unit, statement.initialization.next)

	statement.condition.instance = instance

	build_end_condition(unit, statement.condition, start.label)

	scope.exit()

	=> result
}

# Summary: Builds the specified forever-loop
build_forever_loop(unit: Unit, statement: LoopNode) {
	start = unit.get_next_label()

	if not settings.is_debugging_enabled {
		# Try to cache loop variables
		Scope.cache(unit, statement)
	}

	# Load constants which might be edited inside the loop
	Scope.load_constants(unit, statement, [ statement.context, statement.body.context ])

	# Register the start and exit label to the loop for control keywords
	statement.start_label = unit.get_next_label()
	statement.exit_label = unit.get_next_label()

	# Append the start label
	unit.add(LabelInstruction(unit, statement.start_label))

	# Build the loop body
	result = build_forever_loop_body(unit, statement, LabelInstruction(unit, start))

	# Jump to the start of the loop
	unit.add(JumpInstruction(unit, start))

	# Append the exit label
	unit.add(LabelInstruction(unit, statement.exit_label))

	=> result
}

# Summary: Builds the specified loop
build(unit: Unit, statement: LoopNode) {
	unit.add_debug_position(statement)

	if statement.is_forever_loop => build_forever_loop(unit, statement)

	# Create the start and end label of the loop
	start = unit.get_next_label()
	end = unit.get_next_label()

	# Register the start and exit label to the loop for control keywords
	statement.start_label = start
	statement.exit_label = end

	# Initialize the loop
	builders.build(unit, statement.initialization)

	if not settings.is_debugging_enabled {
		# Try to cache loop variables
		Scope.cache(unit, statement)
	}

	# Load constants which might be edited inside the loop
	Scope.load_constants(unit, statement, [ statement.body.context ])

	# Build the nodes around the actual condition by disabling the condition temporarily
	instance = statement.condition.instance
	statement.condition.instance = NODE_DISABLED

	builders.build(unit, statement.initialization.next)

	statement.condition.instance = instance

	active_variables = Scope.get_all_active_variables(unit, statement)

	# Jump to the end based on the comparison
	conditionals.build_condition(unit, statement.condition, end, active_variables)

	# Build the loop body
	result = build_loop_body(unit, statement, LabelInstruction(unit, start), active_variables)

	# Append the label where the loop ends
	unit.add(LabelInstruction(unit, end))

	=> result
}

# Summary: Builds the the specified condition which should be placed at the end of a loop
build_end_condition(unit: Unit, condition: Node, success: Label) {
	=> build_end_condition(unit, condition, success, none as Label)
}

# Summary: Builds the the specified condition which should be placed at the end of a loop
build_end_condition(unit: Unit, condition: Node, success: Label, failure: Label) {
	exit = unit.get_next_label()

	instructions = conditionals.build_condition(unit, condition, success, exit)
	instructions.add(LabelInstruction(unit, exit))

	if failure != none instructions.add(JumpInstruction(unit, failure))

	conditionals.build_condition_instructions(unit, instructions, unit.scope.actives)
}