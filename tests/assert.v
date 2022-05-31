DECIMAL_PRECISION = 0.000000001

export are_equal(a: large, b: large) {
	console.write(a)
	console.write(' == ')
	console.write_line(b)

	if a == b return
	application.exit(1)
}

export are_equal(a: char, b: char) {
	console.write(String(a))
	console.write(' == ')
	console.write_line(String(b))

	if a == b return
	application.exit(1)
}

export are_equal(a: decimal, b: decimal) {
	console.write(to_string(a))
	console.write(' == ')
	console.write_line(b)

	d = a - b

	if d >= -DECIMAL_PRECISION and d <= DECIMAL_PRECISION return
	application.exit(1)
}

export are_equal(a: String, b: String) {
	console.write(a)
	console.write(' == ')
	console.write_line(b)

	if a == b return
	application.exit(1)
}

export are_equal(a: link, b: link) {
	console.write(a as large)
	console.write(' == ')
	console.write_line(b as large)

	if a == b return
	application.exit(1)
}

export are_equal(a: link, b: link, offset: large, length: large) {
	console.write('Memory comparison: Offset=')
	console.write(offset)
	console.write(', Length=')
	console.write_line(length)

	loop (i = 0, i < length, i++) {
		console.write(i)
		console.write(': ')

		x = a[offset + i]
		y = b[offset + i]

		console.write(to_string(x))
		console.write(' == ')
		console.write_line(to_string(y))

		if x != y application.exit(1)
	}
}

export are_not_equal(a: large, b: large) {
	console.write(a)
	console.write(' != ')
	console.write_line(b)

	if a != b return
	application.exit(1)
}