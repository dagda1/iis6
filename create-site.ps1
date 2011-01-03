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
function Install-WebServer($Server, $WebSiteName, $Port, $SourcePath, $VirDirPath, $AppPoolName, $HostName, $TeachMePath)  
{  
	Init $SourcePath $VirDirPath $TeachMePath
    $objLocator = New-Object -com WbemScripting.SWbemLocator  
    $objProvider = $objLocator.ConnectServer($Server, 'root/MicrosoftIISv2')  
    $objService = $objProvider.Get("IIsWebService='W3SVC'")  
    $objBindings = @($objProvider.Get('ServerBinding').SpawnInstance_())  
    $objBindings[0].Properties_.Item('Port').value = $Port  
	$objBindings[0].Properties_.Item('Hostname').value = $HostName
    $createNewSiteMethod = $objService.Methods_.Item('CreateNewSite')  
  
    $objInParameters = $createNewSiteMethod.InParameters.SpawnInstance_()  
    $objInParameters.Properties_.Item('PathOfRootVirtualDir').value = $SourcePath  
    $objInParameters.Properties_.Item('ServerBindings').value = $objBindings  
    $objInParameters.Properties_.Item('ServerComment').value = $WebSiteName  
     
    # Creating new WebSite '$strWebSiteName'  
    $objOutParameters = $objService.ExecMethod_("CreateNewSite", $objInParameters)  
 
    # Getting website ID  
    $id = ''  
    $objOutParameters.properties_ | % {  
        $id = $_.Value -match "[^']'([^']+)'.*"  
        if ($id) { $id = $matches[1] }  
    }  
	
	Write-Host "website id = $id"
	
    if ($id.ToUpper() -match "^W3SVC/\d+$")  
    {  
		Write-Host "Web site Id = $id"
	
		# Configuring Website '$WebSiteName'  
        $objSite = [ADSI]"IIS://$Server/$id/Root"  
        $objSite.Put("DefaultDoc", "Default.aspx")  
        $objSite.Put("AppPoolId", $AppPoolName)  
		$objsite.put("AuthFlags", 3)  
        $objsite.Put("AppFriendlyName", $WebSiteName)  
        $objsite.Put("AccessFlags", 1)  
        $objsite.Put("AccessRead", $true)  
		$objsite.Put("AccessWrite", $true)  
        $objsite.Put("AccessScript", $true)  
		$objsite.Put("AuthAnonymous", $true)  
		$objsite.Put("AuthBasic", $false) 
		$objsite.Put("AuthNTLM", $true) 
        #$objsite.Put("AccessExecute", $true)  
        $objSite.SetInfo()	

 
        # If we are on the web server itself  
        if ((Get-ChildItem env:COMPUTERNAME).Value.ToUpper() -eq $Server.ToUpper())  
        {  
        	Set-FrameWorkVersion $id  
		}  
		
		
		# create virtual directory
		$newdir = $objSite.Create("IISWebVirtualDir", "store")
		$newdir.Put("Path", $VirDirPath)
		$newdir.Put("AccessRead",$true)
		$newdir.Put("AccessWrite",$true)
		$newdir.Put("AccessScript", $true)  
		$newdir.AppCreate2(1) 
		$newdir.Put("AppFriendlyName", "store")
		$newdir.SetInfo()		
		
		# create child virtual directory
		$childdir = $newdir.Create("IISWebVirtualDir", "TeachMe")
		$childdir.Put("Path", $TeachMePath)
		$childdir.Put("AccessRead",$true)
		$childdir.Put("AccessWrite",$true)
		$childdir.Put("AccessScript", $true) 
		$childdir.AppCreate2(1) 
		$childdir.Put("AppFriendlyName", "TeachMe")		
		$childdir.SetInfo()
		
		# set ssl properties
		
		# start website
    }  
}  

function Create-VirtualDir($Parent, $FriendlyName, $VirPath)
{
	$newdir = $Parent.Create("IISWebVirtualDir", $FriendlyName)
	$newdir.Put("Path", $VirPath)
	$newdir.Put("AccessRead", $true)
	$newdir.Put("AccessWrite",$true)
	$newdir.Put("AccessScript", $true)  
	$childdir.AppCreate2(1) 
	$childdir.Put("AppFriendlyName", $FriendlyName)		
	$newdir.SetInfo()
	return $newdir
}

  
Install-WebServer -Server (Get-ChildItem env:COMPUTERNAME).Value -WebSiteName 'bupa' -Port 80 -SourcePath 'c:\www\bupa'  -VirDirPath 'C:\www\bupa\store' -AppPoolName 'dotnet40' -HostName 'test.continuity2.com' -TeachMePath 'C:\www\teachme'
