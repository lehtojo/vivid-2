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
		=> fullname.slice(i + 1, fullname.length)
	}

	filename_without_extension() {
		start = fullname.last_index_of(`/`) + 1

		end = fullname.last_index_of(`.`)
		if end <= start { end = fullname.length }

		=> fullname.slice(start, end)
	}
}

# Summary: Loads the source files specified by the user
load() {
	filenames = settings.filenames
	if filenames.size == 0 => Status('Please enter input files')

	files = List<SourceFile>(filenames.size, true)

	loop (i = 0, i < files.size, i++) {
		filename = filenames[i]

		bytes = io.read_file(filename)
		if bytes.empty => Status((String('Could not load file ') + filename).text)

		content = String(bytes.value.data, bytes.value.count).replace(`\r`, ` `).replace(`\t`, ` `)
		files[i] = SourceFile(filename, content, i)
	}

	settings.source_files = files
	=> Status()
}