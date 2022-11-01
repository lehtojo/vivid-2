Object {
	x: normal
	y: decimal
	other: Object
}

export memory_case_1(object: Object, value: normal) {
	object.x = value
	return object.x
}

export memory_case_2(a: link, i: normal) {
	a[i] = i + 1
	return a[i]
}

# TODO: Does not work on Windows, add second parameter 'empty: decimal'
export memory_case_3(object: Object, value: decimal) {
	object.y++
	object.x = value
	return object.x + object.y
}

export memory_case_4(a: Object, b: Object) {
	a.x = 1
	b.x = 2
	return a.x
}

export memory_case_5(a: Object, b: link) {
	a.y = 123.456
	b[5] = 7
	return a.y
}

export memory_case_6(a: Object) {
	a.other.y = -3.14159
	return a.other.y
}

export memory_case_7(a: Object, other: Object) {
	a.other.y = -3.14159
	a.other = other
	return a.other.y
}

export memory_case_8(a: Object, other: Object) {
	a.other.y = -3.14159
	a = other
	return a.other.y
}

export memory_case_9(a: Object, other: Object) {
	a.other.y = -3.14159
	other.y = 10
	return a.other.y
}

export memory_case_10(a: Object, other: Object) {
	a.other.y = -3.14159
	other.other = other
	return a.other.y
}

export memory_case_11(a: Object, i: large) {
	if i > 0 {
		a.x += 1
		a.other.x += 1
	}
	else {
		a.x += 1
		a.other.x += 1
	}
}

export memory_case_12(a: Object, i: large) {
	if i > 0 {
		a.x = a.y
	}
	else {
		a.y = a.x
	}

	return a.x
}

export memory_case_13(a: Object, i: large) {
	if i > 0 {
		a.x += i
		a.y += i
		a.y += 1
	}
	else {
		a.x += i
		a.y += i
		a.y += 1
	}
}

init() {
	a = Object()
	x = Object()
	a.other = x

	b = Object()
	y = Object()
	b.other = y

	are_equal(10, memory_case_1(a, 10))
	are_equal(10, a.x)

	memory = allocate(10)
	are_equal(7, memory_case_2(memory, 6))
	are_equal(7, memory[6])

	a.y = 1.718281
	are_equal(10.718281, memory_case_3(a, 8.8))

	are_equal(8, a.x)
	are_equal(2.718281, a.y)

	are_equal(2, memory_case_4(a, a))
	are_equal(2, a.x)

	are_equal(120.11225, memory_case_5(memory as Object, memory + 12))

	are_equal(-3.14159, memory_case_6(a))
	are_equal(-3.14159, a.other.y)
	
	a.y = 1.0
	b.y = -1.0
	previous = a.other
	are_equal(-1.0, memory_case_7(a, b))
	are_not_equal(previous as large, a.other as large)
	are_equal(-3.14159, previous.y)
	a.other = previous

	b.other.y = 101.1000
	are_equal(101.1000, memory_case_8(a, b))

	are_equal(10.0, memory_case_9(a, a.other))
	are_equal(10.0, a.other.y)

	a.y = 13579.2468
	are_equal(13579.2468, memory_case_10(a, a))
	
	a.x = 10
	a.other = x
	a.other.x = 20
	memory_case_11(a, 7)
	are_equal(11, a.x)
	are_equal(21, a.other.x)
	
	memory_case_11(a, -3)
	are_equal(12, a.x)
	are_equal(22, a.other.x)

	a.y = -2.25
	are_equal(-2, memory_case_12(a, 555))
	are_equal(-2, a.x)
	are_equal(-2.25, a.y)

	a.x = 101
	are_equal(101, memory_case_12(a, -111))
	are_equal(101, a.x)
	are_equal(101.0, a.y)

	a.x = 3
	a.y = 92.001
	memory_case_13(a, 7)
	are_equal(10, a.x)
	are_equal(100.001, a.y)

	a.x = 7
	a.y = 6.0
	memory_case_13(a, -7)
	are_equal(0, a.x)
	are_equal(0.0, a.y)
	return 0
}