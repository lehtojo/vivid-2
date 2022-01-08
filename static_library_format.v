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