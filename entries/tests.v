constant UNIT_TEST_PREFIX = 'unit_'

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

abort(position: Position, message: link) {
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

complain(status: Status) {
	console.write('Compilation terminated: ')
	console.write_line(status.message)
	application.exit(1)
}

project_file(folder: link, name: link) {
	return io.get_process_working_folder() + `/` + folder + `/` + name
}

relative_file(name: link) {
	return io.get_process_working_folder() + `/` + name
}

compile(output: link, source_files: List<String>, optimization: large, prebuilt: bool) {
	String.empty = ""
	settings.initialize()
	initialize_configuration()

	arguments = List<String>()
	arguments.add_all(source_files)
	arguments.add("-a")
	arguments.add("-l")
	arguments.add("kernel32.dll")
	arguments.add("-o")
	arguments.add(String(UNIT_TEST_PREFIX) + output)
	arguments.add_all(get_standard_object_files())

	if prebuilt {
		objects = io.get_folder_files(io.get_process_working_folder() + '/prebuilt/', false)

		loop object in objects {
			# Add object files and source files
			if object.fullname.ends_with(LANGUAGE_FILE_EXTENSION) or 
				object.fullname.ends_with(object_file_extension) {
				arguments.add(object.fullname)
			}
		}
	}
	else {
		# Add the built standard library
		arguments.add_all(get_standard_library_utility())
	}

	# Add optimization level
	if optimization != 0 arguments.add("-O" + to_string(optimization))

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

	primitives.initialize()
	numbers.initialize()

	parser.initialize()
	result = parser.parse()
	if result.problematic complain(result)

	result = resolver.resolve()
	if result.problematic complain(result)

	analysis.analyze()
	if result.problematic complain(result)

	platform.x64.initialize()
	assembler.assemble()
	if result.problematic complain(result)
}

execute(name: link) {
	executable_name = String(UNIT_TEST_PREFIX) + name
	if settings.is_target_windows { executable_name = executable_name + '.exe' }

	io.write_file(executable_name + '.out', String.empty)

	pid = 0

	if settings.is_target_windows {
		pid = io.shell(executable_name + ' > ' + executable_name + '.out')
	}
	else {
		pid = io.shell("./" + executable_name + ' > ' + executable_name + '.out')
	}

	exit_code = io.wait_for_exit(pid)
	if exit_code != 0 abort('Executed process exited with an error code')

	if io.read_file(executable_name + '.out') has not log return String.empty

	return String(log.data, log.size)
}

# Summary: Loads the specified assembly output file and returns the section which represents the specified function
load_assembly_function(output: link, function: link) {
	if io.read_file(String(UNIT_TEST_PREFIX) + output + '.asm') has not content {
		abort('Could not load the specified assembly function')
	}

	assembly = String(content.data)
	start = assembly.index_of(String(function) + ':')
	end = assembly.index_of('\n\n', start)

	if start == -1 or end == -1 {
		abort("Could not load assembly function " + function + ' from file ' + UNIT_TEST_PREFIX + output + '.asm')
	}

	return assembly.slice(start, end)
}

# Summary: Loads the specified assembly output file
load_assembly_output(project: link) {
	if io.read_file(String(UNIT_TEST_PREFIX) + project + `.` + project + '.asm') has content return String(content.data)
	return String.empty
}

# Summary: Returns the number of the specified instructions, which contain the specified content
count_of(assembly: String, instruction: link, content: link) {
	lines = assembly.split(`\n`)
	count = 0

	loop line in lines {
		if line.index_of(instruction) == -1 or (content != none and line.index_of(content) == -1) continue
		count++
	}

	return count
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
		if line.index_of(platform.x64.EVALUATE) != -1 continue

		count++
	}

	return count
}

# Summary: Returns the section which represents the specified function
get_function_from_assembly(assembly: String, function: link) {
	start = assembly.index_of(String(function) + ':')
	end = assembly.index_of('\n\n', start)

	if start == -1 or end == -1 abort('Could not load the specified function from assembly')

	return assembly.slice(start, end)
}

get_standard_object_files(): List<String> {
	return [ relative_file('min.math.obj'), relative_file('min.memory.obj'), relative_file('min.tests.obj') ]
}

get_standard_library_utility() {
	files = List<String>()
	files.add(project_file('libv/tests', 'core.v'))
	files.add(project_file('libv/windows-x64', 'application.v'))
	files.add(project_file('libv/windows-x64', 'internal-console.v'))
	files.add(project_file('libv/windows-x64', 'internal-memory.v'))
	files.add(project_file('libv', 'array.v'))
	files.add(project_file('libv', 'console.v'))
	files.add(project_file('libv', 'exceptions.v'))
	files.add(project_file('libv', 'list.v'))
	files.add(project_file('libv', 'math.v'))
	files.add(project_file('libv', 'memory-utility.v'))
	files.add(project_file('libv', 'sequential-iterator.v'))
	files.add(project_file('libv', 'sort.v'))
	files.add(project_file('libv', 'string-builder.v'))
	files.add(project_file('libv', 'string-utility.v'))
	files.add(project_file('libv', 'string.v'))
	return files
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

	# Do not analyze the assembly when optimizations are enabled
	if optimization > 0 return

	assembly = load_assembly_output('special_multiplications')

	if settings.is_x64 {
		are_equal(1, count_of(assembly, platform.x64.SIGNED_MULTIPLY, none as link))
		are_equal(1, count_of(assembly, platform.x64.SHIFT_LEFT, none as link))
		are_equal(1, count_of(assembly, platform.x64.EVALUATE, none as link))
		are_equal(1, count_of(assembly, platform.x64.SHIFT_RIGHT, none as link))
	}
	else {
		are_equal(1, count_of(assembly, platform.arm64.SHIFT_LEFT, '#1'))
		are_equal(2, count_of(assembly, platform.all.ADD, 'lsl #'))
		are_equal(1, count_of(assembly, platform.arm64.SHIFT_RIGHT, '#2'))
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
		if settings.is_x64 { j = assembly.index_of("add rsp, ", j) }
		else { j = assembly.index_of("ldp", j) }

		if j < 0 abort('Assembly output did not contain five \'add rsp, ...\' or \'ldp\' instructions')
		j++
	}
}

memory_operations(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'memory.v'))
	compile('memory', files, optimization, true)

	log = execute('memory')

	# TODO: Remove this when memory access optimization is added
	return

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
	files.add(project_file('tests', 'assert.v'))
	compile('fibonacci', files, optimization, false)

	log = execute('fibonacci')

	if not (log == '0\n1\n1\n2\n3\n5\n8\n13\n21\n34\n') {
		console.write_line('Fibonacci unit test did not produce the correct output')
	}
}

pi(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'pi.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('pi', files, optimization, false)

	log = execute('pi')

	if io.read_file(project_file('tests', 'pi.txt')) has not bytes {
		console.write_line('Could not load the expected Pi unit test output')
	}

	expected = String.from(bytes.data, bytes.size)

	if not (log == expected) {
		console.write_line('Pi unit test did not produce the correct output')
	}
}

inheritance(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'inheritance.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('inheritance', files, optimization, false)

	log = execute('inheritance')
}

namespaces(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'namespaces.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('namespaces', files, optimization, false)

	log = execute('namespaces')

	if not (log == 'Apple\nBanana\nFactory Foo.Apple\nFactory Foo.Apple\nFactory Foo.Apple\n') {
		console.write_line('Namespaces unit test did not produce the correct output')
	}
}

extensions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'extensions.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('extensions', files, optimization, false)

	log = execute('extensions')

	if not (log == 'Decimal seems to be larger than tiny\nFactory created new Foo.Bar.Counter\n7\n') {
		console.write_line('Extensions unit test did not produce the correct output')
	}
}

virtuals(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'virtuals.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('virtuals', files, optimization, false)

	log = execute('virtuals')

	if io.read_file(project_file('tests', 'virtuals.txt')) has not bytes {
		console.write_line('Could not load the expected Virtuals unit test output')
	}

	expected = String.from(bytes.data, bytes.size)

	if not (log == expected) {
		console.write_line('Virtuals unit test did not produce the correct output')
	}
}

expression_variables(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'expression_variables.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('expression_variables', files, optimization, false)

	log = execute('expression_variables')

	if io.read_file(project_file('tests', 'expression_variables.txt')) has not bytes {
		console.write_line('Could not load the expected Expression variables unit test output')
	}

	expected = String.from(bytes.data, bytes.size)

	if not (log == expected) {
		console.write_line('Expression variables unit test did not produce the correct output')
	}
}

iteration(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'iteration.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('iteration', files, optimization, false)

	log = execute('iteration')
}

lambdas(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'lambdas.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('lambdas', files, optimization, false)

	log = execute('lambdas')

	if io.read_file(project_file('tests', 'lambdas.txt')) has not bytes {
		console.write_line('Could not load the expected Lambdas unit test output')
	}

	expected = String.from(bytes.data, bytes.size)

	if not (log == expected) {
		console.write_line('Lambdas unit test did not produce the correct output')
	}
}

is_expressions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'is.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('is', files, optimization, false)

	log = execute('is')
}

whens_expressions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'whens.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('whens', files, optimization, false)

	log = execute('whens')
}

conversions(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'conversions.v'))
	files.add(project_file('tests', 'assert.v'))
	compile('conversions', files, optimization, false)

	log = execute('conversions')
}

lists(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'lists.v'))
	compile('lists', files, optimization, false)

	log = execute('lists')
	expected = '1, 2, 3, 5, 7, 11, 13, \n42, 69, \nFoo, Bar, Baz, Qux, Xyzzy, \nFoo, Bar, Baz x 3, Qux, Xyzzy x 7, \n'

	if not (log == expected) {
		console.write_line('Lists unit test did not produce the correct output')
	}
}

packs(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'packs.v'))
	compile('packs', files, optimization, false)

	log = execute('packs')
	expected = '170\n2143\n20716\n3050\n4058\n3502\n354256\n'

	if not (log == expected) {
		console.write_line('Packs unit test did not produce the correct output')
	}
}

unnamed_packs(optimization: large) {
	files = List<String>()
	files.add(project_file('tests', 'unnamed_packs.v'))
	compile('unnamed_packs', files, optimization, false)

	log = execute('unnamed_packs')
	expected = '420\n420\n2310\n'

	if not (log == expected) {
		console.write_line('Unnamed packs unit test did not produce the correct output')
	}
}

init() {
	optimization = 2
	console.write_line('Arithmetic')
	arithmetic(optimization)
	console.write_line('Assignment')
	assignment(optimization)
	console.write_line('Bitwise')
	bitwise(optimization)
	console.write_line('Conditionally changing constant')
	conditionally_changing_constant(optimization)
	console.write_line('Conditionals')
	conditionals_statements(optimization)
	console.write_line('Constant permanence')
	constant_permanence(optimization)
	console.write_line('Decimals')
	decimals(optimization)
	console.write_line('Evacuation')
	evacuation(optimization)
	console.write_line('Large functions')
	large_functions(optimization)
	console.write_line('Linkage')
	linkage(optimization)
	console.write_line('Logical operators')
	logical_operators(optimization)
	console.write_line('Loops')
	loops_statements(optimization)
	console.write_line('Objects')
	objects(optimization)
	console.write_line('Register utilization')
	register_utilization(optimization)
	console.write_line('Scopes')
	scopes(optimization)
	console.write_line('Special multiplications')
	special_multiplications(optimization)
	console.write_line('Stack')
	stack(optimization)
	console.write_line('Memory')
	memory_operations(optimization)
	console.write_line('Templates')
	templates(optimization)
	console.write_line('Fibonacci')
	fibonacci(optimization)
	console.write_line('Pi')
	pi(optimization)
	console.write_line('Inheritance')
	inheritance(optimization)
	console.write_line('Namespaces')
	namespaces(optimization)
	console.write_line('Extensions')
	extensions(optimization)
	console.write_line('Virtuals')
	virtuals(optimization)
	console.write_line('Conversions')
	conversions(optimization)
	console.write_line('Expression variables')
	expression_variables(optimization)
	console.write_line('Iteration')
	iteration(optimization)
	console.write_line('Lambdas')
	lambdas(optimization)
	console.write_line('Is')
	is_expressions(optimization)
	console.write_line('Whens')
	whens_expressions(optimization)
	console.write_line('Lists')
	lists(optimization)
	console.write_line('Packs')
	packs(optimization)
	console.write_line('Unnamed packs')
	unnamed_packs(optimization)
	return 0
}