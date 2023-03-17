namespace console

# Summary: Specifies the maximum number of characters that can be read from single line of input
constant CONSOLE_READ_LINE_MAX_LENGTH = 1000

# Summary: Reads the next line of characters from the console
export read_line(): String {
	buffer: char[CONSOLE_READ_LINE_MAX_LENGTH]
	size = internal.console.read(buffer as link, CONSOLE_READ_LINE_MAX_LENGTH) - 2

	if size <= 0 return String.empty

	return String(buffer as link, size)
}

# Summary: Reads the next line of characters from the console and returns it to the specified buffer
export read_line(buffer: link, size: large): _ {
	internal.console.read(buffer, size)
}

# Summary: Writes the specified string to the console
export write(string: String): _ {
	internal.console.write(string.data, string.length)
}

# Summary: Writes the specified string to the console
export write(string: link): _ {
	internal.console.write(string, length_of(string))
}

# Summary: Writes the specified number of characters from the specified string
export write(string: link, length: large): _ {
	internal.console.write(string, length)
}

# Summary: Writes the specified integer to the console
export write(value: large): _ {
	buffer: byte[32]
	zero(buffer as link, 32)
	length = to_string(value, buffer as link)
	internal.console.write(buffer as link, length)
}

# Summary: Writes the specified integer to the console
export write(value: normal): _ { write(value as large) }

# Summary: Writes the specified integer to the console
export write(value: small): _ { write(value as large) }

# Summary: Writes the specified integer to the console
export write(value: tiny): _ { write(value as large) }

# Summary: Writes the specified decimal to the console
export write(value: decimal): _ {
	buffer: byte[64]
	zero(buffer as link, 64)
	length = to_string(value, buffer as link)
	console.write(buffer as link, length)
}

# Summary: Writes the specified bool to the console
export write(value: bool): _ {
	if value {
		write('true', 4)
	}
	else {
		write('false', 5)
	}
}

# Summary: Writes the specified string to the console
export write_line(string: String): _ {
	internal.console.write(string.data, string.length)
	put(`\n`)
}

# Summary: Writes the specified string to the console
export write_line(string: link): _ {
	internal.console.write(string, length_of(string))
	put(`\n`)
}

# Summary: Writes the specified number of characters from the specified string
export write_line(string: link, length: large): _ {
	internal.console.write(string, length)
	put(`\n`)
}

# Summary: Writes the specified integer to the console
export write_line(value: large): _ {
	buffer: byte[32]
	zero(buffer as link, 32)
	length = to_string(value, buffer as link)
	buffer[length] = `\n`
	internal.console.write(buffer as link, length + 1)
}

# Summary: Writes the specified integer to the console
export write_line(value: normal): _ { write_line(value as large) }

# Summary: Writes the specified integer to the console
export write_line(value: small): _ { write_line(value as large) }

# Summary: Writes the specified integer to the console
export write_line(value: tiny): _ { write_line(value as large) }

# Summary: Writes the specified decimal to the console
export write_line(value: decimal): _ {
	buffer: byte[64]
	zero(buffer as link, 64)
	length = to_string(value, buffer as link)
	buffer[length] = `\n`
	console.write(buffer as link, length + 1)
}

# Summary: Writes the specified bool to the console
export write_line(value: bool): _ {
	if value {
		write('true\n', 5)
	}
	else {
		write('false\n', 6)
	}
}

# Summary: Writes an empty line to the console
export write_line(): _ {
	put(`\n`)
}

# Summary: Writes the specified character to the console
export put(value: char): _ {
	buffer: char[1]
	buffer[] = value
	internal.console.write(buffer as link, 1)
}