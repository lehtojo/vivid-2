namespace optimizer

optimize(implementation: FunctionImplementation, root: Node) {
	minimum_cost_snapshot = root
	minimum_cost = expression_optimizer.get_cost(root)

	result = none as Node

	loop (result === none or not result.is_equal(minimum_cost_snapshot)) {
		result = minimum_cost_snapshot

		snapshot = minimum_cost_snapshot.clone()

		if settings.is_mathematical_analysis_enabled {
			assignment_optimizer.assign_variables(implementation, snapshot)
		}

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

	=> result
}

optimize() {
	root = settings.parse.root
	context = settings.parse.context

	implementations = common.get_all_function_implementations(context)
	i = 0

	loop implementation in implementations {
		if settings.is_verbose_output_enabled {
			put(`[`)
			print(++i)
			put(`/`)
			print(implementations.size)
			put(`]`)
			print(' Optimizing ')
			println(implementation.string())
		}

		implementation.node = optimize(implementation, implementation.node)
	}

	# Reload variable usages, because we have modified the functions
	analysis.reset_variable_usages(context)
	analysis.load_variable_usages(context, root)
}