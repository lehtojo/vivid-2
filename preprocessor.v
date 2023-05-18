namespace preprocessing

# Summary: Attempts to consume a token from the specified position that has the specified type
try_consume_next_token(code: StringBuilder, position: Position, type: u64): TextArea {
	# Get the next token
	code_view = String.from(code.buffer, code.length)
	if get_next_token(code_view, position) has not area return none as TextArea

	# If the text area is not of the specified type, return none
	if area.type != type return none as TextArea

	# Return the text area
	return area
}

pack MacroArgument {
	values: List<String>

	shared new(value: String): MacroArgument {
		return new([value])
	}

	shared new(values: List<String>): MacroArgument {
		return pack { values: values } as MacroArgument
	}

	string(): String {
		return String.join(", ", values)
	}
}

plain Macro {
	private usages: i64 = 0

	name: String
	parameters: List<String>
	lines: List<String>
	is_variadic: bool

	init(name: String, parameters: List<String>, lines: List<String>) {
		# Other code always assumes macros have a result line
		if lines.size == 0 lines.add(String.empty)

		this.name = name
		this.parameters = parameters
		this.lines = lines
		this.is_variadic = parameters.size > 0 and (is_variadic_parameter(parameters[0]) or is_variadic_parameter(parameters[parameters.size - 1]))
	}

	# Summary: Returns whether the specified parameter is variadic
	is_variadic_parameter(name: String): bool {
		return name.ends_with('...')
	}

	# Summary: Returns whether this macro conflicts with the specified macro
	conflicts(other: Macro): bool {
		# 1. We assume two variadic macros conflict even though there can be cases were they do not
		if is_variadic and other.is_variadic return true

		# 2. Handle non-variadic and variadic macro conflicts
		if is_variadic return other.parameters.size >= parameters.size - 1
		if other.is_variadic return parameters.size >= other.parameters.size - 1

		# 3. Two non-variadic macros conflict if they have the same number of parameters 
		return parameters.size == other.parameters.size
	}

	# Summary: Returns whether this macro can be used with the specified arguments
	passes(arguments: List<String>): bool {
		if arguments.size == parameters.size return true

		# Allow there to be zero arguments for the variadic parameter
		return arguments.size >= parameters.size - 1 and is_variadic
	}

	# Summary: Creates arguments from the specified raw arguments
	create_arguments(arguments: List<String>): List<MacroArgument> {
		if arguments.size == parameters.size return arguments.map<MacroArgument>((i: String) -> MacroArgument.new(i))

		require(is_variadic, 'Expected macro to be variadic')

		# Compute how many non-variadic parameters there are
		non_variadic_parameter_count = parameters.size - 1

		# Compute how many variadic arguments are passed
		variadic_argument_count = arguments.size - non_variadic_parameter_count

		# If the variadic parameter is at the beginning, do the following:
		if is_variadic_parameter(parameters[0]) {
			variadic_argument = MacroArgument.new(arguments.slice(0, variadic_argument_count))
			non_variadic_arguments = arguments.slice(variadic_argument_count).map<MacroArgument>((i: String) -> MacroArgument.new(i))

			result_arguments = List<MacroArgument>()
			result_arguments.add(variadic_argument)
			result_arguments.add_all(non_variadic_arguments)
			return result_arguments
		}

		# The variadic parameter must be at the end, so do the following:
		variadic_argument = MacroArgument.new(arguments.slice(arguments.size - variadic_argument_count))
		non_variadic_arguments = arguments.slice(0, arguments.size - variadic_argument_count).map<MacroArgument>((i: String) -> MacroArgument.new(i))
		return non_variadic_arguments + variadic_argument
	}

	# Summary: Returns whether the specified index is the end of the preceding variable name
	private has_variable_name_ended(line: StringBuilder, end: u64): bool {
		# Situation: <variable> <?>
		# We have a variable name and something <?> after it and we want to know if <?> is part of the variable name.
		# If there is nothing after the variable name, the variable name has ended.
		# Situations where variable name has not ended:
		# - <?> is a letter or digit
		# - <?> is "..."

		# If there is nothing after the variable name, the variable name has ended
		if end >= line.length return true

		# If the next character is a letter or digit, the variable name has not ended
		if is_text(line[end]) or is_digit(line[end]) return false

		# If there is "..." after the variable name, the variable name has not ended
		if end + 2 < line.length and line[end] == `.` and line[end + 1] == `.` and line[end + 2] == `.` return false

		# The variable name has ended
		return true
	}

	# Summary: Replaces all parameter occurrences in the specified lines with the corresponding arguments
	private replace_parameters_with_arguments(lines: List<String>, arguments: List<MacroArgument>): _ {
		# Replace all parameters with corresponding arguments
		loop (line_index = 0, line_index < lines.size, line_index++) {
			line = StringBuilder(lines[line_index])

			loop (parameter_index = 0, parameter_index < arguments.size, parameter_index++) {
				# Get the parameter
				parameter = parameters[parameter_index]

				# Get the corresponding argument
				argument = arguments[parameter_index]

				# Replace all occurrences of the parameter with the argument
				search_offset = 0

				loop {
					# Find the next occurrence of the parameter in the current line
					parameter_start = line.index_of(parameter, search_offset)

					# If the parameter was not found, there are no more usages of it in the line
					if parameter_start < 0 stop

					# We also need to verify the parameter name does not continue after the occurrence
					# to prevent situations such as replacing $variable part in $variables.
					parameter_end = parameter_start + parameter.length

					# If the parameter name continues after the occurrence, continue to the next line
					if not has_variable_name_ended(line, parameter_end) {
						# Search for the next occurrence of the parameter after the current one
						search_offset = parameter_end
						continue
					}

					# Replace the parameter with the argument
					argument_string = argument.string()
					line.replace(parameter_start, parameter_end, argument_string)

					# Search for the next occurrence of the parameter after the current one
					search_offset = parameter_start + argument_string.length
				}
			}

			# Save the modified line
			lines[line_index] = line.string()
		}
	}

	# Summary: Finds macro loops and unfolds them
	private unfold_macro_loops(lines: List<String>, usage: i64): _ {

	}

	# Summary: Generates new variable names for local macro variables
	private replace_macro_variables(lines: List<String>, usage: i64): _ {
		loop (i = 0, i < lines.size, i++) {
			line = lines[i]

			# Attempt to find the first macro variable in the line
			# Note: The code is structured this way, because we want to avoid 
			# creating the objects below on lines that do not have macro variables
			macro_variable_start = line.index_of(`$`)
			if macro_variable_start < 0 continue

			# Create a builder for the line so that we can modify it
			builder = StringBuilder(line)
			position = Position(0, 0, 0, 0)

			# Replace all macro variables with the following naming pattern: __$macro-name_$variable-name_$usage
			loop (macro_variable_start >= 0) {
				# Attempt to consume an identifier token after the dollar sign
				position.character = macro_variable_start + 1
				position.local = macro_variable_start + 1
				position.absolute = macro_variable_start + 1
				area = try_consume_next_token(builder, position, TEXT_TYPE_TEXT)

				if area !== none {
					# Get the name of the macro variable
					macro_variable_end = area.end.absolute
					macro_variable_name = builder.slice(macro_variable_start + 1, macro_variable_end)

					# Replace the macro variable with the new name
					macro_variable_name = "__" + name + `_` + macro_variable_name + `_` + to_string(usage)
					builder.replace(macro_variable_start, macro_variable_end, macro_variable_name)
				}

				# Attempt to find the next macro variable
				macro_variable_start = builder.index_of(`$`, macro_variable_start + 1)
			}

			# Save the modified line
			lines[i] = builder.string()
		}
	}

	# Summary: Applies the specified arguments into this macro and returns the produced lines
	private use(arguments: List<MacroArgument>): List<String> {
		# Save the current usage number and increment
		usage = usages++

		# Clone the lines from this macro
		lines: List<String> = List<String>(this.lines)

		replace_parameters_with_arguments(lines, arguments)
		unfold_macro_loops(lines, usage)
		replace_macro_variables(lines, usage)
		return lines
	}

	# Summary: Applies this macro into the specified usage
	use(code: StringBuilder, line_start_index: u64, usage_start: u64, usage_end: u64, arguments: List<String>): _ {		
		# Use the macro with the arguments and get the lines
		lines: List<String> = use(create_arguments(arguments))

		# Remove the result line (last line) from the lines
		result = lines[lines.size - 1]
		lines.remove_at(lines.size - 1)

		# Replace the macro usage in the code with the result
		code.replace(usage_start, usage_end, result)

		# Insert the macro lines before the result line into the code
		if lines.size > 0 {
			code.insert(line_start_index, String.join(`\n`, lines) + `\n`)
		}
	}
}

plain Macros {
	private macros: List<Macro> = List<Macro>()

	# Summary: Attempts to add the specified macro. Returns whether it succeeded.
	try_add(macro: Macro): bool {
		# Ensure the specified macro does not conflict with any other added macro
		loop other in macros {
			if macro.conflicts(other) return false
		}

		# Add the specified macro as it does not conflict
		macros.add(macro)
		return true
	}

	# Summary: Attempts to find a macro that is suitable for the specified arguments. If none is found, none is returned.
	find(arguments: List<String>): Macro {
		loop macro in macros {
			if macro.passes(arguments) return macro
		}

		return none as Macro
	}
}

plain Preprocessor {
	errors: List<Status> = List<Status>()

	private debug_print(file, code) {
		if file.fullname.ends_with('simple-macros.v') {
			console.write_line(code.string())
		}
	}

	# Summary: Adds the specified error
	private report(position: Position, message: String): _ {
		errors.add(Status(position, message))
	}

	# Summary: Returns whether the specified parameters are valid
	private are_valid_parameters(parameters: List<String>): bool {
		# Count the number of variadic parameters, they maximum number of variadic parameters is 1
		variadic_parameter_count = 0

		loop parameter in parameters {
			# Handle variadic parameters separately
			if parameter.ends_with('...') {
				variadic_parameter_count++

				# There can only be one variadic parameter
				if variadic_parameter_count > 1 return false

				# Cut off the "..." from the end
				parameter = parameter.slice(0, parameter.length - 3)
			}

			# Parameter names may only contain: letters, digits and underscores
			loop (i = 0, i < parameter.length, i++) {
				character = parameter[i]
				if is_text(character) or is_digit(character) or character == `$` continue
				return false
			}
		}

		return true
	}

	# Summary:
	# Loads macros from the specified code and inserts them to the specified map by name
	private load_macros(code: StringBuilder, lines: List<String>, macros: Map<String, Macros>): _ {
		# Macros have the following syntax:
		# $$name!($parameter-1, $parameter-2, ...) [\n] {...}
		i = 0

		loop (i < code.length) {
			# Find the next dollar mark
			macro_start_index = code.index_of(`$`, i)

			# If there is no dollar mark, there can not be any macros left to process
			if macro_start_index < 0 stop

			# Set the position to be after the dollar mark, because whether there is a macro or not,
			# we will start to search for the next macro at least from there.
			i = macro_start_index + 1

			# Start consuming tokens from the start of the line.
			# We expect the tokens to be: $identifier ! (...) [\n] {...}
			position = Position(0, macro_start_index + 1, macro_start_index + 1, macro_start_index + 1)

			# Attempt to consume the name
			name_area = try_consume_next_token(code, position, TEXT_TYPE_TEXT)
			if name_area === none continue

			# Attempt to consume the exclamation mark
			exclamation_area = try_consume_next_token(code, name_area.end, TEXT_TYPE_OPERATOR)
			if exclamation_area === none or not (exclamation_area.text == '!') continue

			# Attempt to consume the parameters
			parameters_area = try_consume_next_token(code, exclamation_area.end, TEXT_TYPE_PARENTHESIS)
			if parameters_area === none or parameters_area.text[0] != `(` continue

			# Attempt to consume the body
			body_area = try_consume_next_token(code, parameters_area.end, TEXT_TYPE_PARENTHESIS)
			if body_area === none or body_area.text[0] != `{` continue

			# Get the name of the macro
			name = name_area.text

			# Get the parameters of the macro:
			# Parameters: ($parameter-1, $parameter-2, ...)
			parameters = parameters_area.text
				.slice(1, parameters_area.text.length - 1)
				.split(`,`)
				.map<String>((i: String) -> i.trim(` `))
				.filter((i: String) -> i.length > 0)
				.map<String>((i: String) -> "$" + i)

			# Do not add the macro and report if there are invalid parameters
			if not are_valid_parameters(parameters) continue

			# Convert the body into lines
			body = body_area.text.slice(1, body_area.text.length - 1).split(`\n`)

			# Trim empty lines from the body
			loop (body.size > 0 and body[0].length == 0) { body.remove_at(0) }
			loop (body.size > 0 and body[body.size - 1].length == 0) { body.remove_at(body.size - 1) }

			# Create the macro
			macro = Macro(name, parameters, body)

			# Ensure there are macro overloads for the macro name
			if not macros.contains_key(name) { macros[name] = Macros() }

			# Attempt to add the macro
			if not macros[name].try_add(macro) {
				report(name_area.start, "Macro conflicts with other overloads")
				continue
			}
		
			# Skip to the end of the macro
			i = body_area.end.absolute

			# Replace the entire macro with spaces, so that it will not get parsed
			code.fill(macro_start_index, i, ` `)
		}
	}

	# Loads all macros from the specified codes
	private load_macros(): Map<String, Macros> {
		macros = Map<String, Macros>()

		loop file in settings.source_files {
			code = StringBuilder(file.content)
			load_macros(code, file.content.split(`\n`), macros)
			file.content = code.string()
		}

		return macros
	}

	# Summary: Extracts the arguments of the macro usage from the code
	private get_macro_arguments(code: StringBuilder, parenthesis_start: u64, parenthesis_end: u64): List<String> {
		arguments = List<String>()

		content = code.slice(parenthesis_start + 1, parenthesis_end - 1)
		argument_start_index = 0
		position = Position(0, 0, 0, 0)

		loop {
			# Stop if there are no tokens left
			if get_next_token(content, position) has not area or area === none stop

			# Find the next token after the current token
			position = area.end

			# Wait until we find a comma
			if not (area.text == ',') continue

			# Extract the argument and add it to the list
			argument_end_index = position.absolute - 1
			argument = content.slice(argument_start_index, argument_end_index).trim(` `)
			arguments.add(argument)

			# The next argument will start after the comma
			argument_start_index = position.absolute
		}

		# Add the last argument
		argument_end_index = position.absolute
		argument = content.slice(argument_start_index, argument_end_index).trim(` `)
		if argument.length > 0 arguments.add(argument)

		return arguments
	}

	# Summary: Applies macros in the specified code
	private preprocess(code: StringBuilder, macros: Map<String, Macros>): _ {
		# Find all macro usages and replace them with the macro body
		search_offset = 0

		loop {
			# Find the next potential macro usage by searching '!('
			exclamation_index = code.index_of('!(', search_offset)

			# If there is no exclamation mark, there can not be any macros usages left to process
			if exclamation_index < 0 stop

			# Load the name of the macro by iterating backwards until we find non-identifier character
			usage_name_start = exclamation_index - 1

			loop {
				# Iterate while we have not reached the start of the code
				if usage_name_start < 0 stop

				# Iterate while we consume identifier characters
				character = code[usage_name_start]
				if not (is_text(character) or is_digit(character)) stop

				# Move to the "next" character
				usage_name_start--
			}

			# Extract the name of the macro
			usage_name = code.slice(usage_name_start + 1, exclamation_index)

			# Find the closing parenthesis for the macro arguments
			code_view = String.from(code.buffer, code.length)
			parenthesis_start = exclamation_index + 1
			parenthesis_end_position = skip_parenthesis(code_view, Position(0, parenthesis_start, parenthesis_start, parenthesis_start))

			# If we could not find the closing parenthesis, then we have not found a macro usage
			if parenthesis_end_position === none {
				# Next search after the exclamation index
				search_offset = parenthesis_start
				continue
			}

			parenthesis_end = parenthesis_end_position.absolute

			# It seems we have found a macro usage, try to find the macro
			if not macros.contains_key(usage_name) {
				usage = code.slice(usage_name_start + 1, parenthesis_end)
				report(none as Position, "Can not find the macro: " + usage)

				# Next search after the exclamation index
				search_offset = parenthesis_start
				continue
			}

			# Find the index of the first character on the current line as we might need it to insert the macro body
			line_start_index = code.last_index_of(`\n`, exclamation_index) + 1

			# Next search will start after the previous line ending as the macro might add new macro usages
			search_offset = line_start_index

			# Extract the arguments of the macro usage
			usage_arguments = get_macro_arguments(code, parenthesis_start, parenthesis_end)

			# Attempt to find a suitable macro overload with the extracted arguments
			macro = macros[usage_name].find(usage_arguments)

			if macro === none {
				usage = code.slice(usage_name_start + 1, parenthesis_end)
				report(none as Position, "Can not find suitable macro overload: " + usage)

				# Next search after the exclamation index
				search_offset = parenthesis_start
				continue
			}

			# Apply the macro to the usage
			macro.use(code, line_start_index as u64, usage_name_start as u64, parenthesis_end as u64, usage_arguments)
		}
	}

	# Summary: Preprocesses all loaded source files
	preprocess(): bool {
		# Todo:
		# Problems:
		# - We can not report macro expansion errors, because the lines expand and stuff
		# - Normals errors get shifted, because macros expand
		# Solution:
		# - 1. Load and replace macros with white spaces
		# - 2. Tokenize the source code so that original positions get assigned
		# - 3. Now expand macros with the loaded macros and insert the expanded macro as tokens 

		# Load all macros from loaded source files
		macros = load_macros()

		# Apply macros in all loaded source files
		loop file in settings.source_files {
			code = StringBuilder(file.content)
			preprocess(code, macros)
			file.content = code.string()
		}

		return errors.size == 0
	}
}