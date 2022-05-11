namespace inliner

constant INLINE_THRESHOLD = 30 # 3 * STANDARD_OPERATOR_COST

# Summary: Finds all the labels under the specified root and localizes them by declaring new labels to the specified context
localize_labels(context: Context, root: Node) {
	# Find all the labels and the jumps under the specified root
	labels = root.find_all(NODE_LABEL) as List<LabelNode>
	jumps = root.find_all(NODE_JUMP) as List<JumpNode>

	# Go through all the labels
	loop label in labels {
		# Create a replacement for the label
		replacement = context.create_label()

		# Find all the jumps which use the current label and update them to use the replacement
		loop (i = jumps.size - 1, i >= 0, i--) {
			jump = jumps[i]
			if jump.label != label.label continue

			jump.label = replacement
			jumps.remove_at(i)
		}

		label.label = replacement
	}
}

# Summary:
# Replaces all the variables created in the specified context with new localized variables.
# This function takes into account the variable node usages as well.
localize_subcontext(context: Context, replacement_context: Context, usages_by_variable: Map<Variable, List<Node>>) {
	loop iterator in context.variables {
		variable = iterator.value

		# Skip the variable if it is the self pointer
		if variable.is_self_pointer continue

		# Create a new variable which represents the original variable and redirect all the usages of the original variable
		replacement_variable = replacement_context.declare_hidden(variable.type)

		# Update the usages of the variable
		if usages_by_variable.contains_key(variable) {
			usages = usages_by_variable[variable]

			loop usage in usages {
				usage.(VariableNode).variable = replacement_variable
			}

			usages_by_variable.remove(variable)
		}

		# TODO: Update declarations?
	}
}

# Summary:
# Finds subcontexts under the specified root and localizes them by declaring new subcontexts to the specified context
localize_subcontexts(context: Context, start: Node, root: Node, usages_by_variable: Map<Variable, List<Node>>) {
	loop node in start {
		subcontext = when(node.instance) {
			NODE_SCOPE => node.(ScopeNode).context,
			NODE_LOOP => node.(LoopNode).context,
			else => none as Context
		}

		if subcontext !== none {
			replacement_context = Context(context, context.type)

			localize_subcontext(subcontext, replacement_context, usages_by_variable)

			# Update the context of the node
			if node.instance == NODE_SCOPE {
				node.(ScopeNode).context = replacement_context
			}
			else node.instance == NODE_LOOP {
				node.(LoopNode).context = replacement_context
			}

			# Go through all its children with the new context
			localize_subcontexts(replacement_context, node, root, usages_by_variable)
			continue
		}

		# Since the node does not have a context, go through all its children
		localize_subcontexts(context, node, root, usages_by_variable)
	}
}

# Summary:
# Initializes all the function parameters at the beginning of the function body with the provided arguments.
insert_parameter_initializations(implementation: FunctionImplementation, arguments: Node, body: Node) {
	# Find all the parameters
	parameters = implementation.parameters
	parameter_index = 0

	loop argument in arguments {
		# Find the parameter which corresponds to the current argument
		parameter = parameters[parameter_index]

		# Assign the current argument to the corresponding parameter
		assignment = OperatorNode(Operators.ASSIGN).set_operands(VariableNode(parameter), argument)

		# Insert the assignment at the beginning of the function body
		body.insert(body.first, assignment)

		# Increment the parameter index
		parameter_index++
	}
}

# Summary:
# Initializes the potential self variable at the beginning of the function body with the provided self argument.
# If the self variable exists, its usages are updated with a localized version of the self argument.
localize_member_access(context: Context, implementation: FunctionImplementation, self_argument: Node, body: Node, usages_by_variable: Map<Variable, List<Node>>) {
	self_pointer = implementation.self

	if self_pointer === none {
		# The function does not have a self pointer, so there is nothing to localize
		return
	}

	# Create a new variable which represents the self pointer and initialize it at the beginning of the function body
	replacement_self_pointer = context.declare_hidden(self_pointer.type)

	assignment = OperatorNode(Operators.ASSIGN).set_operands(VariableNode(replacement_self_pointer), self_argument)
	body.insert(body.first, assignment)

	if usages_by_variable.contains_key(self_pointer) {
			# Replace the usages of the self pointer with the new variable
		usages = usages_by_variable[self_pointer]

		loop usage in usages {
			usage.(VariableNode).variable = replacement_self_pointer
		}

		usages_by_variable.remove(self_pointer)
	}
}

# Summary:
# Replaces return statements with jump nodes that jump to the end of the function body.
# Since the return statements have return values, they are stored to the provided result variable.
rewrite_return_statements_with_values(context: Context, body: Node, result: Variable) {
	# Find all return statements
	return_statements = body.find_all(NODE_RETURN) as List<ReturnNode>

	# Request a label representing the end of the function only if needed
	end = none as Label

	# Replace all the return statements with an assign operator which stores the value to the result variable
	loop return_statement in return_statements {
		# Assign the return value of the function to the variable which represents the result of the function
		assignment = OperatorNode(Operators.ASSIGN).set_operands(VariableNode(result), return_statement.value)

		# If the return statement is the last statement in the function, no need to create a jump
		if return_statement.next === none and return_statement.parent.parent === none {
			# Replace the return statement with the assignment
			return_statement.replace(assignment)
			continue
		}

		# Create a jump to the end of the function
		if end === none {
			end = context.create_label()

			# Initialize the result variable with an empty value at the beginning of the function
			body.insert(body.first, OperatorNode(Operators.ASSIGN).set_operands(VariableNode(result), Node()))

			body.add(JumpNode(end)) # Add this jump because it will trigger label merging
			body.add(LabelNode(end, none as Position))
		}

		# Create a jump node that exits the inlined function since there can be more inlined code after the result is assigned
		jump = JumpNode(end)

		# Replace the return statement with the assignment and the jump
		return_statement.insert(assignment)
		return_statement.replace(jump)
	}

	# Add the return value to the end of the body just in case
	body.add(VariableNode(result))
}

# Summary:
# Replaces return statements with jump nodes that jump to the end of the function body.
rewrite_return_statements_without_values(context: Context, body: Node) {
	# Find all return statements
	return_statements = body.find_all(NODE_RETURN) as List<ReturnNode>

	if return_statements.size == 0 {
		# There are no return statements, so there is nothing to rewrite
		return
	}

	end = context.create_label()

	# Replace each return statement with a jump node which goes to the end of the inlined body
	loop return_statement in return_statements {
		# Create a jump node that exits the inlined function since there can be more inlined code after the result is assigned
		jump = JumpNode(end)

		# Replace the return statement with the jump
		return_statement.replace(jump)
	}

	body.add(JumpNode(end)) # Add this jump because it will trigger label merging
	body.add(LabelNode(end, none as Position))
}

pack State {
	caller: Node
	body: Node
	context: Context
	has_return_value: bool
	is_assigned_to_local: bool
	result: Variable
	implementation: FunctionImplementation
}

# Summary:
# Returns a state containing a node tree that represents the body of the specified function implementation and other related information.
# The returned node tree will not have any connections to the original function implementation.
start_inlining(context: Context, implementation: FunctionImplementation, caller: Node, self_argument: Node, arguments: Node) {
	# Clone the body of the called function, so that we are free to modify it
	body = implementation.node.clone()

	# Initialize the parameters at the beginning of the function body
	insert_parameter_initializations(implementation, arguments, body)

	# Group all variable usages by variable
	usages = body.find_all(NODE_VARIABLE).filter(i -> i.(VariableNode).variable.is_predictable)
	usages_by_variable = assembler.group_by<Node, Variable>(usages, (i: Node) -> i.(VariableNode).variable)

	# Localize all the contexts
	localize_subcontext(implementation, context, usages_by_variable)
	localize_subcontexts(context, body, body, usages_by_variable)

	# Handle the self argument
	localize_member_access(context, implementation, self_argument, body, usages_by_variable)

	has_return_value = not primitives.is_primitive(implementation.return_type, primitives.UNIT)

	is_assigned_to_local = false
	result = none as Variable

	if has_return_value {
		# Determine the variable, which will store the result of the function call.
		# If the function call is assigned to a variable, use that variable. Otherwise, create a new temporary variable.
		is_assigned_to_local = caller.parent.match(Operators.ASSIGN) and caller.previous !== none and caller.previous.instance == NODE_VARIABLE

		if is_assigned_to_local {
			result = caller.previous.(VariableNode).variable
		}
		else {
			result = context.declare_hidden(implementation.return_type)
		}

		rewrite_return_statements_with_values(context, body, result)
	}
	else {
		rewrite_return_statements_without_values(context, body)
	}

	=> pack {
		caller: caller,
		body: body,
		context: context,
		has_return_value: has_return_value,
		is_assigned_to_local: is_assigned_to_local,
		result: result,
		implementation: implementation
	} as State
}

# Summary: Replaces the function call with the body of the specified function using the parameter values of the call
start_inlining(implementation: FunctionImplementation, usage: Node) {
	# Get the root of the function call and the potential self argument
	caller = none as Node
	self_argument = none as Node
	arguments = usage.clone()

	# Verify the function usage is part of a member function call
	if usage.next === none and usage.parent.instance == NODE_LINK {
		caller = usage.parent
		self_argument = usage.previous.clone()
	}
	else {
		caller = usage
	}

	# Create an isolated context for inlining
	environment = usage.get_parent_context()
	context = Context(environment.create_identity(), NORMAL_CONTEXT)

	=> start_inlining(context, implementation, caller, self_argument, arguments)
}

# Summary:
# Finishes inlining the function by inserting the function body into the node tree containing the caller.
finish_inlining(state: State) {
	# Get the environment context surrounding the caller
	environment = state.caller.get_parent_context()

	# Merge the isolated context with the environment context
	environment.merge(state.context)

	# Localize all the labels and subcontexts
	implementation_parent = environment.find_implementation_parent()
	localize_labels(implementation_parent, state.body)

	# Get the node before which to insert the body of the called function
	insertion_position = reconstruction.get_expression_extract_position(state.caller)
	insertion_position.insert_children(state.body)

	if state.has_return_value {
		# 1. If the function call was assigned to a local variable,
		# the return statements were replaced with assignments to the local variable.
		# Therefore, the assignment created by the user is no longer needed after the inlined body.
		# 2. If the function call was not assigned to a local variable (complex destination or complex usage),
		# the return statements were replaced with assignments to a temporary variable.
		# The function call created by the user after the inlined body must be replaced with the temporary variable.
		if state.is_assigned_to_local {
			assignment = state.caller.parent
			assignment.remove()
		}
		else {
			state.caller.replace(VariableNode(state.result))
		}
	}
	else {
		# If a value is expected to return even though the function does not return a value, replace the function call with an undefined value
		if common.is_value_used(state.caller) {
			state.caller.replace(UndefinedNode(state.implementation.return_type, SYSTEM_FORMAT))
		}
		else {
			state.caller.remove()
		}
	}
}

# Summary:
# Returns whether the called function can be inlined. Do not inline when recursion is detected.
is_inlinable(destination: FunctionImplementation, called: FunctionImplementation) {
	calls = called.node.find_all(NODE_FUNCTION)

	loop call in calls {
		if call.(FunctionNode).function === called => false
	}

	=> called !== destination
}

# Summary:
# Returns cost for inlining the specified function that is based on general heuristics.
heuristical_cost(called: FunctionImplementation, arguments: Node) {
	# If the arguments contain constants, inlining is likely to be a win.
	loop argument in arguments {
		if common.is_constant(argument) => INLINE_THRESHOLD
	}

	# If the called function returns a constant, inlining is likely to be a win.
	return_statements = called.node.find_all(NODE_RETURN)

	loop return_statement in return_statements {
		return_value = return_statement.(ReturnNode).value

		# If the return value exists and is a constant, inlining is likely to be a win.
		if return_value !== none and common.is_constant(return_value) => INLINE_THRESHOLD
	}

	=> 0
}

# Summary:
# Attempts to inline functions optimally in the specified function and in the functions that it calls.
optimize(implementation: FunctionImplementation, states: Map<FunctionImplementation, bool>) {
	# Do not process the same function twice
	if states.contains_key(implementation) return
	states[implementation] = true # Mark the implementation as visited

	# Get the root of the function implementation and clone it
	snapshot = implementation.node.clone()
	functions = snapshot.find_all(NODE_FUNCTION) as List<FunctionNode>

	# Approximate the current cost of the function implementation
	cost = expression_optimizer.get_cost(snapshot)

	loop usage in functions {
		called_function = usage.function

		# 1. Imported functions can not be inlined
		# 2. Do not inline recursive function and the current function
		if called_function.is_imported or not is_inlinable(implementation, called_function) continue

		# Perform inlining in the called function before doing anything, so that obvious inlining is not done multiple times when others call the same function
		optimize(called_function, states)

		# 1. Create an isolated version of the called function body with parameters initialized with the passed arguments
		state = start_inlining(called_function, usage)

		# 2. Optimize the isolated node tree
		state.body = optimizer.optimize(state.context, state.body)

		# 3. Approximate the cost of executing the called function separately from the current function
		before = cost + expression_optimizer.get_cost(called_function.node)

		# 4. Approximate the cost after inlining the function
		# Cost after inlining = (Cost of nodes surrounding the function call) + (Cost of the optimized function body)
		# NOTE: Costs is affected by several factors, such as the size of the node tree and the number of function calls and memory accesses
		
		# 4.1. Disable the function call so that its cost will not be approximated
		instance = usage.instance
		usage.instance = NODE_DISABLED

		# 4.2. Approximate the cost of the current function without the function call
		after = expression_optimizer.get_cost(snapshot)

		# 4.3. Add the cost of the optimized function body to the cost after inlining
		after += expression_optimizer.get_cost(state.body)

		# 4.4. Restore the function call instance
		usage.instance = instance

		# 5. If the decrease in the cost reaches a specific threshold, proceed with inlining the function
		if (before - after) + heuristical_cost(called_function, usage) >= INLINE_THRESHOLD {
			finish_inlining(state)

			# 6. Optimize the whole function body, because the inlined function can affect decisions
			snapshot = optimizer.optimize(implementation, snapshot)

			cost = expression_optimizer.get_cost(snapshot)
		}
	}

	implementation.node = snapshot
}

# Summary:
# Attempts to inline functions optimally in the functions declared in the specified context.
optimize(context: Context) {
	implementations = common.get_all_function_implementations(context, false)
	states = Map<FunctionImplementation, bool>()

	loop implementation in implementations {
		optimize(implementation, states)
	}
}