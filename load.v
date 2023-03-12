SourceFile {
	fullname: String
	content: String
	index: large
	tokens: List<Token>
	root: Node
	context: Context
	
	init(fullname: String, content: String, index: large) {
		this.fullname = fullname.replace(`\\`, `/`)
		this.content = content
		this.index = index
	}

	filename() {
		i = fullname.last_index_of(`/`)
		return fullname.slice(i + 1, fullname.length)
	}

	filename_without_extension() {
		start = fullname.last_index_of(`/`) + 1

		end = fullname.last_index_of(`.`)
		if end <= start { end = fullname.length }

		return fullname.slice(start, end)
	}
}

# Summary: Finds and sets the build filter
find_build_filter(filenames: List<String>, files: List<SourceFile>): _ {
	path = settings.build_filter_path
	if path === none return

	loop (i = 0, i < filenames.size, i++) {
		if not (filenames[i] == path) continue
		settings.build_filter = files[i]
		stop
	}

	if settings.build_filter === none abort("Specified filter file was not in the build files: " + path)
}

# Summary: Loads the source files specified by the user
load() {
	filenames = settings.filenames
	if filenames.size == 0 return Status('Please enter input files')

	files = List<SourceFile>(filenames.size, true)

	loop (i = 0, i < files.size, i++) {
		filename = filenames[i]

		bytes = io.read_file(filename)
		if bytes.empty return Status("Could not load file " + filename)

		content = String(bytes.value.data, bytes.value.size).replace(`\r`, ` `).replace(`\t`, ` `)
		files[i] = SourceFile(filename, content, i)
	}

	find_build_filter(filenames, files)

	settings.source_files = files
	return Status()
}