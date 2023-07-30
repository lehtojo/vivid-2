namespace preprocessing

# Summary: Attempts to consume a token from the specified position that has the specified type
try_consume_next_token(code: StringBuilder, position: Position, type: u64): TextArea {
	# Get the next token
	if get_next_token(code.string(), position) has not area return none as TextArea

	# If the text area is not of the specified type, return none
	if area.type != type return none as TextArea

	# Return the text area
	return area
}

# Summary: Sets the positions of all tokens to the specified position
set_token_positions(tokens: List<Token>, position: Position): _ {
	loop token in tokens {
		token.position = position

		# Set the positions of the tokens inside the parenthesis
		if token.type == TOKEN_TYPE_PARENTHESIS set_token_positions(token.(ParenthesisToken).tokens, position)
	}
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
			position = Position()

			# Replace all macro variables with the following naming pattern: __<macro-name>_<variable-name>_<usage>
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

	# Summary: Applies the arguments into this macro
	use(arguments: List<String>): List<String> {
		return use(create_arguments(arguments))
	}

	# Summary: Applies this macro into the specified usage
	apply(code: StringBuilder, line_start_index: u64, usage_start: u64, usage_end: u64, arguments: List<String>): _ {		
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

pack MacroUsage {
	start: Position
	end: Position
	macro: Macro
	arguments: List<String>

	shared new(start: Position, end: Position, macro: Macro, arguments: List<String>): MacroUsage {
		return pack { start: start, end: end, macro: macro, arguments: arguments } as MacroUsage
	}
}

pack MacroExpansion {
	start: Position
	tokens: List<Token>

	shared new(start: Position, tokens: List<Token>): MacroExpansion {
		return pack { start: start, tokens: tokens } as MacroExpansion
	}
}

pack ExpansionStackFrame {
	position: Position
	preview: String

	shared new(position: Position, preview: String): ExpansionStackFrame {
		return pack { position: position, preview: preview } as ExpansionStackFrame
	}
}

pack ExpansionStackTrace {
	frames: List<ExpansionStackFrame>

	shared new(): ExpansionStackTrace {
		return pack { frames: List<ExpansionStackFrame>() } as ExpansionStackTrace
	}

	add(code: StringBuilder, usage: MacroUsage): _ {
		preview = code.slice(usage.start.absolute, usage.end.absolute)
		frame = ExpansionStackFrame.new(usage.start, preview)
		frames.add(frame)
	}

	add(code: StringBuilder, position: Position, usage_start: u64, usage_end: u64): _ {
		preview = code.slice(usage_start, usage_end)
		frame = ExpansionStackFrame.new(position, preview)
		frames.add(frame)
	}

	pop(): _ {
		require(frames.size > 0, 'Macro expansion stack trace did not have frames')
		frames.remove_at(frames.size - 1)
	}

	position(): Position {
		if frames.size == 0 return none as Position
		return frames[0].position
	}

	string(): String {
		if frames.size == 0 return String.empty
		return String.join(" -> ", frames.map<String>((i: ExpansionStackFrame) -> i.preview))
	}
}

plain Preprocessor {
	errors: List<Status> = List<Status>()

	private macros: Map<String, Macros> = Map<String, Macros>()
	private expansions: Map<SourceFile, List<MacroExpansion>> = Map<SourceFile, List<MacroExpansion>>()

	private debug_print(file, code) {
		if file.fullname.ends_with('simple-macros.v') {
			console.write_line(code.string())
		}
	}

	# Summary: Adds the specified error
	private report(trace: ExpansionStackTrace, message: String): _ {
		errors.add(Status(trace.position, "Expansion: " + trace.string() + ': ' + message))
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

	# Summary: Removes the specified range with spaces while preserving line endings
	private remove_using_spaces(code: StringBuilder, start: u64, end: u64): _ {
		# Replace all characters in the specified range with spaces
		loop (i = start, i < end, i++) {
			character = code[i]
			if character == `\n` continue
			code[i] = ` `
		}
	} 

	# Summary:
	# Loads macros from the specified code and inserts them to the specified map by name
	private load_macros(file: SourceFile, code: StringBuilder, lines: List<String>): _ {
		# Macros have the following syntax:
		# $<name>!(<parameter-1>, <parameter-2>, ...) [\n] {...}
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
			# We expect the tokens to be: <identifier> ! (...) [\n] {...}
			position = Position(file, 0, macro_start_index + 1, macro_start_index + 1, macro_start_index + 1)

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
			# Parameters: (<parameter-1>, <parameter-2>, ...)
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
			remove_using_spaces(code, macro_start_index, i)
		}
	}

	# Loads all macros from the specified codes
	private load_macros(files: List<SourceFile>): _ {
		loop file in files {
			code = StringBuilder(file.content)
			load_macros(file, code, file.content.split(`\n`))
			file.content = code.string()
		}
	}

	# Summary: Extracts the arguments of the macro usage from the code
	private get_macro_arguments(code: StringBuilder, parenthesis_start: u64, parenthesis_end: u64): List<String> {
		arguments = List<String>()

		content = code.slice(parenthesis_start + 1, parenthesis_end - 1)
		argument_start_index = 0
		position = Position()

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

	# Summary: Find the next macro usage position
	private find_next_macro_usage(code: StringBuilder, start: Position, trace: ExpansionStackTrace): MacroUsage {
		position = start.clone()

		# Note: Macro usage will require at least 3 characters after the name: !()
		loop (position.absolute < code.length - 3) {
			# We are looking for pattern '!(' while tracking the line number etc.
			absolute = position.absolute
			character = code[absolute]

			if character != `!` {
				if character == `\n` { position.next_line() }
				else { position.next_character() }
				continue
			}

			# Verify there is `(` after the `!`
			if code[absolute + 1] != `(` {
				position.next_character()
				continue
			}

			# Load the name of the macro by iterating backwards until we find non-identifier character
			name_start = absolute

			loop {
				# Iterate while we have not reached the start of the code
				if name_start - 1 < 0 stop

				# Iterate while we consume identifier characters
				character = code[name_start - 1]
				if not (is_text(character) or is_digit(character)) stop

				# Move to the "next" character
				name_start--
			}

			# Ensure the name is not empty
			if name_start == absolute {
				position.next_character()
				continue
			}

			# Extract the name
			name = code.slice(name_start, absolute)

			# Find the closing parenthesis to extract the arguments
			name_position = position.translate(name_start - absolute)
			parenthesis_start = position.translate(1)
			parenthesis_end = skip_parenthesis(code.string(), parenthesis_start)

			# Move over the `!` so that next search will not find it
			position.next_character()

			# If we could not find the closing parenthesis, then we have not found a macro usage
			if parenthesis_end === none continue

			# It seems we have found a macro usage, try to find the macro
			if not macros.contains_key(name) {
				trace.add(code, name_position, name_start, parenthesis_end.absolute)
				report(trace, "Can not find the macro")
				trace.pop()

				# Remove the usage so that it will not cause error again
				remove_using_spaces(code, name_start, parenthesis_end.absolute)
				continue
			}

			# Extract the arguments of the macro usage
			arguments = get_macro_arguments(code, parenthesis_start.absolute, parenthesis_end.absolute)

			# Attempt to find a suitable macro overload with the extracted arguments
			macro = macros[name].find(arguments)

			if macro === none {
				trace.add(code, name_position, name_start, parenthesis_end.absolute)
				report(trace, "Can not find suitable macro overload")
				trace.pop()

				# Remove the usage so that it will not cause error again
				remove_using_spaces(code, name_start, parenthesis_end.absolute)
				continue
			}

			# Return the macro usage
			return MacroUsage.new(name_position, parenthesis_end, macro, arguments)
		}

		return none as MacroUsage
	}

	# Summary: Places the specified expansion into the code 
	private apply_expansion(code: StringBuilder, expansion: StringBuilder, line_start_index: u32, usage_start: u64, usage_end: u64, arguments: List<String>): _ {
		# Remove the result line (last line) from the expansion
		result_start = expansion.last_index_of(`\n`) + 1
		result = expansion.slice(result_start, expansion.length)

		# Replace the macro usage in the code with the result
		code.replace(usage_start, usage_end, result)

		# Insert the macro lines before the result line into the code
		if result_start > 0 {
			code.insert(line_start_index, expansion.slice(0, result_start))
		}
	}

	# Summary: Expands all macro usages recursively in the specified code
	private expand_all(content: String, trace: ExpansionStackTrace): StringBuilder {
		code = StringBuilder(content)
		start = Position()

		loop {
			# Attempt to find the next macro usage
			usage = find_next_macro_usage(code, start, trace)

			if usage.start === none {
				trace.pop()
				return code
			}

			# Use the macro with the arguments and expand all macros inside it
			lines = usage.macro.use(usage.arguments)
			trace.add(code, usage)
			expansion = expand_all(String.join(`\n`, lines), trace)

			# Find the index of the first character on the current line
			line_start_index = code.last_index_of(`\n`, usage.start.absolute) + 1

			# Use the macro with the arguments
			apply_expansion(code, expansion, line_start_index, usage.start.absolute, usage.end.absolute, usage.arguments)
		}
	}

	# Summary: Applies macros in the specified code
	private preprocess(code: StringBuilder, position: Position, macros: Map<String, Macros>): List<MacroExpansion> {
		expansions: List<MacroExpansion> = List<MacroExpansion>()
		trace = ExpansionStackTrace.new()

		loop {
			# Attempt to find the next macro usage
			usage = find_next_macro_usage(code, position, trace)
			if usage.start === none return expansions

			# Find the next macro usage after the processed usage
			position = usage.end

			# Use the macro with the arguments and expand all macros inside it
			lines = usage.macro.use(usage.arguments)
			trace.add(code, usage)
			expansion = expand_all(String.join(`\n`, lines), trace).string()

			# Tokenize the produced lines
			result = get_tokens(expansion, usage.start, true)

			if result has not tokens {
				trace.add(code, usage)
				report(trace, result.get_error())
				trace.pop()
				continue
			}

			# Set the positions of all expanded tokens to point to the usage, 
			# so that the errors related to the expansion always point to the usage
			set_token_positions(tokens, usage.start)

			# Create an expansion of the usage
			expansions.add(MacroExpansion.new(usage.start, tokens))
		}
	}

	# Summary: Preprocesses all loaded source files
	preprocess(files: List<SourceFile>): bool {
		# Load all macros from the source files
		load_macros(files)

		# Apply macros in all the source files
		loop file in files {
			code = StringBuilder(file.content)
			expansions.add(file, preprocess(code, Position(file, 0, 0), macros))
			file.content = code.string()
		}

		return errors.size == 0
	}

	# Summary: Extracts the tokens of the last line into a list
	private extract_result_tokens(tokens: List<Token>): List<Token> {
		# Find the last line ending token
		result_start = tokens.find_last_index((i: Token) -> i.type == TOKEN_TYPE_END) + 1
		result_tokens = tokens.slice(result_start)

		# Remove the result line tokens
		tokens.remove_all(result_start, tokens.size)

		return result_tokens
	}

	# Summary: Applies macro expansions into the specified tokens
	private expand(file: SourceFile, tokens: List<Token>, expansions: List<MacroExpansion>): _ {
		line_start_index = 0

		loop (i = 0, i < tokens.size and expansions.size > 0, ) {
			token = tokens[i]

			if token.type == TOKEN_TYPE_END {
				line_start_index = i + 1
				i++
				continue
			}

			# Load the expansion we are looking for
			expansion = expansions[0]

			# Insert the expansion when we have found the token
			if token.position.absolute == expansion.start.absolute {
				# There must be at least 3 tokens to remove: <name> ! (...)
				require(tokens.size - i >= 3, 'Invalid macro expansion')

				# Remove the expansion from the list
				expansions.remove_at(0)

				expansion_tokens = common.clone(expansion.tokens)
				result_tokens = extract_result_tokens(expansion_tokens)

				# Replace the "<name> ! (...)" with the result tokens
				tokens.remove_all(i, i + 3) # Remove: <name> ! (...)
				tokens.insert_all(i, result_tokens)

				# Add the rest of the tokens before the current line
				tokens.insert(line_start_index, Token(TOKEN_TYPE_END))
				tokens.insert_all(line_start_index, expansion_tokens)

				# Go past the processed area
				i += result_tokens.size + expansion_tokens.size + 1
				continue
			}

			# If we have gone past the expansion, we have a fatal error, because the expansion should exist
			if token.position.absolute > expansion.start.absolute {
				abort(token.position, "Failed to find macro expansion at offset " + to_string(expansion.start.absolute as large))
			}

			# If the current token contains tokens, examine them only if the expansion can be among them
			if token.type == TOKEN_TYPE_PARENTHESIS {
				# Do not examine the tokens, because all of the tokens are before the expansion
				if token.(ParenthesisToken).end.absolute <= expansion.start.absolute {
					i++
					continue
				}

				# Examine the tokens
				expand(file, token.(ParenthesisToken).tokens, expansions)
			}

			# Move to the next token
			i++
		}
	}

	# Summary: Expands macros into the specified files
	expand(files: List<SourceFile>): bool {
		loop file in files {
			# If there are no expansions for the current file, skip the current file
			if not expansions.contains_key(file) continue

			# Expand macros in the current file
			expand(file, file.tokens, expansions[file])
			require(expansions[file].size == 0, 'All macro expansions were not expanded')
		}

		return errors.size == 0
	}
}