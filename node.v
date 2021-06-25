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
	instance: small
	start: Position
	parent: Node
	previous: Node
	next: Node
	first: Node
	last: Node
	is_resolvable: bool = false

	match(instance: large) => this.instance == instance

	match(operator: Operator) {
		=> instance == NODE_OPERATOR and this.(OperatorNode).operator == operator
	}

	find_all(type: large) {
		result = List<Node>()

		loop (iterator = first, iterator != none, iterator = iterator.next) {
			if iterator.instance == type result.add(iterator)
			result.add_range(iterator.find_all(type))
		}

		=> result
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

	virtual string() {
		=> String('Node')
	}
}