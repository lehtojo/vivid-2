# Arguments passed to the compilers
$Arguments = './', './entries/vivid.v', './optimizer/', './tests/assert.v', './libv/', './libv/windows-x64/', './libv/allocator/allocator.v', './minimum.math.obj', './minimum.memory.obj', './minimum.tests.obj', '-a', '-l', 'kernel32.dll'
# Should the script remove the build files?
$Clean = $true

if ( $args.Count -gt 0 ) {
	Write-Output "Additional arguments: $args"
	$Arguments += $args
}

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

function Clean()
{
	if (!$Clean) { return }

	# Delete all files starting with "v1." and "v2."
	$Files = Get-ChildItem -Path "." -Filter "v1.*" -ErrorAction SilentlyContinue
	$Files += Get-ChildItem -Path "." -Filter "v2.*" -ErrorAction SilentlyContinue

	if ($Files)
	{
		foreach ($File in $Files)
		{
			Remove-Item $File -Force -ErrorAction SilentlyContinue
		}
	}
}

# Remove build files from previous runs
Clean

Write-ColorOutput blue "Building the first stage..."
./build/vc.exe $Arguments -o v1

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "v1.exe" -PathType Leaf) )
{
	Write-ColorOutput red "Failed to build the first stage"
	Clean
	Exit 1
}

Write-ColorOutput green "Successfully built the first stage"

Write-ColorOutput blue "Building the second stage..."
./v1.exe $Arguments -o v2

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "v2.exe" -PathType Leaf) )
{
	Write-ColorOutput red "Failed to build the second stage"
	Clean
	Exit 1
}

Write-ColorOutput green "Successfully built the second stage"

$FirstStageHash = (Get-FileHash v1.exe).Hash
$SecondStageHash = (Get-FileHash v2.exe).Hash

Write-Output "Stage 1 hash: $FirstStageHash"
Write-Output "Stage 2 hash: $SecondStageHash"

# Compare the hashes of the first and second stages
if ( $FirstStageHash -ne $SecondStageHash )
{
	Write-ColorOutput red "Verification failed"
	Clean
	Exit 1
}

Write-ColorOutput green "Verification succeeded"
Clean
Exit 0
