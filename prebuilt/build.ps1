$Arguments = './windows-x64/', '-objects'

../v0.exe $Arguments

# Verify the compiler exited successfully and the output file was created
if ( ($LASTEXITCODE -ne 0) -or !(Test-Path "prebuilt.obj" -PathType Leaf) )
{
	Write-Output "Failed to build"
	Exit 1
}