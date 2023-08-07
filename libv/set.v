Set<T> {
	private inline container: Map<T, bool>
	size => container.size

	init(elements) {
		container.init(elements.size)
		add_all(elements)
	}

	init() {
		container.init()
	}

	contains(element: T): bool {
		return container.contains_key(element)
	}

	add(element: T): bool {
		if container.contains_key(element) return false
		container.add(element, true)
		return true
	}

	add_all(elements): _ {
		loop element in elements {
			add(element)
		}
	}

	clear(): _ {
		container.clear()
	}

	iterator(): MapKeyIterator<T, bool> {
		return container.key_iterator()
	}

	to_list(): List<T> {
		return container.get_keys()
	}
}