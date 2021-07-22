namespace analysis

analyze(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_PARSE)) as Optional<Parse> has parse) => Status('Nothing to analyze')

	context = parse.context
	implementations = common.get_all_function_implementations(context)
	#resolver.debug_print(context)

	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]
		if implementation.metadata.is_imported continue

		reconstruction.start(implementation, implementation.node)
		reconstruction.end(implementation.node)
	}

	#resolver.debug_print(context)
}

is_used_later(variable: Variable, node: Node) {
	=> is_used_later(variable, node, false)
}

is_used_later(variable: Variable, node: Node, self: bool) {
	=> true
}