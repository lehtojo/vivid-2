namespace thread

import 'C' Sleep(milliseconds: large)

export sleep(milliseconds: large): _ {
	Sleep(milliseconds)
}