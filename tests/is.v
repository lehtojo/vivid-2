Entity {}

Entity Person {
	name: String
	skill: large
	likes_driving: bool
	likes_riding: bool

	init(name: link, skill: large, likes_driving: bool, likes_riding: bool) {
		this.name = String(name)
		this.skill = skill
		this.likes_driving = likes_driving
		this.likes_riding = likes_riding
	}
}

Usable {
	open likes(entity: Entity): bool
}

Usable Vehicle {
	speed: decimal
	weight: large
	acceleration: decimal
	passengers: small

	time(distance: decimal) {
		return sqrt(2 * distance / acceleration)
	}

	open skill(): large
	open reliability(): large
}

Drivable {}
Ridable {}

Ridable Vehicle Pig {

	init() {
		speed = 7
		weight = 100
		acceleration = 3
		passengers = 1
	}

	override skill() {
		return 1
	}

	override reliability() {
		return -1
	}

	override likes(entity: Entity) {
		return entity is Person person and person.likes_riding
	}
}

Drivable Vehicle Car {

	init() {
		speed = 55
		weight = 1500
		acceleration = 5.555
		passengers = 5
	}

	override skill() {
		return 10
	}

	override reliability() {
		return 100
	}

	override likes(entity: Entity) {
		return entity is Person person and person.likes_driving
	}
}

Usable Entity Banana {
	override likes(entity: Entity) {
		return true
	}
}

Drivable Vehicle Bus {
	init() {
		speed = 40
		weight = 4000
		acceleration = 2.5
		passengers = 40
	}

	override skill() {
		return 40
	}

	override reliability() {
		return 100
	}

	override likes(entity: Entity) {
		return entity is Person person and person.likes_driving
	}
}

export can_use(entity: Entity, usable: Usable) {
	if not usable.likes(entity) {
		return false
	}
	else usable is Vehicle vehicle and entity is Person person {
		return person.skill >= vehicle.skill()
	}

	return false
}

export get_reliable_vehicles(usables: Array<Usable>, min_reliability: large) {
	vehicles = List<Vehicle>()

	loop (i = 0, i < usables.size, i++) {
		if usables[i] is Vehicle {
			vehicles.add(usables[i] as Vehicle)
		}
	}

	loop (i = vehicles.size - 1, i >= 0, i--) {
		if vehicles[i].reliability() < min_reliability {
			vehicles.remove_at(i)
		}
	}

	return vehicles
}

export choose_vehicle(entity: Entity, vehicles: List<Vehicle>, distance: large) {
	return choose_vehicle(entity, vehicles, distance as decimal)
}

export choose_vehicle(entity: Entity, vehicles: List<Vehicle>, distance: decimal) {
	if entity is Person person and person.name == 'Steve' {
		return Pig() as Vehicle
	}

	chosen_vehicle = vehicles[]
	minimum_time = vehicles[].time(distance)

	loop (i = 1, i < vehicles.size, i++) {
		vehicle = vehicles[i]
		time = vehicle.time(distance)

		if time < minimum_time {
			chosen_vehicle = vehicle
			minimum_time = time
		}
	}

	return chosen_vehicle
}

export create_pig() {
	return Pig()
}

export create_bus() {
	return Bus()
}

export create_car() {
	return Car()
}

export create_banana() {
	return Banana()
}

export create_john() {
	return Person('John', 10, true, false)
}

export create_max() {
	return Person('Max', 7, true, true)
}

export create_gabe() {
	return Person('Gabe', 50, true, false)
}

export create_steve() {
	return Person('Steve', 1, false, true)
}

export create_array(size: large) {
	return Array<Usable>(size)
}

export set(array: Array<Usable>, usable: Usable, i: large) {
	array[i] = usable
}

export is_pig(vehicle: Vehicle) {
	return vehicle is Pig
}

init() {
	pig = create_pig()
	bus = create_bus()
	car = create_car()
	banana = create_banana()

	john = create_john()
	max = create_max()
	gabe = create_gabe()
	steve = create_steve()

	array = create_array(4)
	set(array, pig, 0)
	set(array, bus, 1)
	set(array, car, 2)
	set(array, banana, 3)

	are_equal(false, can_use(john, pig))
	are_equal(false, can_use(john, bus))
	are_equal(true, can_use(john, car))
	are_equal(false, can_use(john, banana))

	are_equal(true, can_use(max, pig))
	are_equal(false, can_use(max, bus))
	are_equal(false, can_use(max, car))
	are_equal(false, can_use(max, banana))

	are_equal(false, can_use(gabe, pig))
	are_equal(true, can_use(gabe, bus))
	are_equal(true, can_use(gabe, car))
	are_equal(false, can_use(gabe, banana))

	are_equal(true, can_use(steve, pig))
	are_equal(false, can_use(steve, bus))
	are_equal(false, can_use(steve, car))
	are_equal(false, can_use(steve, banana))

	get_reliable_vehicles(array, -1000000)

	vehicles = get_reliable_vehicles(array, 10)

	are_equal(car as Vehicle as link, choose_vehicle(john, vehicles, 7000) as link)
	are_equal(car as Vehicle as link, choose_vehicle(max, vehicles, 1000) as link)
	are_equal(car as Vehicle as link, choose_vehicle(gabe, vehicles, 3000) as link)

	vehicle = choose_vehicle(steve, vehicles, 3000)

	are_equal(true, is_pig(vehicle))
	return 0
}