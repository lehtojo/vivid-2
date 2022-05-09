namespace assignment_optimizer

pack VariableWrite {
	node: Node
	dependencies: List<Node>
	assignable: List<Node>
	is_declaration: bool
	value => node.last
}

pack VariableDescriptor {
	writes: List<VariableWrite>
	reads: List<Node>
}

# Summary:
# Safety check, which looks for assignments inside assignments. Such assignments have a high chance of causing trouble.
capture_nested_assignments(root: Node) {
	#warning Optimize this function away in release builds?
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop assignment in assignments {
		loop (iterator = assignment.parent, iterator !== none, iterator = iterator.parent) {
			if iterator.instance == NODE_OPERATOR and iterator.(OperatorNode).operator.type != OPERATOR_TYPE_LOGICAL abort('Found a nested assignment while optimizing')
		}
	}
}

# Summary:
# Produces a descriptor for the specified variable from the specified set of variable nodes
get_variable_descriptor(variable: Variable, nodes: Map<Variable, List<Node>>) {
	if not nodes.contains_key(variable) => pack { writes: List<VariableWrite>(), reads: List<Node>() } as VariableDescriptor

	usages = nodes[variable]
	writes = List<VariableWrite>()
	reads = List<Node>()

	loop usage in usages {
		if common.is_edited(usage) {
			editor = common.get_editor(usage)
			writes.add(pack { node: editor, dependencies: List<Node>(), assignable: List<Node>(), is_declaration: writes.size == 0 })
		}
		else {
			reads.add(usage)
		}
	}

	=> pack { writes: writes, reads: reads } as VariableDescriptor
}

# Summary:
# Produces descriptors for all the variables defined in the specified context
get_variable_descriptors(context: Context, root: Node) {
	nodes = assembler.group_by<Node, Variable>(root.find_all(NODE_VARIABLE), (i: Node) -> i.(VariableNode).variable)
	result = Map<Variable, VariableDescriptor>()

	loop variable in context.all_variables {
		result[variable] = get_variable_descriptor(variable, nodes)
	}

	=> result
}

# Summary:
# Registers all dependencies for the specified variable writes.
# This means that the non-write usages of the variables are added to the lists of the writes that affect them.
register_write_dependencies(descriptor: VariableDescriptor, flow: StatementFlow) {
	loop write in descriptor.writes {
		write.dependencies.clear()
	}

	# Get the indices of all writes, we will use this information to determine which writes own which non-write usages
	obstacles = descriptor.writes.map<normal>((i: VariableWrite) -> flow.index_of(i.node))

	# Group all non-write usages by their statement index.
	# If a write affects a certain statement, it affects all the non-write usages inside it.
	reads_by_statement = assembler.group_by<Node, normal>(descriptor.reads, (i: Node) -> flow.index_of(i))

	# Extract all statement indices, which contain reads.
	read_statements = reads_by_statement.get_keys()

	# The idea is that all writes try to reach the statements that contain non-write usages without hitting other writes.
	# If a write usage can reach a non-write usage without hitting other writes, it is added to the dependencies of the write.
	loop (i = 0, i < descriptor.writes.size, i++) {
		start = obstacles[i]
		reached = flow.get_executable_positions(start + 1, obstacles, List<normal>(read_statements))

		# None is returned from the function call above, if the complexity of the flow reaches the default limit.
		# It is always possible to compute, which non-write usages can be reached, but the computation is currently limited for performance reasons.
		# If the complexity of the flow reaches the specified limit, we just assume the write affects everything.
		if reached === none { reached = read_statements }

		if reached.size > 0 {
			write = descriptor.writes[i]

			# Add all the non-write usages in the reached statements as dependencies to the current write
			loop statement in reached {
				write.dependencies.add_range(reads_by_statement[statement])
			}
		}
	}
}

# Summary:
# Returns whether the value of the specified assignment can be inlined safely
is_assignable(assignment: Node) {
	# Assignable if does not contain:
	# - Function calls
	# - Memory accesses
	# - Assignment operators
	# - Non-predictable variables (members and static variables)
	# - Non-free casts
	unallowed = assignment.find((node) -> {
		if node.instance == NODE_VARIABLE => not node.(VariableNode).variable.is_predictable
		if node.instance == NODE_OPERATOR => node.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT
		if node.instance == NODE_CAST => not node.(CastNode).is_free()

		allowed = NODE_DATA_POINTER | NODE_NEGATE | NODE_NOT | NODE_NUMBER | NODE_PARENTHESIS | NODE_STACK_ADDRESS | NODE_STRING | NODE_TYPE
		=> not node.match(allowed)
	})

	=> unallowed === none
}

# Summary:
# Returns all the predictable variables that affect the specified value
get_value_dependencies(value: Node) {
	result = List<Variable>()

	if value.instance == NODE_VARIABLE {
		variable = value.(VariableNode).variable
		if variable.is_predictable and not variable.is_constant { result.add(variable) }
	}
	else {
		nodes = value.find_all(NODE_VARIABLE)

		loop node in nodes {
			variable = node.(VariableNode).variable
			if variable.is_predictable and not variable.is_constant and not variable.is_self_pointer { result.add(variable) }
		}
	}

	=> result
}

# Summary:
# Returns if any of the writes of the specified variable expect the specifed write contains the specified read as dependency.
is_dependent_on_other_write(descriptor: VariableDescriptor, write: VariableWrite, read: Node) {
	loop other in descriptor.writes {
		if other === write continue

		loop dependency in other.dependencies {
			if dependency === read => true
		}
	}

	=> false
}

# Summary:
# Returns all variable nodes from the specified root while taking into account if the specified root is a variable node
get_all_variable_usages(root: Node) {
	usages = none as List<Node>

	if root.instance == NODE_VARIABLE { usages = [ root ] }
	else { usages = root.find_all(NODE_VARIABLE) }

	=> usages.filter(i -> i.(VariableNode).variable.is_predictable)
}

# Summary:
# Removes all local variable usages from the specified node tree 'from' and adds the new usages from the specified node tree 'to'
update_variable_usages(descriptors: Map<Variable, VariableDescriptor>, from: Node, to: Node) {
	# Find all variable usages from the node tree 'from' and remove them from descriptors
	previous_usages = get_all_variable_usages(from)

	loop usage in previous_usages {
		variable = usage.(VariableNode).variable
		if not descriptors.contains_key(variable) continue

		descriptor = descriptors[variable]
		reads = descriptor.reads

		loop (i = 0, i < reads.size, i++) {
			if reads[i] !== usage continue
			reads.remove_at(i)
			stop
		}
	}

	# NOTE: We do not need to add the new usages of the assigned variable into the dependency lists of those writes that affect them, because those writes have been processed already
	if to === none return

	# Add all the variable usages from the node tree 'to' into the descriptors
	assignment_usages = get_all_variable_usages(to)

	loop usage in assignment_usages {
		variable = usage.(VariableNode).variable
		if not descriptors.contains_key(variable) continue

		descriptors[variable].reads.add(usage)
	}
}

# Summary:
# Adds all the variable usages from the specified node tree 'from' into the specified descriptors
add_variable_usages_from(descriptors: Map<Variable, VariableDescriptor>, from: Node) {
	usages = get_all_variable_usages(from)

	loop usage in usages {
		variable = usage.(VariableNode).variable
		if not descriptors.contains_key(variable) continue

		descriptors[variable].reads.add(usage)
	}
}

# Summary:
# Assigns the value of the specified write to the specified reads
assign(variable: Variable, write: VariableWrite, recursive: bool, descriptors: Map<Variable, VariableDescriptor>, descriptor: VariableDescriptor, flow: StatementFlow) {
	assigned = false

	loop read in write.assignable {
		# Find the root of the expression which contains the root and approximate the cost of the expression
		root = reconstruction.get_expression_root(read)
		before = expression_optimizer.get_cost(root)

		# Clone the assignment value and find all the variable references
		value = write.value.clone()
		read.replace(value)

		# Find the root of the expression which contains the root and approximate the cost of the expression
		root = reconstruction.get_expression_root(value)

		# Clone the root so that it can be modified
		optimized = root.clone()

		# Optimize the root where the value was assigned
		optimized = expression_optimizer.optimize_all_expressions(optimized)

		# Approximate the new cost of the root
		after = expression_optimizer.get_cost(optimized)

		# 1. If the assignment is recursive, all the assignments must be done
		# 2. If the cost has decreased, the assignment should be done in most cases
		if not recursive and after > before {
			# Revert back the changes since the cost has risen
			value.replace(read)

			if settings.is_verbose_output_enabled { print('Did not assign ') }
		}
		else {
			# Remove the read from the write dependencies
			loop (i = 0, i < write.dependencies.size, i++) {
				if write.dependencies[i] !== read continue
				write.dependencies.remove_at(i)
				stop
			}

			# Remove the read from the reads
			loop (i = 0, i < descriptor.reads.size, i++) {
				if descriptor.reads[i] !== read continue
				descriptor.reads.remove_at(i)
				stop
			}

			# Update the local variable usages, since the assigned value 
			add_variable_usages_from(descriptors, root)
			assigned = true

			if settings.is_verbose_output_enabled { print('Assigned ') }
		}

		if settings.is_verbose_output_enabled {
			print(variable.name)
			print(', Cost: ')

			if after > before { put(`+`) println(after - before) }
			else after < before { println(after - before) }
			else { println('0') }
		}
	}

	if write.dependencies.size != 0 => assigned

	# If the write declares the variable and the variable is still used, this write needs to be preserved in simpler form, so that the variable is declared
	if write.is_declaration and descriptor.writes.size > 1 {
		# Replace the value of the write with an undefined value, because it does not need to be computed
		replacement = OperatorNode(Operators.ASSIGN).set_operands(
			VariableNode(variable),
			UndefinedNode(variable.type, variable.type.get_register_format())
		)

		write.node.replace(replacement)
		flow.replace(write.node, replacement)
	}
	else {
		# Remove the write from the node tree and the statement flow
		write.node.remove()
		flow.remove(write.node)
	}

	# Remove all the variable usages from the old write
	update_variable_usages(descriptors, write.node, none as Node)

	# Finally, remove the write from the current descriptor
	loop (i = 0, i < descriptor.writes.size, i++) {
		if descriptor.writes[i] !== write continue
		descriptor.writes.remove_at(i)
		stop
	}

	=> assigned
}

# Summary:
# Removes the variable, if it represents an allocated object that is only written into.
# Returns whether the specified variable was removed.
remove_unread_allocated_variables(variable: Variable, descriptor: VariableDescriptor) {
	# Do nothing if optimizations are not enabled
	if not settings.is_optimization_enabled => false

	# If something is written into a parameter object, it can not be determined whether the written value is used elsewhere
	if variable.is_parameter => false

	# The writes must use the registered allocation function or stack allocation
	loop write in descriptor.writes {
		value = common.get_source(write.value)

		if value.instance == NODE_STACK_ADDRESS continue
		if value.instance == NODE_FUNCTION and value.(FunctionNode).function === settings.allocation_function continue

		=> false
	}

	# If any of the reads of the variable is not used to write into the object, just abort
	loop read in descriptor.reads {
		selected = read.parent

		if selected.instance == NODE_SCOPE {
			# Abort if the scope returns the read
			if selected.(ScopeNode).is_value_returned and read === selected.last => false
			continue
		}

		if selected.instance == NODE_CAST { selected = selected.parent }
		if selected.instance != NODE_LINK or not common.is_edited(selected) => false
	}

	# 1. Remove discarded usages
	# 2. Replace the assignments with the assigned values
	loop write in descriptor.writes {
		write.node.replace(write.node.last)
	}

	loop read in descriptor.reads {
		selected = read.parent

		if selected.instance == NODE_SCOPE {
			read.remove()
			continue
		}

		if selected.instance == NODE_CAST { selected = selected.parent }

		# Replace the editor with the assigned value
		editor = common.get_editor(selected)
		editor.replace(editor.last)
	}

	=> true
}

# Summary:
# Looks for assignments of the specified variable which can be inlined
assign_variables(context: Context, root: Node, hidden_only: bool) {
	variables = List<Variable>(context.all_variables)
	variables.distinct()

	if hidden_only { variables = variables.filter(i -> i.is_hidden) }

	# Create assignments, which initialize the parameters
	# NOTE: Fixes the situation, where the code contains a single conditional assignment to the parameter and one read.
	# Without the initialization, the value of the single assignment would be inlined.
	initializations = List<Node>()

	loop iterator in context.variables {
		parameter = iterator.value
		if not parameter.is_parameter continue

		initialization = OperatorNode(Operators.ASSIGN).set_operands(
			VariableNode(parameter),
			UndefinedNode(parameter.type, parameter.type.get_register_format())
		)

		initializations.add(initialization)
		root.insert(root.first, initialization)
	}

	descriptors = get_variable_descriptors(context, root)
	flow = StatementFlow(root)

	capture_nested_assignments(root)

	loop variable in variables {
		descriptor = descriptors[variable]

		if remove_unread_allocated_variables(variable, descriptor) {
			descriptors.remove(variable)
			continue
		}

		register_write_dependencies(descriptor, flow)

		assignable = List<Node>()

		copied_writes = List<VariableWrite>(descriptor.writes)

		loop write in copied_writes {
			# The initializations of parameters must be left intact
			if variable.is_parameter and write.is_declaration continue

			# If the value of the write contains a call for example, it should not be assigned
			if not is_assignable(write.node) continue

			# Collect all local variables that affect the value of the write. If any of these is edited, it means the value of the write changes
			value_dependencies = get_value_dependencies(write.value)
			obstacles = List<Node>()

			# Add each write of all value dependencies as an obstacle, because any one of them might affect the value of the current write
			loop dependency in value_dependencies {
				if not descriptors.contains_key(dependency) continue
				dependency_writes = descriptors[dependency].writes

				loop dependency_write in dependency_writes {
					obstacles.add(dependency_write.node)
				}
			}

			# Collect all reads from the dependencies, where the value of the current write can be assigned
			recursive = write.value.find(i -> i.match(variable)) !== none

			assignable.clear()

			loop read in write.dependencies {
				# If the read is dependent on any of the other writes of the current variable, the value of the current write can not be assigned
				if is_dependent_on_other_write(descriptor, write, read) continue

				assign = true
				from = flow.index_of(write.node) + 1
				to = flow.index_of(read)

				# If the read happens before the edit, which is possible in loops for example, it is not reliable to get all the nodes between the edit and the read
				if to < from continue

				# Find all assignments between the write and the read
				loop (i = from, i < to, i++) {
					node = flow.nodes[i]
					if node == none or not node.match(Operators.ASSIGN) continue

					edited = common.get_edited(node)
					if edited.instance != NODE_VARIABLE continue

					# If one of the dependencies is edited between the write and the read, the value of the write can not be assigned
					if not value_dependencies.contains(edited.(VariableNode).variable) continue

					assign = false
					stop
				}

				if assign assignable.add(read)
			}

			if recursive {
				is_inside_loop = write.node.find_parent(NODE_LOOP) !== none

				# 1. Recursive writes must be assigned to all their reads
				# 2. It is assumed that recursive code can not be assigned inside a loop, if the edited variable is created externally
				if assignable.size != write.dependencies.size or is_inside_loop continue
			}

			write.assignable = assignable
			assign(variable, write, recursive, descriptors, descriptor, flow)
		}
	}

	# Remove the parameter initializations, because the should not be executed
	loop initialization in initializations { initialization.remove() }

	capture_nested_assignments(root)
}

# Summary:
# Looks for assignments of the specified variable which can be inlined
assign_variables(context: Context, root: Node) {
	assign_variables(context, root, not settings.is_optimization_enabled)
}