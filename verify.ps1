$Mode = $args[0]
$Additionals = $args[1..($args.Count)]

if ( $Additionals.Count -gt 0 ) {
	Write-Output "Additional arguments: $Additionals"
}

if ($Mode -eq 'coreless') {
	Write-Output "Verifying without core library"

	$Arguments = './', './entries/vivid.v', './optimizer/', './tests/assert.v', './libv/', './libv/windows-x64/', './libv/allocator/allocator.v', './min.math.obj', './min.memory.obj', './min.tests.obj', '-l', 'kernel32.dll'
	$Arguments += $Additionals
	./verify-base.ps1 @Arguments
} elseif ($Mode -eq 'core') {
	Write-Output "Verifying with core library"

	$Arguments = './', './entries/vivid.v', './optimizer/', './tests/assert.v', '-l', 'core', '-l', 'kernel32.dll'
	$Arguments += $Additionals
	./verify-base.ps1 @Arguments
} else {
	Write-Output "Verifying all configurations"

	# Verify using debug mode and all optimization levels without the core library
	./verify.ps1 coreless
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	./verify.ps1 coreless -d
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	./verify.ps1 coreless -O1
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	./verify.ps1 coreless -O2
	if ($LASTEXITCODE -ne 0) { Exit 1 }
	
	# Verify using debug mode and all optimization levels with the core library
	./verify.ps1 core
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	# ./verify.ps1 core -d
	# if ($LASTEXITCODE -ne 0) { Exit 1 }

	./verify.ps1 core -O1
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	./verify.ps1 core -O2
	if ($LASTEXITCODE -ne 0) { Exit 1 }

	Write-Output "Done"
}