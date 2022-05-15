namespace statement_optimizer

LoopConditionalStatementLiftupDescriptor {
	statement: IfNode
	dependencies: List<Variable>
	is_condition_predictable: bool
	is_potentially_liftable => dependencies.size > 0 and is_condition_predictable

	init(statement: IfNode) {
		this.statement = statement

		# Find all local variables, which affect the condition
		condition_container = statement.condition_container

		# The condition is predictable when it is not dependent on external factors such as function calls
		is_condition_predictable = condition_container.find(NODE_CALL | NODE_CONSTRUCTION | NODE_FUNCTION | NODE_LINK | NODE_ACCESSOR) === none

		# Load the dependencies only if the condition is predictable, because the loop can not be pulled out if the condition is not predictable
		if not is_condition_predictable {
			dependencies = List<Variable>()
			return
		}

		dependencies = condition_container.find_all(NODE_VARIABLE)
			.map<Variable>((i: Node) -> i.(VariableNode).variable)
			.filter(i -> i.is_predictable)
	}
}

# Summary: Returns whether the specified node might have a direct effect on the flow
is_affector(node: Node) {
	=> node.match(NODE_CALL | NODE_CONSTRUCTION | NODE_DECLARE | NODE_DECREMENT | NODE_DISABLED | NODE_FUNCTION | NODE_INCREMENT | NODE_JUMP | NODE_LABEL | NODE_COMMAND | NODE_RETURN | NODE_OBJECT_LINK | NODE_OBJECT_UNLINK) or (node.instance == NODE_OPERATOR and node.(OperatorNode).operator.type == OPERATOR_TYPE_ASSIGNMENT)
}

# Summary:
# Removes the specified conditional branch while taking into account other branches
remove_conditional_branch(branch: Node) {
	if branch.instance != NODE_IF and branch.instance != NODE_ELSE_IF {
		branch.remove()
		return
	}

	statement = branch.(IfNode).successor

	# If there is no successor, this statement can be removed completely
	if statement === none {
		branch.remove()
		return
	}

	if statement.instance == NODE_ELSE_IF {
		successor = statement as ElseIfNode

		# Create a conditional statement identical to the successor but as an if-statement
		replacement = IfNode()

		loop node in successor {
			replacement.add(node)
		}

		# Since the specified branch will not be executed, replace it with its successor
		successor.replace(replacement)

		# Continue to execute the code below, so that the if-statement is removed
	}
	else {
		# Replace the specified branch with the body of the successor
		statement.replace_with_children(statement.(ElseNode).body)
		return
	}

	branch.remove()
}

# Summary: Finds statements which can not be reached and removes them
remove_unreachable_statements(root: Node) {
	return_statements = root.find_all(NODE_RETURN)
	removed = false

	loop (i = return_statements.size - 1, i >= 0, i--) {
		return_statement = return_statements[i]

		# Remove all statements which are after the return statement in its scope
		iterator = return_statement.parent.last

		loop (iterator !== return_statement) {
			previous = iterator.previous
			iterator.remove()
			iterator = previous
			removed = true
		}
	}

	=> removed
}

remove_abandoned_statements_in_scope(statement: Node) {
	iterator = statement.first

	loop (iterator !== none) {
		# If the iterator represents a statement, it means it contains affectors, because otherwise it would not exist (statements without affectors are removed below)
		if iterator.match(NODE_IF | NODE_ELSE_IF | NODE_ELSE | NODE_LOOP | NODE_INLINE | NODE_SCOPE | NODE_NORMAL) {
			iterator = iterator.next
			continue
		}

		# Do not remove return values of scopes
		if iterator === statement.last and statement.instance == NODE_SCOPE and statement.(ScopeNode).is_value_returned stop

		# 1. If the statement does not contain any node, which has an effect on the flow (affector), it can be removed
		contains_affector = is_affector(iterator) or iterator.find(i -> is_affector(i)) !== none

		# 2. Remove abandoned allocation function calls
		if not contains_affector or common.get_source(iterator).match(settings.allocation_function) {
			iterator.remove()
		}

		iterator = iterator.next
	}
}

remove_abandoned_conditional_statement(node: Node) {
	statement = node as IfNode

	# 1. The statement can not be removed, if its body is not empty
	# 2. The statement can not be removed, if it has a successor
	if statement.body.first !== none or statement.successor !== none return

	# If the condition has multiple steps, the statement can not be removed
	condition_container = statement.condition_container

	if condition_container.first !== condition_container.last return

	# If the condition contains affectors, the statement can not be removed
	affector = condition_container.find(i -> is_affector(i))
	if affector !== none return

	remove_conditional_branch(statement)
}

# Summary:
# Finds all statements, which do not have an effect on the flow, and removes them
remove_abandoned_expressions(root: Node) {
	statements = root.find_all(NODE_IF | NODE_ELSE_IF | NODE_ELSE | NODE_LOOP | NODE_INLINE | NODE_SCOPE | NODE_NORMAL)
	statements.insert(0, root)
	statements.reverse()

	# Contains all conditions and their node types. The node types are needed because the nodes are disabled temporarily
	conditions = Map<Node, large>()

	# Disable all conditions, so that they are categorized as affectors
	# NOTE: Categorizing conditions as affectors saves us from doing some node tree lookups
	loop statement in statements {
		condition = none as Node

		if statement.match(NODE_IF | NODE_ELSE_IF) {
			condition = statement.(IfNode).condition
		}
		else statement.instance == NODE_LOOP and not statement.(LoopNode).is_forever_loop {
			condition = statement.(LoopNode).condition
		}
		else {
			continue
		}

		conditions[condition] = condition.instance
		condition.instance = NODE_DISABLED
	}

	# Restores the instance of the condition of the specified statement from the condition instance table
	enable_condition = (statement: Node) -> {
		condition = when(statement.instance) {
			NODE_IF => statement.(IfNode).condition,
			NODE_ELSE_IF => statement.(ElseIfNode).condition,
			NODE_LOOP => statement.(LoopNode).condition,
			else => none as Node
		}

		condition.instance = conditions[condition]
	}

	# Disables the condition of the specified statement
	disable_condition = (statement: Node) -> {
		condition = when(statement.instance) {
			NODE_IF => statement.(IfNode).condition,
			NODE_ELSE_IF => statement.(ElseIfNode).condition,
			NODE_LOOP => statement.(LoopNode).condition,
			else => none as Node
		}

		condition.instance = NODE_DISABLED
	}

	loop statement in statements {
		if statement.match(NODE_SCOPE | NODE_NORMAL) {
			remove_abandoned_statements_in_scope(statement)
			continue
		}
		else statement.match(NODE_IF | NODE_ELSE_IF) {
			enable_condition(statement)
			remove_abandoned_conditional_statement(statement)
			disable_condition(statement)
			continue
		}
		else statement.instance == NODE_ELSE {
			# The statement can not be removed, if its body is not empty
			if statement.(ElseNode).body.first !== none continue

			remove_conditional_branch(statement)
			continue
		}
		else statement.instance == NODE_LOOP {
			# TODO: Support removing empty loops
			continue
		}
		else statement.instance == NODE_INLINE {
			# Inline nodes can not be removed, if it is not empty
			if statement.first !== none continue
		}

		statement.remove()
	}

	# Restore the condition node types
	loop iterator in conditions {
		condition = iterator.key
		instance = iterator.value
		condition.instance = instance
	}
}

find_edited_locals(statement: Node) {
	# Find all edited variables inside the specified statement
	editors = statement.find_all(i -> i.match(Operators.ASSIGN))
	edited_locals = Map<Variable, List<Node>>()

	loop editor in editors {
		edited = common.get_edited(editor)
		if edited.instance != NODE_VARIABLE or not edited.(VariableNode).variable.is_predictable continue

		edited_local = edited.(VariableNode).variable

		if edited_locals.contains_key(edited_local) {
			edited_locals[edited_local].add(edited)
		}
		else {
			edited_locals[edited_local] = [ edited ]
		}
	}

	editors.clear()
	=> edited_locals
}

# Summary:
# Returns whether the condition is not dependent on the statements inside the specified loop.
# However, the condition can be dependent on the statements that originate from the condition of the specified conditional.
is_condition_isolated(statement: LoopNode, inner_conditional: LoopConditionalStatementLiftupDescriptor, edited_locals: Map<Variable, List<Node>>) {
	condition_scope = statement.condition_container as ScopeNode

	# 1. Dependencies must be defined outside the statement or inside the condition scope
	statement_context = statement.context
	condition_context = condition_scope.context

	loop dependency in inner_conditional.dependencies {
		# 1. If the parent context of the dependency is not inside the statement, the dependency is defined outside
		if not dependency.parent.is_inside(statement_context) continue

		# 2. We can continue, if the dependency is defined inside the condition scope
		if dependency.parent.is_inside(condition_context) continue

		=> false
	}

	# 2. Dependencies can only be edited outside the statement or inside the condition scope
	loop dependency in inner_conditional.dependencies {
		if not edited_locals.contains_key(dependency) continue

		# If any of the edited usages is not inside the condition scope, it means the dependency is edited inside the statement
		# NOTE: All the edited usages are inside the statement, not the whole function
		all_edited = edited_locals[dependency]

		loop edited in all_edited {
			if not edited.is_under(condition_scope) => false
		}
	}

	=> true
}

# Summary:
# Copies the nodes and contexts inside the specified statement and connects it to the specified context.
deep_copy_statement(statement: Node, context: Context) {
	copy = statement.clone()

	# Place the copy inside a container, so that the function below will process the copy by iterating the container node
	container = Node()
	container.add(copy)

	# Group variable usages inside the copied statement by the variable
	usages = container.find_all(NODE_VARIABLE).filter(i -> i.(VariableNode).variable.is_predictable)
	usages_by_variable = assembler.group_by<Node, Variable>(usages, (i: Node) -> i.(VariableNode).variable)

	# Cloning nodes does not copy the context, so we need to copy the contexts as well
	inliner.localize_subcontexts(context, container, usages_by_variable)

	# Detach the copy from the container
	copy.remove()
	copy.parent = none as Node

	=> copy
}

liftup_conditional_statements_from_loop(statement: LoopNode, conditional: IfNode) {
	# Get the environment context
	environment = statement.context.parent

	# Replace the statement with a placeholder node
	placeholder = Node()
	statement.replace(placeholder)

	# Store the parent node that contains the conditional statement
	container = conditional.parent

	# 1. If the only successor is an else statement, we can replace it with its own body
	# 2. If the first successor is an else-if statement, we can rewrite it to an if-statement
	successors = conditional.get_successors()

	if successors.size > 0 {
		successor = successors[0]
		replacement = none as Node

		if successor.instance == NODE_ELSE {
			# Replace the else statement with its body
			replacement = successor.(ElseNode).body
			successor.replace(replacement)
		}
		else {
			# Rewrite the else-if statement to an if-else statement
			replacement = IfNode(successor.start)

			# Move the child nodes of the else-if statement to the if-else statement
			loop child in successor {
				child.remove()
				replacement.add(child)
			}

			# Replace the else-if statement with the if-else statement
			successor.replace(replacement)
		}

		successors[0] = replacement
	}

	# 3. Remove the specified conditional statement. This will form the negative statement, because the successors will be executed.
	negative_scope_context = Context(environment, NORMAL_CONTEXT)
	negative_scope = Node()

	# 3.1. Save the position of the conditional statement and detach it from its parent
	position = conditional.next
	conditional.remove()

	# 3.2. Clone the statement, this will be the negative statement
	negative_statement = deep_copy_statement(statement, negative_scope_context)

	# 4. Insert the body of the conditional before the successors and remove the successors. This will form the positive statement, because the successors will not be executed.
	container.insert(position, conditional.body)

	loop successor in successors {
		successor.remove()
	}

	# 5. Create the positive branch:

	# 5.1. Disconnect the condition context from the loop context
	condition_context = conditional.condition_container.(ScopeNode).context
	condition_context.destroy()

	# 5.2. Connect the condition context to the context surrounding the statement
	condition_context.connect(environment)

	# 5.3. Create a scope for the positive statement
	positive_scope_context = Context(environment, NORMAL_CONTEXT)
	positive_scope = ScopeNode(positive_scope_context, none as Position, none as Position, false)

	# 5.4. Add the positive statement to the scope
	positive_scope.add(statement)

	# 5.5. Connect the context of the statement to the scope context
	statement.context.destroy()
	statement.context.connect(positive_scope_context)

	# 5.6. Form the positive branch by giving the conditional statement the positive scope as body
	# NOTE: The body of the conditional statement was removed at step 4.
	conditional.add(positive_scope)

	# 6. Create the negative branch:

	# 6.1. Add the negative statement to the scope
	negative_scope.add(negative_statement)

	# 6.2. Create an else-statement that will be the negative branch
	negative_branch = ElseNode(negative_scope_context, negative_scope, none as Position, none as Position)

	# 7. Insert the positive branch before the placeholder
	placeholder.insert(conditional)

	# 8. Replace the placeholder with the negative branch
	placeholder.replace(negative_branch)
}

# Summary:
# Find conditional statements, which can be pulled out of loops.
# These conditional statements usually have a condition, which is only dependent constants and local variables, which are not altered inside the loop.
# Example:
# a = random() > 0.5
# loop (i = 0, i < n, i++) { if a { ... } }
# =>
# a = random() > 0.5
# if a { loop (i = 0, i < n, i++) { ... }
# else { loop (i = 0, i < n, i++) { # If-statement is optimized out } }
liftup_conditional_statements_from_loops(root: Node) {
	statements = root.find_all(NODE_LOOP)
	conditionals = root.find_all(NODE_IF)
		.map<LoopConditionalStatementLiftupDescriptor>((i: Node) -> LoopConditionalStatementLiftupDescriptor(i as IfNode))
		.filter(i -> i.is_potentially_liftable)

	loop (i = 0, i < statements.size, i++) {
		statement = statements[i]
		position = statement.start
		inner_conditionals = conditionals.filter(i -> i.statement.is_under(statement))

		# Find all edited variables inside the statement
		edited_locals = find_edited_locals(statement)

		loop (j = inner_conditionals.size - 1, j >= 0, j--) {
			inner_conditional = inner_conditionals[j]
			if not is_condition_isolated(statement, inner_conditional, edited_locals) continue

			liftup_conditional_statements_from_loop(statement, inner_conditional.statement)
		}
	}
}

optimize(context: Context, root: Node) {
	remove_unreachable_statements(root)
	remove_abandoned_expressions(root)
	liftup_conditional_statements_from_loops(root)
}