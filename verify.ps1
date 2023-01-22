$Mode = $args[0]
$Additionals = $args[1..($args.Count)]

if ( $Additionals.Count -gt 0 ) {
	Write-Output "Additional arguments: $Additionals"
}

if ($Mode -eq 'full') {
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
	Write-Output "Usage: full/core"
	Exit 1
}