namespace importer

constant WINDOWS_SHARED_LIBRARY_EXTENSION = '.dll'
constant UNIX_SHARED_LIBRARY_EXTENSION = '.so'

constant STATIC_LIBRARY_SYMBOL_TABLE_OFFSET = 68
constant STATIC_LIBRARY_SYMBOL_TABLE_FIRST_LOCATION_ENTRY_OFFSET = 72

constant FILENAME_LENGTH = 16
constant TIMESTAMP_LENGTH = 12
constant IDENTITY_LENGTH = 6
constant FILEMODE_LENGTH = 8
constant SIZE_LENGTH = 10

constant PADDING_VALUE = 0x20

constant TEMPLATE_TYPE_VARIANT_IMPORT_FILE_EXTENSION = '.types.templates'
constant TEMPLATE_FUNCTION_VARIANT_IMPORT_FILE_EXTENSION = '.functions.templates'
constant GENERAL_IMPORT_FILE_EXTENSION = '.exports'

constant EXPORT_TABLE_FILENAME = '/'
constant FILENAME_TABLE_NAME = '//'

# Summary: Returns whether the specified bytes start with the correct signature
is_signature_valid(bytes: Array<u8>): bool {
	signature = static_library_format.SIGNATURE.(u64*)[]
	return bytes.size >= sizeof(u64) and bytes.data.(u64*)[] == signature
}

# Summary:
# Iterates through the specified headers and looks for an export file and imports it.
# Export files contain exported source code such as template types and functions.
import_export_file(context: Context, bytes: Array<byte>, headers: List<StaticLibraryFormatFileHeader>, library: String, files: List<SourceFile>): Node {
	loop (i = 0, i < headers.size, i++) {
		# Look for an export file
		header = headers[i]
		if not header.filename.ends_with(GENERAL_IMPORT_FILE_EXTENSION) continue

		start = header.pointer_of_data
		end = start + header.size

		if start < 0 or start > bytes.size or end < 0 or end > bytes.size abort('Export file data was out of bounds')

		# Determine the next available index for the new source file
		index = 0

		loop file in files {
			if file.index < index continue
			index = file.index + 1
		}
		
		# Since the file is source code, it can be converted into text
		text = String(bytes.data + start, end - start)
		file = SourceFile(library + '/' + header.filename, text, index)

		files.add(file)

		# Produce tokens from the template code
		if get_tokens(text, true) has not tokens abort('Failed to tokenize export file')
		file.tokens = tokens

		# Register the file to the produced tokens
		register_file(file.tokens, file)

		# Parse all the tokens
		root = ScopeNode(context, none as Position, none as Position, false)

		parser.parse(root, context, file.tokens)
		
		file.root = root
		file.context = context

		# Find all the types and parse them
		type_nodes = root.find_all(NODE_TYPE_DEFINITION) as List<TypeDefinitionNode>

		loop type_node in type_nodes {
			type_node.parse()
		}

		# Find all the namespaces and parse them
		namespace_nodes = root.find_all(NODE_NAMESPACE) as List<NamespaceNode>

		loop namespace_node in namespace_nodes {
			namespace_node.parse(context)
		}

		return root
	}

	return none as Node
}

# Summary:
# Iterates through the specified file headers and imports all object files by adding them to the specified object file list.
# Object files are determined using filenames stored in the file headers.
import_object_files_from_static_library(file: String, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>, object_files: Map<SourceFile, BinaryObjectFile>): _ {
	loop header in headers {
		# Find object files only
		is_object_file = header.filename.ends_with('.o') or header.filename.ends_with('.obj') or header.filename.ends_with('.o/') or header.filename.ends_with('.obj/')
		if not is_object_file continue

		object_file_name = file + `/` + header.filename
		object_file_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)

		object_file = none as BinaryObjectFile

		if settings.is_target_windows {
			object_file = pe_format.import_object_file(object_file_name, object_file_bytes)
		} else {
			object_file = elf_format.import_object_file(object_file_name, object_file_bytes)
		}

		object_file_source = SourceFile(object_file_name, String.empty, -1)
		object_files.add(object_file_source, object_file)
	}
}

# Summary:
# Imports all template type variants using the specified static library file headers
import_template_type_variants(context: Context, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>): _ {
	loop header in headers {
		if not header.filename.ends_with(TEMPLATE_TYPE_VARIANT_IMPORT_FILE_EXTENSION) continue

		template_variant_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)
		template_variants = String(template_variant_bytes.data, template_variant_bytes.size).split(`\n`)

		loop template_variant in template_variants {
			if template_variant.length == 0 continue
			if get_tokens(template_variant, true) has not tokens continue

			# Create the template variant from the current line
			imported_type = common.read_type(context, tokens)
			if imported_type == none abort('Could not to import template type variant')

			imported_type.modifiers |= MODIFIER_IMPORTED
		}
	}
}

# Summary:
# Imports all template function variants using the specified static library file headers
import_template_function_variants(context: Context, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>): _ {
	loop header in headers {
		if not header.filename.ends_with(TEMPLATE_FUNCTION_VARIANT_IMPORT_FILE_EXTENSION) continue

		template_variant_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)
		template_variants = String(template_variant_bytes.data, template_variant_bytes.size).split(`\n`)

		loop template_variant_text in template_variants {
			if template_variant_text.length == 0 continue

			# Extract the container type components
			if get_tokens(template_variant_text, true) has not tokens abort('Could not to import template function variant')
			components = List<UnresolvedTypeComponent>()

			loop (tokens.size > 0) {
				components.add(common.read_type_component(context, tokens))

				# Stop collecting type components if there are no tokens left or if the next token is not a dot operator
				if tokens.size == 0 or not tokens[].match(Operators.DOT) stop

				tokens.pop_or(none as Token)
			}

			if tokens.size != 1 abort('Missing template function variant parameter types')
			
			# Extract the parameter types
			parameter_types = List<Type>()
			parameter_tokens = tokens[].(ParenthesisToken).tokens

			loop (parameter_tokens.size > 0) {
				parameter_type = common.read_type(context, parameter_tokens)
				if parameter_type == none abort("Could not import template function variant: " + template_variant_text)

				parameter_types.add(parameter_type)

				if parameter_tokens.size == 0 stop
				if parameter_tokens.pop_or(none as Token).match(Operators.COMMA) continue

				abort("Could not import template function variant: " + template_variant_text)
			}

			# Extract the type, which will contain the template function variant
			environment = context

			if components.size > 1 {
				environment = UnresolvedType(components.slice(0, components.size - 1), none as Position).resolve_or_none(context)
				if environment == none abort("Could not import template function variant: " + template_variant_text)
			}

			template_function_name = components[components.size - 1].identifier

			# Find the template function from the container type
			template_function = environment.get_function(template_function_name)
			if template_function == none abort("Could not import template function variant: " + template_variant_text)

			# Now, find the overload which accepts the template arguments
			template_variant = template_function.get_implementation(parameter_types, components[components.size - 1].arguments)
			if template_variant == none abort("Could not import template function variant: " + template_variant_text)

			template_variant.is_imported = true
		}
	}
}

# Summary:
# Resolve issues such as parameter types in the imported context and node tree
resolve(context: Context, root: Node): _ {
	current = resolver.get_report(context, root)
	evaluated = false

	# Try to resolve as long as errors change -- errors do not always decrease since the program may expand each cycle
	loop {
		previous = current

		# Try to resolve problems in the node tree and get the status after that
		resolver.resolve_context(context)
		resolver.resolve(context, root)

		current = resolver.get_report(context, root)

		# Try again only if the errors have changed
		if not resolver.are_reports_equal(previous, current) continue
		if evaluated stop

		evaluator.evaluate(context)
		evaluated = true
	}

	if current.size > 0 {
		common.report(current)
		abort('Failed to import a library')
	}
}

# Summary:
# Imports the specified static library by finding the exported symbols and importing them
internal_import_static_library(context: Context, file: String, files: List<SourceFile>, object_files: Map<SourceFile, BinaryObjectFile>): _ {
	if io.read_file(file) has not bytes abort('Failed to open a library')

	# Verify the signature
	require(is_signature_valid(bytes), 'Static library did not have valid signature')

	entries = binary_utility.read<normal>(bytes, STATIC_LIBRARY_SYMBOL_TABLE_OFFSET)
	entries = binary_utility.swap_endianness_int32(entries)

	# Skip all of the location entries to reach the actual symbol names
	position = STATIC_LIBRARY_SYMBOL_TABLE_FIRST_LOCATION_ENTRY_OFFSET + entries * strideof(normal)

	# Load all the exported symbols
	exported_symbols = pe_format.load_number_of_strings(bytes, position, entries)
	if exported_symbols == none abort('Failed to load exported symbols from a library')

	headers = load_file_headers(bytes)
	if headers.size == 0 abort('Failed to load headers from a library')

	root = import_export_file(context, bytes, headers, file, files)
	import_object_files_from_static_library(file, headers, bytes, object_files)
	import_template_type_variants(context, headers, bytes)
	import_template_function_variants(context, headers, bytes)

	# Resolve issues in the imported context and node tree if they exist
	if root !== none resolve(context, root)
}

# Summary:
# Assigns the actual filenames to the specified file headers from the specified filename table
load_filenames(bytes: Array<byte>, filenames: StaticLibraryFormatFileHeader, headers: List<StaticLibraryFormatFileHeader>): bool {
	loop header in headers {
		# Look for files which have names such as: /10
		if not header.filename.starts_with(`/`) or header.filename.length <= 1 continue

		# Ensure the filename is a extended filename, meaning the actual filename is loaded from a string table at the offset given by the extended filename
		digits = header.filename.slice(1)
		is_extended_filename = true

		loop (i = 0, i < digits.length, i++) {
			if is_digit(digits[i]) continue
			is_extended_filename = false
			stop
		}

		if not is_extended_filename continue

		# This still might fail if the index is too large
		if as_integer(digits) has not offset continue

		# Compute the position of the filename
		position = filenames.pointer_of_data + offset

		# Check whether the position is out of bounds
		if position < 0 or position >= bytes.size continue

		# Extract the name until a zero byte is found
		end = position
		loop (bytes[end] != 0, end++) {}

		header.filename = String(bytes.data + position, end - position)
	}

	return true
}

# Summary:
# Loads all static library file headers from the specified file.
# Returns an empty list if it fails, since static libraries should not be empty
load_file_headers(bytes: Array<byte>): List<StaticLibraryFormatFileHeader> {
	headers = List<StaticLibraryFormatFileHeader>()
	position = 8 # Skip signature: !<arch>\n

	loop (position < bytes.size) {
		# If a line ending is encountered, it means that the file headers have been consumed
		if bytes[position] == `\n` stop

		# Extract the file name
		name_buffer = bytes.slice(position, position + FILENAME_LENGTH) # File name is always padded inside 16 bytes
		name_end = name_buffer.index_of(PADDING_VALUE)
		name = String(name_buffer.data, name_end)
		
		# Extract the file size
		position += FILENAME_LENGTH + TIMESTAMP_LENGTH + IDENTITY_LENGTH * 2 + FILEMODE_LENGTH
		
		# Load the file size text into a string
		size_text_buffer = bytes.slice(position, position + SIZE_LENGTH)
		size_text_end = size_text_buffer.index_of(PADDING_VALUE)
		size_text = String(size_text_buffer.data, size_text_end)

		# Parse the file size
		if as_integer(size_text) has not size return List<StaticLibraryFormatFileHeader>()

		# Go to the end of the header, that is the start of the file data
		position += SIZE_LENGTH + 2 # Skip end command as well: \x60\n

		headers.add(StaticLibraryFormatFileHeader(name, size, position))

		# Skip to the next header
		position += size
		position += position % 2
	}

	# Try to find the section which has the actual filenames
	# NOTE: Sometimes file headers contain their actual filenames
	i = -1

	loop (j = 0, j < headers.size, j++) {
		if not (headers[j].filename == FILENAME_TABLE_NAME) continue
		i = j
		stop
	}

	# If the filename table was found, apply it to the headers
	if i != -1 and not load_filenames(bytes, headers[i], headers) return List<StaticLibraryFormatFileHeader>()

	return headers
}

# Summary:
# Imports the specified file.
# This function assumes the file represents a library
import_static_library(context: Context, file: String, files: List<SourceFile>, object_files: Map<SourceFile, BinaryObjectFile>): bool {
	import_context = parser.create_root_context(context.create_identity())

	internal_import_static_library(import_context, file, files, object_files)

	# Ensure all functions are marked as imported
	functions = common.get_all_visible_functions(import_context)

	loop function in functions {
		parameter_types = function.parameters.map<Type>((i: Parameter) -> i.type)

		if function.is_template_function or parameter_types.any(i -> i === none) {
			# Set all template functions as not imported as later variations are no longer imported
			function.modifiers &= !MODIFIER_IMPORTED
		}
		else {
			# Create a default implementation for the imported function, since it does not require template arguments
			if function.get(parameter_types) === none abort('Failed to import a function')
		}
	}

	# Register all implementations here imported
	implementations = common.get_all_function_implementations(import_context, true)

	loop implementation in implementations {
		implementation.is_imported = true
	}

	# Ensure all types are marked as imported
	types = common.get_all_types(import_context)

	loop type in types {
		type.modifiers = combine_modifiers(type.modifiers, MODIFIER_IMPORTED)
	}

	context.merge(import_context)
	return true
}