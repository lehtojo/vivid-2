namespace conditionals

# Summary: Builds the body of an if-statement or an else-if-statement
build_body(unit: Unit, body: ScopeNode) {
	# Build the body
	result = builders.build(unit, body) as Result

	# Restore the state after the body
	unit.add_debug_position(body.end)
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

	# Jump to the next label based on the comparison
	build_condition(unit, condition, interphase)

	# Build the body of this if-statement
	result = build_body(unit, statement.body)

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

	result = build_body(unit, node.(ElseNode).body)

	=> result
}

start(unit: Unit, node: IfNode) {
	end = LabelInstruction(unit, unit.get_next_label())
	result = build(unit, node, end)
	unit.add(end)

	=> result
}

build_condition(unit: Unit, condition: Node, failure: Label) {
	success = unit.get_next_label()

	instructions = build_condition(unit, condition, success, failure) as List<Instruction>
	instructions.add(LabelInstruction(unit, success))

	build_condition_instructions(unit, instructions)
}

build_condition_instructions(unit: Unit, instructions: List<Instruction>) {
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
			instruction.(TemporaryCompareInstruction).add()
		}
		else {
			unit.add(instruction)
		}
	}
}

TemporaryInstruction TemporaryCompareInstruction {
	private root: Node
	private comparison: Node
	private first => comparison.first
	private last => comparison.last

	init(unit: Unit, comparison: Node) {
		TemporaryInstruction.init(unit, INSTRUCTION_TEMPORARY_COMPARE)
		this.root = none as Node
		this.comparison = comparison
	}

	init(unit: Unit, root: Node, comparison: Node) {
		TemporaryInstruction.init(unit, INSTRUCTION_TEMPORARY_COMPARE)
		this.root = root
		this.comparison = comparison
	}

	add() {
		if root != none {
			# Build the code surrounding the comparison
			instance = comparison.instance
			comparison.instance = NODE_DISABLED
			builders.build(unit, root)
			comparison.instance = instance
		}

		# Build the body
		left = references.get(unit, first, ACCESS_READ)
		right = references.get(unit, last, ACCESS_READ)

		# Compare the two operands
		unit.add(CompareInstruction(unit, left, right))
	}
}

build_condition(unit: Unit, condition: Node, success: Label, failure: Label) {
	if condition.match(NODE_OPERATOR) {
		operation = condition as OperatorNode
		type = operation.operator.type

		if type == OPERATOR_TYPE_LOGICAL => build_logical_condition(unit, operation, success, failure) as List<Instruction>
		if type == OPERATOR_TYPE_COMPARISON => build_comparison(unit, operation, success, failure) as List<Instruction>
	}

	if condition.instance == NODE_PARENTHESIS => build_condition(unit, condition.last, success, failure) as List<Instruction>

	if condition.instance == NODE_INLINE {
		comparison = common.get_source(condition)

		if comparison.instance == NODE_OPERATOR and comparison.(OperatorNode).operator.type == OPERATOR_TYPE_COMPARISON {
			first_type = comparison.first.get_type()
			second_type = comparison.last.get_type()
			unsigned = (first_type.format == FORMAT_DECIMAL or second_type.format == FORMAT_DECIMAL) or (is_unsigned(first_type.format) and is_unsigned(second_type.format))

			instructions = List<Instruction>()
			instructions.add(TemporaryCompareInstruction(unit, condition, comparison))
			instructions.add(JumpInstruction(unit, comparison.(OperatorNode).operator as ComparisonOperator, false, not unsigned, success))
			instructions.add(JumpInstruction(unit, failure))

			=> instructions
		}
	}

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
		instructions.add_all(build_condition(unit, condition.first, interphase, failure))
		instructions.add(LabelInstruction(unit, interphase))
		instructions.add_all(build_condition(unit, condition.last, success, failure))
	}
	else condition.operator == Operators.LOGICAL_OR {
		instructions.add_all(build_condition(unit, condition.first, success, interphase))
		instructions.add(LabelInstruction(unit, interphase))
		instructions.add_all(build_condition(unit, condition.last, success, failure))
	}
	else {
		abort('Unsupported logical operator encountered while building a conditional statement')
	}

	=> instructions
}