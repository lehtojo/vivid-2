# Summary:
# Represents a bitset that can automatically grow depending on needs
DynamicBitset {
	readable data: link
	readable size: normal
	readable max_size: normal

	init(size: normal, max_size: normal) {
		require(size <= max_size, 'Maximum bitset size was exceeded')
		this.max_size = max_size
		this.size = size
		this.data = allocate(size / 8 + 1)
	}

	private grow(expanded_size: normal) {
		require(expanded_size <= max_size, 'Maximum bitset size was exceeded')

		# Allocate a larger memory buffer, copy the old data there and deallocate the old memory
		expanded_data = allocate(expanded_size / 8 + 1)
		copy(data, size / 8 + 1, expanded_data)
		deallocate(data)

		this.data = expanded_data
		this.size = expanded_size
	}

	set(i: large) {
		require(i >= 0, 'Index can not be negative')

		# Grow the bitset if the specified index is outside the allocated memory
		if i >= size grow(i + 1)

		# Set the corresponding bit as follows: data[i / 8] |= (1 <| (i % 8))
		slot = i / 8
		mask = 1 <| (i - slot * 8)
		data[slot] |= mask
	}

	unset(i: large) {
		require(i >= 0, 'Index can not be negative')

		# Grow the bitset if the specified index is outside the allocated memory
		if i >= size grow(i + 1)

		# Unset the corresponding bit as follows: data[i / 8] &= !(1 <| (i % 8))
		slot = i / 8
		mask = 1 <| (i - slot * 8)
		data[slot] &= !mask
	}

	get(i: large) {
		require(i >= 0, 'Index can not be negative')

		# Grow the bitset if the specified index is outside the allocated memory
		if i >= size grow(i + 1)

		# Determine if the bit is set as follows: (data[i / 8] & (1 <| (i % 8))) != 0
		slot = i / 8
		mask = 1 <| (i - slot * 8)
		return (data[slot] & mask) != 0
	}

	dispose() {
		deallocate(data)
	}
}

pack LoopDescriptor {
	start: Label
	end: Label
}

StatementFlow {
	constant DEFAULT_MAX_BITSET_SIZE = 10000000
	constant DEFAULT_MAX_DEPTH = 10

	nodes: List<Node> = List<Node>()
	indices: Map<Node, normal> = Map<Node, normal>()
	jumps: Map<JumpNode, normal> = Map<JumpNode, normal>()
	labels: Map<String, normal> = Map<String, normal>()
	paths: Map<String, List<JumpNode>> = Map<String, List<JumpNode>>()
	loops: Map<LoopNode, LoopDescriptor> = Map<LoopNode, LoopDescriptor>()
	end: Label
	label_identity: normal = 0

	get_next_label() {
		return to_string(label_identity++)
	}

	init(root: Node) {
		end = Label(get_next_label())
		linearise(root)
		add(LabelNode(end, none as Position))

		register_jumps_and_labels()
	}

	# Summary:
	# Registers the indices of all jumps and labels.
	# Groups all the jumps by their destination labels as well.
	register_jumps_and_labels() {
		loop iterator in indices {
			node = iterator.key
			index = iterator.value

			if node.instance == NODE_JUMP {
				jumps.add(node, index) # Register the index of the jump

				# Add this jump to the paths that lead to the destination label
				label = node.(JumpNode).label.name

				if paths.contains_key(label) {
					paths[label].add(node as JumpNode)
				}
				else {
					paths[label] = [ node as JumpNode ]
				}
			}
			else node.instance == NODE_LABEL {
				labels.add(node.(LabelNode).label.name, index)
			}
		}
	}

	add(node: Node) {
		indices.add(node, indices.size)
		nodes.add(node)
	}

	remove(node: Node) {
		if not indices.contains_key(node) return

		index = indices[node]

		indices.remove(node)
		nodes[index] = none as Node
	}

	replace(what: Node, with: Node) {
		if not indices.contains_key(what) return

		index = indices[what] # Extract the index of the node that we are replacing

		indices[with] = index # Add the new node to the node indices map
		indices.remove(what) # Remove the old node from the node indices map

		nodes[index] = with # Replace the old node from the node list with the new one
	}

	# Summary:
	# Returns the index of the statement inside of which the specified node is.
	# If such a statement does not exist, this function panics.
	index_of(node: Node) {
		# Go up in the node tree until we get an index.
		# This is helpful, because if we pass a child node of an statement, we get back the index of statement
		loop (iterator = node, iterator != none, iterator = iterator.parent) {
			if indices.contains_key(iterator) return indices[iterator]
		}

		abort('Could not return the flow index of the specified node')
	}

	linearise_logical_operator(operation: OperatorNode, success: Label, failure: Label) {
		left = operation.first
		right = operation.last

		if left.instance == NODE_OPERATOR and left.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL {
			intermediate = Label(get_next_label())

			if operation.operator == Operators.LOGICAL_AND {
				linearise_logical_operator(left as OperatorNode, intermediate, failure) # Operator: AND
			}
			else {
				linearise_logical_operator(left as OperatorNode, success, intermediate) # Operator: OR
			}

			add(LabelNode(intermediate, none as Position))
		}
		else operation.operator == Operators.LOGICAL_AND {
			linearise(left) # Operator: AND
			add(JumpNode(failure, true))
		}
		else {
			linearise(left) # Operator: OR
			add(JumpNode(success, true))
		}

		if right.instance == NODE_OPERATOR and right.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL {
			linearise_logical_operator(right as OperatorNode, success, failure)
		}
		else operation.operator == Operators.LOGICAL_AND {
			linearise(right) # Operator: AND
			add(JumpNode(failure, true))
		}
		else {
			linearise(right) # Operator: OR
			add(JumpNode(failure, true))
		}
	}

	linearise_condition(statement: IfNode, failure: Label) {
		condition = statement.condition
		parent = condition.parent

		# Remove the condition for a while
		if not condition.remove() abort('Could not remove the condition of a conditional statement during flow analysis')

		# Linearise all the nodes under the condition container except the actual condition
		loop node in statement.condition_container {
			linearise(node)
		}

		# Add the condition back
		parent.add(condition)

		if condition.instance == NODE_OPERATOR and condition.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL {
			success = Label(get_next_label())
			linearise_logical_operator(condition as OperatorNode, success, failure)
			add(LabelNode(success, none as Position))
		}
		else {
			linearise(condition)
			add(JumpNode(failure, true))
		}
	}

	linearise_condition(statement: LoopNode, failure: Label) {
		condition = statement.condition
		parent = condition.parent

		# Remove the condition for a while
		if not condition.remove() abort('Could not remove the condition of a conditional statement during flow analysis')

		# Linearise all the nodes under the condition container except the actual condition
		loop node in statement.condition_container {
			linearise(node)
		}

		# Add the condition back
		parent.add(condition)

		if condition.instance == NODE_OPERATOR and condition.(OperatorNode).operator.type == OPERATOR_TYPE_LOGICAL {
			success = Label(get_next_label())
			linearise_logical_operator(condition as OperatorNode, success, failure)
			add(LabelNode(success, none as Position))
		}
		else {
			linearise(condition)
		}
	}

	linearise(node: Node) {
		instance = node.instance

		if instance == NODE_OPERATOR {
			add(node)
			return
		}

		if instance == NODE_IF {
			statement = node as IfNode
			intermediate = Label(get_next_label())
			end: Label = Label(get_next_label())

			linearise_condition(statement, intermediate)
			add(statement.condition_container) # Add the condition scope

			# The body may be executed based on the condition. If it executes, it jumps to the end label
			linearise(statement.body)
			add(JumpNode(end))
			add(LabelNode(intermediate, none as Position))

			loop iterator in statement.get_successors() {
				if iterator.instance == NODE_ELSE_IF {
					successor = iterator as ElseIfNode
					intermediate = Label(get_next_label())

					linearise_condition(successor, intermediate)
					add(successor.condition_container) # Add the condition scope

					# The body may be executed based on the condition. If it executes, it jumps to the end label
					linearise(successor.body)
					add(JumpNode(end))

					add(LabelNode(intermediate, none as Position))
				}
				else iterator.instance == NODE_ELSE {
					# The body always executes and jumps to the end label
					linearise(iterator.(ElseNode).body)
				}
			}

			add(LabelNode(end, none as Position))
			return
		}

		if instance == NODE_LOOP {
			statement = node as LoopNode
			start: Label = Label(get_next_label())
			end: Label = Label(get_next_label())

			loops.add(statement, pack { start: start, end: end })

			if statement.is_forever_loop {
				add(LabelNode(start, none as Position))
				linearise(statement.body)
				add(JumpNode(start))
				add(LabelNode(end, none as Position))
				return
			}
			
			linearise(statement.initialization) # Add the initialization before entering the loop

			add(LabelNode(start, none as Position)) # Add the start label, so that the loop can repeat

			linearise_condition(statement, end) # Add the condition for the loop, which can fall through or exit the loop
			add(JumpNode(end, true))

			linearise(statement.body) # Add the body of the loop
			linearise(statement.action) # Execute the loop action after the body

			add(JumpNode(start)) # Jump back to the beginning and repeat if the condition passes
			add(LabelNode(end, none as Position)) # Add the exit label for the loop
			return
		}

		if instance == NODE_COMMAND {
			instruction = node.(CommandNode).instruction

			container = node.(CommandNode).container
			if container === none abort('Command node does not have a parent loop')

			if instruction === Keywords.CONTINUE {
				start: Label = loops[container].start

				add(node)
				add(JumpNode(start))
			}
			else instruction === Keywords.STOP {
				end: Label = loops[container].end

				add(node)
				add(JumpNode(end))
			}
			else {
				abort('Invalid command node')
			}

			return
		}

		if instance == NODE_RETURN {
			add(node)
			add(JumpNode(end))
			return
		}

		if instance == NODE_ELSE or instance == NODE_ELSE_IF {
			return
		}

		if instance == NODE_SCOPE or instance == NODE_NORMAL or instance == NODE_INLINE {
			loop iterator in node {
				linearise(iterator)
			}

			add(node)
			return
		}

		add(node)
	}

	# Summary:
	# Finds the positions which can be reached starting from the specified position while avoiding the specified obstacles
	# NOTE: Provide a copy of the positions since this function edits the specified list
	get_executable_positions(start: normal, obstacles: List<normal>, positions: List<normal>, visited: DynamicBitset, depth: normal) {
		executable = List<normal>(positions.size, false)

		loop {
			# Try to find the closest obstacle which is ahead of the current position
			closest_obstacle = NORMAL_MAX

			loop (i = 0, i < obstacles.size, i++) {
				obstacle = obstacles[i]

				if obstacle >= start and obstacle < closest_obstacle {
					closest_obstacle = obstacle
					stop
				}
			}

			# Try to find the closest jump which is ahead of the current position
			closest_jump = NORMAL_MAX
			closest_jump_node = none as JumpNode

			loop iterator in jumps {
				jump_node = iterator.key
				jump_position = iterator.value

				if jump_position >= start {
					closest_jump = jump_position
					closest_jump_node = jump_node
					stop
				}
			}

			# Determine whether an obstacle or a jump is closer
			closest = min(closest_obstacle, closest_jump)

			# Register all positions which fall between the closest obstacle or jump and the current position
			loop (i = positions.size - 1, i >= 0, i--) {
				position = positions[i]

				if position >= start and position <= closest {
					executable.add(position)
					positions.remove_at(i)
				}
			}

			# 1. Return if there are no positions to be reached
			# 2. If the closest has the value of the maximum integer, it means there is no jump or obstacle ahead
			# 3. Return from the call if an obstacle is hit
			# 4. The closest value must represent a jump, so ensure it is not visited before
			if positions.size == 0 or closest == NORMAL_MAX or closest == closest_obstacle or visited[closest] return executable

			# Do not visit this jump again
			visited.set(closest_jump)

			if closest_jump_node.is_conditional {
				# Visit the jump destination and try to reach the positions there
				destination = labels[closest_jump_node.label.name]

				# Do not continue if the maximum depth is reached (recursion limit)
				if depth - 1 <= 0 return none as List<normal>

				result = get_executable_positions(destination, obstacles, positions, visited, depth - 1)
				if result == none return none as List<normal>

				executable.add_all(result)

				# Delete the result, since we copied it
				result.clear()

				# Do not continue if all positions have been reached already
				if positions.size == 0 return executable

				# Fall through the conditional jump
				start = closest + 1
			}
			else {
				# Since the jump is not conditional go to its label
				start = labels[closest_jump_node.label.name]
			}
		}
	}

	# Summary:
	# Finds the positions which can be reached starting from the specified position while avoiding the specified obstacles
	# NOTE: Provide a copy of the positions since this function edits the specified list
	get_executable_positions(start: normal, obstacles: List<normal>, positions: List<normal>) {
		visited = DynamicBitset(indices.size, DEFAULT_MAX_BITSET_SIZE)
		result = get_executable_positions(start, obstacles, positions, visited, DEFAULT_MAX_DEPTH)
		visited.dispose()
		return result
	}
}