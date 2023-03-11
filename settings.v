SYSTEM_FORMAT = FORMAT_UINT64
SYSTEM_SIGNED = FORMAT_INT64
SYSTEM_BITS = 64
SYSTEM_BYTES = 8

namespace settings

architecture: large
is_optimization_enabled: bool
is_instruction_analysis_enabled: bool
is_mathematical_analysis_enabled: bool
is_repetition_analysis_enabled: bool
is_statement_analysis_enabled: bool
is_function_inlining_enabled: bool
is_garbage_collector_enabled: bool
is_debugging_enabled: bool
is_verbose_output_enabled: bool
is_target_windows: bool
use_indirect_access_tables: bool
is_assembly_output_enabled: bool
is_system_mode_enabled: bool
parse: Parse
object_files: Map<SourceFile, BinaryObjectFile> # Stores all imported objects (compiler and user)
user_imported_object_files: List<String> # Stores the object files added by the user
source_files: List<SourceFile> # Stores compiler generated information about the source files specified by the user
libraries: List<String> # Stores the libraries needed to link the program
output_name: String # Stores the name of the output file
output_type: normal # Stores the output type of the program (executable, library, etc.)
link_objects: bool # Whether to link the object files produced by the compiler (relevant only in textual assembly mode)
time: bool # Whether to print the time taken to execute various parts of the compiler.
rebuild: bool # Whether to rebuild all the specified source files
service: bool # Whether to start a compiler service for code completion
filenames: List<String> # Stores the user-defined source files to load
textual_assembly: bool # Stores whether textual assembly mode is enabled
base_address: u64 # Stores the base address used in binary mode

allocation_function: FunctionImplementation
deallocation_function: FunctionImplementation
inheritance_function: FunctionImplementation
initialization_function: FunctionImplementation
included_folders: List<String>

is_x64 => settings.architecture == ARCHITECTURE_X64

initialize(): _ {
	architecture = ARCHITECTURE_X64
	is_optimization_enabled = false
	is_instruction_analysis_enabled = false
	is_mathematical_analysis_enabled = false
	is_repetition_analysis_enabled = false
	is_statement_analysis_enabled = false
	is_function_inlining_enabled = false
	is_garbage_collector_enabled = false
	is_debugging_enabled = false
	is_verbose_output_enabled = false
	is_target_windows = true
	use_indirect_access_tables = false
	is_assembly_output_enabled = false
	is_system_mode_enabled = false
	parse = none as Parse
	object_files = Map<SourceFile, BinaryObjectFile>()
	user_imported_object_files = List<String>()
	source_files = List<SourceFile>()
	libraries = List<String>()
	output_name = "v"
	output_type = BINARY_TYPE_EXECUTABLE
	link_objects = false
	time = false
	rebuild = false
	service = false
	filenames = List<String>()
	textual_assembly = false
	base_address = 0x1000
	included_folders = List<String>()
}