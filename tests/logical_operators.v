export single_boolean(b: bool) {
	if b == true {
		=> false
	}
	else {
		=> true
	}
}

export two_booleans(a: bool, b: bool) {
	if a == true {
		=> 1
	}
	else b == true {
		=> 2
	}
	else {
		=> 3
	}
}

export nested_if_statements(x: large, y: large, z: large) {
	if x == 1 {
		if y == 2 {
			if z == 3 {
				=> true
			}
			else z == 4 {
				=> true
			}
		}
		else y == 0 {
			if z == 1 {
				=> true
			}
			else z == -1 {
				=> true
			}
		}
		
		=> false
	}
	else x == 2 {
		if y == 4 {
			if z == 8 {
				=> true
			}
			else z == 6 {
				=> true
			}
		}
		else y == 3 {
			if z == 4 {
				=> true
			}
			else z == 5 {
				=> true
			}
		}
		
		=> false
	}
	
	=> false
}

export logical_and_in_if_statement(a: bool, b: bool) {
	if a == true and b == true {
		=> 10
	}
	
	=> 0
}

export logical_or_in_if_statement(a: bool, b: bool) {
	if a == true or b == true {
		=> 10
	}
	
	=> 0
}

export nested_logical_statements(a: bool, b: bool, c: bool, d: bool) {
	if (a == true and b == true) and (c == true and d == true) {
		=> 1
	}
	else (a == true or b == true) and (c == true and d == true) {
		=> 2
	}
	else (a == true and b == true) and (c == true or d == true) {
		=> 3
	}
	else (a == true and b == true) or (c == true and d == true) {
		=> 4
	}
	else (a == true or b == true) or (c == true or d == true) {
		=> 5
	}
	else {
		=> 6
	}
}

export logical_operators_1(a: large, b: large) {
	if a > b or a == 0 {
		=> b
	}
	else a == b and b == 1 {
		=> a
	}
	else {
		=> 0
	}
}

export logical_operators_2(a: large, b: large, c: large) {
	if (a > b and a > c) or c > b {
		=> 1
	}
	else (a <= b or b >= c) and (c == 1 or a == 1) {
		=> 0
	}
	else {
		=> -1
	}
}

f(a: large) {
	if a == 7 {
		=> true
	}
	else {
		=> false
	}
}

export logical_operators_3(a: large, b: large) {
	if (a > 10 or f(a) == true) and a > b {
		=> 0
	}
	else {
		=> 1
	}
}

init() {
	# Single boolean as input
	are_equal(false, single_boolean(true))
	are_equal(true, single_boolean(false))

	# Two booleans as input
	are_equal(1, two_booleans(true, false))
	are_equal(2, two_booleans(false, true))
	are_equal(3, two_booleans(false, false))

	# Nested if-statement:

	# All correct inputs
	are_equal(true, nested_if_statements(1, 2, 3))
	are_equal(true, nested_if_statements(1, 2, 4))
	are_equal(true, nested_if_statements(1, 0, 1))
	are_equal(true, nested_if_statements(1, 0, -1))

	are_equal(true, nested_if_statements(2, 4, 8))
	are_equal(true, nested_if_statements(2, 4, 6))
	are_equal(true, nested_if_statements(2, 3, 4))
	are_equal(true, nested_if_statements(2, 3, 5))

	# Most of the paths for returning false
	are_equal(false, nested_if_statements(0, 0, 0))

	are_equal(false, nested_if_statements(1, 1, 1))
	are_equal(false, nested_if_statements(1, 2, 5))
	are_equal(false, nested_if_statements(1, 0, 0))

	are_equal(false, nested_if_statements(2, 0, 0))
	are_equal(false, nested_if_statements(2, 4, 7))
	are_equal(false, nested_if_statements(2, 3, 6))

	# Logical and
	are_equal(10, logical_and_in_if_statement(true, true))
	are_equal(0, logical_and_in_if_statement(true, false))
	are_equal(0, logical_and_in_if_statement(false, true))
	are_equal(0, logical_and_in_if_statement(false, false))

	# Logical or
	are_equal(10, logical_or_in_if_statement(true, true))
	are_equal(10, logical_or_in_if_statement(true, false))
	are_equal(10, logical_or_in_if_statement(false, true))
	are_equal(0, logical_or_in_if_statement(false, false))

	# Nested logical statements
	are_equal(1, nested_logical_statements(true, true, true, true))
	are_equal(2, nested_logical_statements(false, true, true, true))
	are_equal(2, nested_logical_statements(true, false, true, true))
	are_equal(3, nested_logical_statements(true, true, false, true))
	are_equal(3, nested_logical_statements(true, true, true, false))
	are_equal(4, nested_logical_statements(true, true, false, false))
	are_equal(4, nested_logical_statements(false, false, true, true))
	are_equal(5, nested_logical_statements(true, false, false, false))
	are_equal(5, nested_logical_statements(false, true, false, false))
	are_equal(5, nested_logical_statements(false, false, true, false))
	are_equal(5, nested_logical_statements(false, false, false, true))
	are_equal(6, nested_logical_statements(false, false, false, false))

	are_equal(5, logical_operators_1(10, 5))
	are_equal(7, logical_operators_1(0, 7))
	are_equal(1, logical_operators_1(1, 1))
	are_equal(0, logical_operators_1(3, 3))
	=> 1
}