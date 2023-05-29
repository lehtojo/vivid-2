StaticLibraryFormatFile {
	name: String
	position: large = 0
	symbols: List<String>
	bytes: Array<byte> = none as Array<byte>

	init(name: String, symbols: List<String>) {
		this.name = name
		this.symbols = symbols
	}

	init(name: String, symbols: List<String>, bytes: Array<byte>) {
		this.name = name
		this.symbols = symbols
		this.bytes = bytes
	}

	init(name: String, symbols: List<String>, value: String) {
		this.name = name
		this.symbols = symbols
		this.bytes = Array<byte>(value.data, value.length)
	}

	load() {
		if bytes != none return true
		if io.read_file(name) has not result return false
		bytes = result
	}

	get_bytes(): Array<u8> {
		if bytes != none return bytes
		if io.read_file(name) has not result return none as Array<byte>
		bytes = result
		return bytes
	}
}

StaticLibraryFormatFileHeader {
	filename: String
	size: large
	pointer_of_data: large

	init(filename: String, size: large, pointer_of_data: large) {
		this.filename = filename
		this.size = size
		this.pointer_of_data = pointer_of_data
	}
}

namespace static_library_format

constant SIGNATURE = '!<arch>\n'
constant EXPORT_TABLE_FILENAME = '/'
constant FILENAME_TABLE_NAME = '//'
constant EXPORT_TABLE_FILEMODE = '0'
constant DEFAULT_FILEMODE = '100666'
constant END_COMMAND = '\x60\n'

constant FILE_HEADER_LENGTH = 60

constant FILENAME_LENGTH = 16
constant TIMESTAMP_LENGTH = 12
constant IDENTITY_LENGTH = 6
constant FILEMODE_LENGTH = 8
constant SIZE_LENGTH = 10

constant PADDING_VALUE = 0x20

write_padding(builder: DataEncoderModule, length: large): _ {
	if length <= 0 return

	loop (i = 0, i < length, i++) {
		builder.write(PADDING_VALUE)
	}
}

write_file_header(builder: DataEncoderModule, filename: String, timestamp: large, size: large, filemode: String): _ {
	# Write the filename
	builder.write(filename.data, min(FILENAME_LENGTH, filename.length))
	write_padding(builder, FILENAME_LENGTH - filename.length)

	# Write the timestamp
	timestamp_text = to_string(timestamp)
	builder.write(timestamp_text.data, min(TIMESTAMP_LENGTH, timestamp_text.length))
	write_padding(builder, TIMESTAMP_LENGTH - timestamp_text.length)

	# Identities are not supported
	builder.write(`0`)
	write_padding(builder, IDENTITY_LENGTH - 1)
	builder.write(`0`)
	write_padding(builder, IDENTITY_LENGTH - 1)

	# Write the file mode
	builder.write(filemode.data, min(FILEMODE_LENGTH, filemode.length))
	write_padding(builder, FILEMODE_LENGTH - filemode.length)

	# Write the size of the file
	size_text = to_string(size)
	builder.write(size_text.data, min(SIZE_LENGTH, size_text.length))
	write_padding(builder, SIZE_LENGTH - size_text.length)

	# End the header
	builder.write(END_COMMAND, 2)
}

write_symbols(files: List<StaticLibraryFormatFile>): DataEncoderModule {
	builder = DataEncoderModule()
	write_symbols(builder, files.flatten<String>((i: StaticLibraryFormatFile) -> i.symbols))
	return builder
}

write_symbols(builder: DataEncoderModule, symbols: List<String>): List<large> {
	indices = List<large>(symbols.size, true)

	loop (i = 0, i < symbols.size, i++) {
		indices[i] = builder.position

		symbol = symbols[i]
		builder.write(symbol.data, symbol.length)
		builder.write(0)
	}

	# Align to 2 bytes if necessary
	if builder.position % 2 != 0 builder.write(0)

	return indices
}

create_filename_table(files: List<StaticLibraryFormatFile>, timestamp: large): DataEncoderModule {
	filenames = DataEncoderModule()
	indices = write_symbols(filenames, files.map<String>((i: StaticLibraryFormatFile) -> i.name))

	# Convert the filenames to use the filename table by using offsets instead of the actual filenames
	loop (i = 0, i < files.size, i++) {
		files[i].name = String(`/`) + to_string(indices[i])
	}

	builder = DataEncoderModule()
	write_file_header(builder, String(FILENAME_TABLE_NAME), timestamp, filenames.position, String(DEFAULT_FILEMODE))

	# Write the filenames into the builder
	builder.write(filenames.output, filenames.position)

	return builder
}

build(files: List<StaticLibraryFormatFile>, output: String): bool {
	loop file in files { file.load() }

	contents = DataEncoderModule()

	timestamp = 0 # TODO: Unix timestamp
	position = 0

	filename_table = create_filename_table(files, timestamp)

	loop file in files {
		file.position = position

		bytes = file.get_bytes()

		write_file_header(contents, file.name, timestamp, bytes.size, String(DEFAULT_FILEMODE))
		contents.write(bytes)

		position += FILE_HEADER_LENGTH + bytes.size

		# Align the position to 2 bytes
		if position % 2 == 0 continue

		contents.write(0)
		position++
	}

	builder = DataEncoderModule()
	builder.write(SIGNATURE, length_of(SIGNATURE))

	# Create the symbol buffer
	symbol_buffer = write_symbols(files)

	# Compute the total number of symbols
	symbol_count = 0

	loop file in files {
		symbol_count += file.symbols.size
	}

	# Compute the size of the export table that will be placed to the start of static library file for quick access
	export_table_size = strideof(normal) + symbol_count * strideof(normal) + symbol_buffer.position

	# Compute the offset which must be applied to all the file positions
	offset = length_of(SIGNATURE) + FILE_HEADER_LENGTH + export_table_size + filename_table.position

	loop file in files {
		file.position += offset
	}

	# Write the export table file header
	write_file_header(builder, String(EXPORT_TABLE_FILENAME), timestamp, export_table_size, String(EXPORT_TABLE_FILEMODE))

	builder.write_int32(binary_utility.swap_endianness_int32(symbol_count))

	# Write all the file pointers
	loop file in files {
		symbol_file_position = binary_utility.swap_endianness_int32(file.position)

		# Each of the symbols points to the file they belong to
		loop (i = 0, i < file.symbols.size, i++) {
			builder.write_int32(symbol_file_position)
		}
	}

	# Add the symbol buffer
	builder.write(symbol_buffer.output, symbol_buffer.position)

	# Add the filename table
	builder.write(filename_table.output, filename_table.position)

	# Finally add the contents
	builder.write(contents.output, contents.position)

	static_library_extension = '.a'
	if settings.is_target_windows { static_library_extension = '.lib' }

	return io.write_file(output + static_library_extension, Array<byte>(builder.output, builder.position))
}

get_object_filename(source: SourceFile, output_name: String): String {
	return output_name + `.` + source.filename_without_extension() + object_file_extension
}

export build(context: Context, object_files: Map<SourceFile, BinaryObjectFile>, output_name: String): bool {
	context_export_file = object_exporter.export_context(context)
	template_type_variants_export_file = object_exporter.export_template_type_variants(context)
	template_function_variants_export_file = object_exporter.export_template_function_variants(context)

	files = List<StaticLibraryFormatFile>()

	loop iterator in object_files {
		source_file = iterator.key
		object_file = iterator.value

		object_file_name = get_object_filename(source_file, output_name)
		object_file_symbols = object_file.exports

		bytes = none as Array<byte>

		if settings.is_target_windows {
			bytes = pe_format.build(object_file.sections, object_file.exports)
		}
		else {
			bytes = elf_format.build_object_file(object_file.sections, object_file.exports)
		}

		files.add(StaticLibraryFormatFile(object_file_name, object_file_symbols.to_list(), bytes))
	}

	files.add(StaticLibraryFormatFile(output_name + importer.GENERAL_IMPORT_FILE_EXTENSION, List<String>(), context_export_file))
	files.add(StaticLibraryFormatFile(output_name + importer.TEMPLATE_TYPE_VARIANT_IMPORT_FILE_EXTENSION, List<String>(), template_type_variants_export_file))
	files.add(StaticLibraryFormatFile(output_name + importer.TEMPLATE_FUNCTION_VARIANT_IMPORT_FILE_EXTENSION, List<String>(), template_function_variants_export_file))

	return build(files, output_name)
}