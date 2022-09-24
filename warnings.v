namespace warnings

# Summary: Reports unnecessary casts in the specified node tree
report_unnecessary_casts(diagnostics: List<Status>, root: Node) {
	casts = root.find_all(NODE_CAST)

	loop cast in casts {
		from = cast.first.get_type()
		to = cast.last.get_type()

		if from === to and from.match(to) {
			diagnostics.add(Status(cast.start, 'Cast is not needed'))
		}
	}
}

# Summary: Analyzes the specified node tree and reports warnings
report(diagnostics: List<Status>, root: Node) {
	report_unnecessary_casts(diagnostics, root)
}

# Summary: Returns all variables that are captured by lambdas in the specified function
get_all_captured_variables(implementation: FunctionImplementation): Map<Variable, bool> {
	lambdas = implementation.node.find_all(NODE_LAMBDA) as List<LambdaNode>
	captures = Map<Variable, bool>()

	loop lambda in lambdas {
		if lambda.implementation === none continue

		loop capture in lambda.implementation.(LambdaImplementation).captures {
			captures[capture.captured] = true
		}
	}

	return captures
}

# Summary: Finds all the variables which are not used and reports them
report_unused_variables(diagnostics: List<Status>, implementation: FunctionImplementation) {
	lambdas = implementation.node.find_all(NODE_LAMBDA) as List<LambdaNode>
	captures = get_all_captured_variables(implementation)

	loop variable in implementation.all_variables {
		if variable.usages.size > 0 or captures.contains_key(variable) continue

		# 1. Skip self pointers and hidden variables, because the user can do nothing about them
		# 2. Pack variables are accessed through their proxies, so they are always 'unused'
		if variable.is_self_pointer or variable.is_hidden or variable.type.is_pack continue

		# Do not complain about unused parameters in virtual function overrides
		if variable.is_parameter and implementation.virtual_function !== none continue

		if variable.is_parameter {
			diagnostics.add(Status(variable.position, "Unused parameter " + variable.name))
		}
		else {
			diagnostics.add(Status(variable.position, "Unused local variable " + variable.name))
		}
	}
}

# Summary: Analyzes the specified function implementation tree and reports warnings
report(diagnostics: List<Status>, implementation: FunctionImplementation) {
	if not implementation.is_imported {
		report_unused_variables(diagnostics, implementation)
	}

	report(diagnostics, implementation.node)
}

# Summary: Analyzes the specified context and returns warnings concerning the functions and types in it
report() {
	context = settings.parse.context
	diagnostics = List<Status>()
	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		report(diagnostics, implementation)
	}

	loop diagnostic in diagnostics {
		if diagnostic.position !== none {
			console.write(diagnostic.position.string())
		}
		else {
			console.write('<Source>:<Line>:<Character>')
		}

		console.write(': Warning: ')
		console.write_line(diagnostic.message)
	}
}