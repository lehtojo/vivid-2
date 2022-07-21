NodeIterator {
	node: Node
	current: Node
	next: Node

	init(node: Node) {
		this.node = node
		this.current = none
		this.next = node.first
	}

	value() {
		return current
	}

	next() {
		current = next
		if current == none return false

		next = current.next
		return true
	}

	reset() {
		next = node.first
	}
}

Node {
	instance: large
	start: Position
	parent: Node
	previous: Node
	next: Node
	first: Node
	last: Node
	is_resolvable: bool = false

	init() {
		this.instance = NODE_NORMAL
	}

	match(instances: large) {
		return (instances & this.instance) != 0
	}

	match(operator: Operator) {
		return instance == NODE_OPERATOR and this.(OperatorNode).operator == operator
	}

	match(variable: Variable) {
		return instance == NODE_VARIABLE and this.(VariableNode).variable === variable
	}

	match(implementation: FunctionImplementation) {
		return instance == NODE_FUNCTION and this.(FunctionNode).function === implementation
	}

	# Summary: Finds the first parent, which passes the specified filter
	find_parent(filter: (Node) -> bool) {
		if parent == none return none as Node
		if filter(parent) return parent
		return parent.find_parent(filter) as Node
	}

	# Summary: Finds the first parent, whose type is the specified type
	find_parent(types: large) {
		if parent == none return none as Node
		if (parent.instance & types) != 0 return parent
		return parent.find_parent(types) as Node
	}

	# Summary: Returns all nodes, which pass the specified filter
	find_all(filter: (Node) -> bool) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if filter(iterator) result.add(iterator)
			result.add_all(iterator.find_all(filter))
		}

		return result
	}

	# Summary: Finds all nodes, whose type matches the specified type
	find_all(types: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if (iterator.instance & types) != 0 result.add(iterator)
			result.add_all(iterator.find_all(types))
		}

		return result
	}

	# Summary: Finds all nodes, whose type is one of the specified types
	find_every(types: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if has_flag(types, iterator.instance) result.add(iterator)
			result.add_all(iterator.find_every(types))
		}

		return result
	}

	# Summary: Returns the first child node, which pass the specified filter. None is returned, if no child node passes the filter.
	find(filter: (Node) -> bool) {
		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if filter(iterator) return iterator

			result = iterator.find(filter) as Node
			if result != none return result
		}

		return none as Node
	}

	# Summary: Returns the first node, whose type matches the specified type
	find(types: large) {
		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if (iterator.instance & types) != none return iterator
			
			result = iterator.find(types) as Node
			if result != none return result
		}

		return none as Node
	}

	# Summary: Returns a list of nodes, which pass the specified filter. However the list can not contain nodes, which are under other returned nodes, since only the top ones are returned.
	find_top(filter: (Node) -> bool) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if filter(iterator) { result.add(iterator) }
			else { result.add_all(iterator.find_top(filter)) }
		}

		return result
	}

	# Summary: Returns a list of nodes, whose type is the specified node type. However the list can not contain nodes, which are under other returned nodes, since only the top ones are returned.
	find_top(types: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if (iterator.instance & types) != none { result.add(iterator) }
			else { result.add_all(iterator.find_top(types)) }
		}

		return result
	}

	find_context() {
		if has_flag(NODE_SCOPE | NODE_LOOP | NODE_TYPE, instance) return this
		if parent == none return none as Node
		return parent.find_context() as Node
	}

	# Summary: Returns whether this node is under the specified node
	is_under(node: Node) {
		iterator = parent

		loop (iterator != node and iterator != none) {
			iterator = iterator.parent
		}

		return iterator == node
	}

	try_get_parent_context() {
		node = find_context()
		if node == none return none as Context

		return when(node.instance) {
			NODE_SCOPE => node.(ScopeNode).context
			NODE_LOOP => node.(LoopNode).context
			NODE_TYPE => node.(TypeNode).type
			else => none as Context
		}
	}

	get_parent_context() {
		node = find_context()

		return when(node.instance) {
			NODE_SCOPE => node.(ScopeNode).context
			NODE_LOOP => node.(LoopNode).context
			NODE_TYPE => node.(TypeNode).type
			else => {
				abort('Invalid context node')
				none as Context
			}
		}
	}

	add(node: Node) {
		node.parent = this
		node.previous = last
		node.next = none

		if first == none {
			first = node
		}

		if last != none {
			last.next = node
		}

		last = node
	}

	# Summary: Transfers the child nodes of the specified node to this node and detaches the specified node
	merge(node: Node) {
		loop iterator in node {
			add(iterator)
		}

		node.detach()
	}

	insert(node: Node) {
		parent.insert(this, node)
	}

	insert(position: Node, child: Node) {
		if position == none {
			if child.parent != none child.parent.remove(child)
			add(child)
			return
		}

		if position == first { first = child }

		left = position.previous

		if left != none { left.next = child }

		position.previous = child

		if child.parent != none child.parent.remove(child)

		child.parent = position.parent
		child.previous = left
		child.next = position
	}

	insert_children(children: Node) {
		iterator = children.first

		loop (iterator !== none) {
			next: Node = iterator.next
			insert(iterator)
			iterator = next
		}
	}

	# Summary: Moves the specified node into the place of this node
	replace(node: Node) {
		# No need to replace if the replacement is this node
		if node == this return

		if previous == none {
			if parent != none { parent.first = node }
		}
		else {
			previous.next = node
		}

		if next == none {
			if parent != none { parent.last = node }
		}
		else {
			next.previous = node
		}

		node.parent = parent
		node.previous = previous
		node.next = next
	}

	replace_with_children(root: Node) {
		iterator = root.first

		loop (iterator != none) {
			next: Node = iterator.next
			parent.insert(this, iterator)
			iterator = next
		}

		return remove()
	}

	remove() {
		return parent != none and parent.remove(this)
	}

	remove(child: Node) {
		if child.parent != this return false

		left = child.previous
		right = child.next

		if left != none { left.next = right }
		if right != none { right.previous = left }

		if first == child { first = right }
		if last == child { last = left }

		return true
	}

	# Summary: Removes all references from this node to other nodes
	detach() {
		parent = none
		previous = none
		next = none
		first = none
		last = none
	}

	private static get_nodes_under_shared_parent(a: Node, b: Node) {
		path_a = List<Node>()
		path_b = List<Node>()

		loop (iterator = a, iterator != none, iterator = iterator.parent) { path_a.add(iterator) }
		loop (iterator = b, iterator != none, iterator = iterator.parent) { path_b.add(iterator) }
		
		path_a.reverse()
		path_b.reverse()

		i = 0
		count = min(path_a.size, path_b.size)

		loop (i < count, i++) {
			if path_a[i] != path_b[i] stop
		}

		# The following situation means that the nodes do not have a shared parent
		if i == 0 return none as Pair<Node, Node>

		# The following situation means that one of the nodes is parent of the other
		if i == count return Pair<Node, Node>(none as Node, none as Node)

		return Pair<Node, Node>(path_a[i], path_b[i])
	}

	# Summary: Returns whether this node is placed before the specified node
	is_before(other: Node) {
		positions = get_nodes_under_shared_parent(other, this)
		if positions == none abort('Nodes did not have a shared parent')
		if positions.key == none return false

		# If this node is after the specified position node (other), the position node can be found by iterating backwards
		iterator = positions.value
		target = positions.key

		if target == iterator return false

		# Iterate backwards and try to find the target node
		loop (iterator != none) {
			if iterator == target return false
			iterator = iterator.previous
		}

		return true
	}
	
	# Summary: Returns whether this node is placed after the specified node
	is_after(other: Node) {
		positions = get_nodes_under_shared_parent(other, this)
		if positions == none abort('Nodes did not have a shared parent')
		if positions.key == none return false

		# If this node is after the specified position node (other), the position node can be found by iterating backwards
		iterator = positions.value
		target = positions.key

		if target == iterator return false

		# Iterate backwards and try to find the target node
		loop (iterator != none) {
			if iterator == target return true
			iterator = iterator.previous
		}

		return false
	}

	iterator() {
		return NodeIterator(this)
	}

	get_type() {
		type = try_get_type()
		if type === none { abort('Could not get node type') }
		return type
	}

	clone() {
		result = copy()
		loop child in this { result.add(child.clone()) }
		return result
	}

	protected is_tree_equal(other: Node) {
		if this === none or other === none or this.instance != other.instance return false

		expected = first
		actual = other.first

		loop {
			# If either one is none, return true only if both are none
			if expected === none or actual === none return expected === actual

			# Compare the node instances
			if expected.instance != actual.instance return false

			# Compare the addresses of both nodes and use the internal comparison function
			if expected !== actual and not expected.is_equal(actual) return false

			expected = expected.next
			actual = actual.next
		}
	}

	virtual is_equal(other: Node) {
		return is_tree_equal(other)
	}

	# Summary: Tries to resolve the potential error state of the node
	virtual resolve(context: Context) {
		return none as Node
	}

	virtual get_status() {
		return none as Status
	}

	virtual try_get_type() {
		return none as Type
	}

	virtual copy() {
		return Node()
	}

	virtual string() {
		return "Node"
	}
}