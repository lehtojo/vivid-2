$add_to_list!(list) {}

$add_to_list!(list, x, elements...) {
	$list.add($x)
	add_to_list!($list, $elements...)
}

$list_of!(T, elements...) {
	$list = List<$T>()
	add_to_list!($list, $elements...)
	$list
}

$loop!(n) {
	loop ($i = 0, $i < $n, $i++)	
}

$print!() {}

$print!(arguments..., argument) {
	print!($arguments...)
	console.write($argument)
}

$foreach!(i, collection, body) {
	loop ($l = $collection.iterator(), $l.next(), ) {
		$i = $l.value()
		$body
	}
}

init() {
	loop!(3) {
		console.write_line("Hello there :^)!")
	}

	loop!(1) { console.write_line("Hello there again :^)!") }

	list = list_of!(u32, 3, 7, 8 + 6, 42)
	sum = 0

	print!('Elements: \n')

	foreach!(i, list, 
		print!(i, '\n')
		sum += i
	)

	print!('Sum: ', sum, '\n', 'Goodbye!\n')
	return 0
}