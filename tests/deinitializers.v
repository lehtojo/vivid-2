plain LocalHeapAllocator {
	allocations: List<link>

	init() {
		this.allocations = List<link>()
	}

	allocate(size: u64): link {
		allocation = global.allocate(size)
		allocations.add(allocation)
		return allocation
	}

	deallocate(allocation: link): _ {
		loop (i = 0, i < allocations.size, i++) {
			if allocations[i] !== allocation continue

			allocations.remove_at(i)
			global.deallocate(allocation)
			return
		}

		panic('Attempted to deallocate memory that was not allocated with this allocator')
	}

	deallocate(): _ {
		loop allocation in allocations {
			global.deallocate(allocation)
		}
	}
}

$local_heap_allocator!() {
	$allocator = LocalHeapAllocator()

	deinit {
		console.write_line('Deallocating...')
		$allocator.deallocate()
	}

	$allocator
}

test_1(n: u64): u64 {
	console.write_line('Test 1: Start')

	# This should be executed at the end of this function
	deinit { console.write_line('Test 1: End') }

	# This allocator should be deallocated at the end of this function before the return value
	allocator = local_heap_allocator!()

	numbers = allocator.allocate(sizeof(u64) * n) as u64*
	numbers[0] = 0
	numbers[1] = 1

	loop (i = 2, true, i++) {
		if i == n return numbers[n - 1]

		numbers[i] = numbers[i - 2] + numbers[i - 1]
	}
}

test_2(): _ {
	console.write_line('Test 2: Start')

	# This should be executed at the end of this function
	deinit { console.write_line('Test 2: End') }

	loop (i = 0, true, i++) {
		# These two deinitializers should be executed at stop, continue and at the end of this scope 
		deinit { console.write_line('tock') }
		deinit { console.write('Tick ') }

		if i >= 4 stop
		if i % 2 == 0 continue
	}
}

init() {
	result = test_1(8)
	deinit { console.write_line('Exiting...') }
	test_2()
	console.write('Number: ')
	console.write_line(result)
	return 0
}