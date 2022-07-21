export arithmetic(a, b, c) {
	x = a * c + a + c
	y = b * a * (c + 1) * 100
	return x + y
}

export addition(a, b) {
	return a + b
}

export subtraction(a, b) {
	return a - b
}

export multiplication(a, b) {
	return a * b
}

export division(a, b) {
	return a / b
}

export remainder(a, b) {
	return a % b
}

export operator_order(a, b) {
	return a + b * a - b / a
}

export addition_with_constant(a) {
	return 10 + a + 10
}

export subtraction_with_constant(a) {
	return -10 + a - 10
}

export multiplication_with_constant(a) {
	return 10 * a * 10
}

export division_with_constant(a) {
	return 100 / a / 10
}

export preincrement(a) {
	return ++a + 7
}

export predecrement(a) {
	return --a + 7
}

export postincrement(a) {
	return a++ + 3
}

export postdecrement(a) {
	return a-- + 3
}

export increments(a) {
	return a + a++ * ++a + a
}

export decrements(a) {
	return a + a-- * --a + a
}

init() {
	are_equal(42069, arithmetic(6, 7, 9))
	
	are_equal(3, addition(1, 2))
	are_equal(-90, subtraction(10, 100))
	are_equal(49, multiplication(7, 7))
	are_equal(7, division(42, 6))

	are_equal(64, addition_with_constant(44))
	are_equal(-1, subtraction_with_constant(19))
	are_equal(1300, multiplication_with_constant(13))
	are_equal(1, division_with_constant(10))

	are_equal(-92, preincrement(-100))
	are_equal(511, predecrement(505))
	are_equal(9879, postincrement(9876))
	are_equal(-1231, postdecrement(-1234))
	are_equal(1016064, increments(-1010))
	are_equal(826277, decrements(909))
	return 0
}