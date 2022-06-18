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
}