#!/bin/bash
arguments=("./" "./entries/vivid.v" "./optimizer/" "./tests/assert.v" "./libv/" "./libv/linux-x64/" "./libv/allocator/allocator.v" "./min.math.o" "./min.memory.o" "./min.system.o" "./min.tests.o")

if [ ! -f ./v0 ]; then
	echo "Building the zeroth stage..."

	Vivid ${arguments[@]} -o v0 -d

	if [[ $? != 0 ]]; then
		echo "Failed to compile the zeroth stage"
		exit 1
	fi

	chmod +x v0

	echo "Successfully built the zeroth stage"
fi

echo "Building the first stage..."

v0 ${arguments[@]} -o v1 -linux

if [[ $? != 0 ]]; then
	echo "Failed to compile the first stage"
	exit 1
fi

echo "Successfully built the first stage"
