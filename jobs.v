namespace jobs

plain Worker {
	pid: u64
	file: String

	init(pid: u64, file: String) {
		this.pid = pid
		this.file = file
	}

	wait(): u64 {
		return io.wait_for_exit(pid)
	}
}

# Summary: Removes the job argument from the specified arguments
remove_job_argument(arguments: List<String>): _ {
	loop (i = 0, i < arguments.size, i++) {
		argument = arguments[i]
		if not (argument == '-j' or argument == '-jobs') continue

		# Remove the job argument and the number of jobs
		arguments.remove_all(i, i + 2)
		return
	}
}

# Summary: Starts a new compiler worker for the specified source file
start_worker(compiler: String, file: String, arguments: List<String>): Worker {
	process_arguments = List<String>(arguments)
	process_arguments.add("-objects")
	process_arguments.add("-filter")
	process_arguments.add(file)

	pid = io.start_process(compiler, process_arguments)

	return Worker(pid, file)
} 

# Summary: Executes compilation using jobs if they are requested
execute(): _ {
	# Do nothing if jobs should not be created
	jobs = settings.jobs
	if jobs == 0 return

	# Load arguments ready that we need to pass to new processes
	compiler = io.get_process_filename()
	arguments = io.get_command_line_arguments()

	# Remove the job argument as we do not want infinite processes...
	remove_job_argument(arguments)

	# Load the source files to be built
	files = settings.filenames

	# Track progress
	number_of_files = files.size
	number_of_compiled_files = 0

	# Compute the number of files to compile based on the remaining number of files and maximum jobs
	batch = min(files.size, jobs)
	workers = List<Worker>(batch, false)

	loop (i = 0, i < batch, i++) {
		workers.add(start_worker(compiler, files[i], arguments))
	}

	files.remove_all(0, batch)

	loop (workers.size > 0) {
		pids = workers.map<large>((i: Worker) -> i.pid)
		exit_information = io.wait_for_any_to_exit(pids)

		# Todo: Place a new flag here
		if true {
			console.write_line("Compiled " + to_string(++number_of_compiled_files) + " of " + to_string(number_of_files) + " files")
		}

		# If the worker failed, report the failure
		if exit_information.exit_code != 0 {
			worker = workers[exit_information.index]
			abort("Failed to compile: " + worker.file)
		}

		# Remove the worker now that it has finished
		workers.remove_at(exit_information.index)

		# Start a new worker if we still have files
		if files.size > 0 {
			workers.add(start_worker(compiler, files[0], arguments))
			files.remove_at(0)
		}
	}

	application.exit(0)
}