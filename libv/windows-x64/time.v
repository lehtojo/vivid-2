namespace time

import 'C' GetSystemTimeAsFileTime(result: large*)

export now(): large {
	value: large[1]
	GetSystemTimeAsFileTime(value as large*)
	return value[]
}