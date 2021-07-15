namespace casts

cast(unit: Unit, result: Result, from: Type, to: Type) {
	if from == to => result

	# TODO: Add support for casting
	=> result
}

build(unit: Unit, node: CastNode, mode: large) {
	from = node.first.get_type()
	to = node.get_type()

	result = references.get(unit, node.first, mode)

	=> cast(unit, result, from, to)
}