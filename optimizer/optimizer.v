namespace optimizer

optimize(context: Context, root: Node) {
	minimum_cost_snapshot = root
	minimum_cost = expression_optimizer.get_cost(root)

	result = none as Node

	loop (result === none or not result.is_equal(minimum_cost_snapshot)) {
		result = minimum_cost_snapshot

		snapshot = minimum_cost_snapshot.clone()

		if settings.is_mathematical_analysis_enabled {
			assignment_optimizer.assign_variables(context, snapshot)
		}

		if settings.is_statement_analysis_enabled {
			statement_optimizer.optimize(context, snapshot)
		}

		# Clean the node tree by removing redundant nodes
		reconstruction.clean(snapshot)

		# Evaluate expressions and statements in the node tree
		evaluator.evaluate(snapshot)

		# Calculate the complexity of the current snapshot
		cost = expression_optimizer.get_cost(snapshot)

		if cost < minimum_cost {
			# Since the current snapshot is less complex it should be used
			minimum_cost_snapshot = snapshot
			minimum_cost = cost
		}

		# Finally, try to simplify all expressions. This is a repetition, but it is needed since some functions do not have variables.
		if settings.is_mathematical_analysis_enabled {
			expression_optimizer.optimize_all_expressions(snapshot)
		}

		# Calculate the complexity of the current snapshot
		cost = expression_optimizer.get_cost(snapshot)

		if cost < minimum_cost {
			# Since the current snapshot is less complex it should be used
			minimum_cost_snapshot = snapshot
			minimum_cost = cost
		}
	}

	return result
}