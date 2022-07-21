import large_function()

export multi_return(a: large, b: large) {
	large_function()

	if a > b {
		return 1
	}
	else a < b {
		return -1
	}
	else {
		return 0
	}
}

init() {
	are_equal(1, multi_return(7, 1))
	are_equal(0, multi_return(-1, -1))
	are_equal(-1, multi_return(5, 20))
	return 0
}