import time(): large

abort(message: String) {
	print('Internal error: ')
	println(message)
	exit(1)
}

abort(message: link) {
	print('Internal error: ')
	println(message)
	exit(1)
}

complain(status: Status) {
	print('Compilation terminated: ')
	println(status.message)
	exit(1)
}

init() {
	start = time()

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

	JumpInstruction.initialize()
	assembler.assemble(bundle)
	if result.problematic complain(result)

	end = time()
	print(to_string((end - start) / 10000.0))
	println(' ms')
	=> 0
}