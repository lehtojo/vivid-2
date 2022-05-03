namespace statement_optimizer

# Summary: Returns whether the specified node might have a direct effect on the flow
is_affector(node: Node) {
	=> node.match(NODE_CALL | NODE_CONSTRUCTION | NODE_DECLARE | NODE_DECREMENT | NODE_DISABLED | NODE_FUNCTION | NODE_INCREMENT | NODE_JUMP | NODE_LABEL | NODE_COMMAND | NODE_RETURN | NODE_OBJECT_LINK | NODE_OBJECT_UNLINK) or (node.instance == NODE_OPERATOR and node.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT)
}

# Summary:
# Removes the specified conditional branch while taking into account other branches
remove_conditional_branch(branch: Node) {
	if branch.instance != NODE_IF and branch.instance != NODE_ELSE_IF {
		branch.remove()
		return
	}

	statement = branch.(IfNode).successor

	# If there is no successor, this statement can be removed completely
	if statement === none {
		branch.remove()
		return
	}

	if statement.instance == NODE_ELSE_IF {
		successor = statement as ElseIfNode

		# Create a conditional statement identical to the successor but as an if-statement
		replacement = IfNode()

		loop node in successor {
			replacement.add(node)
		}

		# Since the specified branch will not be executed, replace it with its successor
		successor.replace(replacement)

		# Continue to execute the code below, so that the if-statement is removed
	}
	else {
		# Replace the specified branch with the body of the successor
		statement.replace_with_children(statement.(ElseNode).body)
		return
	}

	branch.remove()
}

# Summary: Finds statements which can not be reached and removes them
remove_unreachable_statements(root: Node) {
	return_statements = root.find_all(NODE_RETURN)
	removed = false

	loop (i = return_statements.size - 1, i >= 0, i--) {
		return_statement = return_statements[i]

		# Remove all statements which are after the return statement in its scope
		iterator = return_statement.parent.last

		loop (iterator !== return_statement) {
			previous = iterator.previous
			iterator.remove()
			iterator = previous
			removed = true
		}
	}

	=> removed
}

remove_abandoned_statements_in_scope(statement: Node) {
	iterator = statement.first

	loop (iterator !== none) {
		# If the iterator represents a statement, it means it contains affectors, because otherwise it would not exist (statements without affectors are removed below)
		if iterator.match(NODE_IF | NODE_ELSE_IF | NODE_ELSE | NODE_LOOP | NODE_INLINE | NODE_SCOPE | NODE_NORMAL) {
			iterator = iterator.next
			continue
		}

		# Do not remove return values of scopes
		if iterator === statement.last and statement.instance == NODE_SCOPE and statement.(ScopeNode).is_value_returned stop

		# 1. If the statement does not contain any node, which has an effect on the flow (affector), it can be removed
		contains_affector = is_affector(iterator) or iterator.find(i -> is_affector(i)) !== none

		# 2. Remove abandoned allocation function calls
		if not contains_affector or common.get_source(iterator).match(settings.allocation_function) {
			iterator.remove()
		}

		iterator = iterator.next
	}
}

remove_abandoned_conditional_statement(node: Node) {
	statement = node as IfNode

	# 1. The statement can not be removed, if its body is not empty
	# 2. The statement can not be removed, if it has a successor
	if statement.body.first !== none or statement.successor !== none return

	# If the condition has multiple steps, the statement can not be removed
	condition_container = statement.condition_container

	if condition_container.first !== condition_container.last return

	# If the condition contains affectors, the statement can not be removed
	affector = condition_container.find(i -> is_affector(i))
	if affector !== none return

	remove_conditional_branch(statement)
}

# Summary:
# Finds all statements, which do not have an effect on the flow, and removes them
remove_abandoned_expressions(root: Node) {
	statements = root.find_all(NODE_IF | NODE_ELSE_IF | NODE_ELSE | NODE_LOOP | NODE_INLINE | NODE_SCOPE | NODE_NORMAL)
	statements.insert(0, root)
	statements.reverse()

	# Contains all conditions and their node types. The node types are needed because the nodes are disabled temporarily
	conditions = Map<Node, large>()

	# Disable all conditions, so that they are categorized as affectors
	# NOTE: Categorizing conditions as affectors saves us from doing some node tree lookups
	loop statement in statements {
		condition = none as Node

		if statement.match(NODE_IF | NODE_ELSE_IF) {
			condition = statement.(IfNode).condition
		}
		else statement.instance == NODE_LOOP and not statement.(LoopNode).is_forever_loop {
			condition = statement.(LoopNode).condition
		}
		else {
			continue
		}

		conditions[condition] = condition.instance
		condition.instance = NODE_DISABLED
	}

	# Restores the instance of the condition of the specified statement from the condition instance table
	enable_condition = (statement: Node) -> {
		condition = when(statement.instance) {
			NODE_IF => statement.(IfNode).condition,
			NODE_ELSE_IF => statement.(ElseIfNode).condition,
			NODE_LOOP => statement.(LoopNode).condition,
			else => none as Node
		}

		condition.instance = conditions[condition]
	}

	# Disables the condition of the specified statement
	disable_condition = (statement: Node) -> {
		condition = when(statement.instance) {
			NODE_IF => statement.(IfNode).condition,
			NODE_ELSE_IF => statement.(ElseIfNode).condition,
			NODE_LOOP => statement.(LoopNode).condition,
			else => none as Node
		}

		condition.instance = NODE_DISABLED
	}

	loop statement in statements {
		if statement.match(NODE_SCOPE | NODE_NORMAL) {
			remove_abandoned_statements_in_scope(statement)
			continue
		}
		else statement.match(NODE_IF | NODE_ELSE_IF) {
			enable_condition(statement)
			remove_abandoned_conditional_statement(statement)
			disable_condition(statement)
			continue
		}
		else statement.instance == NODE_ELSE {
			# The statement can not be removed, if its body is not empty
			if statement.(ElseNode).body.first !== none continue

			remove_conditional_branch(statement)
			continue
		}
		else statement.instance == NODE_LOOP {
			# TODO: Support removing empty loops
			continue
		}
		else statement.instance == NODE_INLINE {
			# Inline nodes can not be removed, if it is not empty
			if statement.first !== none continue
		}

		statement.remove()
	}

	# Restore the condition node types
	loop iterator in conditions {
		condition = iterator.key
		instance = iterator.value
		condition.instance = instance
	}
}

optimize(implementation: FunctionImplementation, root: Node) {
	remove_unreachable_statements(root)
	remove_abandoned_expressions(root)
}