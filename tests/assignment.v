Holder {
	Normal: normal
	Tiny: tiny
	Double: decimal
	Large: large
	Small: small
}

Sequence {
	address: decimal*
}

# Tests whether the compiler can store values into object instances
export assignment_1(instance: Holder) {
	instance.Normal = 314159265
	instance.Tiny = 64
	instance.Double = 1.414
	instance.Large = -2718281828459045
	instance.Small = 12345
}

# Tests whether the compiler can store values into raw memory
export assignment_2(instance: Sequence) {
	instance.address[] = -123.456
	instance.address[1] = -987.654
	instance.address[2] = 101.010
}

init() {
	holder = Holder()
	assignment_1(holder)

	are_equal(64, holder.Tiny)
	are_equal(12345, holder.Small)
	are_equal(314159265, holder.Normal)
	are_equal(-2718281828459045, holder.Large)
	are_equal(1.414, holder.Double)

	buffer = allocate(24)
	sequence = Sequence()
	sequence.address = buffer

	assignment_2(sequence)

	are_equal(-123.456, sequence.address[])
	are_equal(-987.654, sequence.address[1])
	are_equal(101.010, sequence.address[2])
	return 0
}