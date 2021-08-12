export bitwise_and(a: tiny, b: tiny) {
	=> a & b
}

export bitwise_xor(a: tiny, b: tiny) {
	=> a ¤ b
}

export bitwise_or(a: tiny, b: tiny) {
	=> a | b
}

export synthetic_and(a: tiny, b: tiny) {
	=> !(a ¤ b) ¤ !(a | b)
}

export synthetic_xor(a: tiny, b: tiny) {
	=> (a | b) & !(a & b)
}

export synthetic_or(a: tiny, b: tiny) {
	=> (a ¤ b) ¤ (a & b)
}

export assign_bitwise_and(a: large) {
	a &= a / 2
	=> a
}

export assign_bitwise_xor(a: large) {
	a ¤= 1
	=> a
}

export assign_bitwise_or(a: large, b: large) {
	a |= b
	=> a
}

init() {
	are_equal(1, bitwise_and(1, 1))
	are_equal(0, bitwise_and(1, 0))
	are_equal(0, bitwise_and(0, 1))
	are_equal(0, bitwise_and(0, 0))

	are_equal(0, bitwise_xor(1, 1))
	are_equal(1, bitwise_xor(1, 0))
	are_equal(1, bitwise_xor(0, 1))
	are_equal(0, bitwise_xor(0, 0))

	are_equal(1, bitwise_or(1, 1))
	are_equal(1, bitwise_or(1, 0))
	are_equal(1, bitwise_or(0, 1))
	are_equal(0, bitwise_or(0, 0))

	are_equal(1, synthetic_and(1, 1))
	are_equal(0, synthetic_and(1, 0))
	are_equal(0, synthetic_and(0, 1))
	are_equal(0, synthetic_and(0, 0))

	are_equal(0, synthetic_xor(1, 1))
	are_equal(1, synthetic_xor(1, 0))
	are_equal(1, synthetic_xor(0, 1))
	are_equal(0, synthetic_xor(0, 0))

	are_equal(1, synthetic_or(1, 1))
	are_equal(1, synthetic_or(1, 0))
	are_equal(1, synthetic_or(0, 1))
	are_equal(0, synthetic_or(0, 0))

	# 111 & 011 = 11
	are_equal(3, assign_bitwise_and(7))

	# 10101 ¤ 00001 = 10100
	are_equal(20, assign_bitwise_xor(21))

	# 10101 ¤ 00001 = 10100
	are_equal(96, assign_bitwise_or(32, 64))
	=> 1
}