export conditionally_changing_constant_with_if_statement(a: large, b: large) {
	c = 7

	if a > b {
		c = a
	}

	=> a + c
}

export conditionally_changing_constant_with_loop_statement(a: large, b: large) {
	c = 100

	loop (a < b, ++a) {
		c += 1
	}

	=> b * c
}

init() {
	are_equal(17, conditionally_changing_constant_with_if_statement(10, 20))
	are_equal(20, conditionally_changing_constant_with_if_statement(10, 0))

	are_equal(200, conditionally_changing_constant_with_loop_statement(3, 2))
	are_equal(515, conditionally_changing_constant_with_loop_statement(2, 5))

	=> 0
}