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

# Summary:
# Iterates through the specified sections which represent template exports and imports them
import_templates(context: Context, bytes: Array<byte>, headers: List<StaticLibraryFormatFileHeader>, library: String, files: List<SourceFile>) {
	loop (i = 0, i < headers.size, i++) {
		# Look for files which represent source code of this language
		header = headers[i]

		# Ensure the file ends with the extension of this language
		if not header.filename.ends_with(LANGUAGE_FILE_EXTENSION) continue

		start = header.pointer_of_data
		end = start + header.size

		if start < 0 or start > bytes.count or end < 0 or end > bytes.count => false

		# Determine the next available index for the new source file
		index = 0

		loop file in files {
			if file.index < index continue
			index = file.index + 1
		}
		
		# Since the file is source code, it can be converted into text
		text = String.from(bytes.data + start, end - start)
		file = SourceFile(library + '/' + header.filename, text, index)

		files.add(file)

		# Produce tokens from the template code
		if not (get_tokens(text, true) has tokens) => false
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
	}

	=> true
}

# Summary:
# Iterates through the specified file headers and imports all object files by adding them to the specified object file list.
# Object files are determined using filenames stored in the file headers.
import_object_files_from_static_library(file: String, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>, object_files: Map<SourceFile, BinaryObjectFile>) {
	object_file_extension = '.o'
	if settings.is_target_windows { object_file_extension = '.obj' }

	loop header in headers {
		# Ensure the file ends with the extension of this language
		if not header.filename.ends_with(object_file_extension) continue

		object_file_name = file + `/` + header.filename
		object_file_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)

		object_file = none as BinaryObjectFile

		if settings.is_target_windows {
			object_file = pe_format.import_object_file(object_file_name, object_file_bytes)
		} else {
			# TODO: Import linux support
		}

		object_file_source = SourceFile(object_file_name, String.empty, -1)
		object_files.add(object_file_source, object_file)
	}
}

# Summary:
# Imports all template type variants using the specified static library file headers
import_template_type_variants(context: Context, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>) {
	loop header in headers {
		if not header.filename.ends_with(TEMPLATE_TYPE_VARIANT_IMPORT_FILE_EXTENSION) continue

		template_variant_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)
		template_variants = String.from(template_variant_bytes.data, template_variant_bytes.count).split(`\n`)

		loop template_variant in template_variants {
			if template_variant.length == 0 continue
			if not (get_tokens(template_variant, true) has tokens) continue

			# Create the template variant from the current line
			imported_type = common.read_type(context, tokens)
			if imported_type == none abort('Could not to import template type variant')

			imported_type.modifiers |= MODIFIER_IMPORTED
		}
	}
}

# Summary:
# Imports all template function variants using the specified static library file headers
import_template_function_variants(context: Context, headers: List<StaticLibraryFormatFileHeader>, bytes: Array<byte>) {
	loop header in headers {
		if not header.filename.ends_with(TEMPLATE_FUNCTION_VARIANT_IMPORT_FILE_EXTENSION) continue

		template_variant_bytes = bytes.slice(header.pointer_of_data, header.pointer_of_data + header.size)
		template_variants = String.from(template_variant_bytes.data, template_variant_bytes.count).split(`\n`)

		loop template_variant_text in template_variants {
			if template_variant_text.length == 0 continue

			# Extract the container type components
			if not (get_tokens(template_variant_text, true) has tokens) abort('Could not to import template function variant')
			components = List<UnresolvedTypeComponent>()

			loop (tokens.size > 0) {
				components.add(common.read_type_component(context, tokens))

				# Stop collecting type components if there are no tokens left or if the next token is not a dot operator
				if tokens.size == 0 or not tokens[0].match(Operators.DOT) stop

				tokens.pop_or(none as Token)
			}

			if tokens.size != 1 abort('Missing template function variant parameter types')
			
			# Extract the parameter types
			parameter_types = List<Type>()
			parameter_tokens = tokens[0].(ParenthesisToken).tokens

			loop (parameter_tokens.size > 0) {
				parameter_type = common.read_type(context, parameter_tokens)
				if parameter_type == none abort(String('Could not import template function variant: ') + template_variant_text)

				parameter_types.add(parameter_type)

				if parameter_tokens.size == 0 stop
				if parameter_tokens.pop_or(none as Token).match(Operators.COMMA) continue

				abort(String('Could not import template function variant: ') + template_variant_text)
			}

			# Extract the type, which will contain the template function variant
			environment = context

			if components.size > 1 {
				environment = UnresolvedType(components.slice(0, components.size - 1)).try_resolve_type(context)
				if environment == none abort(String('Could not import template function variant: ') + template_variant_text)
			}

			template_function_name = components[components.size - 1].identifier

			# Find the template function from the container type
			template_function = environment.get_function(template_function_name)
			if template_function == none abort(String('Could not import template function variant: ') + template_variant_text)

			# Now, find the overload which accepts the template arguments
			template_variant = template_function.get_implementation(parameter_types, components[components.size - 1].arguments)
			if template_variant == none abort(String('Could not import template function variant: ') + template_variant_text)

			template_variant.is_imported = true
		}
	}
}

# Summary:
# Imports the specified static library by finding the exported symbols and importing them
internal_import_static_library(context: Context, file: String, files: List<SourceFile>, object_files: Map<SourceFile, BinaryObjectFile>) {
	if not (io.read_file(file) has bytes) => false
	entries = binary_utility.read<normal>(bytes, STATIC_LIBRARY_SYMBOL_TABLE_OFFSET)
	entries = binary_utility.swap_endianness_int32(entries)

	# Skip all of the location entries to reach the actual symbol names
	position = STATIC_LIBRARY_SYMBOL_TABLE_FIRST_LOCATION_ENTRY_OFFSET + entries * sizeof(normal)

	# Load all the exported symbols
	exported_symbols = pe_format.load_number_of_strings(bytes, position, entries)
	if exported_symbols == none => false

	headers = load_file_headers(bytes)
	if headers.size == 0 => false

	import_templates(context, bytes, headers, file, files)
	import_object_files_from_static_library(file, headers, bytes, object_files)
	import_template_type_variants(context, headers, bytes)
	import_template_function_variants(context, headers, bytes)
	=> true
}

# Summary:
# Assigns the actual filenames to the specified file headers from the specified filename table
load_filenames(bytes: Array<byte>, filenames: StaticLibraryFormatFileHeader, headers: List<StaticLibraryFormatFileHeader>) {
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
		if not (as_number(digits) has offset) continue

		# Compute the position of the filename
		position = filenames.pointer_of_data + offset

		# Check whether the position is out of bounds
		if position < 0 or position >= bytes.count continue

		# Extract the name until a zero byte is found
		end = position
		loop (bytes[end] != 0, end++) {}

		header.filename = String.from(bytes.data + position, end - position)
	}

	=> true
}

# Summary:
# Loads all static library file headers from the specified file.
# Returns an empty list if it fails, since static libraries should not be empty
load_file_headers(bytes: Array<byte>) {
	headers = List<StaticLibraryFormatFileHeader>()
	position = 8 # Skip signature: !<arch>\n

	loop (position < bytes.count) {
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
		if not (as_number(size_text) has size) => List<StaticLibraryFormatFileHeader>()

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
	if i != -1 and not load_filenames(bytes, headers[i], headers) => List<StaticLibraryFormatFileHeader>()

	=> headers
}

# Summary:
# Imports the specified file.
# This function assumes the file represents a library
import_static_library(context: Context, file: String, files: List<SourceFile>, object_files: Map<SourceFile, BinaryObjectFile>) {
	import_context = parser.create_root_context(file)

	internal_import_static_library(import_context, file, files, object_files)

	# Ensure all functions are marked as imported
	functions = common.get_all_visible_functions(import_context)

	loop function in functions {
		function.modifiers |= MODIFIER_IMPORTED

		# Create default implementations for imported functions that do not require template arguments
		parameter_types = function.parameters.map<Type>((i: Parameter) -> i.type)

		if not function.is_template_function and parameter_types.all(i -> i != none and i.is_resolved) {
			function.get(parameter_types)
		}

		# Register the default implementations as imported
		loop implementation in function.implementations {
			implementation.is_imported = true
		}
	}

	# Ensure all types are marked as imported
	types = common.get_all_types(import_context)

	loop type in types {
		type.modifiers = combine_modifiers(type.modifiers, MODIFIER_IMPORTED)
	}

	# TODO: Verify all parameter types are resolved
	context.merge(import_context)
	=> true
}