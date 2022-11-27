# Arguments passed to the compilers
$Arguments = './', './entries/vivid.v', './optimizer/', './tests/assert.v', './libv/', './libv/windows-x64/', './libv/allocator/allocator.v', './min.math.obj', './min.memory.obj', './min.tests.obj', '-l', 'kernel32.dll'

function Write-ColorOutput($ForegroundColor)
{
	# Save the current color
	$PreviousForegroundColor = $host.UI.RawUI.ForegroundColor

	# Set the new color
	$host.UI.RawUI.ForegroundColor = $ForegroundColor

	# Write the output
	if ($args)
	{
		Write-Output $args
	}
	else
	{
		$input | Write-Output
	}

	# Restore the original color
	$host.UI.RawUI.ForegroundColor = $PreviousForegroundColor
}

if ( !(Test-Path "v0.exe" -PathType Leaf) )
{
	Write-ColorOutput blue "Building the zeroth stage..."

	Vivid $Arguments -o v0 -d

	if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "v0.exe" -PathType Leaf) )
	{
		Write-ColorOutput red "Failed to build the zeroth stage"
		Exit 1
	}

	Write-ColorOutput green "Successfully built the zeroth stage"
}

Write-ColorOutput blue "Building the first stage..."

./v0.exe $Arguments -o v1

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "v1.exe" -PathType Leaf) )
{
	Write-ColorOutput red "Failed to build the first stage"
	Exit 1
}

Write-ColorOutput green "Successfully built the first stage"
