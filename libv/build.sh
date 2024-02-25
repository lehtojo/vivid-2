arguments=('./libv/' './libv/allocator/allocator.v' './libv/linux-x64/' './min.math.o' './min.memory.o' './min.system.o' './min.tests.o' '-static' '-o' 'core' '-linux')

./v0 "${arguments[@]}"

# Verify the compiler exited successfully and the output file was created
if [ $? -ne 0 ] || [ ! -f "core.a" ]; then
    echo -e "\e[31mFailed to build the core library\e[0m"
    exit 1
fi
