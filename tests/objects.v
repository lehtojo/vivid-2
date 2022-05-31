Apple {
	weight = 100
	price = 0.1
}

Car {
	weight = 2000000
	brand = 'Flash'
	price: decimal

	init(p: decimal) {
		price = p
	}
}

export create_apple() {
	=> Apple()
}

export create_car(price: decimal) {
	=> Car(price)
}

init() {
	apple = create_apple()
	are_equal(100, apple.weight)
	are_equal(0.1, apple.price)

	car = create_car(20000)
	are_equal(2000000, car.weight)
	are_equal(20000.0, car.price)

	are_equal('Flash', car.brand, 0, 5)
	=> 0
}