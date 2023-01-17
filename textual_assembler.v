namespace textual_assembler

assemble() {
	if not settings.textual_assembly return Status()

	files = settings.source_files
	if files.size == 0 return Status('Nothing to assemble')

	link_object_files = settings.link_objects

	# Determine the output basename of the object files
	output_basename = settings.output_name

	# Initialize the target architecture
	platform.x64.initialize()
	Keywords.all.clear()
	Operators.all.remove(Operators.LOGICAL_AND.identifier)
	Operators.all.remove(Operators.LOGICAL_OR.identifier)

	if link_object_files {
		object_files = List<BinaryObjectFile>()

		loop file in files {
			parser = AssemblyParser()
			parser.parse(file, file.content)

			encoder_output = instruction_encoder.encode(parser.instructions, parser.debug_file)

			sections = List<BinarySection>()
			sections.add(encoder_output.section) # Add the text section
			sections.add_all(parser.sections.get_values().map<BinarySection>((i: DataEncoderModule) -> i.build())) # Add the data sections

			if encoder_output.lines != none { sections.add(encoder_output.lines.build()) } # Add the debug lines
			if encoder_output.frames != none { sections.add(encoder_output.frames.build()) } # Add the debug frames

			object_file = none as BinaryObjectFile

			if settings.is_target_windows {
				object_file = pe_format.create_object_file(file.fullname, sections, parser.exports)
			}
			else {
				object_file = elf_format.create_object_file(file.fullname, sections, parser.exports)
			}

			object_files.add(object_file)
		}

		binary = none as Array<byte>

		if settings.is_target_windows {
			binary = pe_format.link(object_files, List<String>(), assembler.get_default_entry_point(), output_basename, true)
		}
		else {
			binary = elf_format.link(object_files, List<String>(), assembler.get_default_entry_point(), true)
		}

		io.write_file(output_basename, binary)
	}
	else {
		loop file in files {
			parser = AssemblyParser()
			parser.parse(file, file.content)

			encoder_output = instruction_encoder.encode(parser.instructions, parser.debug_file)
			
			sections = List<BinarySection>()
			sections.add(encoder_output.section) # Add the text section
			sections.add_all(parser.sections.get_values().map<BinarySection>((i: DataEncoderModule) -> i.build())) # Add the data sections

			if encoder_output.lines != none { sections.add(encoder_output.lines.build()) } # Add the debug lines
			if encoder_output.frames != none { sections.add(encoder_output.frames.build()) } # Add the debug frames

			binary = none as Array<byte>

			if settings.is_target_windows {
				binary = pe_format.build(sections, parser.exports)
			}
			else {
				binary = elf_format.build_object_file(sections, parser.exports)
			}

			object_filename = output_basename + `.` + file.filename_without_extension() + object_file_extension
			io.write_file(object_filename, binary)
		}
	}

	application.exit(0)
	return Status()
}