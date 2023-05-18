export StringBuilder {
	private capacity: large
	private position: large

	buffer: link
	length => position

	init() {
		capacity = 1
		buffer = allocate(1)
	}

	init(value: String) {
		capacity = value.length
		buffer = allocate(value.length)
		append(value)
	}

	private grow(requirement: large): _ {
		capacity: large = (position + requirement) * 2
		buffer: link = allocate(capacity)

		copy(this.buffer, position, buffer)
		deallocate(this.buffer)

		this.capacity = capacity
		this.buffer = buffer
	}

	append(text: link, length: large): _ {
		if length == 0 return

		if position + length > capacity grow(length)

		offset_copy(text, length, buffer, position)
		position += length
	}

	append(text: link): _ {
		length = length_of(text)
		append(text, length)
	}

	append(text: String): _ {
		append(text.data, text.length)
	}

	append(value: large) {
		append(to_string(value))
	}

	append(value: decimal) {
		append(to_string(value))
	}

	append_line(text: link): _ {
		append(text)
		append(`\n`)
	}

	append_line(text: String): _ {
		append(text.data, text.length)
		append(`\n`)
	}

	append_line(text: large): _ {
		append_line(to_string(text))
	}

	append_line(text: decimal) {
		append_line(to_string(text))
	}

	append_line(character: char): _ {
		append(character)
		append(`\n`)
	}

	append(character: char): _ {
		if position + 1 > capacity grow(1)
		buffer[position] = character
		position++
	}

	remove(start: large, end: large): _ {
		count = end - start
		if count == 0 return
		
		move(buffer + end, buffer + start, position - end)

		position -= count
	}

	insert(index: large, text: link, length: large): _ {
		if length == 0 return
		if position + length > capacity grow(length)

		move(buffer + index, buffer + index + length, position - index)
		offset_copy(text, length, buffer, index)
		position += length
	}

	# Summary: Inserts the specified string into the specified index
	insert(index: large, string: String): _ {
		insert(index, string.data, string.length)
	}

	insert(index: large, character: char): _ {
		if position + 1 > capacity grow(1)
		move(buffer + index, buffer + index + 1, position - index)
		buffer[index] = character
		position++
	}

	insert(index: large, text: link): _ {
		return insert(index, text, length_of(text))
	}

	replace(from: link, to: link): _ {
		a = length_of(from)
		b = length_of(to)

		if a == 0 return

		loop (i = position - a, i >= 0, i--) {
			match = true

			loop (j = 0, j < a, j++) {
				if buffer[i + j] == from[j] continue
				match = false
				stop
			}

			if not match continue

			remove(i, i + a)
			insert(i, to)
		}
	}

	# Summary: Replaces the specified region with the replacement
	replace(start: large, end: large, replacement: String): _ {
		remove(start, end)
		insert(start, replacement)
	}

	# Summary: Fills the specified region with the specified character
	fill(start: large, end: large, character: char): _ {
		require(start >= 0 and start <= end and end <= position, 'Index out of bounds')

		loop (i = start, i < end, i++) {
			buffer[i] = character
		}
	}

	reverse() {
		count = position / 2

		loop (i = 0, i < count, i++) {
			temporary = buffer[i]
			buffer[i] = buffer[position - i - 1]
			buffer[position - i - 1] = temporary
		}
	}

	# Todo: Remove the underscore shenanigans once we have support for global scope access (global.index_of(...))
	index_of(value: char): large {
		return __index_of(buffer, position, value, 0) 
	}

	index_of(value: char, start: large): large {
		return __index_of(buffer, position, value, start)
	}

	index_of(value: link): large {
		return __index_of(buffer, position, value, length_of(value))
	}

	index_of(value: link, start: large): large {
		return __index_of(buffer, position, value, length_of(value), start)
	}

	index_of(value: String, start: large): large {
		return __index_of(buffer, position, value.data, value.length, start)
	}

	last_index_of(value: char, before: large): large {
		return __last_index_of(buffer, position, value, before)
	}

	slice(start: large, end: large): String {
		return String(buffer + start, end - start)
	}

	get(i: large): u8 {
		require(i >= 0 and i < position, 'Index out of bounds')
		return buffer[i]
	}

	string(): String {
		return String(buffer, position)
	}

	deinit() {
		deallocate(buffer)
	}
}