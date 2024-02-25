$Arguments = './libv/', './libv/allocator/allocator.v', './libv/windows-x64/', 'min.math.obj', 'min.memory.obj', 'min.tests.obj', '-static', '-o', 'core', '-windows'

./v0.exe $Arguments

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "core.lib" -PathType Leaf) )
{
	Write-Output red "Failed to build the core library"
	Exit 1
}