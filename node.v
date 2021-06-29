NodeIterator {
	node: Node
	current: Node
	next: Node

	init(node: Node) {
		this.node = node
		this.current = none
		this.next = node.first
	}

	value() => current

	next() {
		current = next
		if current == none => false

		next = current.next
		=> true
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

	match(instances: large) => (instances & this.instance) != 0

	match(operator: Operator) {
		=> instance == NODE_OPERATOR and this.(OperatorNode).operator == operator
	}

	# Summary: Finds the first parent, which passes the specified filter
	find_parent(filter: (Node) -> bool) {
		if parent == none => none as Node
		if filter(parent) => parent
		=> parent.find_parent(filter) as Node
	}

	# Summary: Finds the first parent, whose type is the specified type
	find_parent(types: large) {
		if parent == none => none as Node
		if (parent.instance & types) != 0 => parent
		=> parent.find_parent(type) as Node
	}

	# Summary: Returns all nodes, which pass the specified filter
	find_all(filter: (Node) -> bool) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if filter(iterator) result.add(iterator)
			result.add_range(iterator.find_all(filter))
		}

		=> result
	}

	# Summary: Finds all nodes, whose type matches the specified type
	find_all(types: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if (iterator.instance & types) != 0 result.add(iterator)
			result.add_range(iterator.find_all(types))
		}

		=> result
	}

	# Summary: Finds all nodes, whose type is one of the specified types
	find_every(types: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if has_flag(types, iterator.instance) result.add(iterator)
			result.add_range(iterator.find_every(types))
		}

		=> result
	}

	# Summary: Returns the first node, whose type matches the specified type
	find(types: large) {
		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if (iterator.instance & types) != none => iterator
			
			result = iterator.find(types) as Node
			if result != none => result
		}

		=> none as Node
	}

	find_context() {
		if has_flag(NODE_SCOPE | NODE_LOOP | NODE_CONTEXT_INLINE | NODE_TYPE, instance) => this
		if parent == none => none as Node
		=> parent.find_context() as Node
	}

	get_parent_context() {
		node = find_context()

		=> when(node.instance) {
			NODE_SCOPE => node.(ScopeNode).context
			NODE_LOOP => node.(LoopNode).context
			NODE_CONTEXT_INLINE => node.(ContextInlineNode).context
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
			next = iterator.next
			parent.insert(this, iterator)
			iterator = next
		}

		=> remove()
	}

	remove() {
		=> parent != none and parent.remove(this)
	}

	remove(child: Node) {
		if child.parent != this => false

		left = child.previous
		right = child.next

		if left != none { left.next = right }
		if right != none { right.previous = left }

		if first == child { first = right }
		if last == child { last = left }

		=> true
	}

	# Summary: Removes all references from this node to other nodes
	detach() {
		parent = none
		previous = none
		next = none
		first = none
		last = none
	}

	iterator() => NodeIterator(this)

	get_type() {
		type = try_get_type()
		if type == none abort(String('Could not get node type'))
		=> type
	}

	clone() {
		result = copy()
		loop child in this { result.add(child.clone()) }
		=> result
	}

	# Summary: Tries to resolve the potential error state of the node
	virtual resolve(context: Context) {
		=> none as Node
	}

	virtual get_status() {
		=> none as Status
	}

	virtual try_get_type() {
		=> none as Type
	}

	virtual copy() {
		=> Node()
	}

	virtual string() {
		=> String('Node')
	}
}