namespace jobs

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

	i = 0

	loop (i < files.size) {
		# Compute the number of remaining files to compile
		remaining = files.size - i

		# Compute the number of files to compile based on the remaining number of files and maximum jobs
		batch = min(remaining, jobs)

		# Save the process ids of next batch
		pids = List<u64>(batch, false)

		# Compile the next batch of files.
		loop (batch > 0, batch--) {
			# Start a new process to compile the next file
			process_arguments = List<String>(arguments)
			process_arguments.add("-objects")
			process_arguments.add("-filter")
			process_arguments.add(files[i++])

			pid = io.start_process(compiler, process_arguments)

			# Save the process id
			pids.add(pid)
		}

		# Wait for the next batch of files to finish
		loop pid in pids {
			# Wait for the process to exit
			exit_code = io.wait_for_exit(pid)

			# Check if the process finished successfully
			if exit_code == 0 continue

			abort('Failed to compile a source file')
		}
	}

	application.exit(0)
}