export constant_permanence_and_array_copy(source: link, destination: link) {
   # Offset should stay as constant in the assembly code
	offset = 3
	i = 0

	loop (i = 0, i < 10, ++i) {
		destination[offset + i] = source[offset + i]
	}
}

init() {
	source = allocate(14)
	source[0] = 1
	source[1] = 2
	source[2] = 3
	source[3] = 5
	source[4] = 7
	source[5] = 11
	source[6] = 13
	source[7] = 17
	source[8] = 19
	source[9] = 23
	source[10] = 29
	source[11] = 31
	source[12] = 37
	source[13] = 41

	destination = allocate(14)

	constant_permanence_and_array_copy(source, destination)

	are_equal(source, destination, 3, 10)
	return 0
}