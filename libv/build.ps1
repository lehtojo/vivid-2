$Arguments = './libv/', './libv/allocator/allocator.v', './libv/windows-x64/', 'min.math.obj', 'min.memory.obj', 'min.tests.obj', '-static', '-o', 'core'

./v0.exe $Arguments

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "core.lib" -PathType Leaf) )
{
	Write-ColorOutput red "Failed to build the core library"
	Clean
	Exit 1
}