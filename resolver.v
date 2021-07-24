namespace resolver

get_shared_type(expected: Type, actual: Type) {
	if expected == actual => expected
	if expected == none or actual == none => none as Type

	if expected.is_number and actual.is_number {
		if expected.format == FORMAT_DECIMAL => expected
		if actual.format == FORMAT_DECIMAL => actual

		# Return the larger number type
		if expected.(Number).bits > actual.(Number).bits => expected
		=> actual
	}

	expected_all_types = expected.get_all_supertypes()
	actual_all_types = expected.get_all_supertypes()

	expected_all_types.add(expected)
	actual_all_types.add(actual)

	loop type in expected_all_types {
		if actual_all_types.contains(type) => type
	}

	=> none as Type
}

# Summary: Returns the shared type between all the specified types
get_shared_type(types: List<Type>) {
	if types.size == 0 => none as Type
	shared = types[0]

	loop (i = 1, i < types.size, i++) {
		shared = get_shared_type(shared, types[i])
		if shared == none => none as Type
	}

	=> shared
}

# Summary: Returns the types of the child nodes, only if all have types
get_types(node: Node) {
	result = List<Type>()

	loop iterator in node {
		type = iterator.try_get_type()
		if type == none => none as List<Type>
		result.add(type)
	}

	=> result
}

# Summary: Tries to resolve the specified type if it is unresolved
resolve(context: Context, type: Type) {
	if type.is_resolved => none as Type
	=> type.(UnresolvedType).try_resolve_type(context)
}

# Summary: Tries to resolve the specified node tree
resolve(context: Context, node: Node) {
	result = resolve_tree(context, node)
	if result == none return
	node.replace(result)
}

# Summary: Tries to resolve problems in the node tree
resolve_tree(context: Context, node: Node) {
	# If the node is unresolved, try to resolve it
	if node.is_resolvable => node.resolve(context)
	loop child in node { resolve(context, child) }
	=> none as Node
}

# Summary: Tries to resolve the type of the specified variable
resolve(variable: Variable) {
	types = List<Type>()

	loop usage in variable.usages {
		parent = usage.parent
		if parent == none continue

		if parent.match(Operators.ASSIGN) {
			# The usage must be the destination
			if parent.first != usage continue
		}
		else parent.instance == NODE_LINK {
			# The usage must be the destination
			if parent.last != usage continue

			parent = parent.parent
			if parent == none or not parent.match(Operators.ASSIGN) continue
		}
		else {
			continue
		}

		# Get the assignment type from the source operand
		type = parent.last.try_get_type()
		if type == none continue

		types.add(type)
	}

	# Get the shared type between all the assignments
	shared = get_shared_type(types)
	if shared == none return

	variable.type = shared
}

# Summary: Tries to resolve all the locals in the specified context
resolve_variables(context: Context) {
	loop local in context.locals { resolve(local) }
}

# Summary: Tries to resolve the return type of the specified implementation based on its return statements
resolve_return_type(implementation: FunctionImplementation) {
	statements = implementation.node.find_all(NODE_RETURN)

	# If there are no return statements, the return type of the implementation must be unit
	if statements.size == 0 {
		implementation.return_type = primitives.create_unit()
		return
	}

	# If any of the return statements does not have a return value, the return type must be unit
	loop statement in statements {
		if statement.(ReturnNode).value != none continue
		implementation.return_type = primitives.create_unit()
		return
	}

	# Collect all return statement value types
	types = List<Type>()

	loop statement in statements {
		type = statement.(ReturnNode).value.try_get_type()
		if type == none or type.is_unresolved return
		types.add(type)
	}

	type = get_shared_type(types)
	if type == none return

	implementation.return_type = type
}

# Summary: Tries to resolve every problem in the specified context
resolve_context(context: Context) {
	types = common.get_all_types(context)

	loop type in types {
		# Resolve all member variables
		loop iterator in type.variables {
			resolve(iterator.value)
		}

		# Resolve all initializations
		loop initialization in type.initialization {
			resolve(type, initialization)
		}
	}

	implementations = common.get_all_function_implementations(context)

	# Resolve all implementation variables and node trees
	loop implementation in implementations {
		if implementation.node == none or implementation.metadata.is_imported continue
		resolve_return_type(implementation)
		resolve_variables(implementation)
		resolve_tree(implementation, implementation.node)
	}
}

get_tree_statuses(root: Node) {
	result = List<Status>()

	loop child in root {
		result.add_range(get_tree_statuses(child))
		result.add(child.get_status())
	}

	=> result
}

get_tree_report(root: Node) {
	errors = List<Status>()
	if root == none => errors

	loop status in get_tree_statuses(root) {
		if status as link == none or not status.problematic continue
		errors.add(status)
	}

	=> errors
}

get_type_report(type: Type) {
	errors = List<Status>()

	loop iterator in type.variables {
		variable = iterator.value
		if variable.is_resolved continue
		errors.add(Status(variable.position, 'Can not resolve the type of the member variable'))
	}

	loop initialization in type.initialization {
		errors.add_range(get_tree_report(initialization))
	}

	loop supertype in type.supertypes {
		if supertype.is_resolved continue
		errors.add(Status(type.position, 'Can not inherit the supertype'))
	}

	=> errors
}

get_function_report(implementation: FunctionImplementation) {
	errors = List<Status>()

	loop variable in implementation.locals {
		if variable.is_resolved continue
		errors.add(Status(variable.position, 'Can not resolve the type of the variable'))
	}

	if implementation.return_type == none or implementation.return_type.is_unresolved {
		errors.add(Status(implementation.metadata.start, 'Can not resolve the return type'))
	}

	errors.add_range(get_tree_report(implementation.node))
	=> errors
}

get_report(context: Context, root: Node) {
	errors = List<Status>()

	types = common.get_all_types(context)

	loop type in types {
		errors.add_range(get_type_report(type))
	}

	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		errors.add_range(get_function_report(implementation))
	}

	errors.add_range(get_tree_report(root))
	=> errors
}

are_reports_equal(a: List<Status>, b: List<Status>) {
	if a.size != b.size => false

	loop (i = 0, i < a.size, i++) {
		x = a[i]
		y = b[i]

		if not (x == y) => false
	}

	=> true
}

register_default_functions(context: Context) {
	allocation_function_overloads = context.get_function(String('allocate'))
	if allocation_function_overloads == none abort('Missing the allocation function, please implement it or include the standard library')

	type = primitives.create_number(primitives.LARGE, FORMAT_INT64)

	settings.allocation_function = allocation_function_overloads.get_implementation(type)
	if settings.allocation_function == none abort('Missing the allocation function, please implement it or include the standard library')
}

complain(report: List<Status>) {
	loop status in report {
		position = status.position

		if position as link == none {
			print('<Source>:<Line>:<Character>')
		}
		else {
			file = position.file

			if file != none print(file.fullname)
			else { print('<Source>') }

			print(':')
			print(to_string(position.line))
			print(':')
			print(to_string(position.character))
		}

		print(': Error: ')
		println(status.message)
	}
}

debug_print(context: Context) {
	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		print('Function ')
		print(implementation.metadata.name)
		println(':')
		parser.print(implementation.node)
	}
}

resolve(bundle: Bundle) {
	if not (bundle.get_object(String(BUNDLE_PARSE)) as Optional<Parse> has parse) => Status('Nothing to resolve')

	context = parse.context
	current = get_report(context, parse.root)
	evaluated = false

	# Find the required functions and save them
	register_default_functions(context)

	# Try to resolve as long as errors change -- errors do not always decrease since the program may expand each cycle
	loop {
		previous = current

		parser.implement_functions(context, none as SourceFile, false)

		# Try to resolve problems in the node tree and get the status after that
		resolve_context(context)
		current = get_report(context, parse.root)

		# Try again only if the errors have changed
		if are_reports_equal(previous, current) stop
	}

	# The compiler must not continue if there are errors in the report
	if current.size > 0 {
		complain(current)
		=> Status('Compilation error')
	}

	=> Status()
}