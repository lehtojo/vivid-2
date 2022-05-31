Animal {
	energy: small = 100
	hunger: tiny = 0

	move() {
		--energy
		++hunger
	}
}

Fish {
	speed: small = 1
	velocity: small = 0
	weight: small = 1500

	swim(animal: Animal) {
		animal.move()
		velocity = speed
	}

	float() {
		velocity = 0
	}
}

Animal Fish Salmon {
	is_hiding = false

	init() {
		speed = 5
		weight = 5000
	}

	hide() {
		float()
		is_hiding = true
	}

	stop_hiding() {
		swim(this)
		is_hiding = false
	}
}

export get_animal() {
	=> Animal()
}

export get_fish() {
	=> Fish()
}

export get_salmon() {
	=> Salmon()
}

export animal_moves(animal: Animal) {
	animal.move()
}

export fish_moves(fish: Fish) {
	if (fish as Salmon).is_hiding == false {
		fish.swim(fish as Salmon)
	}
}

export fish_swims(animal: Animal) {
	(animal as Salmon).swim(animal)
}

export fish_stops(animal: Animal) {
	(animal as Salmon).float()
}

export fish_hides(salmon: Salmon) {
	fish_moves(salmon)
	salmon.hide()
}

export fish_stops_hiding(salmon: Salmon) {
	salmon.stop_hiding()
	salmon.swim(salmon)
}

Salmon_Gang {
	size = 1

	init(size) {
		this.size = size
	}
}

init() {
	animal = get_animal()
	are_equal(100, animal.energy)
	are_equal(0, animal.hunger)

	fish = get_fish()
	are_equal(1, fish.speed)
	are_equal(0, fish.velocity)
	are_equal(1500, fish.weight)

	salmon = get_salmon()
	are_equal(false, salmon.is_hiding)
	are_equal(5000, salmon.weight)

	animal_moves(salmon)
	are_equal(99, salmon.energy)
	are_equal(1, salmon.hunger)

	fish_moves(salmon)
	are_equal(5, salmon.speed)
	are_equal(5, salmon.velocity)
	are_equal(98, salmon.energy)
	are_equal(2, salmon.hunger)

	fish_swims(salmon)
	are_equal(5, salmon.speed)
	are_equal(5, salmon.velocity)
	are_equal(97, salmon.energy)
	are_equal(3, salmon.hunger)

	fish_stops(salmon)
	are_equal(5, salmon.speed)
	are_equal(0, salmon.velocity)

	fish_hides(salmon)
	are_equal(5, salmon.speed)
	are_equal(0, salmon.velocity)
	are_equal(96, salmon.energy)
	are_equal(4, salmon.hunger)
	are_equal(true, salmon.is_hiding)

	# The fish should not move since it is hiding
	fish_moves(salmon)
	are_equal(5, salmon.speed)
	are_equal(0, salmon.velocity)
	are_equal(96, salmon.energy)
	are_equal(4, salmon.hunger)
	are_equal(true, salmon.is_hiding)

	fish_stops_hiding(salmon)
	are_equal(5, salmon.speed)
	are_equal(5, salmon.velocity)
	are_equal(94, salmon.energy)
	are_equal(6, salmon.hunger)
	are_equal(false, salmon.is_hiding)
	=> 0
}