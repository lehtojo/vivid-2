Status {
	position: Position
	message: String
	problematic: bool = false

	init(message: link, problematic: bool) {
		this.message = String(message)
		this.problematic = problematic
	}

	init(message: link) {
		this.position = none
		this.message = String(message)
		this.problematic = true
	}

	init(message: String) {
		this.position = none
		this.message = message
		this.problematic = true
	}

	init(position: Position, message: link) {
		this.position = position
		this.message = String(message)
		this.problematic = true
	}

	init(position: Position, message: String) {
		this.position = position
		this.message = message
		this.problematic = true
	}

	init() {}

	equals(other: Status): bool {
		if not (message == other.message) return false
		
		a = position
		b = other.position

		if a === none or b === none return a === b
		return a == b
	}
}