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
		if root.first != none and root.first.match(NODE_OPERATOR) and root.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL root.replace(root.first)
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
			position.insert(scope)
			scope.add(position)
			stop
		}

		position = iterator
		iterator = iterator.parent
	}

	=> position
}

extract_calls(root: Node) {
	nodes = root.find_every(NODE_CALL | NODE_CONSTRUCTION | NODE_FUNCTION)
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
	if node.parent != none and node.parent.match(Operators.ASSIGN) {
		edited = common.get_edited(node.parent)

		if edited.match(NODE_VARIABLE) and edited.(VariableNode).variable.is_predictable {
			=> InlineContainer(node.parent, InlineNode(node.start), edited.(VariableNode).variable)
		}
	}

	environment = node.get_parent_context()
	container = ContextInlineNode(Context(environment, NORMAL_CONTEXT), node.start)
	instance = container.context.declare_hidden(type)

	=> InlineContainer(node, container, instance)
}

copy_type_descriptors(type: Type, supertypes: List<Type>) {
	descriptors = List<Pair<Type, DataPointerNode>>()
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
	descriptors = copy_type_descriptors(type, supertypes)

	# Register the runtime configurations
	loop iterator in descriptors {
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.key.configuration.variable, position), position),
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
	descriptors = copy_type_descriptors(type, supertypes)

	# Register the runtime configurations
	loop iterator in descriptors {
		container.node.add(OperatorNode(Operators.ASSIGN, position).set_operands(
			LinkNode(VariableNode(container.result, position), VariableNode(iterator.key.configuration.variable, position)),
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

# Summary: Finds expressions which do not represent statement conditions and can be evaluated to bool values
# Example: element.is_visible = element.color.alpha > 0
find_bool_values(root: Node) {
	# NOTE: Find all bool operators, including nested ones, because sometimes even bool operators have nested bool operators, which must be extracted
	# Example: a = i > 0 and f(i < 10) # Here both the right assignment operand and the expression 'i < 10' must be extracted
	candidates = root.find_all(i -> i.match(NODE_OPERATOR) and [i.(OperatorNode).operator.type == OPERATOR_TYPE_COMPARISON or i.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL])
	result = List<Node>()

	loop candidate in candidates {
		node = candidate.find_parent(i -> [not i.match(NODE_PARENTHESIS)])

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
	edits = root.find_all(i -> i.match(NODE_INCREMENT | NODE_DECREMENT) or [i.instance == NODE_OPERATOR and i.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT])

	loop edit in edits {
		replacement = try_rewrite_as_assignment_operator(edit)
		if replacement == none abort('Could not rewrite edit as an assignment operator')

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
# Finds assignments which have implicit casts and adds them
add_assignment_casts(root: Node) {
	assignments = root.find_all(i -> i.match(Operators.ASSIGN))

	loop assignment in assignments {
		to = assignment.first.get_type()
		from = assignment.last.get_type()

		# Skip assignments which do not cast the value
		if to == from continue

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

# Summary: Evaluates the values of inspection nodes
rewrite_inspections(root: Node) {
	inspections = root.find_all(NODE_INSPECTION) as List<InspectionNode>

	loop inspection in inspections {
		type = inspection.first.get_type()

		if inspection.instance == INSPECTION_TYPE_NAME {
			inspection.replace(StringNode(type.string(), inspection.start))
		}
		else {
			inspection.replace(NumberNode(SYSTEM_FORMAT, type.reference_size, inspection.start))
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
	arguments.add(DataPointerNode(expected.configuration.descriptor as large, 0, position))

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

		# Declare a variable which is used to store the inspected object
		object_type = expression.first.get_type()
		object_variable = expression_context.declare_hidden(object_type)

		# Object variable should be declared
		initialization = DeclareNode(object_variable, position)

		get_insert_position(expression).insert(initialization)

		# Load the inspected object
		load = OperatorNode(Operators.ASSIGN, position).set_operands(
			VariableNode(object_variable),
			expression.first
		)

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
		result.add(load)
		result.add(conditional_assignment)
		result.add(result_condition)
		expression.replace(result)
	}
}

start(implementation: FunctionImplementation, root: Node) {
	rewrite_inspections(root)
	strip_links(root)
	remove_redundant_parentheses(root)
	rewrite_discarded_increments(root)
	extract_expressions(root)
	add_assignment_casts(root)
	rewrite_is_expressions(root)
	rewrite_constructions(root)
	extract_bool_values(root)
	rewrite_edits_as_assignments(root)
	remove_redundant_inline_nodes(root)
}

end(root: Node) {
	construct_assignment_operators(root)
	remove_redundant_inline_nodes(root)
}