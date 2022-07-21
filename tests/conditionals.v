export conditionals(a, b) {
	if a >= b {
		return a
	}
	else {
		return b
	}
}

export if_statement_greater_than(a, b) {
	if a > b {
		return true
	}

	return false
}

export if_statement_greater_than_or_equal(a, b) {
	if a >= b {
		return true
	}

	return false
}

export if_statement_less_than(a, b) {
	if a < b {
		return true
	}

	return false
}

export if_statement_less_than_or_equal(a, b) {
	if a <= b {
		return true
	}

	return false
}

export if_statement_equals(a, b) {
	if a == b {
		return true
	}

	return false
}

export if_statement_not_equals(a, b) {
	if a != b {
		return true
	}

	return false
}

init() {
	are_equal(999, conditionals(100, 999))
	are_equal(1, conditionals(1, -1))
	are_equal(-123, conditionals(-123, -321))
	are_equal(777, conditionals(777, 777))

	are_equal(false, if_statement_greater_than(100, 999))
	are_equal(true, if_statement_greater_than(999, 100))
	are_equal(false, if_statement_greater_than(100, 100))

	are_equal(false, if_statement_greater_than_or_equal(100, 999))
	are_equal(true, if_statement_greater_than_or_equal(999, 100))
	are_equal(true, if_statement_greater_than_or_equal(100, 100))

	are_equal(true, if_statement_less_than(100, 999))
	are_equal(false, if_statement_less_than(999, 100))
	are_equal(false, if_statement_less_than(100, 100))

	are_equal(true, if_statement_less_than_or_equal(100, 999))
	are_equal(false, if_statement_less_than_or_equal(999, 100))
	are_equal(true, if_statement_less_than_or_equal(100, 100))
	
	are_equal(false, if_statement_equals(100, 999))
	are_equal(false, if_statement_equals(999, 100))
	are_equal(true, if_statement_equals(100, 100))

	are_equal(true, if_statement_not_equals(100, 999))
	are_equal(true, if_statement_not_equals(999, 100))
	are_equal(false, if_statement_not_equals(100, 100))
	return 0
}