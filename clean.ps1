$Files = Get-ChildItem -Path "." -Filter "v1.*" -ErrorAction SilentlyContinue
$Files += Get-ChildItem -Path "." -Filter "v2.*" -ErrorAction SilentlyContinue
$Files += Get-ChildItem -Path "." -Filter "t1.*" -ErrorAction SilentlyContinue
$Files += Get-ChildItem -Path "." -Filter "unit_*" -ErrorAction SilentlyContinue

if ($Files)
{
	foreach ($File in $Files)
	{
		Remove-Item $File -Force -ErrorAction SilentlyContinue
	}
}