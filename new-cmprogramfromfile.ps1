function new-programfromfile
{
[CmdletBinding()]
	
	param (

[Parameter( Mandatory=$True,Position=1 )][string]$directory,
[Parameter( Mandatory=$True,Position=2 )][validateset("AKR","DEN","HQ","IMR","NPS","MWR","NCR","NER","PWR","SER")][string]$region,
[Parameter( Mandatory=$True,Position=3 )][validateset("NPS-MWR","NPS-MWR-MWRO","NPS-MWR-MWRO")][string]$DPG,
[Parameter( Mandatory=$True,Position=4 )][string]$vendor,
[Parameter( Mandatory=$True,Position=5 )][validateset("Install","Uninstall")][string]$DeploymentType
 
)
 BEGIN  {

$file="Deploy-Application.ps1"
$a=$directory+'\'+$file
write-host  "loading new app from following directory $directory"
$a=Get-Content $a -TotalCount 100 -Wait | where {$_.Contains('[string]$app')}
 
$apparray=$a.Split('=')
$appVendor=$apparray[1].Replace("'","")
$appName=$apparray[3].Replace("'","")
$appVersion=$apparray[5].Replace("'","")
$appArch=$apparray[7].Replace("'","")
$appLang=$apparray[9].Replace("'","")
$appRevision=$apparray[11].Replace("'","")
$appScriptVersion=$apparray[13].Replace("'","")
$appScriptDate=$apparray[15].Replace("'","")
$appScriptAuthor=$apparray[17].Replace("'","")

 
}
 
 PROCESS   {
 $CMModulePath = $Env:SMS_ADMIN_UI_PATH.ToString().SubString(0,$Env:SMS_ADMIN_UI_PATH.Length - 5) + "\ConfigurationManager.psd1" 
 
import-module $CMModulePath 
Set-Location NE1:

        if ((Get-Location).Provider.Name -ne 'CMSite') {
        
         Write-Error -Message "Not Connected to a CMSite PSDrive"   { Write-Error -Message "Not Connected to a CMSite PSDrive" -ErrorAction Stop }
        
 
 } 
    #settings program

        $ApplicationFullName=  $appVendor  + " " +$appName   + " " +$appVersion  + " " +$appArch
    $ApplicationFullName=$ApplicationFullName.trim()


      $NewCMPackage= @{
        'Name' = $ApplicationFullName
        'Manufacturer' = $appVendor
        'Version' = $appVersion
        'Path'=$directory
        }
    $NewCMPackage
Write-Host -Message "Creating $ApplicationFullName Package  "
New-CMPackage @NewCMPackage -ErrorAction Stop | Out-Null	
$cmpackageid=Get-CMPackage -Name $ApplicationFullName | select PackageID
$cmpackageid=$cmpackageid.PackageID
$cmpackageid

Write-Host -Message "Creating $ApplicationFullName Program  "
$newCMprogram = @{
    'PackageId'= $cmpackageid
    'StandardProgramName'= $ApplicationFullName 
    'CommandLine'= "Deploy-Application.EXE /32 -DeploymentType ""$DeploymentType""  -DeployMode ""NonInteractive"""
    'RunType'= "Hidden"
    'RunMode'= "RunWithAdministrativeRights"
    'DiskSpaceRequirement'= "100"
    'Duration'= "30"
    'ProgramRunType' = "WhetherOrNotUserIsLoggedOn" 
    'UserInteraction'= $false 

}
$newCMprogram
New-CMProgram  @newCMprogram -ErrorAction Stop   | Out-Null	


Write-Host -Message "Distribute  $ApplicationFullName Program to $DPG  "
Start-CMContentDistribution -PackageId "$cmpackageid" -DistributionPointGroupName $DPG

}
 
End {Set-Location c:


 
$APPScopeID = Get-WmiObject -Namespace Root\SMS\Site_NE1 -Class SMS_ApplicationLatest -Filter "LocalizedDisplayName='$ApplicationFullName'" -ComputerName inprestcmne1
$TargetFolderID = Get-WmiObject -Namespace Root\SMS\Site_NE1 -Class SMS_ObjectContainerNode -Filter "Name='$vendor'and ObjectType=2" -ComputerName inprestcmne1
$CurrentFolderID = 0
$ObjectTypeID = 2

$WMIConnection = [WMIClass]"\\inprestcmne1\root\SMS\Site_NE1:SMS_objectContainerItem"
    $MoveItem = $WMIConnection.psbase.GetMethodParameters("MoveMembers")
    $MoveItem.ContainerNodeID = $CurrentFolderID
    $MoveItem.InstanceKeys = $APPScopeID.ModelName
    $MoveItem.ObjectType = $ObjectTypeID
    $MoveItem.TargetContainerNodeID = $TargetFolderID.ContainerNodeID
$WMIConnection.psbase.InvokeMethod("MoveMembers",$MoveItem,$null)

}

}