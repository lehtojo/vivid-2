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
			return false
		}

		if access == ACCESS_TYPE_WRITE { variable.writes.add(usage) }
		else { variable.reads.add(usage) }
	}

	return true
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
			resolver.output(Status(variable.position, "Value for constant " + variable.name + ' is never assigned'))
			application.exit(1)
		}

		if variable.writes.size > 1 {
			resolver.output(Status(variable.position, "Value for constant " + variable.name + ' is assigned more than once'))
			application.exit(1)
		}

		value = evaluate_constant(variable)

		if value === none {
			resolver.output(Status(variable.position, "Could not evaluate a constant value for " + variable.name))
			application.exit(1)
		}

		loop usage in variable.reads {
			# If the parent of the constant is a link node, it needs to be replaced with the value of the constant
			destination = usage
			if usage.previous !== none and usage.parent !== none and usage.parent.instance == NODE_LINK { destination = usage.parent }

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

# Summary: Evaluates the value of the specified constant and returns it. If evaluation fails, none is returned.
evaluate_constant(variable: Variable, trace: Map<Variable, bool>) {
	# Ensure we do not enter into an infinite evaluation cycle
	if trace.contains_key(variable) return none as Node
	trace[variable] = true

	# Verify there is exactly one definition for the specified constant
	analysis.classify_variable_usages(variable)

	writes = variable.writes
	if writes.size !== 1 return none as Node

	write = variable.writes[].parent
	if write === none or not write.match(Operators.ASSIGN) return none as Node

	# Extract the definition for the constant
	value = common.get_source(write.last)

	# If the current value is a constant, we can just stop
	if value.match(NODE_NUMBER | NODE_STRING) return write.last

	# Find other constant from the extracted definition
	dependencies = value.find_all(NODE_VARIABLE).filter(i -> i.(VariableNode).variable.is_constant)

	if value.instance === NODE_VARIABLE and value.(VariableNode).variable.is_constant {
		dependencies = [ value ]
	}

	evaluation = none as Node

	# Evaluate the dependencies
	loop dependency in dependencies {
		# If the evaluation of the dependency fails, the whole evaluation fails as well
		evaluation = evaluate_constant(dependency.(VariableNode).variable, trace)
		if evaluation === none return none as Node

		# If the parent of the dependency is a link node, it needs to be replaced with the value of the dependency
		destination = dependency
		if dependency.previous !== none and dependency.parent !== none and dependency.parent.instance == NODE_LINK { destination = dependency.parent }

		# Replace the dependency with its value
		destination.replace(evaluation)
	}

	# Update the value, because it might have been replaced
	value = common.get_source(write.last)

	# Since all of the dependencies were evaluated successfully, we can try evaluating the value of the specified constant
	evaluation = expression_optimizer.get_simplified_value(value)
	if not evaluation.match(NODE_NUMBER | NODE_STRING) return none as Node

	value.replace(evaluation)
	return write.last
}

# Summary: Evaluates the value of the specified constant and returns it. If evaluation fails, none is returned.
evaluate_constant(variable: Variable) {
	return evaluate_constant(variable, Map<Variable, bool>())
}

# Summary: Finds all the constant usages in the specified node tree and inserts the values of the constants into their usages
apply_constants_into(root: Node) {
	usages = root.find_all(NODE_VARIABLE).filter(i -> i.(VariableNode).variable.is_constant)

	loop usage in usages {
		value = evaluate_constant(usage.(VariableNode).variable)
		if value === none continue

		# If the parent of the constant is a link node, it needs to be replaced with the value of the constant
		destination = usage
		if usage.previous !== none and usage.parent !== none and usage.parent.instance == NODE_LINK { destination = usage.parent }

		destination.replace(value.clone())
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

	# Classify usages of variables inside functions
	loop implementation in implementations {
		loop variable in implementation.all_variables {
			classify_variable_usages(variable)
		}

		if implementation.self != none {
			classify_variable_usages(implementation.self)
		}
	}

	# Classify usages of variables inside types
	loop type in common.get_all_types(context) {
		loop iterator in type.variables {
			variable = iterator.value
			classify_variable_usages(variable)
		}
	}

	# Classify usages of global variables
	loop iterator in context.variables {
		variable = iterator.value
		classify_variable_usages(variable)
	}
}

analyze() {
	root = settings.parse.root
	context = settings.parse.context

	# Update variable usages, because they are needed for analyzing
	reset_variable_usages(context)
	load_variable_usages(context, root)

	# Report warnings at this point, because variables usages are now updated and we have the most information here before reconstruction
	warnings.report()

	# Apply the values of constant variables
	apply_constants(context)

	implementations = common.get_all_function_implementations(context)

	# Rewrite self returning functions, so that they return the modified version of the self argument
	loop implementation in implementations {
		# Process only self returning functions
		if not implementation.return_type.is_self or not implementation.is_member continue

		reconstruction.complete_self_returning_function(implementation)
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