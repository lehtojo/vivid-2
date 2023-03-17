ParserState {
	all: List<Token>
	tokens: List<Token>
	pattern: parser.Pattern
	start: normal
	end: normal
	error: Status

	save(): ParserState {
		result = ParserState()
		result.all = List<Token>(all)
		result.tokens = List<Token>(tokens)
		result.start = start
		result.end = end
		return result
	}

	restore(from: ParserState): _ {
		all.clear()
		all.add_all(from.all)
		tokens.clear()
		tokens.add_all(from.tokens)
		start = from.start
		end = from.end
	}

	consume(): _ {
		tokens.add(all[end])
		end++
	}

	# Summary: Consumes the next token, if its type is contained in the specified types. This function returns true, if the next token is consumed, otherwise false.
	consume(types: large): bool {
		if end >= all.size return false
		next = all[end]
		if not has_flag(types, next.type) return false
		tokens.add(next)
		end++
		return true
	}

	# Summary: Consumes the next token if it exists and it represents the specified operator
	consume_operator(operator: Operator): bool {
		if end >= all.size return false
		next = all[end]
		if not next.match(operator) return false
		tokens.add(next)
		end++
		return true
	}

	# Summary: Consumes the next token if it exists and it represents the specified parenthesis
	consume_parenthesis(type: char): bool {
		if end >= all.size return false
		next = all[end]
		if not next.match(type) return false
		tokens.add(next)
		end++
		return true
	}

	# Summary: Consumes the next token, if its type is contained in the specified types. This function returns true, if the next token is consumed, otherwise an empty token is consumed and false is returned.
	consume_optional(types: large): bool {
		if end >= all.size {
			tokens.add(Token(TOKEN_TYPE_NONE))
			return false
		}
		next = all[end]
		if not has_flag(types, next.type) {
			tokens.add(Token(TOKEN_TYPE_NONE))
			return false
		}
		tokens.add(next)
		end++
		return true
	}

	peek(): Token {
		if all.size > end return all[end]
		return none as Token
	}
}

Parse {
	context: Context
	root: Node

	init(context: Context, root: Node) {
		this.context = context
		this.root = root
	}
}

namespace parser

# NOTE: Patterns all sorted so that the longest pattern is first, so if it passes, it takes priority over all the other patterns
patterns: List<List<Pattern>>

constant MIN_PRIORITY = 0
constant MAX_FUNCTION_BODY_PRIORITY = 19
constant MAX_PRIORITY = 23
constant PRIORITY_ALL = -1

constant STANDARD_RANGE_TYPE = 'Range'
constant STANDARD_LIST_TYPE = 'List'
constant STANDARD_LIST_ADDER = 'add'
constant STANDARD_STRING_TYPE = 'String'
constant STANDARD_ALLOCATOR_FUNCTION = 'allocate'

Pattern {
	path: List<small> = List<small>()
	priority: tiny
	id: large
	is_consumable: bool = true

	open passes(context: Context, state: ParserState, tokens: List<Token>, priority: tiny): bool
	open build(context: Context, state: ParserState, tokens: List<Token>): Node
}

Token DynamicToken {
	readable node: Node

	init(node: Node) {
		Token.init(TOKEN_TYPE_DYNAMIC)
		this.node = node
	}

	init(node: Node, position: Position) {
		Token.init(TOKEN_TYPE_DYNAMIC)
		this.node = node
		this.position = position
	}

	override clone() {
		return DynamicToken(node, position)
	}
}

# Summary: Returns the patterns which have the specified priority
get_patterns(priority: large): List<parser.Pattern> {
	return patterns[priority]
}

# Summary: Adds the specified pattern to the pattern list
add_pattern(pattern: Pattern): _ {
	if pattern.priority != -1 {
		get_patterns(pattern.priority).add(pattern)
		return
	}

	loop (i = 0, i < patterns.size, i++) {
		get_patterns(i).add(pattern)
	}
}

initialize(): _ {
	patterns = List<List<Pattern>>(MAX_PRIORITY + 1, false)
	loop (i = 0, i < MAX_PRIORITY + 1, i++) { patterns.add(List<Pattern>()) }

	add_pattern(CommandPattern())
	add_pattern(AssignPattern())
	add_pattern(FunctionPattern())
	add_pattern(OperatorPattern())
	add_pattern(TypePattern())
	add_pattern(ReturnPattern())
	add_pattern(IfPattern())
	add_pattern(InheritancePattern())
	add_pattern(LinkPattern())
	add_pattern(ListConstructionPattern())
	add_pattern(ListPattern())
	add_pattern(SingletonPattern())
	add_pattern(LoopPattern())
	add_pattern(ForeverLoopPattern())
	add_pattern(CastPattern())
	add_pattern(AccessorPattern())
	add_pattern(ImportPattern())
	add_pattern(ConstructorPattern())
	add_pattern(NotPattern())
	add_pattern(VariableDeclarationPattern())
	add_pattern(ElsePattern())
	add_pattern(UnarySignPattern())
	add_pattern(PostIncrementPattern())
	add_pattern(PreIncrementPattern())
	add_pattern(ExpressionVariablePattern())
	add_pattern(ModifierSectionPattern())
	add_pattern(SectionModificationPattern())
	add_pattern(NamespacePattern())
	add_pattern(IterationLoopPattern())
	add_pattern(TemplateFunctionPattern())
	add_pattern(TemplateFunctionCallPattern())
	add_pattern(TemplateTypePattern())
	add_pattern(VirtualFunctionPattern())
	add_pattern(SpecificModificationPattern())
	add_pattern(TypeInspectionPattern())
	add_pattern(CompilesPattern())
	add_pattern(IsPattern())
	add_pattern(OverrideFunctionPattern())
	add_pattern(PackConstructionPattern())
	add_pattern(LambdaPattern())
	add_pattern(RangePattern())
	add_pattern(HasPattern())
	add_pattern(ExtensionFunctionPattern())
	add_pattern(WhenPattern())
	add_pattern(UsingPattern())
}

# Summary: Returns whether the specified pattern can be built at the specified position
fits(pattern: Pattern, tokens: List<Token>, start: large, state: ParserState): bool {
	path = pattern.path
	result = List<Token>(path.size, false)

	i = 0
	j = 0

	loop (i < path.size, i++) {
		types = path[i]

		# Ensure there is a token available
		if start + j >= tokens.size {
			# If the token type is optional on the path, we can add a none token even though there are no tokens available
			if has_flag(types, TOKEN_TYPE_OPTIONAL) {
				result.add(Token(TOKEN_TYPE_NONE))
				continue
			}

			return false
		}

		token = tokens[start + j]
		type = token.type
		
		# Add the token if the allowed types contains its type
		if has_flag(types, type) {
			result.add(token)
			j++
		}
		else has_flag(types, TOKEN_TYPE_OPTIONAL) {
			result.add(Token(TOKEN_TYPE_NONE))
			# NOTE: Do not skip the current token, since it was not consumed
		}
		else {
			result.clear()
			return false
		}
	}

	state.tokens = result
	state.pattern = pattern
	state.start = start
	state.end = start + j

	return true
}

# Summary: Tries to find the next pattern from the specified tokens, which has the specified priority
next(context: Context, tokens: List<Token>, priority: normal, start: large, state: ParserState): bool {
	all = patterns[priority]

	loop (start < tokens.size, start++) {
		# NOTE: Patterns all sorted so that the longest pattern is first, so if it passes, it takes priority over all the other patterns
		loop (i = 0, i < all.size, i++) {
			pattern = all[i]
			if fits(pattern, tokens, start, state) and pattern.passes(context, state, state.tokens, priority) return true
		}
	}

	return false
}

# Summary: Tries to find the next pattern from the specified tokens, which has the specified priority
next_consumable(context: Context, tokens: List<Token>, priority: normal, start: large, state: ParserState, disabled: large): bool {
	all = patterns[priority]

	loop (start < tokens.size, start++) {
		# NOTE: Patterns all sorted so that the longest pattern is first, so if it passes, it takes priority over all the other patterns
		loop (i = 0, i < all.size, i++) {
			pattern = all[i]

			# Ensure the pattern is consumable and is not disabled
			if not pattern.is_consumable or (disabled & pattern.id) != 0 continue

			if fits(pattern, tokens, start, state) and pattern.passes(context, state, state.tokens, priority) return true
		}
	}

	return false
}

parse(root: Node, context: Context, tokens: List<Token>): Status {
	return parse(root, context, tokens, MIN_PRIORITY, MAX_PRIORITY)
}

# Summary: Forms function tokens from the specified tokens
create_function_tokens(tokens: List<Token>): _ {
	if tokens.size < 2 return

	loop (i = tokens.size - 2, i >= 0, i--) {
		name = tokens[i]
		if name.type != TOKEN_TYPE_IDENTIFIER continue
		parameters = tokens[i + 1]
		if not parameters.match(`(`) continue
		
		tokens[i] = FunctionToken(name as IdentifierToken, parameters as ParenthesisToken, name.position)
		tokens.remove_at(i + 1)
		
		i--
	}
}

is_line_related(tokens: List<Token>, i: large, j: large, k: large): bool {
	first_line_end_index = j - 1
	second_line_start_index = j + 1

	first_line_end = none as Token
	if first_line_end_index >= 0 { first_line_end = tokens[first_line_end_index] }

	second_line_start = none as Token
	if second_line_start_index < tokens.size { second_line_start = tokens[second_line_start_index] }

	if first_line_end != none and first_line_end.match(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_KEYWORD) return true
	if second_line_start != none and (second_line_start.match(TOKEN_TYPE_OPERATOR | TOKEN_TYPE_KEYWORD) or second_line_start.match(`{`)) return true

	loop (l = i, l < j, l++) {
		if tokens[l].type != TOKEN_TYPE_KEYWORD continue

		keyword = tokens[l].(KeywordToken).keyword
		if keyword.type == KEYWORD_TYPE_FLOW return true
	}

	return false
}

is_consuming_namespace(tokens: List<Token>, i: large): List<Token> {
	# Save the position of the namespace keyword
	start = i

	# Move to the next token
	i++

	# Find the start of the body by skipping the name
	loop (i < tokens.size and tokens[i].match(TOKEN_TYPE_IDENTIFIER | TOKEN_TYPE_OPERATOR), i++) {}

	# If we reached the end, stop and return none
	if i >= tokens.size return none as List<Token>

	# Optionally consume a line ending
	if tokens[i].type == TOKEN_TYPE_END {
		i++

		# If we reached the end, stop and return none
		if i >= tokens.size return none as List<Token>
	}

	# If this namespace is a consuming section, then the next token is not curly brackets
	if tokens[i].match(`{`) return none as List<Token>

	section = tokens.slice(start, tokens.size)
	tokens.remove_all(start, tokens.size)

	return section
}

# Summary:
# Returns the first section from the specified tokens that consumes all the lines below it.
# If such section can not be found, none is returned.
find_consuming_section(tokens: List<Token>): List<Token> {
	loop (i = 0, i < tokens.size, i++) {
		section = none as List<Token>
		next = tokens[i]

		if next.match(Keywords.NAMESPACE) {
			section = is_consuming_namespace(tokens, i)
		}

		if section != none return section
	}

	return none as List<Token>
}

split(tokens: List<Token>): List<List<Token>> {
	consuming_section = find_consuming_section(tokens)

	sections = List<List<Token>>()
	i = 0

	loop (i < tokens.size) {
		# Look for the first line ending after i
		j = i + 1
		loop (j < tokens.size and tokens[j].type != TOKEN_TYPE_END, j++) {}

		# If we reached the end here, we can just add the active section and stop
		if j == tokens.size {
			section = tokens.slice(i, j)
			sections.add(section)
			stop
		}

		# Start consuming lines after j
		k = j + 1

		loop (k < tokens.size, k++) {
			if tokens[k].type != TOKEN_TYPE_END continue

			# If the line is related to the active section, we can just consume it and continue
			if is_line_related(tokens, i, j, k) {
				j = k
				continue
			}

			# Since the line is not related to the active section, the active section ends at j
			section = tokens.slice(i, j)
			sections.add(section)

			i = j # Start over in a situation where the line i+1..j is the first 
			stop
		}

		if k != tokens.size continue

		if is_line_related(tokens, i, j, k) {
			section = tokens.slice(i, k)
			sections.add(section)
		}
		else {
			section = tokens.slice(i, j)
			sections.add(section)

			section = tokens.slice(j, k)
			sections.add(section)
		}

		stop
	}

	# Add the consuming section to the end of all sections, if such was found
	if consuming_section != none sections.add(consuming_section)

	return sections
}

parse_section(root: Node, context: Context, tokens: List<Token>, min: normal, max: normal): Status {
	create_function_tokens(tokens)
	
	state = ParserState()
	state.all = tokens

	loop (priority = max, priority >= min, priority--) {
		loop {
			if not next(context, tokens, priority, 0, state) stop
			
			state.error = none
			node = state.pattern.build(context, state, state.tokens)

			# Remove the consumed tokens
			length = state.end - state.start
			loop (length-- > 0) { tokens.remove_at(state.start) }

			# Remove the consumed tokens from the state
			state.tokens.clear()

			# Replace the consumed tokens with the a dynamic token if a node was returned
			if node != none tokens.insert(state.start, DynamicToken(node))
			else state.error != none return state.error
		}
	}

	loop (i = 0, i < tokens.size, i++) {
		token = tokens[i]
		
		if token.type == TOKEN_TYPE_DYNAMIC {
			root.add(token.(DynamicToken).node)
			continue
		}

		if token.type != TOKEN_TYPE_END {
			return Status(token.position, 'Can not understand')
		}
	}

	return Status()
}

clear_sections(sections: List<List<Token>>): _ {
	loop section in sections {
		section.clear()
	}

	sections.clear()
}

parse(root: Node, context: Context, tokens: List<Token>, min: normal, max: normal): Status {
	sections = split(tokens)

	loop section in sections {
		result = parse_section(root, context, section, min, max)

		if result.problematic {
			clear_sections(sections)
			return result
		}
	}

	clear_sections(sections)
	return Status()
}

parse(context: Context, tokens: List<Token>, min: normal, max: normal): Node {
	result = Node()
	parse(result, context, tokens, min, max)
	return result
}

# Summary: Creates the root context, which might contain some default types
create_root_context(index: large): Context {
	context = Context(to_string(index), NORMAL_CONTEXT)
	primitives.inject(context)
	return context
}

# Summary: Creates the root context, which might contain some default types
create_root_context(identity: String): Context {
	context = Context(identity, NORMAL_CONTEXT)
	primitives.inject(context)
	return context
}

# Summary: Creates the root node, which might contain some default initializations
create_root_node(context: Context): ScopeNode {
	root = ScopeNode(context, none as Position, none as Position, false)

	positive_infinity = Variable(context, primitives.create_number(primitives.DECIMAL, FORMAT_DECIMAL), VARIABLE_CATEGORY_GLOBAL, String(POSITIVE_INFINITY_CONSTANT), MODIFIER_PRIVATE | MODIFIER_CONSTANT)
	negative_infinity = Variable(context, primitives.create_number(primitives.DECIMAL, FORMAT_DECIMAL), VARIABLE_CATEGORY_GLOBAL, String(NEGATIVE_INFINITY_CONSTANT), MODIFIER_PRIVATE | MODIFIER_CONSTANT)

	true_constant = Variable(context, primitives.create_bool(), VARIABLE_CATEGORY_GLOBAL, "true", MODIFIER_PRIVATE | MODIFIER_CONSTANT)
	false_constant = Variable(context, primitives.create_bool(), VARIABLE_CATEGORY_GLOBAL, "false", MODIFIER_PRIVATE | MODIFIER_CONSTANT)

	context.declare(positive_infinity)
	context.declare(negative_infinity)
	context.declare(true_constant)
	context.declare(false_constant)

	position = none as Position

	root.add(OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(positive_infinity, position),
		NumberNode(FORMAT_DECIMAL, decimal_to_bits(POSITIVE_INFINITY), position)
	))

	root.add(OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(negative_infinity, position),
		NumberNode(FORMAT_DECIMAL, decimal_to_bits(NEGATIVE_INFINITY), position)
	))

	root.add(OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(true_constant, position),
		CastNode(NumberNode(SYSTEM_FORMAT, 1, position), TypeNode(primitives.create_bool(), position), position)
	))

	root.add(OperatorNode(Operators.ASSIGN, position).set_operands(
		VariableNode(false_constant, position),
		CastNode(NumberNode(SYSTEM_FORMAT, 0, position), TypeNode(primitives.create_bool(), position), position)
	))

	return root
}

# Summary: Finds all the extension functions under the specified node and tries to apply them
apply_extension_functions(context: Context, root: Node): _ {
	extensions = root.find_all(NODE_EXTENSION_FUNCTION)
	loop extension in extensions { resolver.resolve(context, extension) }
}

# Summary: Ensures that all exported and imported functions are implemented
implement_required_functions(context: Context, file: SourceFile, all: bool): _ {
	loop function in common.get_all_visible_functions(context) {
		# If the file filter is specified, skip all functions which are not defined inside that file
		if file !== none and function.start !== none and function.start.file !== file continue

		# Function must be implemented when:
		# - 1. All functions are automatically exported
		# - 2. It is imported
		# - 3. It is set to be exported
		# - 4. It is inside an exported type
		is_implementation_required = all or function.is_imported or function.is_exported or (function.parent != none and function.parent.is_type and function.parent.(Type).is_exported)

		# Skip all functions which are not exported
		if not is_implementation_required continue

		# Template functions can not be implemented
		if function.is_template_function continue

		# Retrieve the parameter types:
		# If any of the parameters has an undefined type, the function can not be implemented
		types = List<Type>()

		loop parameter in function.parameters {
			type = parameter.type

			if type == none or type.is_unresolved {
				types = none as List<Type>
				stop
			}

			types.add(type)
		}

		if types == none continue

		# Force implement the current exported function
		function.get(types)
	}
}

# Summary: Ensures that all virtual function overrides are implemented
implement_virtual_function_overrides(types: List<Type>, file: SourceFile): _ {
	# Implement all virtual function overloads
	loop type in types {
		# Find all virtual functions
		virtual_functions = type.get_all_virtual_functions()

		loop virtual_function in virtual_functions {
			result = type.get_override(virtual_function.name)
			if result == none continue
			overloads = result.overloads

			expected = List<Type>()
			loop parameter in virtual_function.parameters { expected.add(parameter.type) }

			loop overload in overloads {
				# If the file filter is specified, skip all functions which are not defined inside that file
				if file != none and (overload.start === none or overload.start.file != file) continue

				actual = List<Type>()
				loop parameter in overload.parameters { actual.add(parameter.type) }

				if actual.size != expected.size continue

				skip = false

				loop (i = 0, i < expected.size, i++) {
					expected_type = expected[i]
					if expected_type != none and expected_type.is_resolved and expected_type.match(actual[i]) continue
					skip = true
					stop
				}

				if skip continue

				implementation = overload.get(expected)
				if implementation == none abort('Could not implement virtual function')

				implementation.virtual_function = virtual_function

				if virtual_function.return_type != none { implementation.return_type = virtual_function.return_type }
				stop
			}
		}
	}
}

# Summary: Ensures that all constructors are implemented
implement_constructors(types: List<Type>, file: SourceFile): _ {
	# Ensure all default constructors are implemented, because otherwise uncalled default constructors might be added after resolving and they might bypass reconstruction
	loop type in types {
		# Constructors of template base types should not be implemented as only the variants are used
		if type.is_template_type and not type.is_template_type_variant continue

		# If a filter file is specified, use it
		if file !== none and type.position !== none type.position.file !== none and type.position.file !== file continue

		type.constructors.get_implementation(List<Type>())
	}
}

# Summary:
# Ensures that all necessary functions are implemented.
# For example, libraries need all functions to be implemented even when they are not called.
implement_functions(context: Context, file: SourceFile, all: bool): _ {
	is_output_library = settings.output_type == BINARY_TYPE_STATIC_LIBRARY or 
		settings.output_type == BINARY_TYPE_SHARED_LIBRARY or 
		settings.output_type == BINARY_TYPE_OBJECTS or 
		settings.output_type == BINARY_TYPE_RAW

	if is_output_library implement_required_functions(context, file, all)

	types = common.get_all_types(context)

	implement_virtual_function_overrides(types, file)

	implement_constructors(types, file)
}

# Summary: Goes through all the specified types and ensures all their supertypes are resolved
validate_supertypes(types: List<Type>): Status {
	loop type in types {
		resolver.resolve_supertypes(type.parent, type)
		if type.supertypes.all(i -> i.is_resolved) continue

		return Status("Could not resolve supertypes for type " + type.name)
	}

	return Status()
}

# Summary:
# Validates the shell of the context.
# Shell means all the types, functions and variables, but not the code.
validate_shell(context: Context): Status {
	types = common.get_all_types(context)

	result = validate_supertypes(types)
	if result.problematic return result

	return Status()
}

# Summary:
# Limits the compiling so that only the code in the specified source file (build filter) is built.
# Of course, this is not always completely possible, because the specified source file might use template objects from other files.
# Basically, the idea is to remove tokens from external functions with return type, so that they will not be parsed or assembled. 
apply_build_filter(context: Context): _ {
	functions = common.get_all_visible_functions(context)

	loop function in functions {
		# Skip functions that are inside the specified source file, because they must be built
		if function.start.file === settings.build_filter {
			# Export all functions from the source file that should be built
			function.modifiers |= MODIFIER_EXPORTED
			continue
		}

		# Remove export flag from all functions from other source files, so that
		# template functions and such stay local and do not conflict with other object files
		function.modifiers &= (!MODIFIER_EXPORTED)

		# Override functions can always be resolved as they are dependent on the virtual function
		if not function.is_override_function {
			# Note: Unresolved return types are accepted as they will still be resolved

			# Skip all functions that have parameters without explicit type
			if function.parameters.any(i -> i.type === none) {
				if not (function.is_template_function or function.name.starts_with('is_')) console.write_line("Parameters: " + function.name + ' ' + function.start.string())
				continue
			}

			# Skip all functions that do not have explicit return type
			if function.return_type === none {
				if not (function.is_template_function or function.name.starts_with('is_')) console.write_line("Return type missing: " + function.name + ' ' + function.start.string())
				continue
			}
		}

		# Clear the blueprint so that the external function will not be parsed or assembled.
		# Set the function as imported, so that it will not be built.
		function.modifiers |= MODIFIER_IMPORTED
		function.blueprint.clear()
	}
}

parse(): Status {
	files = settings.source_files

	loop (i = 0, i < files.size, i++) {
		file = files[i]

		context = create_root_context(i + 1)
		root = ScopeNode(context, none as Position, none as Position, false)

		result = parse(root, context, file.tokens)

		if result.problematic {
			resolver.output(result)
		}

		file.root = root
		file.context = context
	}

	# Parse all type definitions
	loop (i = 0, i < files.size, i++) {
		file = files[i]
		types = file.root.find_all(NODE_TYPE_DEFINITION)
		loop type in types { type.(TypeDefinitionNode).parse() }
	}

	context = create_root_context(0)
	root = create_root_node(context)

	libraries = settings.libraries
	object_files = settings.object_files

	loop library in libraries {
		if library.ends_with('.lib') or library.ends_with('.a') {
			importer.import_static_library(context, library, files, object_files)
		}
		else {
			# console.write_line('Warning: Shared libraries are not supported yet')
		}
	}

	loop file in files {
		context.merge(file.context)
		root.merge(file.root)
	}

	# Parse all namespaces
	loop node in root.find_all(NODE_NAMESPACE) { node.(NamespaceNode).parse(context) }

	# Applies all extension function
	apply_extension_functions(context, root)

	# Validate the shell before proceeding
	result = validate_shell(context)
	if result.problematic return result

	# Apply the build filter (multithreading)
	apply_build_filter(context)

	# Ensure exported and virtual functions are implemented
	implement_functions(context, settings.build_filter, false)

	if settings.output_type != BINARY_TYPE_STATIC_LIBRARY and settings.output_type != BINARY_TYPE_OBJECTS {
		function = context.get_function("init")
		if function == none return Status('Can not find the entry function \'init()\'')

		function.overloads[].get(List<Type>())
	}

	settings.parse = Parse(context, root as Node)
	return Status()
}

parse(environment: Context, token: Token): Node {
	return parse(environment, environment, token)
}

parse_identifier(context: Context, identifier: IdentifierToken, linked: bool): Node {
	position = identifier.position

	if context.is_variable_declared(identifier.value, linked) {
		variable = context.get_variable(identifier.value)

		# Static variables must be accessed using their parent types
		if variable.is_static and not linked return LinkNode(TypeNode(variable.parent as Type, position), VariableNode(variable, position), position)

		if variable.is_member and not variable.is_static and not variable.is_constant and not linked {
			self = common.get_self_pointer(context, position)

			return LinkNode(self, VariableNode(variable, position), position)
		}

		return VariableNode(variable, position)
	}

	if context.is_property_declared(identifier.value, linked) {
		implementation = context.get_property(identifier.value).get(List<Type>())

		if implementation.is_member and not implementation.is_static and not linked {
			self = common.get_self_pointer(context, position)
			return LinkNode(self, FunctionNode(implementation, position), position)
		}

		return FunctionNode(implementation, position)
	}

	if context.is_type_declared(identifier.value, linked) return TypeNode(context.get_type(identifier.value), position)

	return UnresolvedIdentifier(identifier.value, position)
}

# Summary: Tries to find a suitable function for the specified settings
get_function_by_name(context: Context, name: String, parameters: List<Type>, linked: bool): FunctionImplementation {
	return get_function_by_name(context, name, parameters, List<Type>(), linked)
}

# Summary: Tries to find a suitable function for the specified settings
get_function_by_name(context: Context, name: String, parameters: List<Type>, template_arguments: List<Type>, linked: bool): FunctionImplementation {
	functions = FunctionList()

	if context.is_type_declared(name, linked) {
		type = context.get_type(name)

		if template_arguments.size > 0 {
			# If there are template arguments and if any of the template parameters is unresolved, then this function should fail
			loop template_argument in template_arguments { if template_argument.is_unresolved return none as FunctionImplementation }

			if type.is_template_type {
				# Since the function name refers to a type, the constructors of the type should be explored next
				functions = type.(TemplateType).get_variant(template_arguments).constructors
			}
			else return none as FunctionImplementation
		}
		else { functions = type.constructors }
	}
	else context.is_function_declared(name, linked) {
		functions = context.get_function(name)

		# If there are template parameters, then the function should be retrieved based on them
		if template_arguments.size > 0 return functions.get_implementation(parameters, template_arguments)
	}
	else return none as FunctionImplementation

	return functions.get_implementation(parameters)
}

# Summary: Tries to build the specified function token into a node
parse_function(environment: Context, primary: Context, token: FunctionToken, linked: bool): Node {
	return parse_function(environment, primary, token, List<Type>(), linked)
}

# Summary: Tries to build the specified function token into a node
parse_function(environment: Context, primary: Context, token: FunctionToken, template_arguments: List<Type>, linked: bool): Node {
	descriptor = token.clone() as FunctionToken
	arguments = descriptor.parse(environment)

	types = resolver.get_types(arguments)
	if types == none return UnresolvedFunction(descriptor.name, template_arguments, descriptor.position).set_arguments(arguments)

	if not linked {
		# Try to form a lambda function call
		result = common.try_get_lambda_call(environment, descriptor)

		if result != none {
			result.start = descriptor.position
			return result
		}
	}

	function = get_function_by_name(primary, descriptor.name, types, template_arguments, linked)

	if function != none {
		node = FunctionNode(function, descriptor.position).set_arguments(arguments)

		if function.is_constructor {
			type = function.find_type_parent()
			if type == none abort('Missing constructor parent type')

			# If the descriptor name is not the same as the function name, it is a direct call rather than a construction
			if not (type.identifier == descriptor.name) return node
			return ConstructionNode(node, node.start)
		}

		if function.is_member and not function.is_static and not linked {
			self = common.get_self_pointer(environment, descriptor.position)
			return LinkNode(self, node, descriptor.position)
		}

		return node
	}

	# Lastly, try to form a virtual function call if this function call is not linked
	if not linked {
		# Try to form a virtual function call
		result = common.try_get_virtual_function_call(environment, descriptor)

		if result != none {
			result.start = descriptor.position
			return result
		}
	}

	return UnresolvedFunction(descriptor.name, template_arguments, descriptor.position).set_arguments(arguments)
}

# Summary: Builds the specified parenthesis into a node
parse_parenthesis(context: Context, parenthesis: ParenthesisToken): ParenthesisNode {
	node = ParenthesisNode(parenthesis.position)
	loop section in parenthesis.get_sections() { parse(node, context, section, MIN_PRIORITY, MAX_FUNCTION_BODY_PRIORITY) }
	return node
}

# Summary: Creates a string object from the specified string node
create_string_object(node: StringNode): UnresolvedFunction {
	arguments = Node()
	arguments.add(node)

	return UnresolvedFunction(String(STANDARD_STRING_TYPE), node.start).set_arguments(arguments)
}

parse(environment: Context, primary: Context, token: Token): Node {
	if token.type == TOKEN_TYPE_IDENTIFIER {
		return parse_identifier(primary, token as IdentifierToken, environment != primary)
	}
	else token.type == TOKEN_TYPE_FUNCTION {
		return parse_function(environment, primary, token as FunctionToken, environment != primary)
	}
	else token.type == TOKEN_TYPE_NUMBER {
		number = token.(NumberToken)
		return NumberNode(number.format, number.data, number.position)
	}
	else token.type == TOKEN_TYPE_PARENTHESIS {
		return parse_parenthesis(environment, token as ParenthesisToken)
	}
	else token.type == TOKEN_TYPE_STRING {
		string = StringNode(token.(StringToken).text, token.position)

		if token.(StringToken).opening === `\"` {
			return create_string_object(string)
		}

		return string
	}
	else token.type == TOKEN_TYPE_DYNAMIC {
		return token.(DynamicToken).node
	}

	abort("Could not understand token")
}

print(node: Node): _ {
	print(node, 0, 0)
}

print(node: Node, indentation: large, total: large): _ {
	padding = Array<char>(indentation * 2 + 1)
	padding[padding.size - 1] = 0
	fill(padding.data, padding.size, ` `)

	internal.console.write(padding.data, length_of(padding.data))
	console.write_line(node.string())

	total++

	loop child in node { total += print(child, indentation + 1, 0) }

	return total
}

# Summary: Returns whether the token matches the specified character
Token.match(value: char) {
	if type != TOKEN_TYPE_PARENTHESIS return false
	if value == `{` return this.(ParenthesisToken).opening == `{`
	if value == `(` return this.(ParenthesisToken).opening == `(`
	if value == `[` return this.(ParenthesisToken).opening == `[`
	return false
}

# Summary: Returns whether the token represents the specified operator
Token.match(operator: Operator) {
	return type == TOKEN_TYPE_OPERATOR and this.(OperatorToken).operator == operator
}

# Summary: Returns whether the token represents the specified keyword
Token.match(keyword: Keyword) {
	return type == TOKEN_TYPE_KEYWORD and this.(KeywordToken).keyword == keyword
}