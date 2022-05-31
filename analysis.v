namespace analysis

# Summary: Loads all variable usages from the specified function
load_variable_usages(implementation: FunctionImplementation) {
	# Reset all parameters and locals
	loop variable in implementation.all_variables {
		variable.usages.clear()
		variable.writes.clear()
		variable.reads.clear()
	}

	self = implementation.self

	if self != none {
		self.usages.clear()
		self.writes.clear()
		self.reads.clear()
	}

	usages = implementation.node.find_all(NODE_VARIABLE)

	loop usage in usages {
		variable = usage.(VariableNode).variable
		if not variable.is_predictable continue
		
		if common.is_edited(usage) { variable.writes.add(usage) }
		else { variable.reads.add(usage) }
		variable.usages.add(usage)
	}
}

# Summary:
# Iterates through the usages of the specified variable and adds them to 'write' and 'read' lists accordingly.
# Returns whether the usages were added or not. This function does not add the usages, if the access type of an usage can not be determined accurately.
classify_variable_usages(variable: Variable) {
	variable.writes.clear()
	variable.reads.clear()

	loop usage in variable.usages {
		access = common.try_get_access_type(usage)

		# If the access type is unknown, accurate information about usages is not available, therefore we must abort
		if access == ACCESS_TYPE_UNKNOWN {
			variable.writes.clear()
			variable.reads.clear()
			=> false
		}

		if access == ACCESS_TYPE_WRITE { variable.writes.add(usage) }
		else { variable.reads.add(usage) }
	}

	=> true
}

# Summary: Inserts the values of the constants in the specified into their usages
apply_constants(context: Context) {
	loop iterator in context.variables {
		variable = iterator.value
		if not variable.is_constant continue

		# Try to categorize the usages of the constant
		# If no accurate information is available, the value of the constant can not be inlined
		if not classify_variable_usages(variable) continue

		if variable.writes.size == 0 {
			resolver.output(Status(variable.position, String('Value for constant ') + variable.name + ' is never assigned'))
			application.exit(1)
		}

		if variable.writes.size > 1 {
			resolver.output(Status(variable.position, String('Value for constant ') + variable.name + ' is assigned more than once'))
			application.exit(1)
		}

		write = variable.writes[0].parent

		if write == none or not write.match(Operators.ASSIGN) {
			resolver.output(Status(variable.position, String('Invalid assignment for constant ') + variable.name))
			application.exit(1)
		}

		value = common.get_source(write.last)

		if not value.match(NODE_NUMBER) and not value.match(NODE_STRING) {
			resolver.output(Status(variable.position, String('Value assigned to constant ') + variable.name + ' is not a constant'))
			application.exit(1)
		}

		loop usage in variable.reads {
			destination = usage

			# If the parent of the constant is a link node, it needs to be replaced with the value of the constant
			# Example:
			# namespace A { C = 0 }
			# print(A.C) => print(0)
			if usage.parent != none and usage.parent.match(NODE_LINK) { destination = usage.parent }
			destination.replace(value.clone())
		}
	}

	loop subcontext in context.subcontexts {
		apply_constants(subcontext)
	}

	loop type in context.types {
		apply_constants(type.value)
	}
}

# Summary: Finds all the constant usages in the specified node tree and inserts the values of the constants into their usages
apply_constants(root: Node) {
	usages = root.find_all(NODE_VARIABLE).filter(i -> i.(VariableNode).variable.is_constant)

	loop usage in usages {
		usage_variable = usage.(VariableNode).variable
		analysis.classify_variable_usages(usage_variable)

		if usage_variable.writes.size == 0 abort(String('Value for the constant ') + usage_variable.name + ' is never assigned')
		if usage_variable.writes.size > 1 abort(String('Value for the constant ') + usage_variable.name + ' is assigned more than once')

		write = usage_variable.writes[0].parent

		if write == none or not write.match(Operators.ASSIGN) abort(String('Invalid assignment for ') + usage_variable.name)
		
		value = common.get_source(write.last)
		if value.instance != NODE_NUMBER and value.instance != NODE_STRING abort(String('Value assigned to ') + usage_variable.name + ' is not a constant')

		destination = usage

		# If the parent of the constant is a link node, it needs to be replaced with the value of the constant
		# Example:
		# namespace A { C = 0 }
		# print(A.C) => print(0)
		if usage.parent != none and usage.parent.instance == NODE_LINK { destination = usage.parent }

		destination.replace(write.last.clone())
	}
}

# Summary: Processes static variables
configure_static_variables(context: Context) {
	types = common.get_all_types(context)

	loop type in types {
		loop iterator in type.variables {
			variable = iterator.value

			# Static variables should be treated like global variables
			if variable.is_static { variable.category = VARIABLE_CATEGORY_GLOBAL }
		}
	}
}

# Summary: Resets all variable usages in the specified context
reset_variable_usages(context: Context) {
	loop implementation in common.get_all_function_implementations(context) {
		loop variable in implementation.all_variables {
			variable.usages.clear()
			variable.writes.clear()
			variable.reads.clear()
		}

		self = implementation.self

		if self != none {
			self.usages.clear()
			self.writes.clear()
			self.reads.clear()
		}
	}

	loop type in common.get_all_types(context) {
		loop iterator in type.variables {
			variable = iterator.value
			variable.usages.clear()
			variable.writes.clear()
			variable.reads.clear()
		}
	}

	loop iterator in context.variables {
		variable = iterator.value
		variable.usages.clear()
		variable.writes.clear()
		variable.reads.clear()
	}
}

# Summary: Load all variable usages in the specified context
load_variable_usages(context: Context, root: Node) {
	implementations = common.get_all_function_implementations(context)
	usages = root.find_all(NODE_VARIABLE)

	loop usage in usages {
		usage.(VariableNode).variable.usages.add(usage)
	}

	# Load all usages
	loop implementation in implementations {
		usages = implementation.node.find_all(NODE_VARIABLE)

		loop usage in usages {
			usage.(VariableNode).variable.usages.add(usage)
		}
	}

	# Classify the loaded usages
	loop implementation in implementations {
		loop variable in implementation.all_variables {
			classify_variable_usages(variable)
		}

		if implementation.self != none {
			classify_variable_usages(implementation.self)
		}
	}

	loop type in common.get_all_types(context) {
		loop iterator in type.variables {
			variable = iterator.value
			classify_variable_usages(variable)
		}
	}
}

analyze() {
	root = settings.parse.root
	context = settings.parse.context

	reset_variable_usages(context)
	load_variable_usages(context, root)
	apply_constants(context)

	implementations = common.get_all_function_implementations(context)

	#resolver.debug_print(context)

	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]

		if settings.is_verbose_output_enabled {
			console.put(`[`)
			console.write(i + 1)
			console.put(`/`)
			console.write(implementations.size)
			console.put(`]`)
			console.write(' Reconstructing ')
			console.write_line(implementation.string())
		}

		reconstruction.start(implementation, implementation.node)
	}

	#resolver.debug_print(context)

	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]

		if settings.is_verbose_output_enabled {
			console.put(`[`)
			console.write(i + 1)
			console.put(`/`)
			console.write(implementations.size)
			console.put(`]`)
			console.write(' Optimizing ')
			console.write_line(implementation.string())
		}

		reconstruction.rewrite_pack_usages(implementation, implementation.node)
		implementation.node = optimizer.optimize(implementation, implementation.node)
		reconstruction.end(implementation.node)
	}

	if settings.is_function_inlining_enabled {
		# Perform inline optimizations
		inliner.optimize(context)
	}

	#resolver.debug_print(context)

	configure_static_variables(context)
	reset_variable_usages(context)
	load_variable_usages(context, root)
}

# Summary: Finds the branch which contains the specified node
get_branch(node: Node) {
	=> node.find_parent(NODE_LOOP | NODE_IF | NODE_ELSE_IF | NODE_ELSE)
}

# Summary: If the specified node represents a conditional branch, this function appends the other branches to the specified denylist
deny_other_branches(denylist: List<Node>, node: Node) {
	if node.instance == NODE_IF {
		loop branch in node.(IfNode).get_branches() { if branch != node denylist.add(branch) }
	}
	else node.instance == NODE_ELSE_IF {
		loop branch in node.(ElseIfNode).get_root().get_branches() { if branch != node denylist.add(branch) }
	}
	else node.instance == NODE_ELSE {
		loop branch in node.(ElseNode).get_root().get_branches() { if branch != node denylist.add(branch) }
	}
}

# Summary: Returns whether the specified perspective is inside the condition of the specified branch
is_inside_branch_condition(perspective: Node, branch: Node) {
	if branch.instance == NODE_IF {
		=> perspective == branch.(IfNode).condition_container or perspective.is_under(branch.(IfNode).condition_container)
	}
	else branch.instance == NODE_ELSE_IF {
		=> perspective == branch.(ElseIfNode).condition_container or perspective.is_under(branch.(ElseIfNode).condition_container)
	}
	else branch.instance == NODE_LOOP {
		if branch.(LoopNode).is_forever_loop => false
		=> perspective == branch.(LoopNode).condition_container or perspective.is_under(branch.(LoopNode).condition_container)
	}

	=> false
}

# Summary: Returns nodes whose contents should be taken into account if execution were to start from the specified perspective
get_denylist(perspective: Node) {
	denylist = List<Node>()
	branch = perspective

	loop {
		branch = get_branch(branch)
		if branch == none stop

		# If the perspective is inside the condition of the branch, it can still enter the other branches
		if is_inside_branch_condition(perspective, branch) {
			continue
		}

		deny_other_branches(denylist, branch)
	}

	=> denylist
}

# Summary:
# Returns whether the specified variable will be used in the future starting from the specified node perspective
# NOTE: Usually the perspective node is a branch but it is not counted as one.
# This behavior is required for determining active variables when there is an if-statement followed by an else-if-statement and both of the conditions use same variables.
is_used_later(variable: Variable, perspective: Node, self: bool) {
	# Get a denylist which describes which sections of the node tree have not been executed in the past or will not be executed in the future
	denylist = get_denylist(perspective)

	# If the it is allowed to count the perspective as a branch as well, append the other branches to the denylist
	if self deny_other_branches(denylist, perspective)

	# If any of the references is placed after the specified perspective, the variable is needed
	loop usage in variable.usages {
		# Ensure the variable is used outside the excluded node trees
		skip = false
		
		loop root in denylist {
			if not usage.is_under(root) continue
			skip = true
			stop
		}

		if skip continue

		# If the variable is used after the perspective, return true
		if usage.is_after(perspective) => true
	}

	# No usage of the variable could be found after the perspective, but return true, if the perspective is inside a loop, since past variable usages might be executed again
	=> perspective.find_parent(NODE_LOOP) != none
}

is_used_later(variable: Variable, node: Node) {
	=> is_used_later(variable, node, false)
}