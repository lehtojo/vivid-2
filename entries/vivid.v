none = 0

abort(message: String) {
	console.write('Internal error: ')
	console.write_line(message)
	application.exit(1)
}

abort(message: link) {
	console.write('Internal error: ')
	console.write_line(message)
	application.exit(1)
}

complain(status: Status) {
	console.write('Compilation terminated: ')
	console.write_line(status.message)
	application.exit(1)
}

init() {
	start = time.now()

	String.empty = ""
	settings.initialize()
	initialize_configuration()

	arguments = io.get_command_line_arguments()
	arguments.pop_or(none as String) # Remove the executable name

	result = configure(arguments)
	if result.problematic complain(result)

	result = load()
	if result.problematic complain(result)

	Keywords.initialize()
	Operators.initialize()

	result = textual_assembler.assemble()
	if result.problematic complain(result)

	result = tokenize()
	if result.problematic complain(result)

	numbers.initialize()

	parser.initialize()
	result = parser.parse()
	if result.problematic complain(result)

	result = resolver.resolve()
	if result.problematic complain(result)

	analysis.analyze()

	platform.x64.initialize()
	assembler.assemble()
	if result.problematic complain(result)

	end = time.now()
	console.write(to_string((end - start) / 10000.0))
	console.write_line(' ms')
	return 0
}