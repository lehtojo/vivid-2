namespace internal.console

constant STANDARD_OUTPUT_HANDLE = -11
constant STANDARD_INPUT_HANDLE = -10

import 'C' GetStdHandle(handle: large): large
import 'C' WriteFile(handle: large, buffer: link, size: large, written: large*, overlapped: large*): bool
import 'C' ReadConsoleA(handle: large, buffer: link, size: large, read: large*, overlapped: large*): bool

export write(bytes: link, length: large) {
	written: large[1]
	handle = internal.console.GetStdHandle(internal.console.STANDARD_OUTPUT_HANDLE)
	internal.console.WriteFile(handle, bytes, length, written as link, none as link)
}

export read(bytes: link, length: large) {
	read: large[1]
	handle = internal.console.GetStdHandle(internal.console.STANDARD_INPUT_HANDLE)
	internal.console.ReadConsoleA(handle, bytes, length, read as link, none as link)
	return read[]
}