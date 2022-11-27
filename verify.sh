#!/bin/bash
# Arguments passed to the compilers
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

if [[ $# > 0 ]]; then
	echo "Additional arguments: $@"
	arguments+=("$@")
fi

echo "Building the first stage..."

v0 ${arguments[@]} -o v1

if [[ $? != 0 ]]; then
	echo "Failed to compile the first stage"
	exit 1
fi

chmod +x v1

echo "Successfully built the first stage"
echo "Building the second stage..."

v1 ${arguments[@]} -o v2

if [[ $? != 0 ]]; then
	echo "Failed to compile the second stage"
	exit 1
fi

chmod +x v2

echo "Successfully built the second stage"

first_stage_hash=`sha256sum v1 | grep -o "^\w* "`
second_stage_hash=`sha256sum v2 | grep -o "^\w* "`

echo "Stage 1 hash: $first_stage_hash"
echo "Stage 2 hash: $second_stage_hash"

# Compare the hashes of the first and second stages
if [[ "$first_stage_hash" != "$second_stage_hash" ]]; then
	echo "Verification failed"
	exit 1
fi

echo "Verification succeeded"
