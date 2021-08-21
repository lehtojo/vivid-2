# Tests whether the two integer statements will be converted into decimal return statements
export automatic_number_conversion(a: large) {
	if a > 0
		=> 2 * a
	else a < 0
		=> a
	else
		=> 1.0
}

# Tests whether integer to decimal cast works
export casts_1(a: large) {
	=> a as decimal
}

# Tests whether decimal to integer cast works
export casts_2(a: decimal) {
	=> a as large
}

# Tests boolean cast
export casts_3(a: large) {
	=> a as bool
}

Foo {
	a: tiny
	b: small

	init(a, b) {
		this.a = a
		this.b = b
	}
}

Bar {
	c: normal
	d: large

	init(c, d) {
		this.c = c
		this.d = d
	}

	virtual bar(): decimal
}

Foo Bar Baz {
	e: decimal

	init(x: decimal) {
		Foo.init(x, x + 1)
		Bar.init(x + 2, x + 3)
		
		e = x + 4
	}

	override bar() {
		if a + b == c + d {
			=> a + b
		}

		=> c + d
	}
}

# Creates an instance of Baz and returns it
export create_baz() {
	=> Baz(0.0)
}

# Creates an instance of the type Baz and tests whether the inner assignment statements work since they require conversions from the input type decimal
export casts_4(x: decimal) {
	=> Baz(x)
}

# Tests whether base class casts work
export casts_5(baz: Baz) {
	=> baz as Foo
}

# Tests whether base class casts work
# NOTE: Here the base class is actually in the middle of the allocated memory so the compiler must add some offset to the pointer
export casts_6(baz: Baz) {
	=> baz as Bar
}

# Tests whether the compiler automatically casts the Baz object into a Bar object since it will be the return type
export automatic_cast_1(baz: Baz) {
	if baz.e >= 1.0 => baz

	=> Bar(baz.e, baz.e)
}

# Tests whether the return statements in the implementation of the function bar will obey the declared return type decimal.
# In addition, the compiler must cast the self pointer to type Bar.
export automatic_cast_2(baz: Baz) {
	=> baz.bar()
}

# Tests whether the loaded tiny from the specified address will be converted into a large integer
export automatic_conversion_1(a: link) {
	if a => a[0]

	=> 0
}

# Tests whether the loaded small from the specified address will be converted into a large integer
export automatic_conversion_2(a: link<small>) {
	if a => a[0]

	=> 0
}

# Tests whether the loaded normal from the specified address will be converted into a large integer
export automatic_conversion_3(a: link<normal>) {
	if a => a[0]

	=> 0
}

# Tests whether the loaded large from the specified address will be converted into a large integer
export automatic_conversion_4(a: link<large>) {
	if a => a[0]

	=> 0
}

# Tests whether the loaded decimal from the specified address will be converted into a large integer
export automatic_conversion_5(a: link<decimal>) {
	if a => a[0] as large

	=> 0
}

B {
	x: large
	y: small
	z: decimal
}

A {
	b: B
}

export assign_addition_1(a: large, b: large, i: A, j: large) {
	a += b
	i.b.x += j
	i.b.y += j
	i.b.z += j
	=> a
}

export assign_subtraction_1(a: large, b: large, i: A, j: large) {
	a -= b
	i.b.x -= j
	i.b.y -= j
	i.b.z -= j
	=> a
}

export assign_multiplication_1(a: large, b: large, i: A, j: large) {
	a *= b
	i.b.x *= j
	i.b.y *= j
	i.b.z *= j
	=> a
}

export assign_division_1(a: large, b: large, i: A, j: large) {
	a /= b
	i.b.x /= j
	i.b.y /= j
	i.b.z /= j
	=> a
}

export assign_remainder_1(a: large, b: large, i: A, j: large) {
	a %= b
	i.b.x %= j
	i.b.y %= j
	# Remainder operation is not defined for decimal values
	=> a
}

export assign_bitwise_and_1(a: large, b: large, i: A, j: large) {
	a &= b
	i.b.x &= j
	i.b.y &= j
	# Bitwise operations are not defined for decimal values
	=> a
}

export assign_bitwise_or_1(a: large, b: large, i: A, j: large) {
	a |= b
	i.b.x |= j
	i.b.y |= j
	# Bitwise operations are not defined for decimal values
	=> a
}

export assign_bitwise_xor_1(a: large, b: large, i: A, j: large) {
	a ¤= b
	i.b.x ¤= j
	i.b.y ¤= j
	# Bitwise operations are not defined for decimal values
	=> a
}

export assign_multiplication_2(a: large, b: large, c: large, d: large, i: A, j: A, k: A, l: A) {
	a *= 2
	b *= 5
	c *= 51
	d *= -8

	i.b.x *= 2
	i.b.y *= 2
	i.b.z *= 2

	j.b.x *= 5
	j.b.y *= 5
	j.b.z *= 5

	k.b.x *= 51
	k.b.y *= 51
	k.b.z *= 51

	l.b.x *= -8
	l.b.y *= -8
	l.b.z *= -8

	=> a * b * c * d
}

export assign_division_2(a: large, b: large, c: large, d: large, i: A, j: A, k: A, l: A) {
	a /= 2
	b /= 5
	c /= 51
	d /= -8

	i.b.x /= 2
	i.b.y /= 2
	i.b.z /= 2

	j.b.x /= 5
	j.b.y /= 5
	j.b.z /= 5

	k.b.x /= 51
	k.b.y /= 51
	k.b.z /= 51

	l.b.x /= -8
	l.b.y /= -8
	l.b.z /= -8

	=> a * b * c * d
}

init() {
	are_equal(6.0, automatic_number_conversion(3))
	are_equal(-15.0, automatic_number_conversion(-15))
	are_equal(1.0, automatic_number_conversion(0))

	are_equal(7.0, casts_1(7))
	are_equal(123, casts_2(123.456))
	are_equal(100, casts_3(100))

	result = casts_4(100)
	are_equal(100, result.a)
	are_equal(101, result.b)
	are_equal(102, result.c)
	are_equal(103, result.d)
	are_equal(104.0, result.e)

	baz = create_baz()
	are_equal(baz as link, casts_5(baz) as link)
	are_equal(baz as Bar as link, casts_6(baz) as link)

	baz.e = -3.0
	are_not_equal(baz as Bar as link, automatic_cast_1(baz) as link)

	baz.e = 2.5
	are_equal(baz as Bar as link, automatic_cast_1(baz) as link)

	baz.a = 10
	baz.b = 1000
	baz.c = 505
	baz.d = 505

	are_equal(1010.0, automatic_cast_2(baz))

	baz.c = 0
	are_equal(505.0, automatic_cast_2(baz))

	(baz as link<decimal>)[0] = 3.14159
	are_equal((baz as link<tiny>)[0], automatic_conversion_1(baz as link<tiny>))
	are_equal((baz as link<small>)[0], automatic_conversion_2(baz as link<small>))
	are_equal((baz as link<normal>)[0], automatic_conversion_3(baz as link<normal>))
	are_equal((baz as link<large>)[0], automatic_conversion_4(baz as link<large>))
	are_equal(3, automatic_conversion_5(baz as link<decimal>))

	are_equal(0, automatic_conversion_1(none as link))
	are_equal(0, automatic_conversion_2(none as link))
	are_equal(0, automatic_conversion_3(none as link))
	are_equal(0, automatic_conversion_4(none as link))
	are_equal(0, automatic_conversion_5(none as link))

	b = B()
	b.x = 66
	b.y = 33
	b.z = 99.99

	a = A()
	a.b = b

	are_equal(8, assign_addition_1(3, 5, a, 2))
	are_equal(68, b.x)
	are_equal(35, b.y)
	are_equal(101.99, b.z)

	are_equal(-13, assign_subtraction_1(-3, 10, a, 2))
	are_equal(66, b.x)
	are_equal(33, b.y)
	are_equal(99.99, b.z)

	are_equal(143, assign_multiplication_1(11, 13, a, -144))
	are_equal(-9504, b.x)
	are_equal(-4752, b.y)
	are_equal(-14398.56, b.z)

	are_equal(-17, assign_division_1(493, -29, a, -48))
	are_equal(198, b.x)
	are_equal(99, b.y)
	are_equal(299.96999999999997, b.z)

	are_equal(2, assign_remainder_1(11, 3, a, 10))
	are_equal(8, b.x)
	are_equal(9, b.y)

	are_equal(66191461, assign_bitwise_or_1(66191360, 101, a, 18834)) # (1010 <| 16) | 101L ... (1010 <| 16, 101, a, 0x4992)
	are_equal(18842, b.x) # 8 | 0x4992
	are_equal(18843, b.y) # 9 | 0x4992

	are_equal(0, assign_bitwise_and_1(528280977408, 21037056, a, 8466)) # (123 <| 32) & (321 <| 16) ... (123 <| 32, 321 <| 16, a, 0x2112)
	are_equal(274, b.x) # (8 | 0x4992) & 0x2112
	are_equal(274, b.y) # (9 | 0x4992) & 0x2112

	are_equal(1, assign_bitwise_xor_1(15996, 15997, a, 274)) # 0x3E7C, 0x3E7D, a, 0x0112
	are_equal(0, b.x)
	are_equal(0, b.y)

	ib = B()
	ib.x = 9
	ib.y = 16
	ib.z = 9.16

	i = A()
	i.b = ib

	jb = B()
	jb.x = 36
	jb.y = 49
	jb.z = 36.49

	j = A()
	j.b = jb

	kb = B()
	kb.x = 2809
	kb.y = 2916
	kb.z = 2809.2916

	k = A()
	k.b = kb

	lb = B()
	lb.x = 49
	lb.y = 36
	lb.z = 49.36

	l = A()
	l.b = lb

	are_equal(-181950390720, assign_multiplication_2(9, 36, 2809, 49, i, j, k, l))

	are_equal(18, ib.x)
	are_equal(32, ib.y)
	are_equal(18.32, ib.z)

	are_equal(180, jb.x)
	are_equal(245, jb.y)
	are_equal(182.45, jb.z)

	are_equal(143259, kb.x)
	are_equal(17644, kb.y)
	are_equal(143273.8716, kb.z)

	are_equal(-392, lb.x)
	are_equal(-288, lb.y)
	are_equal(-394.88, lb.z)

	are_equal(-22400, assign_division_2(100, 40, 357, 64, i, j, k, l))

	are_equal(9, ib.x)
	are_equal(16, ib.y)
	are_equal(9.16, ib.z)

	are_equal(36, jb.x)
	are_equal(49, jb.y)
	are_equal(36.49, jb.z)

	are_equal(2809, kb.x)
	are_equal(345, kb.y)
	are_equal(2809.2916000000005, kb.z)

	are_equal(49, lb.x)
	are_equal(36, lb.y)
	are_equal(49.36, lb.z)
	=> 1
}