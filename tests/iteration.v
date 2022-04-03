CustomArrayIterator<T> {
	elements: link<T>
	position: normal
	count: normal

	init(elements: link<T>, count: large) {
		this.elements = elements
		this.position = -1
		this.count = count
	}

	value() {
		=> elements[position]
	}

	next() {
		=> ++position < count
	}

	reset() {
		position = -1
	}
}

CustomArray<T> {
	data: link<T>
	count: large
	
	init(count: large) {
		this.data = allocate(count * sizeof(T))
		this.count = count
	}

	init(data: link<T>, count: large) {
		this.data = data
		this.count = count
	}
	
	set(i: large, value: T) {
		data[i] = value
	}
	
	get(i: large) {
		=> data[i]
	}

	iterator() {
		=> CustomArrayIterator<T>(data, count)
	}
	
	deinit() {
		deallocate(data, count)
	}
}

Object {
	public:
	value: decimal
	flag: bool = false
	
	value() {
		flag = true
		=> value
	}
}

export iteration_1(array: CustomArray<large>, destination: link<large>) {
	loop i in array {
		destination[0] = i
		destination += sizeof(large)
	}
}

export iteration_2(destination: link<large>) {
	loop i in -10..10 {
		destination[0] = i * i
		destination += sizeof(large)
	}
}

export iteration_3(range: Range, destination: link<large>) {
	loop i in range {
		destination[0] = 2 * i
		destination += sizeof(large)
	}
}

export iteration_4(objects: CustomArray<Object>) {
	loop i in objects {
		if i.value() > -10.0 and i.value() < 10.0 {
			stop
		}
	}
}

export iteration_5(objects: CustomArray<Object>) {
	loop i in objects {
		if i.value() < -12.34 or i.value() > 12.34 {
			continue
		}

		stop
	}
}

export range_1() {
	=> 1..10
}

export range_2() {
	=> -5e2..10e10
}

export range_3(a: large, b: large) {
	=> a..b
}

export range_4(a: large, b: large) {
	=> a * a .. b * b
}

init() {
	numbers = allocate<large>(5)
	numbers[0] = -2
	numbers[1] = 3
	numbers[2] = -5
	numbers[3] = 7
	numbers[4] = -11

	destination = allocate<large>(5)

	number_array = CustomArray<large>(numbers, 5)
	iteration_1(number_array, destination)

	loop (i = 0, i < 5, i++) {
		are_equal(numbers[i], destination[i])
	}

	deallocate(destination)
	destination = allocate<large>(21)

	iteration_2(destination)

	loop (i = -10, i <= 10, i++) {
		are_equal(i * i, destination[i + 10])
	}

	range = Range(-7, -3)

	deallocate(destination)
	destination = allocate<large>(5)

	iteration_3(range, destination)

	loop (i = -7, i <= -3, i++) {
		are_equal(2 * i, destination[i + 7])
	}

	deallocate(numbers)

	objects = allocate<Object>(3)

	first = Object()
	first.value = -123.456
	first.flag = false

	second = Object()
	second.value = -1.333333
	second.flag = false

	third = Object()
	third.value = 1010
	third.flag = false
	
	objects[0] = first
	objects[1] = second
	objects[2] = third

	object_array = CustomArray<Object>(objects, 3)

	iteration_4(object_array)

	are_equal(true, first.flag)
	are_equal(true, second.flag)
	are_equal(false, third.flag)

	first.value = 12.345
	first.flag = false

	second.value = -12.34
	second.flag = false

	third.value = 101
	third.flag = false

	iteration_5(object_array)

	are_equal(true, first.flag)
	are_equal(true, second.flag)
	are_equal(false, third.flag)

	range = range_1()

	are_equal(1, range.start)
	are_equal(10, range.end)

	range = range_2()

	are_equal(-5e2, range.start)
	are_equal(10e10, range.end)

	range = range_3(314159, -42)

	are_equal(314159, range.start)
	are_equal(-42, range.end)

	range = range_4(-12, -14)

	are_equal(144, range.start)
	are_equal(196, range.end)
	=> 1
}