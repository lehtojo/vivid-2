import large_function()

export evacuation(a: large, b: large) {
	c = a * b + 10
	large_function()
	=> a + b + c
}

export evacuation_with_memory(a: large, b: large, c: decimal, d: decimal) {
	e = a + b
	f = a - b
	g = a * b
	h = a / b
	i = c + d
	j = c - d
	k = c * d
	l = c / d
	large_function()
	=> a + b + c + d + e + f + g + h + i + j + k + l
}

init() {
	are_equal(570, evacuation(10, 50))
	are_equal(-8284.8593704716513, evacuation_with_memory(42, -10, -77.101, 101.77))
	=> 1
}