namespace resolver

get_shared_type(expected: Type, actual: Type) {
	if expected == none or actual == none return none as Type
	if expected == actual or expected.match(actual) return expected

	if expected.is_number and actual.is_number {
		bits = max(expected.reference_size * 8, actual.reference_size * 8)
		signed = not expected.(Number).unsigned or not actual.(Number).unsigned
		is_decimal = expected.format == FORMAT_DECIMAL or actual.format == FORMAT_DECIMAL
		return primitives.create_number(bits, signed, is_decimal)
	}

	expected_all_types = expected.get_all_supertypes()
	actual_all_types = actual.get_all_supertypes()

	expected_all_types.insert(0, expected)
	actual_all_types.insert(0, actual)

	loop type in expected_all_types {
		if actual_all_types.contains(type) return type
	}

	return none as Type
}

# Summary: Returns the shared type between all the specified types
outline get_shared_type(types: List<Type>) {
	if types.size == 0 return none as Type
	shared = types[]

	loop (i = 1, i < types.size, i++) {
		shared = get_shared_type(shared, types[i])
		if shared == none return none as Type
	}

	return shared
}

# Summary: Returns the types of the child nodes, only if all have types
get_types(node: Node) {
	result = List<Type>()

	loop iterator in node {
		type = iterator.try_get_type()
		if type == none return none as List<Type>
		result.add(type)
	}

	return result
}

# Summary: Tries to resolve the specified array type
resolve_array_type(environment: Context, type: ArrayType) {
	type.resolve(environment)
	if type.is_resolved return type
	return none as Type
}

# Summary: Tries to resolve the specified type if it is unresolved
resolve(context: Context, type: Type) {
	if type.is_resolved return none as Type

	# Resolve array types, because their sizes need to be determined at compile time and they can be dependent on expressions
	if type.is_array_type return resolve_array_type(type.parent, type as ArrayType)

	return type.(UnresolvedType).resolve_or_none(context)
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
	if node.is_resolvable return node.resolve(context)

	loop child in node {
		resolve(context, child)
	}

	return none as Node
}

# Summary: Tries to resolve the type of the specified variable
resolve(variable: Variable) {
	if variable.type != none {
		# If the variable is already resolved, there is no need to do anything
		if variable.type.is_resolved return

		# Try to resolve the variable type
		resolved = resolve(variable.parent, variable.type)
		if resolved == none return

		variable.type = resolved
		return
	}

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

# Summary: Resolves the parameters of the specified function
resolve(function: Function) {
	# Resolve the parameters
	loop parameter in function.parameters {
		type = parameter.type
		if type == none or type.is_resolved continue

		type = resolve(function, type)
		if type == none continue

		parameter.type = type
	}
}

# Summary: Tries to resolve all the locals in the specified context
resolve_variables(context: Context) {
	loop iterator in context.variables {
		resolve(iterator.value)
	}

	loop subcontext in context.subcontexts {
		resolve_variables(subcontext)
	}
}

# Summary: Tries to resolve the return type of the specified implementation based on its return statements
resolve_return_type(implementation: FunctionImplementation) {
	# Do not resolve the return type if it is already resolved.
	# This also prevents virtual function overrides from overriding the return type, enforced by the virtual function declaration
	if implementation.return_type != none {
		if implementation.return_type.is_resolved return

		# Try to resolve the return type
		resolved = implementation.return_type.(UnresolvedType).resolve_or_none(implementation)
		if resolved === none return

		# Update the return type, since we resolved it
		implementation.return_type = resolved
		return
	}

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

# Summary: Resolves return types of the virtual functions declared in the specified type
resolve_virtual_functions(type: Type) {
	overloads = List<VirtualFunction>()
	loop iterator in type.virtuals { overloads.add_all(iterator.value.overloads as List<VirtualFunction>) }

	# Virtual functions do not have return types defined sometimes, the return types of those virtual functions are dependent on their default implementations
	loop virtual_function in overloads {
		if virtual_function.return_type != none continue
		
		# Find all overrides with the same name as the virtual function
		result = type.get_override(virtual_function.name)
		if result == none continue
		overloads = result.overloads

		# Take out the expected parameter types
		expected = List<Type>()
		loop parameter in virtual_function.parameters { expected.add(parameter.type) }

		loop overload in overloads {
			# Ensure the actual parameter types match the expected types
			actual = List<Type>(overload.parameters.size, false)
			loop parameter in overload.parameters { actual.add(parameter.type) }

			if actual.size != expected.size continue

			skip = false

			loop (i = 0, i < expected.size, i++) {
				if expected[i].match(actual[i]) continue
				skip = true
				stop
			}

			if skip or overload.implementations.size == 0 continue

			# Now the current overload must be the default implementation for the virtual function
			virtual_function.return_type = overload.implementations[].return_type
			stop
		}
	}
}

# Summary: Tries to resolve supertypes which were not found previously
resolve_supertypes(context: Context, type: Type) {
	loop (i = type.supertypes.size - 1, i >= 0, i--) {
		supertype = type.supertypes[i]
		if supertype.is_resolved continue

		# Try to resolve the supertype
		resolved = resolve(context, supertype)

		# Skip the supertype if it could not be resolved or if it is not allowed to be inherited
		if resolved === none or not type.is_inheriting_allowed(resolved) continue

		# Replace the old unresolved supertype with the resolved one
		type.supertypes[i] = resolved
	}
}

# Summary: Tries to resolve every problem in the specified context
resolve_context(context: Context) {
	functions = common.get_all_visible_functions(context)
	loop function in functions { resolve(function) }

	types = common.get_all_types(context)
	
	# Resolve all the types
	loop type in types {
		resolve_supertypes(context, type)

		# Resolve all member variables
		loop iterator in type.variables {
			resolve(iterator.value)
		}

		# Resolve all initializations
		loop initialization in type.initialization {
			resolve(type, initialization)
		}

		# Resolve array types, because their sizes need to be determined at compile time and they can be dependent on expressions
		if type.is_array_type resolve_array_type(type.parent, type as ArrayType)

		resolve_virtual_functions(type)
	}

	implementations = common.get_all_function_implementations(context)

	# Resolve all implementation variables and node trees
	loop implementation in implementations {
		resolve_return_type(implementation)
		resolve_variables(implementation)

		if implementation.node == none continue
		resolve_tree(implementation, implementation.node)
	}

	# Resolve constants
	resolve_variables(context)
}

get_tree_statuses(root: Node) {
	result = List<Status>()

	loop child in root {
		result.add_all(get_tree_statuses(child))

		status = child.get_status()
		if status === none continue

		result.add(status)
	}

	return result
}

get_tree_report(root: Node) {
	errors = List<Status>()
	if root == none return errors

	loop status in get_tree_statuses(root) {
		if status === none or not status.problematic continue
		errors.add(status)
	}

	return errors
}

get_type_report(type: Type) {
	errors = List<Status>()

	loop iterator in type.variables {
		variable = iterator.value
		if variable.is_resolved continue
		errors.add(Status(variable.position, 'Can not resolve the type of the member variable'))
	}

	loop initialization in type.initialization {
		errors.add_all(get_tree_report(initialization))
	}

	loop supertype in type.supertypes {
		if supertype.is_resolved continue
		errors.add(Status(type.position, 'Can not inherit the supertype'))
	}

	return errors
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

	errors.add_all(get_tree_report(implementation.node))
	return errors
}

get_report(context: Context, root: Node) {
	errors = List<Status>()

	types = common.get_all_types(context)

	loop type in types {
		errors.add_all(get_type_report(type))
	}

	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		errors.add_all(get_function_report(implementation))
	}

	errors.add_all(get_tree_report(root))
	return errors
}

are_reports_equal(a: List<Status>, b: List<Status>) {
	if a.size != b.size return false

	loop (i = 0, i < a.size, i++) {
		x = a[i]
		y = b[i]

		if not (x == y) return false
	}

	return true
}

register_default_functions(context: Context) {
	# Allocation:
	allocation_function_overloads = context.get_function("allocate")
	if allocation_function_overloads == none abort('Missing the allocation function, please implement it or include the standard library')

	settings.allocation_function = allocation_function_overloads.get_implementation(primitives.create_number(primitives.LARGE, FORMAT_INT64))
	if settings.allocation_function == none abort('Missing the allocation function, please implement it or include the standard library')

	# Deallocation:
	deallocation_function_overloads = context.get_function("deallocate")
	if deallocation_function_overloads == none abort('Missing the deallocation function, please implement it or include the standard library')

	settings.deallocation_function = deallocation_function_overloads.get_implementation(Link())
	if settings.deallocation_function == none abort('Missing the deallocation function, please implement it or include the standard library')

	# Inheritance:
	inheritance_function_overloads = context.get_function("internal_is")
	if inheritance_function_overloads == none abort('Missing the inheritance function, please implement it or include the standard library')

	types = List<Type>(2, false)
	types.add(Link())
	types.add(Link())
	
	settings.inheritance_function = inheritance_function_overloads.get_implementation(types)
	if settings.inheritance_function == none abort('Missing the inheritance function, please implement it or include the standard library')

	# Initialization function:
	initialization_function_overloads = context.get_function("internal_init")
	if initialization_function_overloads != none {
		# Try to implement the initialization function with a link as parameter and without
		settings.initialization_function = initialization_function_overloads.get_implementation(Link())
		if settings.initialization_function == none { settings.initialization_function = initialization_function_overloads.get_implementation(List<Type>()) }
	}
}

output(status: Status) {
	position = status.position

	if position === none {
		console.write('<Source>:<Line>:<Character>')
	}
	else {
		file = position.file

		if file != none console.write(file.fullname)
		else { console.write('<Source>') }

		console.write(':')
		console.write(to_string(position.line + 1))
		console.write(':')
		console.write(to_string(position.character + 1))
	}

	console.write(': Error: ')
	console.write_line(status.message)
}

complain(report: List<Status>) {
	loop status in report { output(status) }
}

debug_print(context: Context) {
	implementations = common.get_all_function_implementations(context)

	loop implementation in implementations {
		console.write('Function ')
		console.write(implementation.metadata.name)
		console.write_line(':')
		parser.print(implementation.node)
	}
}

resolve() {
	parse = settings.parse

	context = parse.context
	root = parse.root

	current = get_report(context, root)
	evaluated = false

	# Find the required functions and save them
	register_default_functions(context)

	# Try to resolve as long as errors change -- errors do not always decrease since the program may expand each cycle
	loop {
		previous = current

		parser.apply_extension_functions(context, root)
		parser.implement_functions(context, none as SourceFile, false)

		# Try to resolve problems in the node tree and get the status after that
		resolve_context(context)
		current = get_report(context, root)

		if settings.is_verbose_output_enabled {
			console.write('Resolving ')
			console.write(current.size)
			console.write_line(' issues...')
		}

		# Try again only if the errors have changed
		if not are_reports_equal(previous, current) continue
		if evaluated stop

		evaluator.evaluate(context)
		evaluated = true
	}

	# The compiler must not continue if there are errors in the report
	if current.size > 0 {
		complain(current)
		return Status('Compilation error')
	}

	if settings.is_verbose_output_enabled console.write_line('Resolved')

	return Status()
}