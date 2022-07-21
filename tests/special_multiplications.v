export special_multiplications(a: large, b: large) {
	return 2 * a + b * 17 + a * 9 + b / 4
}

init() { 
	are_equal(1802, special_multiplications(7, 100))
	return 0
}