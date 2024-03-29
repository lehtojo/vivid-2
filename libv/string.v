# Summary: Tries to convert the specified string to a decimal number
export as_decimal(string: String): Optional<decimal> {
	return as_decimal(string.data, string.length)
}

# Summary: Tries to convert the specified string to an integer number
export as_integer(string: String): Optional<large> {
	return as_integer(string.data, string.length)
}

# Summary: Tries to convert the specified string to a decimal number
export to_decimal(string: String) {
	return to_decimal(string.data, string.length)
}

# Summary: Tries to convert the specified string to an integer number
export to_integer(string: String): large {
	return to_integer(string.data, string.length)
}

# Summary: Converts the specified decimal to a string
export to_string(value: decimal): String {
	buffer: byte[64]
	zero(buffer as link, 64)
	length = to_string(value, buffer as link)
	return String(buffer as link, length)
}

# Summary: Converts the specified integer to a string
export to_string(value: large): String {
	buffer: byte[32]
	zero(buffer as link, 32)
	length = to_string(value, buffer as link)
	return String(buffer as link, length)
}

export String {
	shared empty: String

	# Summary: Combines all the specified strings while separating them the specified separator
	shared join(separator: char, strings: List<String>) {
		if strings.size == 0 return String.empty
		if strings.size == 1 return strings[]

		# Set the length of the result to the number of separators, because each separator adds one character
		result_length = strings.size - 1

		# Add the lengths of all the strings to join
		loop (i = 0, i < strings.size, i++) {
			result_length += strings[i].length
		}

		# Allocate and populate the result
		buffer = allocate(result_length + 1)
		position = buffer

		loop (i = 0, i < strings.size, i++) {
			# Add the string to the result
			string = strings[i]
			copy(string.data, string.length, position)
			position += string.length

			# Add the separator, even if it is the last one
			position[] = separator
			position++
		}

		# Remove the last separator and replace it with a zero terminator
		buffer[result_length] = 0

		return String.from(buffer, result_length)
	}

	# Summary: Combines all the specified strings while separating them the specified separator
	shared join(separator: String, strings: List<String>): String {
		if strings.size == 0 return String.empty
		if strings.size == 1 return strings[]

		# Set the length of the result to the number of characters the separators will take
		result_length = (strings.size - 1) * separator.length

		# Add the lengths of all the strings to join
		loop (i = 0, i < strings.size, i++) {
			result_length += strings[i].length
		}

		# Allocate and populate the result
		buffer = allocate(result_length + 1)

		# Add the first string to the result
		string = strings[]
		copy(string.data, string.length, buffer)

		# Start after the first added string
		position = buffer + string.length

		loop (i = 1, i < strings.size, i++) {
			# Add the separator
			copy(separator.data, separator.length, position)
			position += separator.length

			# Add the string to the result
			string = strings[i]
			copy(string.data, string.length, position)
			position += string.length
		}

		return String.from(buffer, result_length)
	}

	public readable data: link
	public readable length: large

	# Summary: Returns whether this string is empty
	empty => length == 0

	# Summary: Creates a string from the specified data. Does not copy the content of the specified data.
	shared from(data: link, length: large): String {
		result = String()
		result.data = data
		result.length = length
		return result
	}

	# Summary: Converts the specified character into a string
	init(value: char) {
		data = allocate(2)
		data[] = value
		data[1] = 0
		length = 1
	}

	# Summary: Creates a string by copying the characters from the specified source
	init(source: link) {
		a = length_of(source)
		length = a

		data = allocate(a + 1)
		data[a] = 0

		copy(source, a, data)
	}

	# Summary: Creates a string by copying the characters from the specified source using the specified length
	init(source: link, length: large) {
		this.length = length

		data = allocate(length + 1)
		data[length] = 0

		copy(source, length, data)
	}

	# Summary: Creates an empty string
	private init() {}

	# Summary: Puts the specified character into the specified position without removing any other characters and returns a new string
	insert(index: large, character: char): String {
		data: link = this.data
		length: large = this.length
		require(index >= 0 and index <= length)

		# Reserve memory for the current characters, the new character and the terminator
		memory = allocate(length + 2)

		# Copy all the characters before the specified index
		copy(data, index, memory)

		# Insert the character
		memory[index] = character

		# Copy the rest of the characters from the original string
		copy(data + index, length - index, memory + index + 1)

		# Create a new string from the buffer
		result = String()
		result.data = memory
		result.length = length + 1
		return result
	}

	# Summary: Puts the specified string into the specified position without removing any other characters and returns a new string
	insert(index: large, string: link, string_length: large) {
		data: link = this.data
		length: large = this.length

		require(index >= 0 and index <= length)

		# Reserve memory for the current characters, the specified string and the terminator
		memory = allocate(length + string_length + 1)

		# Copy all the characters before the specified index
		copy(data, index, memory)

		# Copy the specified string into the buffer
		copy(string, string_length, memory + index)

		# Copy the rest of the characters after the inserted string
		copy(data + index, length - index, memory + index + string_length)

		# Create a new string from the buffer
		result = String()
		result.data = memory
		result.length = length + string_length
		return result
	}

	# Summary: Puts the specified string into the specified position without removing any other characters and returns a new string
	insert(index: large, string: link) {
		return insert(index, string, length_of(string))
	}

	# Summary: Puts the specified string into the specified position without removing any other characters and returns a new string
	insert(index: large, string: String) {
		return insert(index, string.data, string.length)
	}

	# Summary: Returns whether the first characters match the specified string
	starts_with(start: String): bool {
		return starts_with(start.data)
	}

	# Summary: Returns whether the first characters match the specified string
	starts_with(start: link): bool {
		a = length_of(start)
		if a == 0 or a > length return false

		loop (i = 0, i < a, i++) {
			if data[i] != start[i] return false
		}

		return true
	}

	# Summary: Returns whether the first character matches the specified character
	starts_with(value: char): bool {
		return length > 0 and data[] == value
	}

	# Summary: Returns whether the last character matches the specified character
	ends_with(value: char): bool {
		return length > 0 and data[length - 1] == value
	}

	# Summary: Returns whether the last characters match the specified string
	ends_with(end: link): bool {
		a = length_of(end)
		b = length

		if a == 0 or a > b return false

		loop (a > 0) {
			if end[--a] != data[--b] return false
		}

		return true
	}

	# Summary: Returns the characters between the specified start and end index as a string
	slice(start: large, end: large): String {
		require(start >= 0 and start <= end, 'Invalid slice start index')
		require(end <= length, 'Invalid slice end index')

		a = length
		require(start >= 0 and start <= a and end >= start and end <= a)

		return String(data + start, end - start)
	}

	# Summary: Returns all the characters after the specified index as a string
	slice(start: large): String {
		require(start >= 0 and start <= length, 'Invalid slice start index')
		return slice(start, length)
	}

	# Summary: Replaces all the occurrences of the specified character with the specified replacement
	replace(old: char, new: char): String {
		a = length
		
		result = String(data, a)
		data: link = result.data

		loop (i = 0, i < a, i++) {
			if data[i] != old continue
			data[i] = new
		}

		return result
	}

	# Summary: Replaces all the occurrences of the specified string with the specified replacement
	replace(old: link, old_length: large, new: link, new_length: large): String {
		length: large = this.length

		# Compute the number of characters the length of the result string changes per occurrence
		length_change = new_length - old_length

		# Compute the length of the result string:
		result_length = length

		# Keep track of the position inside the original string
		position = 0

		loop {
			# Find the index of the next occurrence
			index = index_of(old, old_length, position)
			if index < 0 stop

			# Skip the occurrence and update the length of the result string
			position = index + old_length
			result_length += length_change
		}

		# Allocate memory for the result string and keep track of the position inside it
		result_data = allocate(result_length + 1)
		result_position = 0

		# Keep track of the position inside the original string
		data: link = this.data
		position = 0

		loop {
			# Find the index of the next occurrence
			index = index_of(old, old_length, position)

			# Stop when no more occurrences can be found
			if index < 0 {
				# Copy the rest of the characters from the original string
				copy(data + position, length - position, result_data + result_position)

				# Return the result as a string
				result = String()
				result.data = result_data
				result.length = result_length
				return result
			}

			# Copy the all characters between the current position and the index of the next occurrence to the result
			copy(data + position, index - position, result_data + result_position)

			# Move the result position over the copied characters
			result_position += index - position

			# Copy the replacement string to the result
			copy(new, new_length, result_data + result_position)

			# Move the result position over the replacement
			result_position += new_length

			# Move the current position over the occurrence and continue
			position = index + old_length
		}
	}

	# Summary: Replaces all the occurrences of the specified string with the specified replacement
	replace(old: link, new: link): String {
		return replace(old, length_of(old), new, length_of(new))
	}

	# Summary: Replaces all the occurrences of the specified string with the specified replacement
	replace(old: String, new: String) {
		return replace(old.data, old.length, new.data, new.length)
	}

	# Summary: Returns the index of the first occurrence of the specified character
	index_of(value: char): large {
		a = length

		loop (i = 0, i < a, i++) {
			if data[i] == value return i
		}

		return -1
	}

	# Summary: Returns the index of the first occurrence of the specified character
	index_of(value: char, start: large): large {
		require(start >= 0 and start <= length, 'Invalid start index')
		
		a = length

		loop (i = start, i < a, i++) {
			if data[i] == value return i
		}

		return -1
	}

	# Summary: Returns the index of the first occurrence of the specified string
	index_of(value: String) {
		return index_of(value.data, value.length, 0)
	}

	# Summary: Returns the index of the first occurrence of the specified string
	index_of(value: link) {
		return index_of(value, length_of(value), 0)
	}

	# Summary: Returns the index of the first occurrence of the specified string
	index_of(value: String, start: large) {
		require(start >= 0 and start <= length, 'Invalid start index')
		return index_of(value.data, value.length, start)
	}

	# Summary: Returns the index of the first occurrence of the specified string
	index_of(value: link, start: large): large {
		require(start >= 0 and start <= length, 'Invalid start index')
		return index_of(value, length_of(value), start)
	}

	# Summary: Returns the index of the first occurrence of the specified string
	index_of(value: link, value_length: large, start: large): large {
		length: large = this.length
		require(start >= 0 and start <= length, 'Invalid start index')

		loop (i = start, i <= length - value_length, i++) {
			match = true

			loop (j = 0, j < value_length, j++) {
				if data[i + j] == value[j] continue
				match = false
				stop
			}

			if match return i
		}

		return -1
	}

	# Summary: Returns the index of the last occurrence of the specified character
	last_index_of(value: char): large {
		return last_index_of(value, length)
	}

	# Summary: Returns the index of the last occurrence of the specified character before the specified position
	last_index_of(value: char, before: large): large {
		require(before >= 0 and before <= length, 'Invalid before index')

		loop (i = before - 1, i >= 0, i--) {
			if data[i] == value return i
		}

		return -1
	}

	# Summary: Converts all upper case alphabetic characters to lower case and returns a new string
	to_lower(): String {
		buffer = allocate(length + 1)
		buffer[length] = 0

		loop (i = 0, i < length, i++) {
			value = data[i]
			if value >= `A` and value <= `Z` { value -= (`A` - `a`) }
			buffer[i] = value
		}

		return String.from(buffer, length)
	}

	# Summary: Converts all lower case alphabetic characters to upper case and returns a new string
	to_upper() {
		buffer = allocate(length + 1)
		buffer[length] = 0

		loop (i = 0, i < length, i++) {
			value = data[i]
			if value >= `a` and value <= `z` { value += (`A` - `a`) }
			buffer[i] = value
		}

		return String.from(buffer, length)
	}

	# Summary: Removes all leading and trailing  Removes all leading and trailing instances of a character from the current string
	trim(character: char): String {
		length: large = this.length
		start: large = 0
		end: large = length

		loop (start < length and data[start] == character, start++) {}
		loop (end > start and data[end - 1] == character, end--) {}

		return slice(start, end)
	}

	# Summary: Adds the two strings together and returns a new string
	plus(string: link, length: large): String {
		a = this.length
		b = length
		c = a + b

		memory = allocate(c + 1) # Include the zero byte

		copy(data, a, memory)
		copy(string, b, memory + a)

		result = String()
		result.data = memory
		result.length = c
		return result
	}

	# Summary: Adds the two strings together and returns a new string
	plus(string: String): String {
		return plus(string.data, string.length)
	}

	# Summary: Adds the two strings together and returns a new string
	plus(other: link): String {
		return plus(other, length_of(other))
	}

	# Summary: Creates a new string which has this string in the beginning and the specified character added to the end
	plus(other: char): String {
		a = length

		# Allocate memory for new string
		memory = allocate(a + 2)

		# Copy this string to the new string
		copy(data, a, memory)
		
		# Add the given character to the end of the new string
		memory[a] = other
		memory[a + 1] = 0

		result = String()
		result.data = memory
		result.length = a + 1
		return result
	}

	# Summary: Overrides the indexed accessor, returning the character in the specified position
	get(i: large): tiny {
		require(i >= 0 and i <= length, 'Invalid getter index')
		return data.(char*)[i]
	}

	# Summary: Overrides the indexed accessor, allowing the user to edit the character in the specified position
	set(i: large, value: char) {
		require(i >= 0 and i <= length, 'Invalid setter index')
		data[i] = value
	}

	# Summary: Returns whether the two strings are equal
	equals(other: String): bool {
		a = length
		b = other.length

		if a != b return false

		loop (i = 0, i < a, i++) {
			if data[i] != other.data[i] return false
		}

		return true
	}

	# Summary: Returns whether the two strings are equal
	equals(data: link): bool {
		a = length
		b = length_of(data)

		if a != b return false

		loop (i = 0, i < a, i++) {
			if this.data[i] != data[i] return false
		}

		return true
	}

	# Summary: Computes hash code for the string
	hash(): large {
		hash = 5381
		a = length

		loop (i = 0, i < a, i++) {
			hash = ((hash <| 5) + hash) + data[i] # hash = hash * 33 + data[i]
		}

		return hash
	}

	deinit() {
		deallocate(data)
	}
}