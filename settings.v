SYSTEM_FORMAT = 17 # FORMAT_UINT64
SYSTEM_BITS = 64
SYSTEM_BYTES = 8

Settings {
	static architecture: large
	static is_optimization_enabled: bool
	static is_instruction_analysis_enabled: bool
	static is_mathematical_analysis_enabled: bool
	static is_repetion_analysis_enabled: bool
	static is_unwrapment_analysis_enabled: bool
	static is_function_inlining_enabled: bool
	static is_debugging_enabled: bool
	static is_verbose_output_enabled: bool
	static included_folders: List<String>

	static initialize() {
		architecture = ARCHITECTURE_X64
		is_optimization_enabled = false
		is_instruction_analysis_enabled = false
		is_mathematical_analysis_enabled = false
		is_repetion_analysis_enabled = false
		is_unwrapment_analysis_enabled = false
		is_function_inlining_enabled = false
		is_debugging_enabled = false
		is_verbose_output_enabled = false
		included_folders = List<String>()
	}
}