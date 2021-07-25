namespace loops

# Summary: Builds a loop control instruction such as continue and stop
build_control_instruction(unit: Unit, node: CommandNode) {
	if node.container == none abort('Loop control instruction was not inside a loop')

	# TODO: Condition support
	#if node.condition != none arithmetic.build_condition(unit, node.condition)

	unit.add(MergeScopeInstruction(unit, node.container.scope))

	label = none as Label

	if node.instruction == Keywords.STOP {
		label = node.container.exit_label
	}
	else node.instruction == Keywords.CONTINUE {
		label = node.container.continue_label
	}
	else {
		abort('Unknown loop control instruction')
	}

	if label == none abort('Missing control node label')

	#if node.condition != none => JumpInstruction(unit, node.condition.operator, false, not node.condition.is_decimal, label).add()

	=> JumpInstruction(unit, label).add()
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

	# Initialization of the condition happens twice, therefore inner labels can duplicate
	inlines.localize_labels(unit.function, statement.initialization.next)

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
	contexts = List<Context>(2, false)
	contexts.add(statement.context)
	contexts.add(statement.body.context)
	Scope.load_constants(unit, statement, contexts)

	# Register the start and exit label to the loop for control keywords
	statement.start_label = unit.get_next_label()
	statement.continue_label = statement.start_label
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
	contexts = List<Context>(1, false)
	contexts.add(statement.body.context)
	Scope.load_constants(unit, statement, contexts)

	# Try to find a loop control node which targets the current loop
	# If even one is found, this loop needs a continue label
	if statement.body.find(i -> i.instance == NODE_COMMAND and i.(CommandNode).instruction == Keywords.CONTINUE and i.(CommandNode).container == statement) != none {
		# Append a label which can be used by the continue-commands
		statement.continue_label = unit.get_next_label()
		unit.add(LabelInstruction(unit, statement.continue_label))
	}

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
	failure = unit.get_next_label()

	instructions = conditionals.build_condition(unit, condition, success, failure)
	instructions.add(LabelInstruction(unit, failure))

	conditionals.build_condition_instructions(unit, instructions, unit.scope.actives)
}