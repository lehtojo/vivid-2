abort(message: String) {
	console.write('Internal error: ')
	console.write_line(message)
	application.exit(1)
}

abort(message: link): _ {
	console.write('Internal error: ')
	console.write_line(message)
	application.exit(1)
}

abort(position: Position, message: String): _ {
	abort(position, message.data)
}

abort(position: Position, message: link): _ {
	console.write('Internal error: ')
	console.write(message)

	if position !== none {
		console.write(' (')

		file = position.file

		if file !== none { console.write(file.fullname) }
		else { console.write('<Source>') }

		console.write(':')
		console.write(to_string(position.line + 1))
		console.write(':')
		console.write(to_string(position.character + 1))
		console.put(`)`)
	}

	console.write_line()
	application.exit(1)
}

terminate(status: Status): _ {
	console.write('Compilation terminated: ')
	console.write_line(status.message)
	application.exit(1)
}

init(): large {
	start = time.now()

	String.empty = ""
	common.initialize()
	settings.initialize()
	initialize_configuration()

	arguments = io.get_command_line_arguments()
	arguments.pop_or(none as String) # Remove the executable name

	result = configure(arguments)
	if result.problematic terminate(result)

	jobs.execute()

	result = load()
	if result.problematic terminate(result)

	Keywords.initialize()
	Operators.initialize()

	preprocessor = preprocessing.Preprocessor()

	if not preprocessor.preprocess(settings.source_files) {
		common.report(preprocessor.errors)
		terminate(Status('Preprocessor failed'))
	}

	result = textual_assembler.assemble()
	if result.problematic terminate(result)

	result = tokenize()
	if result.problematic terminate(result)

	if not preprocessor.expand(settings.source_files) {
		common.report(preprocessor.errors)
		terminate(Status('Preprocessor failed'))
	}

	primitives.initialize()
	numbers.initialize()

	parser.initialize()
	result = parser.parse()
	if result.problematic terminate(result)

	result = resolver.resolve()
	if result.problematic terminate(result)

	analysis.analyze()

	platform.x64.initialize()
	assembler.assemble()
	if result.problematic terminate(result)

	end = time.now()
	console.write(to_string((end - start) / 10000.0))
	console.write_line(' ms')
	return 0
}