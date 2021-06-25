Pair<Tk, Tv> {
	key: Tk
	value: Tv

	init(key: Tk, value: Tv) {
		this.key = key
		this.value = value
	}
}

Bundle {
	private objects: List<Pair<String, link>>
	private integers: List<Pair<String, large>>
	private decimals: List<Pair<String, decimal>>
	private bools: List<Pair<String, bool>>

	init() {
		objects = List<Pair<String, link>>()
		integers = List<Pair<String, large>>()
		decimals = List<Pair<String, decimal>>()
		bools = List<Pair<String, bool>>()
	}

	# Summary: Returns whether the specified list contains the specified name
	private contains(name: String, list) {
		loop i in list {
			if (i.key == name) => true
		}

		=> false
	}

	# Summary: Tries to find an element with the specified name from the specified list
	private find<T>(name: String, list) {
		loop i in list {
			if (i.key == name) => Optional<T>(i.value)
		}

		=> Optional<T>()
	}

	# Summary: Stores an object with the specified name
	put(name: String, value: link) {
		if contains(name, objects) => false
		objects.add(Pair<String, link>(name, value))
		=> true
	}

	# Summary: Stores an integer with the specified name
	put(name: String, value: large) {
		if contains(name, integers) => false
		integers.add(Pair<String, large>(name, value))
		=> true
	}

	# Summary: Stores a decimal with the specified name
	put(name: String, value: decimal) {
		if contains(name, decimals) => false
		decimals.add(Pair<String, decimal>(name, value))
		=> true
	}

	# Summary: Stores a bool with the specified name
	put(name: String, value: bool) {
		if contains(name, bools) => false
		bools.add(Pair<String, bool>(name, value))
		=> true
	}
	
	# Summary: Tries to find an object with the specified name
	get_object(name: String) {
		=> find<link>(name, objects)
	}
	
	# Summary: Tries to find an integer with the specified name
	get_integer(name: String) {
		=> find<large>(name, integers)
	}
	
	# Summary: Tries to find a decimal with the specified name
	get_decimal(name: String) {
		=> find<decimal>(name, decimals)
	}
	
	# Summary: Tries to find a bool with the specified name
	get_bool(name: String) {
		=> find<bool>(name, bools)
	}

	# Summary: Tries to find an object with the specified name, if it is not found, this function returns the specified fallback value
	get_object(name: String, fallback: link) {
		if find<link>(name, objects) has result => result
		=> fallback
	}
	
	# Summary: Tries to find an integer with the specified name, if it is not found, this function returns the specified fallback value
	get_integer(name: String, fallback: large) {
		if find<large>(name, integers) has result => result
		=> fallback
	}
	
	# Summary: Tries to find a decimal with the specified name, if it is not found, this function returns the specified fallback value
	get_decimal(name: String, fallback: decimal) {
		if find<decimal>(name, decimals) has result => result
		=> fallback
	}
	
	# Summary: Tries to find a bool with the specified name, if it is not found, this function returns the specified fallback value
	get_bool(name: String, fallback: bool) {
		if find<bool>(name, bools) has result => result
		=> fallback
	}

	# Summary: Returns whether the bundle contains an object with the specified name
	contains_object(name: String) {
		=> contains(name, objects)
	}
	
	# Summary: Returns whether the bundle contains an integer with the specified name
	contains_integer(name: String) {
		=> contains(name, integers)
	}
	
	# Summary: Returns whether the bundle contains a decimal with the specified name
	contains_decimal(name: String) {
		=> contains(name, decimals)
	}
	
	# Summary: Returns whether the bundle contains a bool with the specified name
	contains_bool(name: String) {
		=> contains(name, bools)
	}
}