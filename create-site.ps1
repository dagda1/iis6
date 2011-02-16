### <summary>  
### Sets the .NET framework version for a given website.  
### Must be executed on the IIS server.  
### </summary>  
### <param name="strID">Website ID</param>  
function Set-FrameWorkVersion($strID)  
{  
    $strPath = (Get-ChildItem Env:windir).Value + '\Microsoft.NET\Framework\'  
      
    $objDir = Get-ChildItem $strPath |  
              where { ($_.GetType().ToString().ToLower() -eq 'system.io.directoryinfo') -and  
                      ($_.name -match "^(v4.[\d\.]+)$")} |  
              sort name  	
			  			  
    if ($objDir -ne $null)  
    {  
		Write-Host "Found framework directory $objDir.Name"
        $strPath += $matches[1]  
        $strPath += "\aspnet_regiis.exe"  
        $objSI = New-Object System.Diagnostics.ProcessStartInfo  
        $objSI.UseShellExecute = $false  
        $objSI.FileName = $strPath  
        $objSI.Arguments = "-s $strID/Root"  
        $objSI.RedirectStandardOutput = $true  
        $objP = [System.Diagnostics.Process]::Start($objSI)  
        $objP.WaitForExit()  
    }  
}  

### <summary>  
### Ensure directories are installed  
### </summary> 
function Init($SourcePath, $VirDirPath, $TeachMePath)
{
	if(!(Test-Path $SourcePath))
	{
		Write-Host "Creating directory " + $SourcePath
		New-Item $SourcePath -type directory
	}
	
	if(!(Test-Path $VirDirPath))
	{
		Write-Host "Creating directory " + $VirDirPath
		New-Item $VirDirPath -type directory	
	}
	
	if(!(Test-Path $TeachMePath))
	{
		Write-Host "Creating directory $TeachMePath"
		New-Item $TeachMePath -type directory
	}	
}

 
### <summary>  
### Installs the IIS website.  
### </summary>  
### <param name="Server">Server's name hosting website</param>  
### <param name="WebSiteName">Web site name</param>  
### <param name="Port">Website port</param>  
### <param name="SourcePath">Path of root virtual directory</param>  
### <param name="VirDirPath">Virtual directory for store directory</param> 
### <param name="AppPoolName">Application name</param> 
### <param name="HostName">Host header</param> 
### <param name="TeachMePath">Teach me virtual directory path</param> 
function Install-WebServer($Server, $WebSiteName, $Port, $SourcePath, $VirDirPath, $AppPoolName, $HostName, $TeachMePath)  
{  
	Init $SourcePath $VirDirPath $TeachMePath
    $locator = New-Object -com WbemScripting.SWbemLocator  
    $provider = $locator.ConnectServer($Server, 'root/MicrosoftIISv2')  
    $iis = $provider.Get("IIsWebService='W3SVC'")  
    $serverBindings = @($provider.Get('ServerBinding').SpawnInstance_())  
    $serverBindings[0].Properties_.Item('Port').value = $Port  
	$serverBindings[0].Properties_.Item('Hostname').value = $HostName
    $createNewSiteMethod = $iis.Methods_.Item('CreateNewSite')  
  
    $inParameters = $createNewSiteMethod.InParameters.SpawnInstance_()  
    $inParameters.Properties_.Item('PathOfRootVirtualDir').value = $SourcePath  
    $inParameters.Properties_.Item('ServerBindings').value = $serverBindings  
    $inParameters.Properties_.Item('ServerComment').value = $WebSiteName  
     
    # Creating new WebSite '$strWebSiteName'  
    $outParameters = $iis.ExecMethod_("CreateNewSite", $inParameters)  
 
    # Getting website ID  
    $id = ''  
    $outParameters.properties_ | % {  
        $id = $_.Value -match "[^']'([^']+)'.*"  
        if ($id) { $id = $matches[1] }  
    }  
	
	Write-Host "website id = $id"		
	
	# Configuring Website '$WebSiteName'  
    $site = [ADSI]"IIS://$Server/$id/Root"  
    $site.Put("DefaultDoc", "Default.aspx")  
    $site.Put("AppPoolId", $AppPoolName)  
	$site.put("AuthFlags", 3)  
    $site.Put("AppFriendlyName", $WebSiteName)  
    $site.Put("AccessFlags", 1)  
    $site.Put("AccessRead", $true)  
	$site.Put("AccessWrite", $true)  
    $site.Put("AccessScript", $true)  
	$site.Put("AuthAnonymous", $true)  
	$site.Put("AuthBasic", $false) 
	$site.Put("AuthNTLM", $true) 
    #$site.Put("AccessExecute", $true)  
    $site.SetInfo()	
 
	# If we are on the web server itself  
    if ((Get-ChildItem env:COMPUTERNAME).Value.ToUpper() -eq $Server.ToUpper())  
    {  
    	Set-FrameWorkVersion $id  
	}  
		
	# create virtual directory
	$storedir = Create-VirtualDir $site "store" $VirDirPath			
	
	# create child virtual directory
	Create-VirtualDir $storedir "TeachMe" $TeachMePath
		
	# set ssl properties
	Set-SSLWildcard $Server $id $HostName
		
	# start website	
}  

function Set-SSLWildcard($server, $appid, $hostname)
{
	$site = New-Object System.DirectoryServices.DirectoryEntry("IIS://$Server/W3SVC/$appid")
	$bindings = [array]$site.psbase.Properties["SecureBindings"].Value

	$newBinding = ":443:$hostname"
	if($bindings -eq $null)
	{
		$newBindings = @($newBinding)
	}
	else
	{
		$newBindings = @($newBinding) + $bindings
	}
		
	$site.psbase.Properties["SecureBindings"].Value = $newBindings
	$site.psbase.CommitChanges()
}

function Create-VirtualDir($Parent, $FriendlyName, $VirPath)
{
	$newdir = $Parent.Create("IISWebVirtualDir", $FriendlyName)
	[Void]$newdir.Put("Path", $VirPath)
	[Void]$newdir.Put("AccessRead", $true)
	[Void]$newdir.Put("AccessWrite",$true)
	[Void]$newdir.Put("AccessScript", $true)  
	[Void]$newdir.AppCreate2(1) 
	[Void]$newdir.Put("AppFriendlyName", $FriendlyName)		
	[Void]$newdir.SetInfo()
	return $newdir
}

  
Install-WebServer -Server (Get-ChildItem env:COMPUTERNAME).Value -WebSiteName 'northumbria' -Port 80 -SourcePath 'D:\www\northumbria'  -VirDirPath 'E:\northumbria\store' -AppPoolName 'net-40-II' -HostName 'northumbriahealthcare.continuity2.com' -TeachMePath 'E:\TeachMe'
