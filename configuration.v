OPERATING_SYSTEM_WINDOWS = 0
OPERATING_SYSTEM_LINUX = 1

OS = 0

BUNDLE_ARGUMENTS = 'arguments'
BUNDLE_DEBUG = 'debug'
BUNDLE_OUTPUT_NAME = 'output_name'
BUNDLE_ASSEMBLY = 'assembly'
BUNDLE_OUTPUT_TYPE = 'output_type'
BUNDLE_TIME = 'time'
BUNDLE_REBUILD = 'rebuild'
BUNDLE_SERVICE = 'service'
BUNDLE_FILENAMES = 'filenames'
BUNDLE_OBJECTS = 'objects'
BUNDLE_IMPORTED_OBJECTS = 'imported-objects'
BUNDLE_LIBRARIES = 'libraries'

# All possible output binary types
BINARY_TYPE_SHARED_LIBRARY = 0
BINARY_TYPE_STATIC_LIBRARY = 1
BINARY_TYPE_EXECUTABLE = 2

LIBRARY_PREFIX = 'lib'

# Supported architectures
ARCHITECTURE_X64 = 0
ARCHITECTURE_ARM64 = 1

# The current compiler version
COMPILER_VERSION = '1.0'

# The primary file extension of this language
ASSEMBLY_EXTENSION = '.asm'
LANGUAGE_FILE_EXTENSION = '.v'
WINDOWS_OBJECT_FILE_EXTENSION = '.obj'
LINUX_OBJECT_FILE_EXTENSION = '.o'

ASSEMBLER_FLAG = 'assembler'
LINK_FLAG = 'link'

DEFAULT_OUTPUT_NAME = 'v'

# Summary: Returns the extension of a static library file
static_library_extension() {
	if OS == OPERATING_SYSTEM_WINDOWS {
		=> '.lib'
	}

	=> '.a'
}

# Summary: Returns the extension of a static library file
shared_library_extension() {
	if OS == OPERATING_SYSTEM_WINDOWS {
		=> '.dll'
	}

	=> '.so'
}

# Summary: Returns whether the element starts with '-'
is_option(element: String) {
	=> element[0] == `-`
}

# Summary: Collect files from the specified folder
collect(files: List<String>, folder: String, recursive: bool) {
	result = io.get_folder_files(folder, recursive)

	loop file in result {
		# Skip files which do not end with the language extension
		if not file.fullname.ends_with(LANGUAGE_FILE_EXTENSION) continue
		
		files.add(file.fullname)
	}
}

# Summary: Initializes the configuration by registering the folders which can be searched through
initialize_configuration() {
	settings.included_folders = List<String>()
	settings.included_folders.add(io.get_process_folder())

	folders = none as List<String>

	if OS == OPERATING_SYSTEM_WINDOWS {
		path = io.get_environment_variable('PATH')
		if path as link == none { path = String('') }

		folders = path.split(`;`).to_list()

		# Ensure all the separators are the same
		loop (i = 0, i < folders.size, i++) {
			folders[i] = folders[i].replace(`\\`, `/`)
		}
	}
	else {
		path = io.get_environment_variable('Path')
		if path as link == none { path = String('') }

		folders = path.split(`:`).to_list()
	}

	# Look for empty folder strings and remove them
	loop (i = folders.size - 1, i >= 0, i--) {
		if folders[i].length > 0 continue
		folders.remove_at(i)
	}

	settings.included_folders.add_range(folders)

	# Ensure all the included folders ends with a separator
	loop (i = 0, i < settings.included_folders.size, i++) {
		folder = settings.included_folders[i]
		if folder.ends_with('/') continue

		settings.included_folders[i] = folder + '/'
	}

	Keywords.initialize()
	Operators.initialize()
}

# Summary: Tries to find the specified library using the include folders
find_library(library: String) {

	loop folder in settings.included_folders {
		filename = folder + library

		if io.exists(filename) => filename

		filename = folder + LIBRARY_PREFIX + library
		if io.exists(filename) => filename

		filename = folder + library + static_library_extension()
		if io.exists(filename) => filename

		filename = folder + library + shared_library_extension()
		if io.exists(filename) => filename

		filename = folder + LIBRARY_PREFIX + library + static_library_extension()
		if io.exists(filename) => filename
		
		filename = folder + LIBRARY_PREFIX + library + shared_library_extension()
		if io.exists(filename) => filename
	}

	=> none as String
}

configure(bundle: Bundle, parameters: List<String>, files: List<String>, libraries: List<String>, value: String) {
	if value == '-help' {
		println('Usage: v [options] <folders / files>')
		println('Options:')
		println('-help')
		println('-r <folder> / -recursive <folder>')
		println('-d / -debug')
		println('-o <filename> / -output <filename>')
		println('-l <library> / -library <library>')
		println('-link')
		println('-a / -assembly')
		println('-shared / -dynamic / -dll')
		println('-static')
		println('-st / -single-thread')
		println('-q / -quiet')
		println('-v / -verbose')
		println('-f / -force / -rebuild')
		println('-t / -time')
		println('-O, -O1, -O2')
		println('-x64')
		println('-arm64')
		println('-version')
		println('-s')
		application.exit(1)
	}
	else value == '-r' or value == '-recursive' {
		if parameters.size == 0 => Status('Missing or invalid value for option')
		
		folder = parameters.take_first()
		if is_option(folder) => Status('Missing or invalid value for option')

		# Ensure the specified folder exists
		if not io.exists(folder) => Status('Folder does not exist')

		collect(files, folder, true)
	}
	else value == '-d' or value == '-debug' {
		if settings.is_optimization_enabled => Status('Optimization and debugging can not be enabled at the same time')

		settings.is_debugging_enabled = true
		bundle.put(String(BUNDLE_DEBUG), true)
	}
	else value == '-o' or value == '-output' {
		if parameters.size == 0 => Status('Missing or invalid value for option')

		name = parameters.take_first()
		if is_option(name) => Status('Missing or invalid value for option')

		bundle.put(String(BUNDLE_OUTPUT_NAME), name as link)
	}
	else value == '-l' or value == '-library' {
		if parameters.size == 0 => Status('Missing or invalid value for option')

		library = parameters.take_first()
		if is_option(library) => Status('Missing or invalid value for option')

		filename = find_library(library)

		if filename as link == none => Status('Can not find the specified library')

		libraries.add(filename)
	}
	else value == '-link' {
		bundle.put(String(LINK_FLAG), true)
	}
	else value == '-a' or value == '-assembly' {
		bundle.put(String(BUNDLE_ASSEMBLY), true)
		settings.is_assembly_output_enabled = true
	}
	else value == '-dynamic' or value == '-shared' or value == '-dll' {
		bundle.put(String(BUNDLE_OUTPUT_TYPE), BINARY_TYPE_SHARED_LIBRARY)
	}
	else value == '-static' {
		bundle.put(String(BUNDLE_OUTPUT_TYPE), BINARY_TYPE_STATIC_LIBRARY)
	}
	else value == '-t' or value == '-time' {
		bundle.put(String(BUNDLE_TIME), true)
	}
	else value == '-q' or value == '-quiet' {
		settings.is_verbose_output_enabled = false
	}
	else value == '-v' or value == '-verbose' {
		settings.is_verbose_output_enabled = true
	}
	else value == '-r' or value == '-rebuild' or value == '-force' {
		bundle.put(String(BUNDLE_REBUILD), true)
	}
	else value == '-O' or value == '-O1' {
		if settings.is_debugging_enabled => Status('Optimization and debugging can not be enabled at the same time')

		settings.is_optimization_enabled = true

		settings.is_instruction_analysis_enabled = true
		settings.is_mathematical_analysis_enabled = true
		settings.is_repetion_analysis_enabled = true
		settings.is_unwrapment_analysis_enabled = true
		settings.is_function_inlining_enabled = false
	}
	else value == '-O2' {
		if settings.is_debugging_enabled => Status('Optimization and debugging can not be enabled at the same time')

		settings.is_optimization_enabled = true

		settings.is_instruction_analysis_enabled = true
		settings.is_mathematical_analysis_enabled = true
		settings.is_repetion_analysis_enabled = true
		settings.is_unwrapment_analysis_enabled = true
		settings.is_function_inlining_enabled = true
	}
	else value == '-x64' {
		settings.architecture = ARCHITECTURE_X64
	}
	else value == '-arm64' {
		settings.architecture = ARCHITECTURE_ARM64
	}
	else value == '-version' {
		print('Vivid version ')
		println(COMPILER_VERSION)
		application.exit(0)
	}
	else value == '-s' {
		bundle.put(String(BUNDLE_SERVICE), true)
	}
	else {
		=> Status(String('Unknown option ') + value)
	}
	
	=> Status()
}

configure(bundle: Bundle, arguments: List<String>) {
	files = List<String>()
	objects = List<String>()
	libraries = List<String>()

	loop (arguments.size > 0) {
		element = arguments.take_first()

		if is_option(element) {
			result = configure(bundle, arguments, files, libraries, element)
			if result.problematic => result
			continue
		}
		else io.exists(element) {
			# If the element represents a folder, source files inside it must be compiled
			if io.is_folder(element) {
				collect(files, element, false)
				continue
			}

			# Ensure the source file ends with the primary file extension
			if element.ends_with(LANGUAGE_FILE_EXTENSION) {
				files.add(element)
			}
			else element.ends_with(ASSEMBLY_EXTENSION) {
				files.add(element)
				bundle.put(String(ASSEMBLER_FLAG), true)
			}
			else element.ends_with(LINUX_OBJECT_FILE_EXTENSION) or element.ends_with(WINDOWS_OBJECT_FILE_EXTENSION) {
				objects.add(element)
			}
			else {
				=> Status('Source files must end with the language extension')
			}

			continue
		}

		=> Status('Invalid source file or folder')
	}

	# Ensure the bundle contains an output name
	if not bundle.contains_object(String(BUNDLE_OUTPUT_NAME)) {
		bundle.put(String(BUNDLE_OUTPUT_NAME), DEFAULT_OUTPUT_NAME)
	}

	bundle.put(String(BUNDLE_FILENAMES), files as link)
	bundle.put(String(BUNDLE_OBJECTS), objects as link)
	bundle.put(String(BUNDLE_IMPORTED_OBJECTS), Map<SourceFile, BinaryObjectFile>() as link)
	bundle.put(String(BUNDLE_LIBRARIES), libraries as link)

	=> Status()
}