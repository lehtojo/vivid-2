SequentialIterator<T> {
	elements: T*
	position: normal
	size: normal

	init(elements: T*, size: large) {
		this.elements = elements
		this.position = -1
		this.size = size
	}

	value(): T {
		return elements[position]
	}

	next(): bool {
		return ++position < size
	}

	reset(): _ {
		position = -1
	}
}