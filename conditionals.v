namespace conditionals

# Summary: Builds the body of an if-statement or an else-if-statement
build_body(unit: Unit, body: ScopeNode, active_variables: List<Variable>) {
	scope = Scope(unit, body, active_variables)
	
	# Merges all changes that happen in the scope with the outer scope
	merge = MergeScopeInstruction(unit, scope)

	# Build the body
	result = builders.build(unit, body)

	# Restore the state after the body
	unit.add_debug_position(body.end)
	unit.add(merge)

	scope.exit()
	=> result
}

# Summary: Builds an if-statement or an else-if-statement
build(unit: Unit, statement: IfNode, condition: Node, end: LabelInstruction) {
	# Set the next label to be the end label if there is no successor since then there wont be any other comparisons
	interphase = end.label
	if statement.successor != none { interphase = unit.get_next_label() }

	# Build the nodes around the actual condition by disabling the condition temporarily
	instance = statement.condition.instance
	statement.condition.instance = NODE_DISABLED

	builders.build(unit, statement.first)

	statement.condition.instance = instance

	active_variables = Scope.get_all_active_variables(unit, statement)

	# Jump to the next label based on the comparison
	build_condition(unit, condition, interphase, active_variables)

	# Build the body of this if-statement
	result = build_body(unit, statement.body, active_variables)

	# If the body of the if-statement is executed it must skip the potential successors
	if statement.successor == none => result

	# Skip the next successor from this if-statement's body and add the interphase label
	unit.add(JumpInstruction(unit, end.label))
	unit.add(LabelInstruction(unit, interphase))

	# Build the successor
	=> build(unit, statement.successor, end) as Result
}

build(unit: Unit, node: Node, end: LabelInstruction) {
	unit.add_debug_position(node)

	if node.match(NODE_IF | NODE_ELSE_IF) => build(unit, node as IfNode, node.(IfNode).condition, end)

	active_variables = Scope.get_all_active_variables(unit, node)
	result = build_body(unit, node.(ElseNode).body, active_variables)

	=> result
}

start(unit: Unit, node: IfNode) {
	branches = node.get_branches()
	contexts = List<Context>()

	loop branch in branches {
		if branch.match(NODE_ELSE) {
			contexts.add(branch.(ElseNode).body.context)
			continue
		}

		contexts.add(branch.(IfNode).body.context)
	}

	Scope.cache(unit, branches, contexts, node.get_parent_context())
	Scope.load_constants(unit, node)

	end = LabelInstruction(unit, unit.get_next_label())
	result = build(unit, node, end)
	unit.add(end)

	=> result
}

build_condition(unit: Unit, condition: Node, failure: Label, active_variables: List<Variable>) {
	# Load constants which might be edited inside the condition
	Scope.load_constants(unit, condition, List<Context>())

	success = unit.get_next_label()

	instructions = build_condition(unit, condition, success, failure) as List<Instruction>
	instructions.add(LabelInstruction(unit, success))

	build_condition_instructions(unit, instructions, active_variables)
}

build_condition_instructions(unit: Unit, instructions: List<Instruction>, active_variables: List<Variable>) {
	# Remove all occurrences of the following pattern from the instructions:
	# Jump L0
	# L0:
	loop (i = instructions.size - 2, i >= 0, i--) {
		if instructions[i].type == INSTRUCTION_JUMP and instructions[i + 1].type == INSTRUCTION_LABEL {
			jump = instructions[i] as JumpInstruction
			label = instructions[i + 1] as LabelInstruction

			if not jump.is_conditional and jump.label == label.label instructions.remove_at(i)
		}
	}

	# Replace all occurrences of the following pattern in the instructions:
	# Conditional Jump L0
	# Jump L1
	# L0:
	# =====================================
	# Inverted Conditional Jump L1
	# L0:
	loop (i = instructions.size - 3, i >= 0, i--) {
		if instructions[i].type == INSTRUCTION_JUMP and instructions[i + 1].type == INSTRUCTION_JUMP and instructions[i + 2].type == INSTRUCTION_LABEL {
			conditional_jump = instructions[i] as JumpInstruction
			jump = instructions[i + 1] as JumpInstruction
			label = instructions[i + 2] as LabelInstruction

			if conditional_jump.is_conditional and not jump.is_conditional and conditional_jump.label == label.label and jump.label != label.label {
				conditional_jump.invert()
				conditional_jump.label = jump.label

				instructions.remove_at(i + 1)
			}
		}
	}

	# Remove unused labels
	labels = List<LabelInstruction>()

	loop instruction in instructions {
		if instruction.type != INSTRUCTION_LABEL continue
		labels.add(instruction as LabelInstruction)
	}

	jumps = List<JumpInstruction>()

	loop instruction in instructions {
		if instruction.type != INSTRUCTION_JUMP continue
		jumps.add(instruction as JumpInstruction)
	}

	loop label in labels {
		# Check if any jump instruction uses the current label
		used = false

		loop jump in jumps {
			if jump.label != label.label continue
			used = true
			stop
		}

		# Remove the label if it is not used
		if not used instructions.remove(label)
	}

	# Append all the instructions to the unit
	loop instruction in instructions {
		if instruction.match(INSTRUCTION_TEMPORARY_COMPARE) {
			instruction.(TemporaryCompareInstruction).add(active_variables)
		}
		else {
			unit.add(instruction)
		}
	}
}

TemporaryInstruction TemporaryCompareInstruction {
	private comparison: Node
	private first => comparison.first
	private last => comparison.last

	init(unit: Unit, comparison: Node) {
		TemporaryInstruction.init(unit, INSTRUCTION_TEMPORARY_COMPARE)
		this.comparison = comparison
	}

	add(active_variables: List<Variable>) {
		# Since this is a body of some statement is also has a scope
		scope = Scope(unit, comparison, active_variables)

		# Merges all changes that happen in the scope with the outer scope
		merge = MergeScopeInstruction(unit, scope)

		# Build the body
		left = references.get(unit, first, ACCESS_READ)
		right = references.get(unit, last, ACCESS_READ)

		# Compare the two operands
		unit.add(CompareInstruction(unit, left, right))

		# Restore the state after the body
		unit.add(merge)

		scope.exit()
	}
}

build_condition(unit: Unit, condition: Node, success: Label, failure: Label) {
	if condition.match(NODE_OPERATOR) {
		operation = condition as OperatorNode
		type = operation.operator.type

		if type == OPERATOR_TYPE_LOGICAL => build_logical_condition(unit, operation, success, failure) as List<Instruction>
		if type == OPERATOR_TYPE_COMPARISON => build_comparison(unit, operation, success, failure) as List<Instruction>
	}

	if condition.match(NODE_PARENTHESIS) => build_condition(unit, condition.first, success, failure) as List<Instruction>

	replacement = OperatorNode(Operators.NOT_EQUALS, condition.start)
	condition.replace(replacement)

	replacement.set_operands(condition, NumberNode(SYSTEM_FORMAT, 0, replacement.start))

	=> build_condition(unit, replacement, success, failure) as List<Instruction>
}

build_comparison(unit: Unit, condition: OperatorNode, success: Label, failure: Label) {
	first_type = condition.first.get_type()
	second_type = condition.last.get_type()
	unsigned = (first_type.format == FORMAT_DECIMAL or second_type.format == FORMAT_DECIMAL) or (is_unsigned(first_type.format) and is_unsigned(second_type.format))

	instructions = List<Instruction>()
	instructions.add(TemporaryCompareInstruction(unit, condition))
	instructions.add(JumpInstruction(unit, condition.operator as ComparisonOperator, false, not unsigned, success))
	instructions.add(JumpInstruction(unit, failure))

	=> instructions
}

build_logical_condition(unit: Unit, condition: OperatorNode, success: Label, failure: Label) {
	instructions = List<Instruction>()
	interphase = unit.get_next_label()

	if condition.operator == Operators.LOGICAL_AND {
		instructions.add_range(build_condition(unit, condition.first, interphase, failure))
		instructions.add(LabelInstruction(unit, interphase))
		instructions.add_range(build_condition(unit, condition.last, success, failure))
	}
	else condition.operator == Operators.LOGICAL_OR {
		instructions.add_range(build_condition(unit, condition.first, success, interphase))
		instructions.add(LabelInstruction(unit, interphase))
		instructions.add_range(build_condition(unit, condition.last, success, failure))
	}
	else {
		abort('Unsupported logical operator encountered while building a conditional statement')
	}

	=> instructions
}