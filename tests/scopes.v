import large_function()

export scopes_nested_if_statements(a, b, c, d, e, f, g, h) {
	x = 2 * a
	y = 3 * b
	z = 5 * c

	if a > 0 {
		if c > 0 {
			large_function()
		}

		large_function()
	}
	else b > 0 {
		if d > 0 {
			large_function()
		}

		large_function()
	}
	else {
		if e > 0 {
			large_function()
		}

		large_function()
	}

	=> (a + b + c + d + e + f + g + h) * x * y * z
}

export scopes_single_loop(a, b, c, d, e, f, g, h) {
	x = 2 * a
	y = 3 * b
	z = 5 * c

	loop (i = 0, i < h, ++i) {
		large_function()
	}

	=> (a + b + c + d + e + f + g + h) * x * y * z
}

export scopes_nested_loops(a, b, c, d, e, f, g, h) {
	x = 2 * a
	y = 3 * b
	z = 5 * c

	loop (i = 0, i < h, ++i) {
		loop (j = 0, j < g, ++j) {
			large_function()
		}

		large_function()
	}

	=> (a + b + c + d + e + f + g + h) * x * y * z
}

init() {
	are_equal(6480, scopes_nested_if_statements(1, 2, 3, 4, 5, 6, 7, 8))
	are_equal(-54000000, scopes_nested_if_statements(10, 20, -30, 40, 50, 60, 70, 80))
	are_equal(-97920, scopes_nested_if_statements(-2, 4, 6, 8, 10, 12, 14, 16))
	are_equal(-748800000, scopes_nested_if_statements(-20, 40, 60, -80, 100, 120, 140, 160))
	are_equal(340200, scopes_nested_if_statements(-3, -5, 9, 11, 13, 17, 19, 23))
	are_equal(2349000000, scopes_nested_if_statements(-30, -50, 90, 110, -130, 170, 190, 230))

	are_equal(3622080, scopes_single_loop(7, 8, 11, 16, 23, 32, 43, 56))
	are_equal(3622080, scopes_nested_loops(7, 8, 11, 16, 23, 32, 43, 56))
	=> 0
}