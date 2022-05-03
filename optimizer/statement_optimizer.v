namespace statement_optimizer

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

optimize(implementation: FunctionImplementation, root: Node) {
	remove_unreachable_statements(root)
}