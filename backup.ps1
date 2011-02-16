$backup = [string]::Format("D:\backups\{0}", $args[0])
$live = [string]::Format("D:\www\{0}", $args[0])
Write-Host deleting backup $backup
rm $backup -force -recurse
mkdir $backup
Write-Host backing up from $live to $backup
cp $live\* $backup\ -recurse
Write-Host finished!
