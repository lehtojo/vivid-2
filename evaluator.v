namespace evaluator

# Summary: Tries to evaluate the result of the specified expression
evaluate_logical_operator(expression: OperatorNode) {
	if expression.first.match(Operators.LOGICAL_AND) or expression.first.match(Operators.LOGICAL_OR) {
		evaluate_logical_operator(expression.first as OperatorNode)
	}

	if expression.last.match(Operators.LOGICAL_AND) or expression.last.match(Operators.LOGICAL_OR) {
		evaluate_logical_operator(expression.last as OperatorNode)
	}

	if expression.first.instance == NODE_NUMBER {
		is_left_zero = expression.first.(NumberNode).value == 0

		if expression.operator === Operators.LOGICAL_AND {
			if is_left_zero {
				# Condition will never pass and right side will never be executed
				expression.replace(expression.first)
			}
			else {
				# Condition is only dependent on the right side
				expression.replace(expression.last)
			}
		}
		else {
			if is_left_zero {
				# Condition is only dependent on the right side
				expression.replace(expression.last)
			}
			else {
				# Condition will always pass and right side will never be executed
				expression.replace(expression.first)
			}
		}
	}
	else expression.last.instance == NODE_NUMBER {
		is_right_zero = expression.last.(NumberNode).value == 0

		if expression.operator === Operators.LOGICAL_AND {
			if is_right_zero {
				# Condition will always fail, but we still must execute the left side.
				# Leave the right side as it is, because the left side could still pass
			}
			else {
				# Condition is only dependent on the left side
				expression.replace(expression.first)
			}
		}
		else {
			if is_right_zero {
				# Condition is only dependent on the left side
				expression.replace(expression.first)
			}
			else {
				# Condition will always pass, but we still must execute the left side
			}
		}
	}
}

# Summary: Evaluates expressions under the specified node
evaluate_logical_operators(root: Node) {
	loop iterator in root {
		if iterator.match(Operators.LOGICAL_AND) or iterator.match(Operators.LOGICAL_OR) {
			evaluate_logical_operator(iterator as OperatorNode)
		}
		else {
			evaluate_logical_operators(iterator)
		}
	}
}

# Summary: Tries to evaluate the specified conditional statement
evaluate_conditional_statement(root: IfNode) {
	# Ensure the condition is single number node
	condition_container = root.condition_container
	condition = condition_container.first

	# 1. Ensure there is only a single node in the condition
	# 2. Ensure the node is a number
	if condition != condition_container.last or condition.instance != NODE_NUMBER return false

	if condition.(NumberNode).value != 0 {
		# None of the successors will execute
		loop successor in root.get_successors() {
			successor.remove()
		}

		if root.predecessor == none {
			# Since the root node is the first branch, the body can be inlined
			root.replace_with_children(root.body.clone())
		}
		else {
			# Since there is a branch before the root node, the root can be replaced with an else statement
			root.replace(ElseNode(root.body.context, root.body.clone(), root.start, root.body.end))
		}
	}
	else root.successor == none or root.predecessor != none {
		root.remove()
	}
	else {
		if root.successor.instance == NODE_ELSE_IF {
			successor = root.successor as ElseIfNode
			root.replace(IfNode(successor.body.context, successor.condition, successor.body, successor.start, successor.body.end))
			successor.remove()
			return true
		}

		root.replace_with_children(root.successor)
		root.successor.remove()
	}

	return true
}

# Summary: Evaluates conditional statements under the specified node
evaluate_conditional_statements(root: Node) {
	iterator = root.first

	loop (iterator != none) {
		if iterator.instance == NODE_IF {
			if evaluate_conditional_statement(iterator as IfNode) {
				iterator = root.first
			}
			else {
				iterator = iterator.next
			}

			continue
		}
		
		if iterator.instance == NODE_ELSE {
			iterator = iterator.next
			continue
		}
		
		evaluate_conditional_statements(iterator)
		iterator = iterator.next
	}
}

evaluate_compiles_nodes(root: Node) {
	nodes = root.find_all(NODE_COMPILES)

	# Evaluate all compiles nodes
	loop node in nodes {
		result = 1
		if node.find(i -> {
			status = i.get_status()
			return status != none and status.problematic
		}) != none { result = 0 }

		node.replace(NumberNode(SYSTEM_FORMAT, result, node.start))
	}
}

evaluate(node: Node) {
	evaluate_compiles_nodes(node)
	evaluate_logical_operators(node)
	evaluate_conditional_statements(node)
}

evaluate(context: Context) {
	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		evaluate(implementation.node)
	}
}