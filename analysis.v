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
	}

	if settings.is_function_inlining_enabled {
		# Perform inline optimizations
		inliner.optimize(context)
	}

	# End reconstruction now that inlining has been completed
	loop (i = 0, i < implementations.size, i++) {
		implementation = implementations[i]
		reconstruction.end(implementation.node)
	}

	#resolver.debug_print(context)

	configure_static_variables(context)
	reset_variable_usages(context)
	load_variable_usages(context, root)
}