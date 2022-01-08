none = 0

abort(message: String) {
	print('Internal error: ')
	println(message)
	application.exit(1)
}

abort(message: link) {
	print('Internal error: ')
	println(message)
	application.exit(1)
}

complain(status: Status) {
	print('Compilation terminated: ')
	println(status.message)
	application.exit(1)
}

init() {
	start = time.now()

	String.empty = String('')
	settings.initialize()
	
	bundle = Bundle()

	arguments = io.get_command_line_arguments()
	arguments.take_first() # Remove the executable name

	result = configure(bundle, arguments)
	if result.problematic complain(result)

	result = load(bundle)
	if result.problematic complain(result)

	Keywords.initialize()
	Operators.initialize()

	result = textual_assembler.assemble(bundle)
	if result.problematic complain(result)

	result = tokenize(bundle)
	if result.problematic complain(result)

	numbers.initialize()

	parser.initialize()
	result = parser.parse(bundle)
	if result.problematic complain(result)

	result = resolver.resolve(bundle)
	if result.problematic complain(result)

	analysis.analyze(bundle)
	if result.problematic complain(result)

	platform.x64.initialize()
	assembler.assemble(bundle)
	if result.problematic complain(result)

	end = time.now()
	print(to_string((end - start) / 10000.0))
	println(' ms')
	=> 0
}