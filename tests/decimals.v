export decimal_addition(a: decimal, b: decimal) {
   => a + b
}

export decimal_subtraction(a: decimal, b: decimal) {
   => a - b
}

export decimal_multiplication(a: decimal, b: decimal) {
   => a * b
}

export decimal_division(a: decimal, b: decimal) {
   => a / b
}

export decimal_operator_order(a: decimal, b: decimal) {
	=> a + b * a - b / a
}

export decimal_addition_with_constant(a: decimal) {
	=> 1.414 + a + 1.414
}

export decimal_subtraction_with_constant(a: decimal) {
	=> -1.414 + a - 1.414
}

export decimal_multiplication_with_constant(a: decimal) {
	=> 1.414 * a * 1.414
}

export decimal_division_with_constant(a: decimal) {
	=> 2.0 / a / 1.414
}

init() {
	are_equal(5.859, decimal_addition(3.141, 2.718))
	are_equal(0.423, decimal_subtraction(3.141, 2.718))
	are_equal(8.5372380000000003, decimal_multiplication(3.141, 2.718))
	are_equal(1.1556291390728477, decimal_division(3.141, 2.718))

	are_equal(7.3019999999999996, decimal_addition_with_constant(4.474))
	are_equal(0.53500000000000014, decimal_subtraction_with_constant(3.363))
	are_equal(4.5026397919999992, decimal_multiplication_with_constant(2.252))
	are_equal(1.0003020912315519, decimal_division_with_constant(1.414))

	are_equal(82.050797781155012, decimal_operator_order(9.870, 7.389))
	=> 0
}