namespace casts

cast(unit: Unit, result: Result, from: Type, to: Type) {
	if from == to => result

	# Determine whether the cast is a down cast
	if from.is_type_inherited(to) {
		if not (from.get_supertype_base_offset(to) has offset) abort('Could not compute base offset of a supertype while building down cast')
		if offset == 0 => result

		=> AdditionInstruction(unit, result, Result(ConstantHandle(offset), SYSTEM_SIGNED), result.format, false).add()
	}

	# Determine whether the cast is a up cast
	if to.is_type_inherited(from) {
		if not (to.get_supertype_base_offset(from) has offset) abort('Could not compute base offset of a supertype while building up cast')
		if offset == 0 => result

		=> AdditionInstruction(unit, result, Result(ConstantHandle(-offset), SYSTEM_SIGNED), result.format, false).add()
	}

	# This means that the cast is unsafe since the types have nothing in common
	=> result
}

build(unit: Unit, node: CastNode, mode: large) {
	from = node.first.get_type()
	to = node.get_type()

	result = references.get(unit, node.first, mode) as Result

	# Number casts:
	if from.is_number and to.is_number {
		a = from.(Number).format == FORMAT_DECIMAL
		b = to.(Number).format == FORMAT_DECIMAL

		# Execute only if exactly one of the types is a decimal number
		if (a ¤ b) != 0 => ConvertInstruction(unit, result, to.(Number).format).add()

		=> result
	}

	=> cast(unit, result, from, to)
}