export move(source: link, offset: large, destination: link, bytes: large) {
	source += offset

	if destination > source {
		loop (i = 0, i < bytes, i++) {
			destination[bytes - 1 - i] = source[bytes - 1 - i]
		}
	}
	else destination < source {
		loop (i = 0, i < bytes, i++) {
			destination[i] = source[i]
		}
	}
}

export move(source: link, destination: link, bytes: large) {
	if destination > source {
		loop (i = 0, i < bytes, i++) {
			destination[bytes - 1 - i] = source[bytes - 1 - i]
		}
	}
	else destination < source {
		loop (i = 0, i < bytes, i++) {
			destination[i] = source[i]
		}
	}
}

# Summary: Allocates a new buffer, with the size of 'to' bytes, and copies the contents of the source buffer to the new buffer. Also deallocates the source buffer.
export resize(source: link, from: large, to: large) {
	resized = allocate(to)
	copy(source, min(from, to), resized)
	deallocate(source)
	=> resized
}