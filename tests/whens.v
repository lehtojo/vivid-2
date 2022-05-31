export numerical_when(x: large) {
	=> when(x) {
		7 => x * x
		3 => x + x + x
		1 => -1
		else => x
	}
}

export create_string(characters: link, length: large) {
	=> String(characters, length)
}

export string_when(text: String) {
	=> when(text) {
		'Foo' => 0
		'Bar' => 1, # The commas are here and down below, since the compiler should not care about them here
		'Baz' => 2
		else => -1,
	}
}

Boo {
	x: large
	y: large
}

Boo Baba {
	init(x) {
		this.x = x
	}

	value() {
		=> x * x
	}
}

Boo Bui {
	init(y) {
		this.y = y
	}

	value() {
		=> y + y
	}
}

Baba Bababui {
	init(x, y) {
		Baba.init(x)
		this.y = y
	}

	value() {
		=> y * Baba.value()
	}
}

export create_boo() {
	=> Boo()
}

export create_baba(x: large) {
	=> Baba(x)
}

export create_bui(x: large) {
	=> Bui(x)
}

export create_bababui(x: large, y: large) {
	=> Bababui(x, y)
}

export is_when(object: Boo) {
	=> when(object) {
		is Bababui bababui => bababui.value(),
		is Baba baba => baba.value(),
		is Bui bui => bui.value(),
		else => -1
	}
}

export range_when(x: large) {
	=> when(x) {
		> 10 => x * x,
		<= -7 => 2 * x,
		else => x
	}
}

init() {
	are_equal(49, numerical_when(7))
	are_equal(9, numerical_when(3))
	are_equal(-1, numerical_when(1))

	are_equal(42, numerical_when(42))
	are_equal(-100, numerical_when(-100))
	are_equal(0, numerical_when(0))

	are_equal(0, string_when(String('Foo')))
	are_equal(1, string_when(String('Bar')))
	are_equal(2, string_when(String('Baz')))
	are_equal(-1, string_when(String('Bababui')))

	boo = create_boo()
	baba = create_baba(42)
	bui = create_bui(777)
	bababui = create_bababui(-123, 321)

	are_equal(-1, is_when(boo))
	are_equal(1764, is_when(baba))
	are_equal(1554, is_when(bui))
	are_equal(4856409, is_when(bababui))

	are_equal(10, range_when(10))
	are_equal(121, range_when(11))
	are_equal(10000, range_when(100))
	are_equal(-6, range_when(-6))
	are_equal(-14, range_when(-7))
	are_equal(-16, range_when(-8))
	are_equal(-84, range_when(-42))
	are_equal(3, range_when(3))
	=> 0
}