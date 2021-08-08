constant UNIT_TEST_PREFIX = 'unit_'

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

current_folder() {
	=> io.get_environment_variable('PWD')
}

project_file(folder: link, name: link) {
	=> current_folder() + `/` + folder + `/` + name
}

compile(output: link, source_files: List<String>, optimization: large, prebuilt: bool) {
	String.empty = String('')
	settings.initialize()
	
	bundle = Bundle()

	arguments = List<String>()
	arguments.add_range(source_files)
	arguments.add(project_file('libv', 'Core.v'))
	arguments.add(String('-a'))
	arguments.add(String('-o'))
	arguments.add(String(UNIT_TEST_PREFIX) + output)

	if prebuilt {
		objects = io.get_folder_files(current_folder() + '/prebuilt/', false)
		loop object in objects { arguments.add(object.fullname) }
	}

	# Add optimization level
	if optimization != 0 arguments.add(String('-O') + to_string(optimization))

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
	result = assembler.assemble(bundle)
	if result.problematic complain(result)
}

execute(name: link) {
	executable_name = String(UNIT_TEST_PREFIX) + name
	io.write_file(executable_name + '.out', String(''))

	exit_code = io.shell(String('./') + executable_name + ' > ' + executable_name + '.out')
	if exit_code != 0 abort('Executed process exited with non-zero code')

	=> io.read_file(executable_name + '.out')
}

arithmetic(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'arithmetic.v'))
	compile('arithmetic', files, optimization, true)

	log = execute('arithmetic')
}

init() {
	println('Arithmetic')
	arithmetic(0)
	=> 0
}