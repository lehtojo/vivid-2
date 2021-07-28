namespace evaluator

evaluate_compiles_nodes(implementation: FunctionImplementation) {
	nodes = implementation.node.find_all(NODE_COMPILES)

	# Evaluate all compiles nodes
	loop node in nodes {
		result = 1
		if node.find(i -> {
			status = i.get_status()
			=> status != none and status.problematic
		}) != none { result = 0 }

		node.replace(NumberNode(SYSTEM_FORMAT, result, node.start))
	}
}

evaluate(context: Context) {
	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		evaluate_compiles_nodes(implementation)
	}
}