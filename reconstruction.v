namespace reconstruction

constant RUNTIME_HAS_VALUE_FUNCTION_IDENTIFIER = 'has_value'
constant RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER = 'get_value'

# Summary: Completes the specified self returning function by adding the necessary statements and by modifying the function information
complete_self_returning_function(implementation: FunctionImplementation) {
	position = implementation.metadata.start

	implementation.return_type = implementation.parent as Type
	implementation.is_self_returning = true
	implementation.node.add(ReturnNode(none as Node, position))

	self = implementation.get_self_pointer()
	require(self !== none, 'Missing self parameter')

	statements = implementation.node.find_all(NODE_RETURN)

	loop statement in statements {
		statement.add(VariableNode(self, position))
	}
}

# Summary: Removes redundant parentheses in the specified node tree
# Example: x = x * (((x + 1))) => x = x * (x + 1)
remove_redundant_parentheses(node: Node): _ {
	# Look for parentheses that have exactly one child
	if node.instance === NODE_PARENTHESIS and node.first !== none and node.first === node.last {
		# Do not remove parentheses that are indices of accessor nodes
		if node.parent !== none and (node.parent.instance !== NODE_ACCESSOR or node.next !== none) {
			# Replace the parentheses with its child
			value = node.first
			node.replace(value)

			# Process the child node next
			node = value
		}
	}

	loop child in node { remove_redundant_parentheses(child) }
}

# Summary: Rewrites increment and decrement operators as action operations if their values are discard.
# Example 1 (Value is not discarded):
# x = ++i
# Example 2 (Value is discarded)
# Before:
# loop (i = 0, i < n, i++)
# After:
# loop (i = 0, i < n, i += 1)
rewrite_discarded_increments(root: Node): _ {
	increments = root.find_all(NODE_INCREMENT | NODE_DECREMENT)

	loop increment in increments {
		if common.is_value_used(increment) continue
		
		operator = Operators.ASSIGN_ADD
		if increment.match(NODE_DECREMENT) { operator = Operators.ASSIGN_SUBTRACT }

		increment.replace(OperatorNode(operator, increment.start).set_operands(
			increment.first,
			NumberNode(SYSTEM_FORMAT, 1, increment.start)
		))
	}
}

# Summary:
# Processes using-expressions by:
# - Extracting the allocators
# - Replacing the using-expressions with the allocated objects
# - Saving the extracted allocators into the allocated objects
# Example:
# Foo() using Allocator
# = Using { Construction { Foo() }, Allocator.allocate(sizeof(Foo)) }
# => Construction { Allocator.allocate(sizeof(Foo)), Foo() }
assign_allocators_constructions(root: Node): _ {
	expressions = root.find_all(NODE_USING)

	loop expression in expressions {
		# Find the construction node
		allocated = expression.first
		if allocated.instance === NODE_LINK { allocated = allocated.last }

		# Extract the allocator provided using the expression
		allocator = expression.last

		expression.replace(expression.first)

		allocated.first.insert(allocator)
	}
}

strip_links(root: Node): _ {
	links = root.find_all(NODE_LINK)

	loop link in links {
		right = link.last

		if right.match(NODE_VARIABLE) {
			if right.(VariableNode).variable.is_member and not right.(VariableNode).variable.is_static continue
		}
		else right.match(NODE_FUNCTION) {
			if right.(FunctionNode).function.is_member and not right.(FunctionNode).function.is_static continue
		}
		else not right.match(NODE_CONSTRUCTION) continue

		link.replace(right)
	}
}

get_expression_extract_position(expression: Node): Node {
	iterator = expression.parent
	position = expression

	loop (iterator != none) {
		type = iterator.instance
		if type == NODE_INLINE or type == NODE_NORMAL or type == NODE_SCOPE stop

		# Logical operators also act as scopes. You can not for example extract function calls from them, because the function calls are not always executed.
		# Example of what this function should do in the following situation:
		# a(b(i)) and c(d(j))
		# =>
		# { x = b(i), a(x) } and { y = d(j), c(y) }
		if type == NODE_OPERATOR and iterator.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL {
			scope = InlineNode(position.start)
			position.replace(scope)
			scope.add(position)
			stop
		}

		position = iterator
		iterator = iterator.parent
	}

	return position
}

# Summary: Returns the root of the expression which contains the specified node
get_expression_root(node: Node): Node {
	iterator = node

	loop {
		next = iterator.parent
		if next == none stop

		if next.instance == NODE_OPERATOR and next.(OperatorNode).operator.type == OPERATOR_TYPE_CLASSIC {
			iterator = next
		}
		else next.match(NODE_PARENTHESIS | NODE_LINK | NODE_NEGATE | NODE_NOT | NODE_ACCESSOR | NODE_PACK) {
			iterator = next
		}
		else {
			stop
		}
	}

	return iterator
}

extract_calls(root: Node): _ {
	nodes = root.find_every(NODE_ACCESSOR | NODE_CALL | NODE_CONSTRUCTION | NODE_FUNCTION | NODE_HAS | NODE_LAMBDA | NODE_LINK | NODE_LIST_CONSTRUCTION | NODE_PACK_CONSTRUCTION | NODE_WHEN)
	nodes.add_all(find_bool_values(root))

	loop (i = 0, i < nodes.size, i++) {
		node = nodes[i]
		parent = node.parent

		# Calls should always have a parent node
		if parent == none continue

		# Do not extract accessors or links that are destinations or packs
		if node.match(NODE_ACCESSOR | NODE_LINK) and (common.is_edited(node) or node.get_type().is_pack) continue

		# Skip values which are assigned to hidden local variables
		if parent.match(Operators.ASSIGN) and parent.last == node and parent.first.match(NODE_VARIABLE) and parent.first.(VariableNode).variable.is_predictable continue

		# Nothing can be done if the value is directly under a logical operator
		if (parent.match(NODE_OPERATOR) and parent.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL) or parent.match(NODE_CONSTRUCTION) continue

		# Select the parent node, if the current node is a member function call
		if node.match(NODE_FUNCTION) and parent.match(NODE_LINK) and parent.last == node { node = parent }

		position = get_expression_extract_position(node)

		# Do nothing if the call should not move
		if position == node continue

		context = node.get_parent_context()
		variable = context.declare_hidden(node.get_type())

		# Replace the result of the call with the created variable
		node.replace(VariableNode(variable, node.start))

		position.insert(OperatorNode(Operators.ASSIGN, node.start).set_operands(
			VariableNode(variable, node.start),
			node
		))
	}
}

get_increment_extractions(increments: List<Node>): List<Pair<Node, List<Node>>> {
	# Group all increment nodes by their extraction positions
	extractions = List<Pair<Node, List<Node>>>()

	loop increment in increments {
		extraction_position = get_expression_extract_position(increment)
		added = false

		# Try to find an extraction with the same extraction position. If one is found, the current increment should be added into it
		loop extraction in extractions {
			if extraction.first != extraction_position continue
			extraction.second.add(increment)
			added = true
			stop
		}

		if added continue

		# Create a new extraction and add the current increment into it
		extraction = Pair<Node, List<Node>>(extraction_position, List<Node>())
		extraction.second.add(increment)

		extractions.add(extraction)
	}

	return extractions
}

create_local_increment_extract_groups(locals: List<Node>): List<Pair<Variable, List<Node>>> {
	# Group all locals increment nodes by their edited locals
	extractions = List<Pair<Variable, List<Node>>>()

	loop increment in locals {
		variable = increment.first.(VariableNode).variable
		added = false

		# Try to find an extraction with the same local variable. If one is found, the current increment should be added into it
		loop extraction in extractions {
			if extraction.first != variable continue
			extraction.second.add(increment)
			added = true
			stop
		}

		if added continue

		# Create a new extraction and add the current increment into it
		extraction = Pair<Variable, List<Node>>(variable, List<Node>())
		extraction.second.add(increment)

		extractions.add(extraction)
	}

	return extractions
}

extract_local_increments(destination: Node, locals: List<Node>): _ {
	local_extract_groups = create_local_increment_extract_groups(locals)

	loop local_extract in local_extract_groups {
		# Determine the edited local
		edited = local_extract.first
		difference = 0

		loop (i = local_extract.second.size - 1, i >= 0, i--) {
			increment = local_extract.second[i]

			# Determine how much the local is incremented
			step = 1
			if not increment.match(NODE_INCREMENT) { step = -1 }

			# Determine whether the node is a post increment or decrement node
			post = (step == 1 and increment.(IncrementNode).post) or (step == -1 and increment.(DecrementNode).post)

			position = increment.start

			if post { difference -= step }

			# Replace the increment node with the current state of the local variable determined by the difference value
			if difference > 0 {
				increment.replace(OperatorNode(Operators.ADD, position).set_operands(increment.first, NumberNode(SYSTEM_FORMAT, difference, position)))
			}
			else difference < 0 {
				increment.replace(OperatorNode(Operators.SUBTRACT, position).set_operands(increment.first, NumberNode(SYSTEM_FORMAT, -difference, position)))
			}
			else {
				increment.replace(increment.first)
			}

			if not post { difference -= step }
		}

		# Apply the total difference to the local variable at the extract position
		destination.insert(OperatorNode(Operators.ASSIGN_ADD, destination.start).set_operands(VariableNode(edited, destination.start), NumberNode(SYSTEM_FORMAT, -difference, destination.start)))
	}
}

extract_complex_increments(destination: Node, others: List<Node>): _ {
	loop increment in others {
		# Determine the edited node
		edited = increment.first
		environment = destination.get_parent_context()

		value = environment.declare_hidden(increment.get_type())
		position = increment.start
		load = OperatorNode(Operators.ASSIGN, position).set_operands(VariableNode(value, position), edited.clone())

		# Determine how much the target is incremented
		step = 1
		if not increment.match(NODE_INCREMENT) { step = -1 }

		# Determine whether the node is a post increment or decrement node
		post = (step == 1 and increment.(IncrementNode).post) or (step == -1 and increment.(DecrementNode).post)

		if post { destination.insert(load) }

		destination.insert(OperatorNode(Operators.ASSIGN_ADD, position).set_operands(increment.first, NumberNode(SYSTEM_FORMAT, step, position)))
		increment.replace(VariableNode(value, position))

		if not post { destination.insert(load) }
	}
}

find_increments(root: Node): List<Node> {
	result = List<Node>()

	loop node in root {
		result.add_all(find_increments(node))

		# Add the increment later than its child nodes, since the child nodes are executed first
		if node.instance == NODE_INCREMENT or node.instance == NODE_DECREMENT { result.add(node) }
	}

	return result
}

extract_increments(root: Node): _ {
	# Find all increment and decrement nodes
	increments = find_increments(root)
	extractions = get_increment_extractions(increments)

	# Extract increment nodes
	loop extracts in extractions {
		# Create the extract position
		# NOTE: This uses a temporary node, since sometimes the extract position can be next to an increment node, which is problematic
		destination = Node()
		extracts.first.insert(destination)

		# Find all increment nodes, whose destinations are variables
		locals = List<Node>()
		loop iterator in extracts.second { if iterator.first.match(NODE_VARIABLE) locals.add(iterator) }

		# Collect all extracts, whose destinations are not variables
		others = extracts.second
		loop (i = others.size - 1, i >= 0, i--) {
			loop (j = 0, j < locals.size, j++) {
				if others[i] != locals[j] continue
				others.remove_at(i)
				stop
			}
		}

		extract_local_increments(destination, locals)
		extract_complex_increments(destination, others)

		destination.remove()
	}
}

extract_expressions(root: Node): _ {
	extract_calls(root)
	extract_increments(root)
}

# Summary:
# Rewrites self returning functions, so that the self argument is modified after the call:
# Case 1:
# local.modify(...)
# =>
# local = local.modify(...)
# Case 2:
# a[i].b.f(...)
# =>
# t = a[i].b.f(...)
# a[i].b = t
rewrite_self_returning_functions(root: Node): _ {
	calls = root.find_all(NODE_FUNCTION)

	loop call in calls {
		# Process only self returning functions
		function = call.(FunctionNode).function
		if not function.is_self_returning continue

		# Verify the called function is a member function
		if not function.is_member continue

		# Verify the node tree is here as follows: <self>.<call>
		caller = call.parent
		require(caller.instance === NODE_LINK, 'Member call is in invalid state')

		# Find the self argument
		self = call.previous

		# Replace the caller with a placeholder node
		placeholder = Node()
		caller.replace(placeholder)

		return_value = caller

		if self.instance !== NODE_VARIABLE {
			# Create a temporary variable that will store the return value
			context = placeholder.get_parent_context()
			temporary_variable = context.declare_hidden(function.return_type)

			# Store the return value into the temporary variable
			placeholder.insert(OperatorNode(Operators.ASSIGN, caller.start).set_operands(VariableNode(temporary_variable), caller))

			return_value = VariableNode(temporary_variable)
		}

		placeholder.replace(OperatorNode(Operators.ASSIGN, caller.start).set_operands(self.clone(), return_value))
	}
}

InlineContainer {
	destination: Node
	node: Node
	result: Variable

	init(destination: Node, node: Node, result: Variable) {
		this.destination = destination
		this.node = node
		this.result = result
	}
}

# Summary: Determines the variable which will store the result and the node that should contain the inlined content
create_inline_container(type: Type, node: Node, is_value_returned: bool): reconstruction.InlineContainer {
	editor = common.try_get_editor(node)

	if editor != none and editor.match(Operators.ASSIGN) {
		edited = common.get_edited(editor)

		if edited.match(NODE_VARIABLE) and edited.(VariableNode).variable.is_predictable {
			return InlineContainer(editor, InlineNode(node.start), edited.(VariableNode).variable)
		}
	}

	environment = node.get_parent_context()
	container = ScopeNode(Context(environment, NORMAL_CONTEXT), node.start, none as Position, is_value_returned)
	instance = container.context.declare_hidden(type)

	return InlineContainer(node, container, instance)
}

# Summary:
# Tries to find the override for the specified virtual function and registers it to the specified runtime configuration.
# If no override can be found, address of zero is registered.
# This function returns the next offset after registering the override function.
try_register_virtual_function_implementation(type: Type, virtual_function: VirtualFunction, configuration: RuntimeConfiguration, offset: large): large {
	# If the configuration is already completed, no need to do anything
	if configuration.is_completed return offset + SYSTEM_BYTES

	# Find all possible implementations of the virtual function inside the specified type
	result = type.get_override(virtual_function.name)

	if result == none {
		# It seems there is no implementation for this virtual function, register address of zero
		configuration.entry.add(0 as large)
		return offset + SYSTEM_BYTES
	}

	overloads = result.overloads

	# Retrieve all parameter types of the virtual function declaration
	expected = List<Type>()
	loop parameter in virtual_function.parameters { expected.add(parameter.type) }

	# Try to find a suitable implementation for the virtual function from the specified type
	implementation = none as FunctionImplementation

	loop overload in overloads {
		actual = List<Type>()
		loop parameter in overload.parameters { actual.add(parameter.type) }

		if not common.compatible(expected, actual) continue

		implementation = overload.get(expected)
		stop
	}

	if implementation === none {
		# It seems there is no implementation for this virtual function, register address of zero
		configuration.entry.add(0 as large)
		return offset + SYSTEM_BYTES
	}

	configuration.entry.add(Label(implementation.get_fullname() + '_v'))
	return offset + SYSTEM_BYTES
}

copy_type_descriptors(type: Type, supertypes: List<Type>): List<Pair<Type, DataPointerNode>> {
	if type.configuration == none return List<Pair<Type, DataPointerNode>>()

	configuration = type.configuration
	descriptor_count = 0

	if type.supertypes.size > 0 { descriptor_count = supertypes.size }
	else { descriptor_count = supertypes.size + 1 }

	descriptors = List<Pair<Type, DataPointerNode>>(descriptor_count, true)

	if not configuration.is_completed {
		# Complete the descriptor of the type
		configuration.descriptor.add(type.content_size as normal)
		configuration.descriptor.add(type.supertypes.size as normal)

		loop supertype in type.supertypes {
			if supertype.configuration == none abort('Missing supertype runtime configuration')
			configuration.descriptor.add(supertype.configuration.descriptor)
		}
	}

	if type.supertypes.size == 0 {
		# Even though there are no supertypes inherited, an instance of this type can be created and casted to a link.
		# It should be possible to check whether the link represents this type or another
		descriptors[descriptors.size - 1] = Pair<Type, DataPointerNode>(type, TableDataPointerNode(configuration.entry, 0, none as Position))
	}

	offset = SYSTEM_BYTES

	# Look for default implementations of virtual functions in the specified type
	loop iterator in type.virtuals {
		loop virtual_function in iterator.value.overloads {
			# Register an implementation for the current virtual function.
			offset = try_register_virtual_function_implementation(type, virtual_function, configuration, offset)
		}
	}

	loop (i = 0, i < supertypes.size, i++) {
		supertype = supertypes[i]

		# Append configuration information only if it is not generated
		if not configuration.is_completed {
			# Begin a new section inside the configuration table
			configuration.entry.add(configuration.descriptor)
		}

		# Types should not inherit types which do not have runtime configurations such as standard integers
		if supertype.configuration == none abort('Type inherited a type which did not have runtime configuration')

		descriptors[i] = Pair<Type, DataPointerNode>(supertype, TableDataPointerNode(configuration.entry, offset, none as Position))
		offset += SYSTEM_BYTES

		# Iterate all virtual functions of this supertype and connect their implementations
		perspective = type
		if i != 0 { perspective = supertype }
		
		loop virtual_function in perspective.get_all_virtual_functions() {
			offset = try_register_virtual_function_implementation(type, virtual_function, configuration, offset)
		}
	}

	configuration.is_completed = true
	return descriptors
}

# Summary: Constructs an object using stack memory
create_stack_construction(type: Type, construction: Node, constructor: FunctionNode): reconstruction.InlineContainer {
	container = create_inline_container(type, construction, true)
	position = construction.start

	container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(container.result, position),
		CastNode(StackAddressNode(construction.get_parent_context(), type, position), TypeNode(type, position), position)
	))

	supertypes = type.get_all_supertypes()

	# Remove supertypes, which cause a configuration variable duplication
	loop (i = 0, i < supertypes.size, i++) {
		current = supertypes[i].get_configuration_variable()

		loop (j = supertypes.size - 1, j >= i + 1, j--) {
			if current != supertypes[j].get_configuration_variable() continue
			supertypes.remove_at(j)
		}
	}

	descriptors = copy_type_descriptors(type, supertypes)

	# Register the runtime configurations
	loop iterator in descriptors {
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.first.get_configuration_variable(), position), position),
			iterator.second
		))
	}

	# Do not call the initializer function if it is empty
	if not constructor.function.is_empty {
		container.node.add(LinkNode(VariableNode(container.result, position), constructor, position))
	}

	# The inline node must return the value of the constructed object
	container.node.add(VariableNode(container.result, position))

	return container
}

get_allocator(type: Type, construction: ConstructionNode, position: Position, size: large): Node {
	if not construction.has_allocator {
		# If system mode is enabled, constructions without allocators use the stack
		if settings.is_system_mode_enabled {
			return StackAddressNode(construction.get_parent_context(), type, position)
		}

		arguments = Node()
		arguments.add(NumberNode(SYSTEM_SIGNED, size, position))

		return FunctionNode(settings.allocation_function, position).set_arguments(arguments)
	}

	allocator = construction.allocator
	allocator.remove()

	return allocator
}

# Summary: Constructs an object using heap memory
create_heap_construction(type: Type, construction: ConstructionNode, constructor: FunctionNode): reconstruction.InlineContainer {
	container = create_inline_container(type, construction, true)
	position = construction.start

	size = max(1, type.content_size)
	allocator = get_allocator(type, construction, construction.start, size)

	# Cast the allocation to the construction type if needed
	if allocator.get_type() !== type {
		casted = CastNode(allocator, TypeNode(type, position), position)
		allocator = casted
	}

	# The following example creates an instance of a type called Object
	# Example: instance = allocate(sizeof(Object)) as Object
	container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(VariableNode(container.result, position), allocator))

	supertypes = type.get_all_supertypes()

	# Remove supertypes, which cause a configuration variable duplication
	loop (i = 0, i < supertypes.size, i++) {
		current = supertypes[i].get_configuration_variable()

		loop (j = supertypes.size - 1, j >= i + 1, j--) {
			if current != supertypes[j].get_configuration_variable() continue
			supertypes.remove_at(j)
		}
	}

	descriptors = copy_type_descriptors(type, supertypes)

	# Register the runtime configurations
	loop iterator in descriptors {
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.first.get_configuration_variable(), position)),
			iterator.second
		))
	}

	# Do not call the initializer function if it is empty
	if not constructor.function.is_empty {
		container.node.add(LinkNode(VariableNode(container.result, position), constructor, position))
	}

	# The inline node must return the value of the constructed object
	container.node.add(VariableNode(container.result, position))

	return container
}

# Summary: Returns if stack construction should be used
is_stack_construction_preferred(root: Node, value: Node): bool {
	return false
}

# Summary: Rewrites construction expressions so that they use nodes which can be compiled
rewrite_constructions(root: Node): _ {
	constructions = root.find_all(NODE_CONSTRUCTION)

	loop construction in constructions {
		if not is_stack_construction_preferred(root, construction) continue

		container = create_stack_construction(construction.get_type(), construction, construction.(ConstructionNode).constructor)
		container.destination.replace(container.node)
	}

	constructions = root.find_all(NODE_CONSTRUCTION)

	loop construction in constructions {
		container = create_heap_construction(construction.get_type(), construction as ConstructionNode, construction.(ConstructionNode).constructor)
		container.destination.replace(container.node)
	}
}

# Summary:
# Rewrites all list constructions under the specified node tree.
# Pattern:
# list = [ $value-1, $value-2, ... ]
# =>
# { list = List<$shared-type>(), list.add($value-1), list.add($value-2), ... }
rewrite_list_constructions(root: Node): _ {
	constructions = root.find_all(NODE_LIST_CONSTRUCTION) as List<ListConstructionNode>

	loop construction in constructions {
		list_type = construction.get_type()
		list_constructor = list_type.constructors.get_implementation(List<Type>())
		container = create_inline_container(list_type, construction, false)

		# Create a new list and assign it to the result variable
		container.node.add(OperatorNode(Operators.ASSIGN, construction.start).set_operands(
			VariableNode(container.result),
			ConstructionNode(FunctionNode(list_constructor, construction.start), construction.start)
		))

		# Add all the elements to the list
		loop element in construction {
			adder = list_type.get_function(String(parser.STANDARD_LIST_ADDER)).get_implementation(element.get_type())

			arguments = Node()
			arguments.add(element)

			container.node.add(LinkNode(
				VariableNode(container.result),
				FunctionNode(adder, construction.start).set_arguments(arguments),
				construction.start
			))
		}

		container.destination.replace(container.node)
	}
}

# <summary>
# Rewrites all unnamed pack constructions under the specified node tree.
# Pattern:
# result = { $member-1: $value-1, $member-2: $value-2, ... }
# =>
# { result = $unnamed-pack(), result.$member-1 = $value-1, result.$member-2 = $value-2, ... }
rewrite_pack_constructions(root: Node): _ {
	constructions = root.find_all(NODE_PACK_CONSTRUCTION) as List<PackConstructionNode>

	loop construction in constructions {
		type = construction.get_type()
		members = construction.members
		container = create_inline_container(type, construction, false)

		# Initialize the pack result variable
		container.node.add(VariableNode(container.result))

		# Assign the pack member values
		i = 0

		loop value in construction {
			member = type.get_variable(members[i])
			if member == none abort('Missing pack member variable')

			container.node.add(OperatorNode(Operators.ASSIGN, construction.start).set_operands(
				LinkNode(
					VariableNode(container.result),
					VariableNode(member),
					construction.start
				),
				value
			))

			i++ # Switch to the next member
		}

		container.destination.replace(container.node)
	}
}

# Summary: Finds expressions which do not represent statement conditions and can be evaluated to bool values
# Example: element.is_visible = element.color.alpha > 0
find_bool_values(root: Node): List<Node> {
	# NOTE: Find all bool operators, including nested ones, because sometimes even bool operators have nested bool operators, which must be extracted
	# Example: a = i > 0 and f(i < 10) # Here both the right assignment operand and the expression 'i < 10' must be extracted
	candidates = root.find_all(i -> i.match(NODE_OPERATOR) and (i.(OperatorNode).operator.type == OPERATOR_TYPE_COMPARISON or i.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL))
	result = List<Node>()

	loop candidate in candidates {
		# Find the root of the expression
		node = candidate
		loop (node.parent.match(NODE_PARENTHESIS | NODE_INLINE)) { node = node.parent }

		# Skip the current candidate, if it represents a statement condition
		if common.is_condition(node) continue

		# Ensure the parent is not a comparison or a logical operator
		parent = node.parent
		if parent.instance == NODE_OPERATOR and parent.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL continue

		result.add(candidate)
	}

	return result
}

extract_bool_values(root: Node): _ {
	expressions = find_bool_values(root)

	loop expression in expressions {
		container = create_inline_container(primitives.create_bool(), expression, true)
		position = expression.start

		# Create the container, since it will contain a conditional statement
		container.destination.replace(container.node)

		# Initialize the result with value 'false'
		initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result, position),
			NumberNode(SYSTEM_FORMAT, 0, position)
		)

		container.node.add(initialization)

		# The destination is edited inside the following statement
		assignment = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result, position),
			NumberNode(SYSTEM_FORMAT, 1, position)
		)

		# Create a conditional statement which sets the value of the destination variable to true if the condition is true
		environment = initialization.get_parent_context()
		context = Context(environment, NORMAL_CONTEXT)
		
		body = Node()
		body.add(assignment)

		statement = IfNode(context, expression, body, position, none as Position)
		container.node.add(statement)

		# If the container node is placed inside an expression, the node must return the result
		container.node.add(VariableNode(container.result, position))
	}
}

# Summary: Tries to build an assignment operator out of the specified edit
# Examples:
# x++ => x = x + 1
# x-- => x = x - 1
# a *= 2 => a = a * 2
# b[i] /= 10 => b[i] = b[i] / 10
try_rewrite_as_assignment_operator(edit: Node): Node {
	if common.is_value_used(edit) return none as Node
	position = edit.start

	return when(edit.instance) {
		NODE_INCREMENT => {
			destination = edit.(IncrementNode).first.clone()

			OperatorNode(Operators.ASSIGN, position).set_operands(
				destination,
				OperatorNode(Operators.ADD, position).set_operands(
					destination.clone(),
					NumberNode(SYSTEM_FORMAT, 1, position)
				)
			)
		}
		NODE_DECREMENT => {
			destination = edit.(DecrementNode).first.clone()

			OperatorNode(Operators.ASSIGN, position).set_operands(
				destination,
				OperatorNode(Operators.SUBTRACT, position).set_operands(
					destination.clone(),
					NumberNode(SYSTEM_FORMAT, 1, position)
				)
			)
		}
		NODE_OPERATOR => {
			if edit.(OperatorNode).operator.type != OPERATOR_TYPE_ASSIGNMENT return none as Node
			if edit.(OperatorNode).operator == Operators.ASSIGN return edit

			destination = edit.(OperatorNode).first.clone()
			type = edit.(OperatorNode).operator.(AssignmentOperator).operator

			if type == none return none as Node

			OperatorNode(Operators.ASSIGN, position).set_operands(
				destination,
				OperatorNode(type, position).set_operands(
					destination.clone(),
					edit.last.clone()
				)
			)
		}

		else => none as Node
	}
}

# Summary: Ensures all edits under the specified node are assignments
# Example: a += 1 => a = a + 1
rewrite_edits_as_assignments(root: Node): _ {
	edits = root.find_all(i -> i.match(NODE_INCREMENT | NODE_DECREMENT) or (i.instance == NODE_OPERATOR and i.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT))

	loop edit in edits {
		replacement = try_rewrite_as_assignment_operator(edit)

		if replacement == none {
			abort('Could not rewrite editor as an assignment operator')
		}

		edit.replace(replacement)
	}
}

# Summary: Finds all inline nodes, which can be replaced with their own child nodes
remove_redundant_inline_nodes(root: Node): _ {
	inlines = root.find_all(NODE_INLINE)

	loop iterator in inlines {
		# If the inline node contains only one child node, the inline node can be replaced with it
		if iterator.first != none and iterator.first == iterator.last {
			iterator.replace(iterator.first)
		}
		else iterator.parent != none and (common.is_statement(iterator.parent) or iterator.parent.match(NODE_INLINE | NODE_NORMAL)) {
			iterator.replace_with_children(iterator)
		}
	}
}

# Summary:
# Tries to find assign operations which can be written as action operations
# Examples: 
# i = i + 1 => i += 1
# x = 2 * x => x *= 2
# this.a = this.a % 2 => this.a %= 2
construct_assignment_operators(root: Node): _ {
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop assignment in assignments {
		if assignment.last.instance != NODE_OPERATOR continue

		expression = assignment.last as OperatorNode
		value = none as Node

		# Ensure either the left or the right operand is the same as the destination of the assignment
		if expression.first.is_equal(assignment.first) {
			value = expression.last
		}
		else expression.last.is_equal(assignment.first) and expression.operator != Operators.DIVIDE and expression.operator != Operators.MODULUS and expression.operator != Operators.SUBTRACT {
			value = expression.first
		}

		if value == none continue

		operator = Operators.get_assignment_operator(expression.operator)
		if operator == none continue

		assignment.replace(OperatorNode(operator, assignment.start).set_operands(assignment.first, value))
	}
}

# Summary:
# Returns whether the cast converts a pack to another pack and whether it needs to be processed later
is_required_pack_cast(from: Type, to: Type): bool {
	return from != to and from.is_pack and to.is_pack
}



# Summary:
# Finds casts which have no effect and removes them
# Example: x = 0 as large
remove_redundant_casts(root: Node): _ {
	casts = root.find_all(NODE_CAST) as List<CastNode>

	loop cast in casts {
		from = cast.first.get_type()
		to = cast.get_type()

		# Do not remove the cast if it changes the type
		if to != from and not to.match(from) continue

		# Leave pack casts for later
		if is_required_pack_cast(from, to) continue

		# Remove the cast since it does nothing
		cast.replace(cast.first)
	}
}

# Summary:
# Finds assignments which have implicit casts and adds them
add_assignment_casts(root: Node): _ {
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop assignment in assignments {
		to = assignment.first.get_type()
		from = assignment.last.get_type()

		# Skip assignments which do not cast the value
		if to == from or to.match(from) continue

		# If the right operand is a number and it is converted into different kind of number, it can be done without a cast node
		if assignment.last.instance == NODE_NUMBER and from.is_number and to.is_number {
			assignment.last.(NumberNode).convert(to.format)
			continue
		}

		# Remove the right operand from the assignment
		value = assignment.last
		value.remove()

		# Now cast the right operand and add it back
		assignment.add(CastNode(value, TypeNode(to, value.start), value.start))
	}
}

# Summary: Rewrites supertypes accesses so that they can be compiled
# Example:
# Base Inheritor {
# 	a: large
# 
# 	init() {
# 		Base.a = 1
# 		# The expression is rewritten as:
# 		this.a = 1
# 		# The rewritten expression still refers to the same member variable even though Inheritor has its own member variable a
# 	}
# }
rewrite_super_accessors(root: Node): _ {
	links = root.find_top(NODE_LINK) as List<LinkNode>

	loop link in links {
		if not is_using_local_self_pointer(link.last) continue

		if link.last.instance == NODE_FUNCTION {
			node = link.last as FunctionNode
			if node.function.is_static or not node.function.is_member continue
		}
		else link.last.instance == NODE_VARIABLE {
			node = link.last as VariableNode
			if node.variable.is_static or not node.variable.is_member continue
		}
		else {
			continue
		}

		link.first.replace(common.get_self_pointer(link.get_parent_context(), link.first.start))
	}
}

# Summary:
# Returns whether the node uses the local self pointer.
# This function assumes the node is a member object.
is_using_local_self_pointer(node: Node): bool {
	link = node.parent

	# Take into account the following situation:
	# Inheritant Inheritor {
	#   init() { 
	#     Inheritant.init()
	#     Inheritant.member = 0
	#   }
	# }
	if link.first.instance == NODE_TYPE return true

	# Take into account the following situation:
	# Namespace.Inheritant Inheritor {
	#   init() { 
	#     Namespace.Inheritant.init()
	#     Namespace.Inheritant.member = 0
	#   }
	# }
	return link.first.instance == NODE_LINK and link.first.last == NODE_TYPE
}

# Summary: Adds default constructors to all supertypes, if the specified function implementation represents a constructor
add_default_constructors(iterator: FunctionImplementation): _ {
	# Ensure the function represents a constructor or a destructor
	if not iterator.is_constructor and not iterator.is_destructor return

	supertypes = iterator.metadata.parent.(Type).supertypes
	position = iterator.metadata.start

	loop supertype in supertypes {
		# Get all the constructor or destructor overloads of the current supertype
		overloads = none as List<Function>
		if iterator.is_constructor { overloads = supertype.constructors.overloads }
		else { overloads = supertype.destructors.overloads }

		# Check if there is already a function call using any of the overloads above, if so, no need to generate another call
		calls = iterator.node.find_all(NODE_FUNCTION) as List<FunctionNode>

		# Determine whether the user calls any of the supertype constructors manually
		is_supertype_constructor_called = false

		loop call in calls {
			if not overloads.contains(call.function.metadata) and not is_using_local_self_pointer(call) continue
			is_supertype_constructor_called = true
			stop
		}

		if is_supertype_constructor_called continue

		# Get the implementation which requires no arguments
		implementation = none as FunctionImplementation
		if iterator.is_constructor { implementation = supertype.constructors.get_implementation(List<Type>()) }
		else { implementation = supertype.destructors.get_implementation(List<Type>()) }

		# 1. If such implementation can not be found, no automatic call for the current supertype can be generated
		# 2. If the implementation is empty, there is now use calling it
		if implementation == none or implementation.is_empty continue

		# Next try to get the self pointer, this should not fail
		self = common.get_self_pointer(iterator, position)
		if self == none continue

		# Add the default call
		if iterator.is_constructor {
			iterator.node.insert(iterator.node.first, LinkNode(self, FunctionNode(implementation, position), position))
		}
		else {
			iterator.node.add(LinkNode(self, FunctionNode(implementation, position), position))
		}
	}
}

# Summary: Evaluates the values of inspection nodes
rewrite_inspections(root: Node): _ {
	inspections = root.find_all(NODE_INSPECTION) as List<InspectionNode>

	loop inspection in inspections {
		type = inspection.first.get_type()

		if inspection.type == INSPECTION_TYPE_NAME {
			inspection.replace(StringNode(type.string(), inspection.start))
		}
		else inspection.type == INSPECTION_TYPE_STRIDE {
			inspection.replace(NumberNode(SYSTEM_FORMAT, type.allocation_size, inspection.start))
		}
		else inspection.type == INSPECTION_TYPE_SIZE {
			inspection.replace(NumberNode(SYSTEM_FORMAT, type.content_size, inspection.start))
		}
	}
}

# Summary: Returns the first position where a statement can be placed outside the scope of the specified node
get_insert_position(from: Node): Node {
	iterator = from.parent
	position = from

	loop (iterator.instance != NODE_SCOPE) {
		position = iterator
		iterator = iterator.parent
	}

	# If the position happens to become a conditional statement, the insert position should become before it
	if position.instance == NODE_ELSE_IF { position = position.(ElseIfNode).get_root() }
	else position.instance == NODE_ELSE { position = position.(ElseNode).get_root() }

	return position
}

# Summary: Creates a condition which passes if the source has the same type as the specified type in runtime
create_type_condition(source: Node, expected: Type, position: Position): Node {
	type = source.get_type()

	if type.configuration == none or expected.configuration == none {
		# If the configuration of the type is not present, it means that the type can not be inherited
		# Since the type can not be inherited, this means the result of the condition can be determined
		return NumberNode(SYSTEM_FORMAT, (type == expected) as large, position)
	}

	configuration = type.get_configuration_variable()
	start = LinkNode(source, VariableNode(configuration))

	arguments = Node()
	arguments.add(AccessorNode(start, NumberNode(SYSTEM_FORMAT, 0, position), position))
	arguments.add(TableDataPointerNode(expected.configuration.descriptor, 0, position))

	condition = FunctionNode(settings.inheritance_function, position).set_arguments(arguments)
	return condition
}

# Summary: Rewrites is-expressions so that they use nodes which can be compiled
rewrite_is_expressions(root: Node): _ {
	expressions = root.find_all(NODE_IS) as List<IsNode>

	loop (i = expressions.size - 1, i >= 0, i--) {
		expression = expressions[i]

		if expression.has_result_variable continue

		expression.replace(create_type_condition(expression.first, expression.type, expression.start))
		expressions.remove_at(i)
	}

	loop expression in expressions {
		position = expression.start

		# Initialize the result variable
		initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(expression.result),
			NumberNode(SYSTEM_FORMAT, 0, position)
		)

		# The result variable must be initialized outside the condition
		get_insert_position(expression).insert(initialization)

		# Get the context of the expression
		expression_context = expression.get_parent_context()

		object_variable = none as Variable
		load = none as Node

		if expression.first.instance != NODE_VARIABLE {
			# Declare a variable which is used to store the inspected object
			object_type = expression.first.get_type()
			object_variable = expression_context.declare_hidden(object_type)

			# Object variable should be declared
			initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
				VariableNode(object_variable),
				UndefinedNode(object_variable.type, object_variable.type.get_register_format())
			)

			get_insert_position(expression).insert(initialization)

			# Load the inspected object
			load = OperatorNode(Operators.ASSIGN, position).set_operands(
				VariableNode(object_variable),
				expression.first
			)
		}
		else {
			object_variable = expression.first.(VariableNode).variable
		}

		assignment_context = Context(expression_context, NORMAL_CONTEXT)

		# Create a condition which passes if the inspected object is the expected type
		condition = create_type_condition(VariableNode(object_variable), expression.type, position)

		# Create an assignment which assigns the inspected object to the result variable while casting it to the expected type
		assignment = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(expression.result),
			CastNode(VariableNode(object_variable), TypeNode(expression.type), position)
		)

		body = Node()
		body.add(assignment)
		conditional_assignment = IfNode(assignment_context, condition, body, position, none as Position)

		# Create a condition which represents the result of the is expression
		result_condition = OperatorNode(Operators.NOT_EQUALS).set_operands(
			VariableNode(expression.result),
			NumberNode(SYSTEM_FORMAT, 0, position)
		)

		# Replace the expression with the logic above
		result = InlineNode(position)
		if load != none result.add(load)
		result.add(conditional_assignment)
		result.add(result_condition)
		expression.replace(result)
	}
}

# Summary:
# Rewrites when-expressions so that they use nodes which can be compiled
rewrite_when_expressions(root: Node): _ {
	expressions = root.find_all(NODE_WHEN) as List<WhenNode>

	loop expression in expressions {
		position = expression.start

		return_type = expression.try_get_type()
		if return_type == none abort('Could not resolve the return type of a when expression')

		container = create_inline_container(return_type, expression, false)

		# The load must be executed before the actual when-statement
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			expression.inspected.clone(),
			expression.value
		))

		# Define the result variable
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result),
			UndefinedNode(return_type, return_type.get_register_format())
		))

		loop section in expression.sections {
			body = expression.get_section_body(section)

			# Load the return value of the section to the return value variable
			value = body.last
			destination = Node()
			value.replace(destination)

			destination.replace(OperatorNode(Operators.ASSIGN, value.start).set_operands(
				VariableNode(container.result, value.start),
				value
			))

			container.node.add(section)
		}

		container.destination.replace(container.node)
	}
}

# Summary: Rewrites lambda nodes using simpler nodes
rewrite_lambda_constructions(root: Node): _ {
	constructions = root.find_all(NODE_LAMBDA) as List<LambdaNode>

	loop construction in constructions {
		position = construction.start

		environment = construction.get_parent_context()
		implementation = construction.implementation as LambdaImplementation
		implementation.seal()

		type = implementation.internal_type

		container = create_inline_container(type, construction, true)

		# If system mode is enabled, lambdas are just function pointers and capturing variables is not allowed
		if settings.is_system_mode_enabled {
			function_pointer_assignment = OperatorNode(Operators.ASSIGN, position).set_operands(
				VariableNode(container.result),
				FunctionDataPointerNode(implementation, 0, position)
			)

			container.node.add(function_pointer_assignment)
			container.node.add(VariableNode(container.result))
			container.destination.replace(container.node)
			continue
		}

		allocator = none as Node

		if is_stack_construction_preferred(root, construction) {
			allocator = CastNode(StackAddressNode(environment, type, position), TypeNode(type), position)
		}
		else {
			arguments = Node()
			arguments.add(NumberNode(SYSTEM_FORMAT, type.content_size, position))
			call = FunctionNode(settings.allocation_function, position).set_arguments(arguments)

			allocator = CastNode(call, TypeNode(type), position)
		}

		allocation = OperatorNode(Operators.ASSIGN, position).set_operands(VariableNode(container.result), allocator)

		container.node.add(allocation)

		function_pointer_assignment = OperatorNode(Operators.ASSIGN, position).set_operands(
			LinkNode(CastNode(VariableNode(container.result), TypeNode(type), position), VariableNode(implementation.function), position),
			FunctionDataPointerNode(implementation, 0, position)
		)

		container.node.add(function_pointer_assignment)

		loop capture in implementation.captures {
			assignment = OperatorNode(Operators.ASSIGN, position).set_operands(
				LinkNode(CastNode(VariableNode(container.result), TypeNode(type), position), VariableNode(capture), position),
				VariableNode(capture.captured)
			)

			container.node.add(assignment)
		}

		container.node.add(VariableNode(container.result))
		container.destination.replace(container.node)
	}
}

# Summary: Rewrites has nodes using simpler nodes
rewrite_has_expressions(root: Node): _ {
	expressions = root.find_all(NODE_HAS) as List<HasNode>

	loop expression in expressions {
		container = create_inline_container(primitives.create_bool(), expression, true)

		context = expression.get_parent_context()
		position = expression.start

		source = expression.(HasNode).source
		source_type = source.get_type()
		source_variable = none as Variable
		source_load = none as Node

		has_value_function = source_type.get_function(String(RUNTIME_HAS_VALUE_FUNCTION_IDENTIFIER)).get_implementation(List<Type>())
		get_value_function = source_type.get_function(String(RUNTIME_GET_VALUE_FUNCTION_IDENTIFIER)).get_implementation(List<Type>())
		require(has_value_function !== none and get_value_function !== none, 'Inspected object did not have the required functions')

		# 1. Determine the variable that will store the source value
		# 2. Load the source value into the variable if necessary
		if source.instance == NODE_VARIABLE {
			source_variable = source.(VariableNode).variable
		}
		else {
			source_variable = context.declare_hidden(source_type)
			source_load = OperatorNode(Operators.ASSIGN, position).set_operands(VariableNode(source_variable, position), source)
		}

		# Initialize the output variable before the expression
		output_variable = expression.(HasNode).output.variable

		output_initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(output_variable, position),
			CastNode(NumberNode(SYSTEM_FORMAT, 0, position), TypeNode(get_value_function.return_type, position), position)
		)

		get_insert_position(expression).insert(output_initialization)

		# Set the result variable equal to false
		result_initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result, position),
			NumberNode(SYSTEM_FORMAT, 0, position)
		)

		# First the function 'has_value(): bool' must return true in order to call the function 'get_value(): any'
		condition = LinkNode(VariableNode(source_variable, position), FunctionNode(has_value_function, position), position)

		# If the function 'has_value(): bool' returns true, load the value using the function 'get_value(): any' and set the result variable equal to true
		body = Node()

		# Load the value and store it in the output variable
		body.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(output_variable, position),
			LinkNode(VariableNode(source_variable), FunctionNode(get_value_function, position), position)
		))

		# Indicate we have loaded a value
		body.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result, position),
			NumberNode(SYSTEM_FORMAT, 1, position)
		))

		conditional_context = Context(context, NORMAL_CONTEXT)
		conditional = IfNode(conditional_context, condition, body, position, none as Position)

		container.node.add(result_initialization)
		if source_load !== none container.node.add(source_load)
		container.node.add(conditional)
		container.node.add(VariableNode(container.result))

		container.destination.replace(container.node)
	}
}

# Summary:
# Creates all member accessors that represent all non-pack members
# Example (root = object.pack, type = { a: large, other: { b: large, c: large } })
# => { object.pack.a, object.pack.other.b, object.pack.other.c }
create_pack_member_accessors(root: Node, type: Type, position: Position): List<Node> {
	result = List<Node>()

	loop iterator in type.variables {
		member = iterator.value

		# Do not initialize static or constant member variables
		if member.is_static or member.is_constant continue

		accessor = LinkNode(root.clone(), VariableNode(member), position)

		if member.type.is_pack {
			result.add_all(create_pack_member_accessors(accessor, member.type, position))
			continue
		}

		result.add(accessor)
	}

	return result
}

# Summary:
# Load the destination address as follows:
# destination[index] = ...
# =>
# local = destination + index * strideof(destination)
# local[0] = ...
prepare_accessor_destination_for_duplication(context: Context, destination: AccessorNode, interphases: Node, position: Position): _ {
	accessor_base = destination.first
	accessor_index = destination.last.first
	accessor_stride = destination.get_stride()

	local_type = accessor_base.get_type()
	local = context.declare_hidden(local_type)

	accessor_base.replace(VariableNode(local, position))
	accessor_index.replace(NumberNode(SYSTEM_FORMAT, 0, position))

	local_value = OperatorNode(Operators.ADD, position).set_operands(
		accessor_base,
		OperatorNode(Operators.MULTIPLY).set_operands(
			accessor_index,
			NumberNode(SYSTEM_FORMAT, accessor_stride, position)
		)
	)

	local_initialization = OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(local, position),
		local_value
	)

	interphases.insert(local_initialization)
}

# Summary:
# Reduces the number of steps in the specified destination node by extracting expressions from it.
# When the destination node is duplicated, this function should reduce duplicated work.
# The function will add all the produced steps before the 'interphases' position.
prepare_destination_for_duplication(context: Context, destination: Node, interphases: Node): _ {
	position = destination.start

	if destination.instance == NODE_ACCESSOR {
		prepare_accessor_destination_for_duplication(context, destination as AccessorNode, interphases, position)
	}
}

# <summary>
# Finds all usages of packs and rewrites them to be more suitable for compilation
# Example (Here $-prefixes indicate generated hidden variables):
# a = b
# c = f()
# g(c)
# Direct assignments are expanded:
# a.x = b.x
# a.y = b.y
# c = f() <- The original assignment is not removed, because it is needed by the placeholders
# c.x = [Placeholder 1] -> c.x
# c.y = [Placeholder 2] -> c.y
# g(c)
# Pack values are replaced with pack nodes:
# a.x = b.x
# a.y = b.y
# c = f() <- The original assignment is not removed, because it is needed by the placeholders
# c.x = [Placeholder 1] -> c.x
# c.y = [Placeholder 2] -> c.y
# g({ $c.x, $c.y }) <- Here a pack node is created, which creates a pack handle in the back end from the child values
# Member accessors are replaced with local variables:
# $a.x = $b.x
# $a.y = $b.y
# c = f() <- The original assignment is not removed, because it is needed by the placeholders
# c.x = [Placeholder 1] -> c.x
# c.y = [Placeholder 2] -> c.y
# g({ $c.x, $c.y })
# Finally, the placeholders are replaced with the actual nodes:
# $a.x = $b.x
# $a.y = $b.y
# c = f() <- The original assignment is not removed, because it is needed by the placeholders
# $c.x = c.x
# $c.y = c.y
# g({ $c.x, $c.y })
rewrite_pack_usages(environment: Context, root: Node): _ {
	placeholders = List<Pair<Node, Node>>()

	# Direct assignments are expanded:
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop (i = assignments.size - 1, i >= 0, i--) {
		assignment = assignments[i]

		destination = assignment.first
		source = assignment.last
		type = destination.get_type()

		# Skip assignments, whose destination is not a pack
		if not type.is_pack {
			assignments.remove_at(i)
			continue
		}

		container = assignment.parent
		position = assignment.start

		prepare_destination_for_duplication(environment, destination, assignment)

		destinations = create_pack_member_accessors(destination, type, position)
		sources = none as List<Node>

		is_function_assignment = common.is_function_call(assignment.last)
		is_memory_accessed = common.is_memory_accessed(assignment.last)
		use_handle = is_function_assignment or is_memory_accessed

		# The sources of function assignments must be replaced with placeholders, so that they do not get overridden by the local proxies of the members
		if use_handle {
			if destination.instance != NODE_VARIABLE {
				context = assignment.get_parent_context()
				temporary_handle = context.declare_hidden(type)

				# Replace the destination with the temporary handle
				temporary_handle_destination = VariableNode(temporary_handle)
				destination.replace(temporary_handle_destination)
				destination = temporary_handle_destination
			}

			loads = create_pack_member_accessors(destination, type, position)
			sources = List<Node>()
			
			loop (j = 0, j < loads.size, j++) {
				placeholder = Node()
				sources.add(placeholder)

				placeholders.add(Pair<Node, Node>(placeholder, loads[j]))
			}
		}
		else {
			sources = create_pack_member_accessors(source, type, position)
		}

		loop (j = destinations.size - 1, j >= 0, j--) {
			container.insert(assignment.next, OperatorNode(Operators.ASSIGN, position).set_operands(destinations[j], sources[j]))
		}

		# The assignment must be removed, if its source is not a function call
		# NOTE: The function call assignment must be left intact, because it must assign the disposable pack handle, whose usage is demonstrated above
		if not use_handle { assignment.remove() }

		assignments.remove_at(i)
	}

	# Find all the usages of the collected local packs
	local_pack_usages = root.find_all(NODE_VARIABLE).filter(i -> {
		variable: Variable = i.(VariableNode).variable
		return variable.type.is_pack and variable.is_predictable
	})

	local_packs = local_pack_usages.map<Variable>((i: Node) -> i.(VariableNode).variable).distinct()

	# Create the pack proxies for all the collected local packs
	loop local_pack in local_packs { common.get_pack_proxies(local_pack) }

	loop (i = local_pack_usages.size - 1, i >= 0, i--) {
		usage = local_pack_usages[i]
		usage_variable = usage.(VariableNode).variable
		type = usage.get_type()

		# Leave function assignments intact
		# NOTE: If the usage is edited, it must be part of a function assignment, because all the other pack assignments were reduced to member assignments above
		if common.is_edited(usage) continue

		# Consider the following situation:
		# Variable a is a local pack variable and identifiers b and c are nested packs of variable a.
		# We start moving from the brackets, because variable a is a local pack usage.
		# [a].b.c
		# We must move all the way to nested pack c, because only the members of c are expanded.
		# a.b.[c] => PackNode { a.b.c.x, a.b.c.y } => PackNode { $.a.b.c.x, $.a.b.c.y }
		# If we access a normal member through a pack, we replace the usage directly with a local:
		# a.b.[c].x => a.b.c.x => $.a.b.c.x
		member = none as Variable
		path = StringBuilder(usage_variable.name)

		loop {
			# The parent node must be a link, since a member access is expected
			parent = usage.parent
			if parent == none or parent.instance != NODE_LINK stop

			# Ensure the current iterator is used for member access
			next = usage.next
			if next.instance != NODE_VARIABLE stop

			# Continue if a nested pack is accessed
			member = next.(VariableNode).variable
			type = member.type
			usage = parent

			path.append(`.`)
			path.append(member.name)

			if not type.is_pack stop
		}

		# If we are accessing at least one member, add a dot to the beginning of the path
		if member !== none path.insert(0, `.`)

		# Find the local variable that represents the accessed path
		context = usage_variable.parent
		accessed = context.get_variable(path.string())
		require(accessed !== none, 'Failed to find local variable for pack access')

		if member !== none and not type.is_pack {
			# Replace the usage with a local variable:
			usage.replace(VariableNode(accessed, usage.start))
		}
		else {
			# Since we are accessing a pack, we must create a pack from its proxies:
			packer = PackNode(type)
			proxies = common.get_pack_proxies(accessed)

			loop proxy in proxies {
				packer.add(VariableNode(proxy, usage.start))
			}

			usage.replace(packer)
		}

		# Remove the usage from the list, because it was replaced
		local_pack_usages.remove_at(i)
	}

	# Returned packs from function calls are handled last:
	loop placeholder in placeholders {
		placeholder.first.replace(placeholder.second)
	}
}

# Summary:
# Applies a cast to a pack node by changing the inner type
apply_pack_cast(cast: Node, from: Type, to: Type): bool {
	if not from.is_pack and not to.is_pack return false

	# Verify the casted value is a packer and that the value type and target type are compatible
	value = cast.first
	if value.instance != NODE_PACK or not to.match(from) abort(value.start, 'Can not cast the value to a pack')

	# Replace the internal type of the packer with the target type
	value.(PackNode).type = to
	return true
}

# Summary:
# Applies a cast to a number node by converting the inner value
apply_number_cast(cast: Node, from: Type, to: Type): bool {
	# Both of the types must be numbers
	if not from.is_number or not to.is_number return false

	# The casted node must be a number node
	value = cast.first
	if value.instance != NODE_NUMBER return false

	# Convert the value to the target type
	value.(NumberNode).convert(to.(Number).format)
	return true
}

# Summary:
# Finds casts and tries to apply them by changing the casted value
apply_casts(root: Node): _ {
	casts = root.find_all(NODE_CAST).reverse()

	loop cast in casts {
		from = cast.first.get_type()
		to = cast.get_type()

		if from === to continue
		if apply_pack_cast(cast, from, to) continue
		if apply_number_cast(cast, from, to) continue
	}
}

# Summary: Casts called objects to match the expected self pointer type
cast_member_calls(root: Node): _ {
	calls = root.find_all(i -> i.instance == NODE_LINK and i.last.instance == NODE_FUNCTION)

	loop call in calls {
		left = call.first
		function = call.last as FunctionNode

		# Ensure the called object has the correct type when it is passed as a parameter
		expected = function.function.metadata.find_type_parent()
		if expected == none abort('Missing parent type for member call')

		actual = left.get_type()

		if actual === expected or actual.get_supertype_base_offset(expected) == 0 continue

		# Cast the left side to the expected type
		left.remove()
		call.last.insert(CastNode(left, TypeNode(expected), left.start))
	}
}

# Summary:
# Finds comparisons between packs and replaces them with member-wise comparisons.
# Example:
#   a: large
#   b: large
# }
# 
# a == b
# =>
# a.a == b.a && a.b == b.b
rewrite_pack_comparisons(root: Node): _ {
	# Find all comparisons
	comparisons = root.find_all(NODE_OPERATOR).filter(i -> i.match(Operators.EQUALS) or i.match(Operators.ABSOLUTE_EQUALS) or i.match(Operators.NOT_EQUALS) or i.match(Operators.ABSOLUTE_NOT_EQUALS))

	loop comparison in comparisons {
		# Find the left and right side of the comparison
		left = comparison.first
		right = comparison.last

		# Find the type of the left and right side
		left_type = left.get_type()
		right_type = right.get_type()

		# Verify the comparison is between two packs
		if not left_type.is_pack or left_type != right_type continue

		left_members = create_pack_member_accessors(left, left_type, left.start)
		right_members = create_pack_member_accessors(right, right_type, right.start)

		operator = comparison.(OperatorNode).operator

		# Rewrite the comparisons as follows:
		if operator == Operators.EQUALS or operator == Operators.ABSOLUTE_EQUALS {
			# Equals: a == b => a.a == b.a && a.b == b.b && ...
			result = OperatorNode(operator).set_operands(left_members[], right_members[])

			loop (i = 1, i < left_members.size, i++) {
				left_member = left_members[i]
				right_member = right_members[i]

				result = OperatorNode(Operators.LOGICAL_AND).set_operands(result, OperatorNode(operator).set_operands(left_member, right_member))
			}

			comparison.replace(result)
		}
		else {
			# Not equals: a != b => a.a != b.a || a.b != b.b || ...
			result = OperatorNode(operator).set_operands(left_members[], right_members[])

			loop (i = 1, i < left_members.size, i++) {
				left_member = left_members[i]
				right_member = right_members[i]

				result = OperatorNode(Operators.LOGICAL_OR).set_operands(result, OperatorNode(operator).set_operands(left_member, right_member))
			}

			comparison.replace(result)
		}
	}
}

# Summary:
# Creates a pack construction where all members are initialized with zeroes. Nested packs are supported.
# Example:
# pack Size { width: decimal, height: decimal }
# pack Object { name: u8*, x: i32, y: i32, size: Size }
#
# object = 0 as Object
# =>
# object = pack { name: 0, x: 0, y: 0, size: pack { width: 0, height: 0 } as Size } as Object
create_zero_initialized_pack(type: Type, position: Position): PackConstructionNode {
	members = List<String>()
	arguments = List<Node>()

	loop iterator in type.variables {
		member = iterator.value

		# Do not initialize static or constant member variables
		if member.is_static or member.is_constant continue

		argument = none as Node

		# If the member is a pack, create a zero initialized construction for it
		if member.type.is_pack {
			argument = create_zero_initialized_pack(member.type, position)
		}
		else {
			# Initialize the member with zero
			argument = NumberNode(SYSTEM_FORMAT, 0, position)
		}

		members.add(member.name)
		arguments.add(argument)
	}

	construction = PackConstructionNode(members, arguments, position)
	construction.type = type

	return construction
}

# Summary: Rewrites expressions that create packs with all members initialized with zero.
# Example:
# pack Size { width: decimal, height: decimal }
# pack Object { name: u8*, x: i32, y: i32, size: Size }
#
# object = 0 as Object
# =>
# object = pack { name: 0, x: 0, y: 0, size: pack { width: 0, height: 0 } as Size } as Object
rewrite_zero_initialized_packs(root: Node): _ {
	casts = root.find_all(NODE_CAST)

	loop cast in casts {
		type = cast.get_type()

		# Look for expressions that cast zeroes into packs
		if not (type.is_pack and common.is_zero(cast.first)) continue

		cast.replace(create_zero_initialized_pack(type, cast.start))
	}
}

start(implementation: FunctionImplementation, root: Node): _ {
	add_default_constructors(implementation)
	rewrite_inspections(root)
	strip_links(root)
	remove_redundant_parentheses(root)
	remove_redundant_casts(root)
	rewrite_discarded_increments(root)
	assign_allocators_constructions(root)
	rewrite_zero_initialized_packs(root)
	extract_expressions(root)
	rewrite_self_returning_functions(root)
	add_assignment_casts(root)
	rewrite_super_accessors(root)
	rewrite_when_expressions(root)
	rewrite_is_expressions(root)
	rewrite_lambda_constructions(root)
	rewrite_list_constructions(root)
	rewrite_has_expressions(root)
	rewrite_zero_initialized_packs(root) # Rewrite zero initialized packs once again, because other rewriters may have generated these
	rewrite_pack_constructions(root)
	rewrite_constructions(root)
	extract_bool_values(root)
	rewrite_edits_as_assignments(root)
	cast_member_calls(root)
	rewrite_pack_comparisons(root)
	remove_redundant_inline_nodes(root)
	apply_casts(root)
}

clean(root: Node): _ {
	remove_redundant_parentheses(root)
	remove_redundant_casts(root)
	remove_redundant_inline_nodes(root)
	apply_casts(root)
}

end(root: Node): _ {
	construct_assignment_operators(root)
	remove_redundant_inline_nodes(root)

	# NOTE: Inline nodes can be directly under logical operators now, so extract bool values again
	extract_bool_values(root)
}