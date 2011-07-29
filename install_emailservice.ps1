$ftp = "C:\Inetpub\ftproot"
$zips = @(ls $ftp\* -Include *.7z)

if(@($zips).Count -lt 1)
{	
	throw new-object System.Exception("No zip files in the root")
}

if(@($zips).Count -gt 1)
{	
	throw new-object System.Exception("More than one zip file in the root")
}

$version = [System.IO.Path]::GetFileNameWithoutExtension($zips[0])

if(!($version -match "^emailservice-\d\.\d\.\d")) 
{
	throw New-Object system.Exception("Wrongly named email service zip")
}

ls  c:\Inetpub\ftproot | where {$_.Extension -ne '.7z'}| Remove-Item -Recurse -force

net stop $version

& "C:\Program Files\7-Zip\7z.exe" X $zips[0].FullName

rm $zips[0].FullName -Force

$destination = [System.String]::Format("D:\services\{0}", $version)

Write-Host "Copying files to " + $destination
cp C:\Inetpub\ftproot\* $destination -Recurse -Force

rm $destination\logs -rec -force

net start $version

rm C:\inetpub\ftproot\* -rec -force

Write-Host "waiting 5 seconds for service to start!"

[System.Threading.Thread]::Sleep(5000)

notepad $destination\logs\CurrentLog.txt

