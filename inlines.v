namespace inlines

# Summary: Finds all the labels under the specified root and localizes them by declaring new labels to the specified context
localize_labels(implementation: FunctionImplementation, root: Node) {
	# Find all the labels and the jumps under the specified root
	labels = root.find_all(NODE_LABEL) as List<LabelNode>
	jumps = root.find_all(NODE_JUMP) as List<JumpNode>

	# Go through all the labels
	loop label in labels {
		# Create a replacement for the label
		replacement = implementation.create_label()

		# Find all the jumps which use the current label and update them to use the replacement
		loop (i = jumps.size - 1, i >= 0, i--) {
			jump = jumps[i]
			if jump.label != label.label continue

			jump.label = replacement
			jumps.remove_at(i)
		}

		label.label = replacement
	}
}