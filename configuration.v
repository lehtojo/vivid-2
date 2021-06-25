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
LANGUAGE_FILE_EXTENSION = '.v'

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
		if not file.ends_with(LANGUAGE_FILE_EXTENSION) continue
		
		files.add(file)
	}
}

# Summary: Initializes the configuration by registering the folders which can be searched through
initialize() {
	Settings.included_folders = List<String>()
	Settings.included_folders.add(io.get_process_folder())

	folders = none as List<String>

	if OS == OPERATING_SYSTEM_WINDOWS {
		path = io.get_environment_variable('PATH')
		if path == none { path = String('') }

		folders = path.split(':').to_list()

		# Ensure all the separators are the same
		loop (i = 0, i < folders.size, i++) {
			folders[i] = folders[i].replace(`\\`, `/`)
		}
	}
	else {
		path = io.get_environment_variable('Path')
		if path == none { path = String('') }

		folders = path.split(';').to_list()
	}

	# Look for empty folder strings and remove them
	loop (i = folders.size - 1, i >= 0, i--) {
		if not folders[i].empty continue
		folders.remove_at(i)
	}

	# Ensure all the included folders ends with a separator
	loop (i = 0, i < Settings.included_folders.size, i++) {
		folder = Settings.included_folders[i]
		if folder.ends_with('/') continue

		Settings.included_folders[i] = folder + '/'
	}
}

# Summary: Tries to find the specified library using the include folders
find_library(library: String) {

	loop folder in Settings.included_folders {
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
		println('-r <folder>')
		println('-d / -debug')
		println('-o <filename> / -output <filename>')
		println('-l <library> / -library <library>')
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
		exit(1)
	}
	else value == '-r' {
		if parameters.size == 0 => Status('Missing or invalid value for option')
		
		folder = parameters.take_first()
		if is_option(folder) => Status('Missing or invalid value for option')

		# Ensure the specified folder exists
		if not io.exists(folder) => Status('Folder does not exist')

		collect(files, folder, true)
	}
	else value == '-d' or value == '-debug' {
		if Settings.is_optimization_enabled => Status('Optimization and debugging can not be enabled at the same time')

		Settings.is_debugging_enabled = true
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

		if filename == none => Status('Can not find the specified library')

		libraries.add(filename)
	}
	else value == '-a' or value == '-assembly' {
		bundle.put(String(BUNDLE_ASSEMBLY), true)
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
		Settings.is_verbose_output_enabled = false
	}
	else value == '-v' or value == '-verbose' {
		Settings.is_verbose_output_enabled = true
	}
	else value == '-r' or value == '-rebuild' or value == '-force' {
		bundle.put(String(BUNDLE_REBUILD), true)
	}
	else value == '-O' or value == '-O1' {
		if Settings.is_debugging_enabled => Status('Optimization and debugging can not be enabled at the same time')

		Settings.is_optimization_enabled = true

		Settings.is_instruction_analysis_enabled = true
		Settings.is_mathematical_analysis_enabled = true
		Settings.is_repetion_analysis_enabled = true
		Settings.is_unwrapment_analysis_enabled = true
		Settings.is_function_inlining_enabled = false
	}
	else value == '-O2' {
		if Settings.is_debugging_enabled => Status('Optimization and debugging can not be enabled at the same time')

		Settings.is_optimization_enabled = true

		Settings.is_instruction_analysis_enabled = true
		Settings.is_mathematical_analysis_enabled = true
		Settings.is_repetion_analysis_enabled = true
		Settings.is_unwrapment_analysis_enabled = true
		Settings.is_function_inlining_enabled = true
	}
	else value == '-x64' {
		Settings.architecture = ARCHITECTURE_X64
	}
	else value == '-arm64' {
		Settings.architecture = ARCHITECTURE_ARM64
	}
	else value == '-version' {
		print('Vivid version ')
		println(COMPILER_VERSION)
		exit(0)
	}
	else value == '-s' {
		bundle.put(String(BUNDLE_SERVICE), true)
	}
	else {
		=> Status(String('Unknown option ') + value)
	}
	
	=> Status()
}

configure(bundle: Bundle) {
	arguments = io.get_command_line_arguments()
	arguments.take_first() # Remove the executable name

	files = List<String>()
	libraries = List<String>()

	loop (arguments.size > 0) {
		element = arguments.take_first()

		if is_option(element) {
			result = configure(bundle, arguments, files, libraries, element)
			if result.problematic => result
		}
		else io.exists(element) {
			# If the element represents a folder, source files inside it must be compiled
			if io.is_folder(element) {
				collect(files, element, false)
				continue
			}

			println(element)

			# Ensure the source file ends with the primary file extension
			if not element.ends_with(LANGUAGE_FILE_EXTENSION) => Status('Source files must end with the language extension')

			files.add(element)
			continue
		}

		=> Status('Invalid source file or folder')
	}

	# Ensure the bundle contains an output name
	if not bundle.contains_object(String(BUNDLE_OUTPUT_NAME)) {
		bundle.put(String(BUNDLE_OUTPUT_NAME), DEFAULT_OUTPUT_NAME)
	}

	bundle.put(String(BUNDLE_FILENAMES), files as link)
	bundle.put(String(BUNDLE_LIBRARIES), libraries as link)

	=> Status()
}