import 'C' ExitProcess(status: large)
import 'C' GetStdHandle(handle: large): large
import 'C' WriteFile(handle: large, buffer: link, size: large, written: large*, overlapped: large*): bool
import 'C' VirtualAlloc(address: link, size: large, type: large, protect: bool): link
import 'C' VirtualFree(address: link, size: large, type: large)

import zero(address: link, size: large)

constant MEMORY_COMMIT = 0x1000
constant MEMORY_RESERVE = 0x2000
constant MEMORY_RELEASE = 0x8000

constant PAGE_READWRITE = 0x04

STANDARD_OUTPUT_HANDLE = -11
STRING_DECIMAL_PRECISION = 15
DECIMAL_PRECISION = 0.000000001

# Exits the application with the specified status code
exit(code: large) {
	ExitProcess(code)
}

# Summary: Reverses the bytes in the specified memory range
reverse(memory: link, amount: large) {
	loop (i = 0, i < amount / 2, i++) {
		temporary = memory[i]
		memory[i] = memory[amount - i - 1]
		memory[amount - i - 1] = temporary
	}
}

# Summary: Converts the specified number into a string and stores it in the specified buffer
to_string(number: large, result: link) {
	position = 0

	if number < 0 {
		loop {
			a = number / 10
			remainder = number - a * 10
			number = a

			result[position] = `0` - remainder
			position++

			if number == 0 stop
		}

		result[position] = `-`
		position++
	}
	else {
		loop {
			a = number / 10
			remainder = number - a * 10
			number = a

			result[position] = `0` + remainder
			position++

			if number == 0 stop
		}
	}

	reverse(result, position)
	return position
}

# Summary: Converts the specified number into a string and stores it in the specified buffer
to_string(number: decimal, result: link) {
	position = to_string(number as large, result)

	# Remove the integer part
	number -= number as large

	# Ensure the number is a positive number
	if number < 0 { number = -number }

	# Add the decimal point
	result[position] = `.`
	position++

	# If the number is zero, skip the fractional part computation
	if number == 0 {
		result[position] = `0`
		return position + 1
	}

	# Compute the fractional part
	loop (i = 0, i < STRING_DECIMAL_PRECISION and number > 0, i++) {
		number *= 10
		digit = number as large
		number -= digit

		result[position] = `0` + digit
		position++
	}

	return position
}

# Summary: Writes the specified bytes to the console
print(bytes: link, length: large) {
	written: large[1]
	handle = GetStdHandle(STANDARD_OUTPUT_HANDLE)
	WriteFile(handle, bytes, length, written as large*, 0 as large*)
}

# Summary: Writes the specified character to the console
print(character: char) {
	written: large[1]
	bytes: char[1]
	bytes[] = character
	handle = GetStdHandle(STANDARD_OUTPUT_HANDLE)
	WriteFile(handle, bytes as link, 1, written as large*, 0 as large*)
}

# Summary: Length is determined by looking for a zero byte
length_of(bytes: link) {
	length = 0

	loop {
		if bytes[length] == 0 return length
		length++
	}
}

# Summary: Writes the specified number to the console
print(number: large) {
	buffer: byte[32]
	zero(buffer as link, 32)
	length = to_string(number, buffer as link)
	print(buffer as link, length)
}

# Summary: Writes the specified number to the console and adds a new line
println(number: large) {
	buffer: byte[32]
	zero(buffer as link, 32)
	length = to_string(number, buffer as link)
	buffer[length] = `\n`
	print(buffer as link, length + 1)
}

# Summary: Writes the specified decimal to the console
print(number: decimal) {
	buffer: byte[64]
	zero(buffer as link, 64)
	length = to_string(number, buffer as link)
	print(buffer as link, length)
}

# Summary: Writes the specified decimal to the console and adds a new line
println(number: decimal) {
	buffer: byte[64]
	zero(buffer as link, 64)
	length = to_string(number, buffer as link)
	buffer[length] = `\n`
	print(buffer as link, length + 1)
}

# Summary: Writes the specified string to the console
print(string: link) {
	length = length_of(string)
	print(string, length)
}

# Summary: Writes the specified string to the console and adds a new line
println(string: link) {
	length = length_of(string)
	print(string, length)
	print(`\n`)
}

export are_equal(a: large, b: large) {
	print(a)
	print(' == ')
	println(b)

	if a == b return
	exit(1)
}

export are_equal(a: char, b: char) {
	print(a)
	print(' == ')
	println(b)

	if a == b return
	exit(1)
}

export are_equal(a: decimal, b: decimal) {
	print(a)
	print(' == ')
	println(b)

	d = a - b

	if d >= -DECIMAL_PRECISION and d <= DECIMAL_PRECISION return
	exit(1)
}

export are_equal(a: link, b: link) {
	print(a as large)
	print(' == ')
	println(b as large)

	if a == b return
	exit(1)
}

export are_equal(a: link, b: link, offset: large, length: large) {
	print('Memory comparison: Offset=')
	print(offset)
	print(', Length=')
	println(length)

	loop (i = 0, i < length, i++) {
		print(i)
		print(': ')

		x = a[offset + i]
		y = b[offset + i]

		print(x as large)
		print(' == ')
		println(y as large)

		if x != y exit(1)
	}
}

export are_not_equal(a: large, b: large) {
	print(a)
	print(' != ')
	println(b)

	if a != b return
	exit(1)
}

allocate(bytes: large): link {
	return VirtualAlloc(0 as link, bytes, MEMORY_COMMIT | MEMORY_RESERVE, PAGE_READWRITE)
}

deallocate(address: link) {
	return VirtualFree(address, 0, MEMORY_RELEASE)
}

internal_is(a: link, b: link): bool {
	panic('Prebuilt library does not support inheritance')
	return false
}

panic(message: link) {
	println(message)
	exit(1)
}