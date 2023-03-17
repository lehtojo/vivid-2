namespace casts

cast(unit: Unit, result: Result, from: Type, to: Type): Result {
	if from == to return result

	# Determine whether the cast is a down cast
	if from.is_type_inherited(to) {
		if from.get_supertype_base_offset(to) has not offset abort('Could not compute base offset of a supertype while building down cast')
		if offset == 0 return result

		return AdditionInstruction(unit, result, Result(ConstantHandle(offset), SYSTEM_SIGNED), result.format, false).add()
	}

	# Determine whether the cast is a up cast
	if to.is_type_inherited(from) {
		if to.get_supertype_base_offset(from) has not offset abort('Could not compute base offset of a supertype while building up cast')
		if offset == 0 return result

		return AdditionInstruction(unit, result, Result(ConstantHandle(-offset), SYSTEM_SIGNED), result.format, false).add()
	}

	# This means that the cast is unsafe since the types have nothing in common
	return result
}

build(unit: Unit, node: CastNode, mode: large): Result {
	from = node.first.get_type()
	to = node.get_type()

	result = references.get(unit, node.first, mode) as Result

	# Number casts:
	if from.is_number and to.is_number {
		a = from.(Number).format
		b = to.(Number).format

		if a !== b return ConvertInstruction(unit, result, to.(Number).format).add()

		return result
	}

	return cast(unit, result, from, to)
}