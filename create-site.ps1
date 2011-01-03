### <summary>  
### Creates the IIS application pool.  
### </summary>  
### <param name="Server">Server's name hosting website</param>  
### <param name="AppPoolName">Application pool name</param>  
### <param name="Domain">Domain short name</param>  
### <param name="SAM">User's SAMAccountName</param>  
### <param name="Password">User's password</param>  
function Create-ApplicationPool([string]$Server, [string]$AppPoolName,  
                                [string]$Domain, [string]$SAM, [string]$Password)  
{  
    trap [Exception]  
    {  
        $bln = $false  
        continue  
    }  
    $bln = $false  
     
    # Check if an application pool with the same name already exists  
    $objApp = [ADSI]"IIS://$Server/W3SVC/AppPools/$AppPoolName"  
    if ($objApp.distinguishedname -eq $null)  
    {  
        # Creating application pool  
        $objApp = [ADSI]"IIS://$Server/W3SVC/AppPools"  
        $objPool = $objapp.Create("IIsApplicationPool", $AppPoolName)  
        $objPool.Put('AppPoolIdentityType', 3)  

 
        # Setting Application pool credentials to $SAM  
        $objPool.Put('WAMUserName', "$Domain\$SAM")  
        $objPool.Put('WAMUserPass', $strPassword)  
        $objPool.SetInfo()  

 
        # Adding user $SAM to group IIS_WPG  
        $objGroup = [ADSI]"WinNT://$Server/IIS_WPG"  
        $objGroup.Add("WinNT://$Domain/$SAM")  
        $bln = $true  
    }  
      
    return $bln  
}  

 
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
                      ($_.name -match "^(v2.[\d\.]+)$")} |  
              sort name  
    if ($objDir -ne $null)  
    {  
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
### Installs the IIS website.  
### </summary>  
### <param name="Server">Server's name hosting website</param>  
### <param name="WebSiteName">Web site name</param>  
### <param name="Port">Website port</param>  
### <param name="SourcePath">Path of root virtual directory</param>  
function Install-WebServer($Server, $WebSiteName, $Port, $SourcePath)  
{  
    $objLocator = New-Object -com WbemScripting.SWbemLocator  
    $objProvider = $objLocator.ConnectServer($Server, 'root/MicrosoftIISv2')  
    $objService = $objProvider.Get("IIsWebService='W3SVC'")  
    $objBindings = @($objProvider.Get('ServerBinding').SpawnInstance_())  
    $objBindings[0].Properties_.Item('Port').value = $Port  
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
	
	Write-Host $id
	
    if ($id.ToUpper() -match "^W3SVC/\d+$")  
    {  
        # Creating new Application Pool '$WebSiteName'  
        $bln = Create-ApplicationPool $Server $WebSiteName 'mydomain' 'myuser' 'P@ssw0rd'  
  
        if ($bln)  
        {  
            # Configuring Website '$WebSiteName'  
            $objSite = [ADSI]"IIS://$Server/$id/Root"  
            $objSite.Put("DefaultDoc", "Default.aspx")  
            $objSite.Put("AppPoolId", $WebSiteName)  
            $objsite.put("AuthFlags", 4)  
            $objsite.Put("AppFriendlyName", $WebSiteName)  
            $objsite.Put("AccessFlags", 1)  
            $objsite.Put("AccessRead", $true)  
            $objsite.Put("AccessScript", $true)  
            $objsite.Put("AccessExecute", $true)  
            $objSite.SetInfo()  

 
            # If we are on the web server itself  
            if ((Get-ChildItem env:COMPUTERNAME).Value.ToUpper() -eq $Server.ToUpper())  
            {  
                Set-FrameWorkVersion $id  
            }  
        }  
    }  
}  
  
Install-WebServer -Server "." -WebSiteName 'My WebSite Name' -Port 8080 -SourcePath 'c:\inetpub\wwwroot\myWebSite'  
