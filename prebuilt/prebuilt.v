import are_equal(a: large, b: large)
import are_equal(a: char, b: char)
import are_equal(a: decimal, b: decimal)
import are_equal(a: link, b: link)
import are_equal(a: link, b: link, offset: large, length: large)
import are_not_equal(a: large, b: large)
import allocate(bytes: large): link
import deallocate(memory: link)
import internal_is(a: link, b: link): bool