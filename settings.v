SYSTEM_FORMAT = 17 # FORMAT_UINT64
SYSTEM_BITS = 64
SYSTEM_BYTES = 8

namespace settings

architecture: large
is_optimization_enabled: bool
is_instruction_analysis_enabled: bool
is_mathematical_analysis_enabled: bool
is_repetion_analysis_enabled: bool
is_unwrapment_analysis_enabled: bool
is_function_inlining_enabled: bool
is_garbage_collector_enabled: bool
is_debugging_enabled: bool
is_verbose_output_enabled: bool
is_target_windows: bool
is_position_independent: bool
allocation_function: FunctionImplementation
included_folders: List<String>

is_x64 => settings.architecture == ARCHITECTURE_X64

initialize() {
	architecture = ARCHITECTURE_X64
	is_optimization_enabled = false
	is_instruction_analysis_enabled = false
	is_mathematical_analysis_enabled = false
	is_repetion_analysis_enabled = false
	is_unwrapment_analysis_enabled = false
	is_function_inlining_enabled = false
	is_garbage_collector_enabled = false
	is_debugging_enabled = false
	is_verbose_output_enabled = false
	is_target_windows = true
	included_folders = List<String>()
}