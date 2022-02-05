namespace reconstruction

# Summary: Removes redundant parentheses in the specified node tree
# Example: x = x * (((x + 1))) => x = x * (x + 1)
remove_redundant_parentheses(root: Node) {
	if root.match(NODE_PARENTHESIS) or root.match(NODE_LIST) {
		loop child in root {
			# Require the child to be a parenthesis node with exactly one child node
			if not child.match(NODE_PARENTHESIS) or child.first == none or child.first != child.last continue
			child.replace(child.first)
		}

		# Remove all parentheses, which block logical operators
		if root.first != none and root.first.match(NODE_OPERATOR) and root.first.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL root.replace(root.first)

		# 1. Ensure the current parenthesis is the only child node of its parent
		# 2. Ensure the current parenthesis has only one child node
		# => The current parenthesis is redundant and it can be replaced with its child node
		if root.parent.first == root.parent.last and root.first == root.last {
			child = root.first
			root.replace(child)
			remove_redundant_parentheses(child)
			return
		}
	}

	loop child in root { remove_redundant_parentheses(child) }
}

# Summary: Rewrites increment and decrement operators as action operations if their values are discard.
# Example 1 (Value is not discarded):
# x = ++i
# Example 2 (Value is discarded)
# Before:
# loop (i = 0, i < n, i++)
# After:
# loop (i = 0, i < n, i += 1)
rewrite_discarded_increments(root: Node) {
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

strip_links(root: Node) {
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

get_expression_extract_position(expression: Node) {
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

	=> position
}

# Summary: Returns the root of the expression which contains the specified node
get_expression_root(node: Node) {
	iterator = node

	loop {
		next = iterator.parent
		if next == none stop

		if next.instance == NODE_OPERATOR and next.(OperatorNode).operator.type != OPERATOR_TYPE_ASSIGNMENT {
			iterator = next
		}
		else next.match(NODE_PARENTHESIS | NODE_LINK | NODE_NEGATE | NODE_NOT | NODE_OFFSET | NODE_PACK) {
			iterator = next
		}
		else {
			stop
		}
	}

	=> iterator
}

extract_calls(root: Node) {
	nodes = root.find_every(NODE_CALL | NODE_CONSTRUCTION | NODE_FUNCTION | NODE_LAMBDA | NODE_LIST_CONSTRUCTION | NODE_PACK_CONSTRUCTION | NODE_WHEN)
	nodes.add_range(find_bool_values(root))

	loop (i = 0, i < nodes.size, i++) {
		node = nodes[i]
		parent = node.parent

		# Calls should always have a parent node
		if parent == none continue

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

get_increment_extractions(increments: List<Node>) {
	# Group all increment nodes by their extraction positions
	extractions = List<Pair<Node, List<Node>>>()

	loop increment in increments {
		extraction_position = get_expression_extract_position(increment)
		added = false

		# Try to find an extraction with the same extraction position. If one is found, the current increment should be added into it
		loop extraction in extractions {
			if extraction.key != extraction_position continue
			extraction.value.add(increment)
			added = true
			stop
		}

		if added continue

		# Create a new extraction and add the current increment into it
		extraction = Pair<Node, List<Node>>(extraction_position, List<Node>())
		extraction.value.add(increment)

		extractions.add(extraction)
	}

	=> extractions
}

create_local_increment_extract_groups(locals: List<Node>) {
	# Group all locals increment nodes by their edited locals
	extractions = List<Pair<Variable, List<Node>>>()

	loop increment in locals {
		variable = increment.first.(VariableNode).variable
		added = false

		# Try to find an extraction with the same local variable. If one is found, the current increment should be added into it
		loop extraction in extractions {
			if extraction.key != variable continue
			extraction.value.add(increment)
			added = true
			stop
		}

		if added continue

		# Create a new extraction and add the current increment into it
		extraction = Pair<Variable, List<Node>>(variable, List<Node>())
		extraction.value.add(increment)

		extractions.add(extraction)
	}

	=> extractions
}

extract_local_increments(destination: Node, locals: List<Node>) {
	local_extract_groups = create_local_increment_extract_groups(locals)

	loop local_extract in local_extract_groups {
		# Determine the edited local
		edited = local_extract.key
		difference = 0

		loop (i = local_extract.value.size - 1, i >= 0, i--) {
			increment = local_extract.value[i]

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

extract_complex_increments(destination: Node, others: List<Node>) {
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

find_increments(root: Node) {
	result = List<Node>()

	loop node in root {
		result.add_range(find_increments(node))

		# Add the increment later than its child nodes, since the child nodes are executed first
		if node.instance == NODE_INCREMENT or node.instance == NODE_DECREMENT { result.add(node) }
	}

	=> result
}

extract_increments(root: Node) {
	# Find all increment and decrement nodes
	increments = find_increments(root)
	extractions = get_increment_extractions(increments)

	# Extract increment nodes
	loop extracts in extractions {
		# Create the extract position
		# NOTE: This uses a temporary node, since sometimes the extract position can be next to an increment node, which is problematic
		destination = Node()
		extracts.key.insert(destination)

		# Find all increment nodes, whose destinations are variables
		locals = List<Node>()
		loop iterator in extracts.value { if iterator.first.match(NODE_VARIABLE) locals.add(iterator) }

		# Collect all extracts, whose destinations are not variables
		others = extracts.value
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

extract_expressions(root: Node) {
	extract_calls(root)
	extract_increments(root)
}

InlineContainer {
	destination: Node
	node: InlineNode
	result: Variable

	init(destination: Node, node: InlineNode, result: Variable) {
		this.destination = destination
		this.node = node
		this.result = result
	}
}

# Summary: Determines the variable which will store the result and the node that should contain the inlined content
create_inline_container(type: Type, node: Node) {
	editor = common.try_get_editor(node)

	if editor != none and editor.match(Operators.ASSIGN) {
		edited = common.get_edited(editor)

		if edited.match(NODE_VARIABLE) and edited.(VariableNode).variable.is_predictable {
			=> InlineContainer(editor, InlineNode(node.start), edited.(VariableNode).variable)
		}
	}

	environment = node.get_parent_context()
	container = ContextInlineNode(Context(environment, NORMAL_CONTEXT), node.start)
	instance = container.context.declare_hidden(type)

	=> InlineContainer(node, container, instance)
}

# Summary:
# Tries to find the override for the specified virtual function and registers it to the specified runtime configuration.
# This function returns the offset after registering the override function.
try_register_virtual_function_implementation(type: Type, virtual_function: VirtualFunction, configuration: RuntimeConfiguration, offset: large) {
	# Find all possible implementations of the virtual function inside the specified type
	result = type.get_override(virtual_function.name)
	if result == none => offset

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

	if implementation == none {
		# It seems there is no implementation for this virtual function
		=> offset
	}

	# Append configuration information only if it is not generated
	if not configuration.is_completed {
		configuration.entry.add(Label(implementation.get_fullname() + '_v'))
	}

	=> offset + SYSTEM_BYTES
}

copy_type_descriptors(type: Type, supertypes: List<Type>) {
	if type.configuration == none => List<Pair<Type, DataPointerNode>>()

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

		# Types should not inherited types which do not have runtime configurations such as standard integers
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
	=> descriptors
}

# Summary: Constructs an object using stack memory
create_stack_construction(type: Type, construction: Node, constructor: FunctionNode) {
	container = create_inline_container(type, construction)
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
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.key.get_configuration_variable(), position), position),
			iterator.value
		))
	}

	# Do not call the initializer function if it is empty
	if not constructor.function.is_empty {
		container.node.add(LinkNode(VariableNode(container.result, position), constructor, position))
	}

	# The inline node must return the value of the constructed object
	container.node.add(VariableNode(container.result, position))

	=> container
}

# Summary: Constructs an object using heap memory
create_heap_construction(type: Type, construction: Node, constructor: FunctionNode) {
	container = create_inline_container(type, construction)
	position = construction.start

	size = max(1, type.content_size)
	arguments = Node()
	arguments.add(NumberNode(SYSTEM_FORMAT, size, position))

	if settings.is_garbage_collector_enabled {
		# TODO: Support garbage collection
	}
	else {
		# The following example creates an instance of a type called Object
		# Example: instance = allocate(sizeof(Object)) as Object
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(container.result, position),
			CastNode(
				FunctionNode(settings.allocation_function, position).set_arguments(arguments),
				TypeNode(type, position),
				position
			)
		))
	}

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
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.key.get_configuration_variable(), position)),
			iterator.value
		))
	}

	# Do not call the initializer function if it is empty
	if not constructor.function.is_empty {
		container.node.add(LinkNode(VariableNode(container.result, position), constructor, position))
	}

	# The inline node must return the value of the constructed object
	container.node.add(VariableNode(container.result, position))

	=> container
}

# Summary: Returns if stack construction should be used
is_stack_construction_preferred(root: Node, value: Node) {
	=> false
}

# Summary: Rewrites construction expressions so that they use nodes which can be compiled
rewrite_constructions(root: Node) {
	constructions = root.find_all(NODE_CONSTRUCTION)

	loop construction in constructions {
		if not is_stack_construction_preferred(root, construction) continue

		container = create_stack_construction(construction.get_type(), construction, construction.(ConstructionNode).constructor)
		container.destination.replace(container.node)
	}

	constructions = root.find_all(NODE_CONSTRUCTION)

	loop construction in constructions {
		container = create_heap_construction(construction.get_type(), construction, construction.(ConstructionNode).constructor)
		container.destination.replace(container.node)
	}
}

# Summary:
# Rewrites all list constructions under the specified node tree.
# Pattern:
# list = [ $value-1, $value-2, ... ]
# =>
# { list = List<$shared-type>(), list.add($value-1), list.add($value-2), ... }
rewrite_list_constructions(root: Node) {
	constructions = root.find_all(NODE_LIST_CONSTRUCTION) as List<ListConstructionNode>

	loop construction in constructions {
		list_type = construction.get_type()
		list_constructor = list_type.constructors.get_implementation(List<Type>())
		container = create_inline_container(list_type, construction)

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
rewrite_pack_constructions(root: Node) {
	constructions = root.find_all(NODE_PACK_CONSTRUCTION) as List<PackConstructionNode>

	loop construction in constructions {
		type = construction.get_type()
		members = construction.members
		container = create_inline_container(type, construction)

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
find_bool_values(root: Node) {
	# NOTE: Find all bool operators, including nested ones, because sometimes even bool operators have nested bool operators, which must be extracted
	# Example: a = i > 0 and f(i < 10) # Here both the right assignment operand and the expression 'i < 10' must be extracted
	candidates = root.find_all(i -> i.match(NODE_OPERATOR) and (i.(OperatorNode).operator.type == OPERATOR_TYPE_COMPARISON or i.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL))
	result = List<Node>()

	loop candidate in candidates {
		node = candidate.find_parent(i -> (not i.match(NODE_INLINE | NODE_PARENTHESIS)))

		# Skip the current candidate, if it represents a statement condition
		if common.is_statement(node) or node.match(NODE_NORMAL) or common.is_condition(candidate) continue

		# Ensure the parent is not a comparison or a logical operator
		if node.match(NODE_OPERATOR) and node.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL continue
		
		result.add(candidate)
	}

	=> result
}

extract_bool_values(root: Node) {
	expressions = find_bool_values(root)

	loop expression in expressions {
		container = create_inline_container(primitives.create_bool(), expression)
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
try_rewrite_as_assignment_operator(edit: Node) {
	if common.is_value_used(edit) => none as Node
	position = edit.start

	=> when(edit.instance) {
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
			if edit.(OperatorNode).operator.type != OPERATOR_TYPE_ASSIGNMENT => none as Node
			if edit.(OperatorNode).operator == Operators.ASSIGN => edit

			destination = edit.(OperatorNode).first.clone()
			type = edit.(OperatorNode).operator.(AssignmentOperator).operator

			if type == none => none as Node

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
rewrite_edits_as_assignments(root: Node) {
	edits = root.find_all(i -> i.match(NODE_INCREMENT | NODE_DECREMENT) or (i.instance == NODE_OPERATOR and i.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT))

	loop edit in edits {
		replacement = try_rewrite_as_assignment_operator(edit)

		if replacement == none {
			abort('Could not rewrite editor as an assignment operator')
		}

		edit.replace(replacement)
	}
}

# Summary: Finds all inlines nodes, which can be replaced with their own child nodes
remove_redundant_inline_nodes(root: Node) {
	inlines = root.find_all(NODE_INLINE | NODE_CONTEXT_INLINE)

	loop iterator in inlines {
		# If the inline node contains only one child node, the inline node can be replaced with it
		if iterator.first != none and iterator.first == iterator.last {
			iterator.replace(iterator.first)
		}
		else iterator.parent != none and [common.is_statement(iterator.parent) or iterator.parent.match(NODE_INLINE | NODE_NORMAL)] {
			iterator.replace_with_children(iterator)
		}
		else {
			continue
		}

		if not iterator.(InlineNode).is_context continue

		environment = iterator.get_parent_context()
		environment.merge(iterator.(ContextInlineNode).context)
	}
}

# Summary:
# Tries to find assign operations which can be written as action operations
# Examples: 
# i = i + 1 => i += 1
# x = 2 * x => x *= 2
# this.a = this.a % 2 => this.a %= 2
construct_assignment_operators(root: Node) {
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop assignment in assignments {
		if assignment.last.instance != NODE_OPERATOR continue

		expression = assignment.last as OperatorNode
		value = none as Node

		# Ensure either the left or the right operand is the same as the destination of the assignment
		if expression.first.equals(assignment.first) {
			value = expression.last
		}
		else expression.last.equals(assignment.first) and expression.operator != Operators.DIVIDE and expression.operator != Operators.MODULUS and expression.operator != Operators.SUBTRACT {
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
is_required_pack_cast(from: Type, to: Type) {
	=> from != to and from.is_pack and to.is_pack
}

# Summary:
# Finds casts which have no effect and removes them
# Example: x = 0 as large
remove_redundant_casts(root: Node) {
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
add_assignment_casts(root: Node) {
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

		# If the left operand represents a pack and the right operand is zero, we should not do anything, since this is a special case
		if to.is_pack and common.is_zero(assignment.last) continue

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
rewrite_super_accessors(root: Node) {
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
is_using_local_self_pointer(node: Node) {
	link = node.parent

	# Take into account the following situation:
	# Inheritant Inheritor {
	#   init() { 
	#     Inheritant.init()
	#     Inheritant.member = 0
	#   }
	# }
	if link.first.instance == NODE_TYPE => true

	# Take into account the following situation:
	# Namespace.Inheritant Inheritor {
	#   init() { 
	#     Namespace.Inheritant.init()
	#     Namespace.Inheritant.member = 0
	#   }
	# }
	=> link.first.instance == NODE_LINK and link.first.last == NODE_TYPE
}

# Summary: Adds default constructors to all supertypes, if the specified function implemenation represents a constructor
add_default_constructors(iterator: FunctionImplementation) {
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
rewrite_inspections(root: Node) {
	inspections = root.find_all(NODE_INSPECTION) as List<InspectionNode>

	loop inspection in inspections {
		type = inspection.first.get_type()

		if inspection.type == INSPECTION_TYPE_NAME {
			inspection.replace(StringNode(type.string(), inspection.start))
		}
		else inspection.type == INSPECTION_TYPE_CAPACITY {
			inspection.replace(NumberNode(SYSTEM_FORMAT, type.content_size, inspection.start))
		}
		else inspection.type == INSPECTION_TYPE_SIZE {
			inspection.replace(NumberNode(SYSTEM_FORMAT, type.allocation_size, inspection.start))
		}
	}
}

# Summary: Returns the first position where a statement can be placed outside the scope of the specified node
get_insert_position(from: Node) {
	iterator = from.parent
	position = from

	loop (iterator.instance != NODE_SCOPE) {
		position = iterator
		iterator = iterator.parent
	}

	# If the position happens to become a conditional statement, the insert position should become before it
	if position.instance == NODE_ELSE_IF { position = position.(ElseIfNode).get_root() }
	else position.instance == NODE_ELSE { position = position.(ElseNode).get_root() }

	=> position
}

# Summary: Creates a condition which passes if the source has the same type as the specified type in runtime
create_type_condition(source: Node, expected: Type, position: Position) {
	type = source.get_type()

	if type.configuration == none or expected.configuration == none {
		# If the configuration of the type is not present, it means that the type can not be inherited
		# Since the type can not be inherited, this means the result of the condition can be determined
		=> NumberNode(SYSTEM_FORMAT, (type == expected) as large, position)
	}

	configuration = type.get_configuration_variable()
	start = LinkNode(source, VariableNode(configuration))

	arguments = Node()
	arguments.add(AccessorNode(start, NumberNode(SYSTEM_FORMAT, 0, position), position))
	arguments.add(TableDataPointerNode(expected.configuration.descriptor, 0, position))

	condition = FunctionNode(settings.inheritance_function, position).set_arguments(arguments)
	=> condition
}

# Summary: Rewrites is-expressions so that they use nodes which can be compiled
rewrite_is_expressions(root: Node) {
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
rewrite_when_expressions(root: Node) {
	expressions = root.find_all(NODE_WHEN) as List<WhenNode>

	loop expression in expressions {
		position = expression.start

		return_type = expression.try_get_type()
		if return_type == none abort('Could not resolve the return type of a when expression')

		container = create_inline_container(return_type, expression)

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
rewrite_lambda_constructions(root: Node) {
	constructions = root.find_all(NODE_LAMBDA) as List<LambdaNode>

	loop construction in constructions {
		position = construction.start

		environment = construction.get_parent_context()
		implementation = construction.implementation as LambdaImplementation
		implementation.seal()

		type = implementation.internal_type

		container = create_inline_container(type, construction)
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

# Summary:
# Creates all member accessors that represent all non-pack members
# Example (root = object.pack, type = { a: large, other: { b: large, c: large } })
# => { object.pack.a, object.pack.other.b, object.pack.other.c }
create_pack_member_accessors(root: Node, type: Type, position: Position) {
	result = List<Node>()
	is_none = common.is_zero(root)

	loop iterator in type.variables {
		member = iterator.value
		accessor = none as Node

		if is_none { accessor = root.clone() }
		else { accessor = LinkNode(root.clone(), VariableNode(member), position) }

		if member.type.is_pack {
			result.add_range(create_pack_member_accessors(accessor, member.type, position))
			continue
		}

		result.add(accessor)
	}

	=> result
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
rewrite_pack_usages(implementation: FunctionImplementation, root: Node) {
	placeholders = List<KeyValuePair<Node, Node>>()

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

		destinations = create_pack_member_accessors(destination, type, position)
		sources = none as List<Node>

		is_function_assignment = assignment.last.match(NODE_CALL | NODE_FUNCTION) or (assignment.last.instance == NODE_LINK and assignment.last.last.match(NODE_CALL | NODE_FUNCTION))

		# The sources of function assignments must be replaced with placeholders, so that they do not get overriden by the local representives of the members
		if is_function_assignment {
			loads = create_pack_member_accessors(destination, type, position)
			sources = List<Node>()
			
			loop (j = 0, j < loads.size, j++) {
				placeholder = Node()
				sources.add(placeholder)

				placeholders.add(KeyValuePair<Node, Node>(placeholder, loads[j]))
			}
		}
		else {
			sources = create_pack_member_accessors(source, type, position)
		}

		loop (j = destinations.size - 1, j >= 0, j--) {
			container.insert(assignment.next, OperatorNode(Operators.ASSIGN, position).set_operands(destinations[j], sources[j]))
		}

		# The assigment must be removed, if its source is not a function call
		# NOTE: The function call assignment must be left intact, because it must assign the disposable pack handle, whose usage is demonstrated above
		if not is_function_assignment { assignment.remove() }

		assignments.remove_at(i)
	}

	# Pack values are replaced with pack nodes:
	# Find all local variables, which are packs
	local_packs = List<Variable>()

	loop local in implementation.locals {
		if local.type.is_pack { local_packs.add(local) }
	}

	loop parameter in implementation.parameters {
		if parameter.type.is_pack { local_packs.add(parameter) }
	}

	###
	NOTE: Locals and parameters should cover all
	loop iterator in implementation.variables {
		variable = iterator.value
		if variable.type.is_pack { local_packs.add(variable) }
	}
	###

	# Create the pack representives for all the collected local packs
	loop local_pack in local_packs { common.get_pack_representives(local_pack) }

	# Find all the usages of the collected local packs
	local_pack_usages = root.find_all(NODE_VARIABLE).filter(i -> local_packs.contains(i.(VariableNode).variable))

	loop (i = local_pack_usages.size - 1, i >= 0, i--) {
		usage = local_pack_usages[i]
		type = usage.get_type()

		# Leave function assignments intact
		# NOTE: If the usage is edited, it must be part of a function assignment, because all the other pack assignments were reduced to member assignments above
		if common.is_edited(usage) continue

		# Consider the following situation:
		# Variable a is a local pack variable and identifiers b and c are nested packs of variable a.
		# We start moving from the brackets, because variable a is a local pack usage.
		# [a].b.c
		# We must move all the way to nested pack c, because only the members of c are expanded.
		# a.b.[c] => Packer { a.b.c.x, a.b.c.y }
		# The next loop will transform the packer elements:
		# a.b.[c] => Packer { a.b.c.x, a.b.c.y } => Packer { $local-1, $local-2 }
		loop {
			# The parent node must be a link, since a member access is expected
			parent = usage.parent
			if parent == none or parent.instance != NODE_LINK stop

			# Ensure the current iterator is used for member access
			next = usage.next
			if next.instance != NODE_VARIABLE stop

			# Continue if a nested pack is accessed
			member = next.(VariableNode).variable
			if not member.type.is_pack stop

			type = member.type
			usage = parent
		}

		# Remove the usage from the list, because it will be replaced with a pack node
		local_pack_usages.remove_at(i)
		
		packer = PackNode(type)

		loop accessor in create_pack_member_accessors(usage, type, usage.start) {
			packer.add(accessor)
		}

		usage.replace(packer)
	}

	# Member accessors are replaced with local variables:
	local_pack_usages = root.find_all(NODE_VARIABLE).filter(i -> local_packs.contains(i.(VariableNode).variable))

	# NOTE: All usages are used to access a member here
	loop usage in local_pack_usages {
		# Leave the function assignments intact
		if common.is_edited(usage) continue

		# NOTE: Add a prefix, because name could conflict with hidden variables
		name = String(`.`) + usage.(VariableNode).variable.name
		iterator = usage
		type = none as Type

		loop (iterator != none) {
			# The parent node must be a link, since a member access is expected
			parent = iterator.parent
			if parent == none or parent.instance != NODE_LINK stop

			# Ensure the current iterator is used for member access
			next = iterator.next
			if next.instance != NODE_VARIABLE stop

			# Append the member to the name
			member = next.(VariableNode).variable
			name = name + String(`.`) + member.name

			iterator = parent
			type = member.type

			if not type.is_pack stop
		}

		if type == none abort('Pack member did not have a type')

		# Find or create the representive for the member access
		context = usage.(VariableNode).variable.parent
		representive = context.get_variable(name)
		if representive == none abort('Missing pack member')

		iterator.replace(VariableNode(representive, usage.start))
	}

	# Returned packs from function calls are handled last:
	loop placeholder in placeholders {
		placeholder.key.replace(placeholder.value)
	}

	# Find all pack casts and apply them
	casts = root.find_all(NODE_CAST).filter(i -> i.get_type().is_pack) as List<CastNode>

	loop cast in casts {
		from = cast.first.get_type()
		to = cast.get_type()

		# Verify the casted value is a packer and that the value type and target type are compatible
		if cast.first.instance != NODE_PACK or (to != from and not to.match(from)) abort('Can not cast the value to a pack')

		value = cast.first as PackNode

		# Replace the internal type of the packer with the target type
		value.type = to
	}
}

start(implementation: FunctionImplementation, root: Node) {
	add_default_constructors(implementation)
	rewrite_inspections(root)
	strip_links(root)
	remove_redundant_parentheses(root)
	remove_redundant_casts(root)
	rewrite_discarded_increments(root)
	extract_expressions(root)
	add_assignment_casts(root)
	rewrite_super_accessors(root)
	rewrite_when_expressions(root)
	rewrite_is_expressions(root)
	rewrite_lambda_constructions(root)
	rewrite_list_constructions(root)
	rewrite_pack_constructions(root)
	rewrite_constructions(root)
	extract_bool_values(root)
	rewrite_edits_as_assignments(root)
	remove_redundant_inline_nodes(root)
	# TODO: Implement pack comparisons
}

end(root: Node) {
	construct_assignment_operators(root)
	remove_redundant_inline_nodes(root)

	# NOTE: Inline nodes can be directly under logical operators now, so extract bool values again
	extract_bool_values(root)
}