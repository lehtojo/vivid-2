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

project_file(folder: link, name: link) {
	=> io.get_process_working_folder() + `/` + folder + `/` + name
}

compile(output: link, source_files: List<String>, optimization: large, prebuilt: bool) {
	String.empty = String('')
	settings.initialize()
	
	bundle = Bundle()

	arguments = List<String>()
	arguments.add_range(source_files)
	arguments.add(String('-a'))
	arguments.add(String('-o'))
	arguments.add(String(UNIT_TEST_PREFIX) + output)

	if prebuilt {
		arguments.add(project_file('libv', 'Core.v'))
		objects = io.get_folder_files(io.get_process_working_folder() + '/prebuilt/', false)
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
	if settings.is_target_windows { executable_name = executable_name + '.exe' }

	io.write_file(executable_name + '.out', String(''))

	pid = 0

	if settings.is_target_windows {
		pid = io.shell(executable_name + ' > ' + executable_name + '.out')
	}
	else {
		pid = io.shell(String('./') + executable_name + ' > ' + executable_name + '.out')
	}

	#exit_code = io.wait_for_exit(pid)
	#if exit_code != 1 abort('Executed process exited with an error code')

	if not [io.read_file(executable_name + '.out') has log] => String.empty

	=> String(log.data)
}

# Summary: Loads the specified assembly output file and returns the section which represents the specified function
load_assembly_function(output: link, function: link) {
	if not [io.read_file(String(UNIT_TEST_PREFIX) + output + '.asm') has content] {
		abort('Could not load the specified assembly function')
	}

	assembly = String(content.data)
	start = assembly.index_of(String(function) + ':')
	end = assembly.index_of('\n\n', start)

	if start == -1 or end == -1 {
		abort(String('Could not load assembly function ') + function + ' from file ' + UNIT_TEST_PREFIX + output + '.asm')
	}

	=> assembly.slice(start, end)
}

# Summary: Loads the specified assembly output file
load_assembly_output(project: link) {
	if io.read_file(String(UNIT_TEST_PREFIX) + project + `.` + project + '.asm') has content => String(content.data)
	=> String.empty
}

# Summary: Returns the number of the specified instructions, which contain the specified content
count_of(assembly: String, instruction: link, content: link) {
	lines = assembly.split(`\n`)
	count = 0

	loop line in lines {
		if line.index_of(instruction) == -1 or (content != none and line.index_of(content) == -1) continue
		count++
	}

	=> count
}

# Summary: Returns number of memory addresses in the specified assembly
get_memory_address_count(assembly: String) {
	lines = assembly.split(`\n`)
	count = 0

	loop line in lines {
		start = line.index_of(`[`)
		if start == -1 continue

		end = line.index_of(`]`, start)
		if end == -1 continue

		# Evaluation instructions do not access memory, they evaluate the 'memory address'
		if line.index_of(instructions.x64.EVALUATE) != -1 continue

		count++
	}

	=> count
}

# Summary: Returns the section which represents the specified function
get_function_from_assembly(assembly: String, function: link) {
	start = assembly.index_of(String(function) + ':')
	end = assembly.index_of('\n\n', start)

	if start == -1 or end == -1 abort('Could not load the specified function from assembly')

	=> assembly.slice(start, end)
}

get_standard_library_utility() {
	files = List<String>()
	files.add(project_file('tests', 'assert.v'))
	files.add(project_file('libv', 'Core.v'))
	files.add(project_file('libv', 'Console.v'))
	files.add(project_file('libv', 'String.v'))
	files.add(project_file('libv', 'StringBuilder.v'))
	files.add(project_file('libv', 'List.v'))
	files.add(project_file('libv', 'Array.v'))
	files.add(project_file('libv', 'Exceptions.v'))
	=> files
}

arithmetic(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'arithmetic.v'))
	compile('arithmetic', files, optimization, true)

	log = execute('arithmetic')
}

assignment(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'assignment.v'))
	compile('assignment', files, optimization, true)

	log = execute('assignment')
}

bitwise(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'bitwise.v'))
	compile('bitwise', files, optimization, true)

	log = execute('bitwise')
}

conditionally_changing_constant(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'conditionally_changing_constant.v'))
	compile('conditionally_changing_constant', files, optimization, true)

	log = execute('conditionally_changing_constant')
}

conditionals_statements(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'conditionals.v'))
	compile('conditionals', files, optimization, true)

	log = execute('conditionals')
}

constant_permanence(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'constant_permanence.v'))
	compile('constant_permanence', files, optimization, true)

	log = execute('constant_permanence')
}

decimals(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'decimals.v'))
	compile('decimals', files, optimization, true)

	log = execute('decimals')
}

evacuation(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'evacuation.v'))
	compile('evacuation', files, optimization, true)

	log = execute('evacuation')
}

large_functions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'large_functions.v'))
	compile('large_functions', files, optimization, true)

	log = execute('large_functions')
}

linkage(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'linkage.v'))
	compile('linkage', files, optimization, true)

	log = execute('linkage')
}

logical_operators(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'logical_operators.v'))
	compile('logical_operators', files, optimization, true)

	log = execute('logical_operators')
}

loops_statements(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'loops.v'))
	compile('loops', files, optimization, true)

	log = execute('loops')
}

objects(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'objects.v'))
	compile('objects', files, optimization, true)

	log = execute('objects')
}

register_utilization(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'register_utilization.v'))
	compile('register_utilization', files, optimization, true)

	log = execute('register_utilization')

	assembly = load_assembly_function('register_utilization.register_utilization', '_V20register_utilizationxxxxxxx_rx')
	are_equal(1, get_memory_address_count(assembly))
}

scopes(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'scopes.v'))
	compile('scopes', files, optimization, true)

	log = execute('scopes')
}

special_multiplications(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'special_multiplications.v'))
	compile('special_multiplications', files, optimization, true)

	log = execute('special_multiplications')

	assembly = load_assembly_output('special_multiplications')

	if settings.is_x64 {
		are_equal(1, count_of(assembly, instructions.x64.SIGNED_MULTIPLY, none as link))
		are_equal(1, count_of(assembly, instructions.x64.SHIFT_LEFT, none as link))
		are_equal(1, count_of(assembly, instructions.x64.EVALUATE, none as link))
		are_equal(1, count_of(assembly, instructions.x64.SHIFT_RIGHT, none as link))
	}
	else {
		are_equal(1, count_of(assembly, instructions.arm64.SHIFT_LEFT, '#1'))
		are_equal(2, count_of(assembly, instructions.shared.ADD, 'lsl #'))
		are_equal(1, count_of(assembly, instructions.arm64.SHIFT_RIGHT, '#2'))
	}
}

stack(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'stack.v'))
	compile('stack', files, optimization, true)

	log = execute('stack')

	assembly = load_assembly_function('stack.stack', '_V12multi_returnxx_rx')
	j = 0

	# There should be five 'add rsp, ...' or 'ldp' instructions
	loop (i = 0, i < 4, i++) {
		if settings.is_x64 { j = assembly.index_of(String('add rsp, '), j) }
		else { j = assembly.index_of(String('ldp'), j) }

		if j < 0 abort('Assembly output did not contain five \'add rsp, ...\' or \'ldp\' instructions')
		j++
	}
}

memory_operations(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'memory.v'))
	compile('memory', files, optimization, true)

	log = execute('memory')

	if optimization < 1 return

	# Load the generated assembly
	assembly = load_assembly_output('memory')
	
	are_equal(1, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_1P6Objecti_ri')))
	are_equal(1, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_2Phi_rh')))
	are_equal(3, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_3P6Objectd_rd')))
	are_equal(3, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_4P6ObjectS0__ri')))
	are_equal(3, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_5P6ObjectPh_rd')))
	are_equal(2, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_6P6Object_rd')))
	are_equal(4, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_7P6ObjectS0__rd')))
	are_equal(4, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_8P6ObjectS0__rd')))
	are_equal(4, get_memory_address_count(get_function_from_assembly(assembly, '_V13memory_case_9P6ObjectS0__rd')))
	are_equal(5, get_memory_address_count(get_function_from_assembly(assembly, '_V14memory_case_10P6ObjectS0__rd')))
	are_equal(6, get_memory_address_count(get_function_from_assembly(assembly, '_V14memory_case_11P6Objectx')))
	are_equal(4, get_memory_address_count(get_function_from_assembly(assembly, '_V14memory_case_12P6Objectx_ri')))
	are_equal(6, get_memory_address_count(get_function_from_assembly(assembly, '_V14memory_case_13P6Objectx')))
}

templates(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'templates.v'))
	compile('templates', files, optimization, true)

	log = execute('templates')
}

fibonacci(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'fibonacci.v'))
	files.add_range(get_standard_library_utility())
	compile('fibonacci', files, optimization, false)

	log = execute('fibonacci')

	if not (log == '0\n1\n1\n2\n3\n5\n8\n13\n21\n34\n') {
		println('Fibonacci unit test did not produce the correct output')
	}
}

pi(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'pi.v'))
	files.add_range(get_standard_library_utility())
	compile('pi', files, optimization, false)

	log = execute('pi')

	if not (io.read_file(project_file('tests', 'pi.txt')) has bytes) {
		println('Could not load the expected Pi unit test output')
	}

	expected = String.from(bytes.data, bytes.count)

	if not (log == expected) {
		println('Pi unit test did not produce the correct output')
	}
}

inheritance(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'inheritance.v'))
	files.add_range(get_standard_library_utility())
	compile('inheritance', files, optimization, false)

	log = execute('inheritance')
}

namespaces(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'namespaces.v'))
	files.add_range(get_standard_library_utility())
	compile('namespaces', files, optimization, false)

	log = execute('namespaces')

	if not (log == 'Apple\nBanana\nFactory Foo.Apple\nFactory Foo.Apple\nFactory Foo.Apple\n') {
		println('Namespaces unit test did not produce the correct output')
	}
}

extensions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'extensions.v'))
	files.add_range(get_standard_library_utility())
	compile('extensions', files, optimization, false)

	log = execute('extensions')

	if not (log == 'Decimal seems to be larger than tiny\nFactory created new Foo.Bar.Counter\n7\n') {
		println('Extensions unit test did not produce the correct output')
	}
}

virtuals(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'virtuals.v'))
	files.add_range(get_standard_library_utility())
	compile('virtuals', files, optimization, false)

	log = execute('virtuals')

	if not (io.read_file(project_file('tests', 'virtuals.txt')) has bytes) {
		println('Could not load the expected Virtuals unit test output')
	}

	expected = String.from(bytes.data, bytes.count)

	if not (log == expected) {
		println('Virtuals unit test did not produce the correct output')
	}
}

expression_variables(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'expression_variables.v'))
	files.add_range(get_standard_library_utility())
	compile('expression_variables', files, optimization, false)

	log = execute('expression_variables')

	if not (io.read_file(project_file('tests', 'expression_variables.txt')) has bytes) {
		println('Could not load the expected Expression variables unit test output')
	}

	expected = String.from(bytes.data, bytes.count)

	if not (log == expected) {
		println('Expression variables unit test did not produce the correct output')
	}
}

iteration(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'iteration.v'))
	files.add_range(get_standard_library_utility())
	compile('iteration', files, optimization, false)

	log = execute('iteration')
}

lambdas(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'lambdas.v'))
	files.add_range(get_standard_library_utility())
	compile('lambdas', files, optimization, false)

	log = execute('lambdas')

	if not (io.read_file(project_file('tests', 'lambdas.txt')) has bytes) {
		println('Could not load the expected Lambdas unit test output')
	}

	expected = String.from(bytes.data, bytes.count)

	if not (log == expected) {
		println('Lambdas unit test did not produce the correct output')
	}
}

is_expressions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'is.v'))
	files.add(project_file('libv', 'Math.v'))
	files.add_range(get_standard_library_utility())
	compile('is', files, optimization, false)

	log = execute('is')
}

whens_expressions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'whens.v'))
	files.add_range(get_standard_library_utility())
	compile('whens', files, optimization, false)

	log = execute('whens')
}

init() {
	println('Whens')
	whens_expressions(0)
	println('Arithmetic')
	arithmetic(0)
	println('Assignment')
	assignment(0)
	println('Bitwise')
	bitwise(0)
	println('Conditionally changing constant')
	conditionally_changing_constant(0)
	#println('Conversions')
	#conversions(0)
	println('Conditionals')
	conditionals_statements(0)
	println('Constant permanence')
	constant_permanence(0)
	println('Decimals')
	decimals(0)
	println('Evacuation')
	evacuation(0)
	println('Large functions')
	large_functions(0)
	println('Linkage')
	linkage(0)
	println('Logical operators')
	logical_operators(0)
	println('Loops')
	loops_statements(0)
	println('Objects')
	objects(0)
	println('Register utilization')
	register_utilization(0)
	println('Scopes')
	scopes(0)
	println('Special multiplications')
	special_multiplications(0)
	println('Stack')
	stack(0)
	println('Memory')
	memory_operations(0)
	println('Templates')
	templates(0)
	println('Fibonacci')
	fibonacci(0)
	println('Pi')
	pi(0)
	println('Inheritance')
	inheritance(0)
	println('Namespaces')
	namespaces(0)
	println('Extensions')
	extensions(0)
	println('Virtuals')
	virtuals(0)
	println('Expression variables')
	expression_variables(0)
	println('Iteration')
	iteration(0)
	println('Lambdas')
	lambdas(0)
	println('Is')
	is_expressions(0)
	=> 0
}