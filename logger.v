namespace logger.verbose {
	write(string: link) {
		if settings.is_verbose_output_enabled { console.write(string) }
	}

	write_line(string: link) {
		if settings.is_verbose_output_enabled { console.write_line(string) }
	}

	write(string: String) {
		write(string.data)
	}

	write_line(string: String) {
		write_line(string.data)
	}

	write(string: link, at: Node) {
		return
		if not settings.is_verbose_output_enabled return

		console.write(string)

		position = at.start
		if position === none return

		console.write(' (')

		if position.file !== none {
			console.write(position.file.fullname)
		}
		else {
			console.write('<unknown>')
		}

		console.put(`:`)
		console.write(position.friendly_line)
		console.put(`:`)
		console.write(position.friendly_character)
		console.put(`)`)
	}

	write(string: String, at: Node) {
		write(string.data, at)
	}

	write_line(string: link, at: Node) {
		return
		if not settings.is_verbose_output_enabled return
	
		write(string)
		console.write_line()
	}

	write_line(string: String, at: Node) {
		write_line(string.data, at)
	}
}