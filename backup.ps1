$ftp = "C:\Inetpub\ftproot"
$zips = @(ls $ftp\* -Include *.7z)
$client = [System.IO.Path]::GetFileNameWithoutExtension($zips[0])
$backup = [string]::Format("D:\backups\{0}", $client)
$live = [string]::Format("D:\www\{0}", $client)

Write-Host file $zips[0].FullName
Write-Host client $client

if(@($zips).Count -lt 1)
{	
	throw new-object System.Exception("No zip files in the root")
}

if(@($zips).Count -gt 1)
{	
	throw new-object System.Exception("More than one zip file in the root")
}

ls  $ftp | where {$_.Extension -ne '.7z'}| Remove-Item -Recurse -force

rm $backup -force -recurse

mkdir $backup

Write-Host backing up from $live to $backup

cp $live\* $backup\ -force -recurse

Write-Host back up finished!
& "C:\Program Files\7-Zip\7z.exe" X $zips[0].FullName

rm $zips[0].FullName

Write-Host "Copying to " + $live

cp $ftp\* $live -rec -force

Write-Host deleting deployment
rm $ftp\* -Recurse -Force

Write-Host finished!