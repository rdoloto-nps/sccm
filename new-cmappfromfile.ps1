function new-appfromfile
{
[CmdletBinding()]
	
	param (

[Parameter( Mandatory=$True,Position=1 )][string]$directory,
[Parameter( Mandatory=$True,Position=2 )][validateset("AKR","DEN","HQ","IMR","NPS","MWR","NCR","NER","PWR","SER")][string]$region,
[Parameter( Mandatory=$True,Position=3 )][validateset("NPS-MWR","NPS-MWR-MWRO")][string]$DPG,
[Parameter( Mandatory=$True,Position=4 )][string]$vendor,
[Parameter( Mandatory=$True,Position=5 )][validateset("MSI","MSU" )] [string] $installtype
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
  Import-Module get-msiInfo
   $msidir=$directory+'\files'
        Switch ($installtype) {
             "MSI" {
 
  
write-host  "this is the directory for msi installations $msidir"

 $currmsi=(Get-ChildItem -path $msidir  *.msi).FullName
write-host  "this is the msi for  installations $currmsi"  
$msipguid=Get-MSIinfo -Path $currmsi -Property ProductCode
Write-host "The following guid was found  $msipguid and it will be used for detection method script"
   $Script = @"
  if  ( get-wmiobject  -Query "select * from WIn32_product where IdentifyingNumber ='$msipguid'"){        Write-Host "Installed"} else {}
"@
}
           
            "MSU"{
           Write-host "You have chosen MSU running quick engineering mode" 
            
           $msufiles=Get-ChildItem -path $msidir *.msu
           $firstmsu=$msufiles[0].Name 
           $kb=$firstmsu.Split("-")
           $kbid= $kb[1]
           Write-Host "the following will $kbid be used for detection method " 

             $Script = @"
  if  ( get-wmiobject  -Query "Select * from WIN32_QuickFixEngineering where HotFixID  ='$kbid'"){        Write-Host "Installed"} else { }
"@
}
           }
        }
    


 

 


#import cm
 
 
 PROCESS   {
 $CMModulePath = $Env:SMS_ADMIN_UI_PATH.ToString().SubString(0,$Env:SMS_ADMIN_UI_PATH.Length - 5) + "\ConfigurationManager.psd1" 
 
import-module $CMModulePath 
Set-Location NE1:
 
        if ((Get-Location).Provider.Name -ne 'CMSite') {
        
         Write-Error -Message "Not Connected to a CMSite PSDrive"   { Write-Error -Message "Not Connected to a CMSite PSDrive" -ErrorAction Stop }
        
 
 } 
    #settings appliations

        $ApplicationFullName=  $appVendor  + " " +$appName   + " " +$appVersion  + " " +$appArch
    $ApplicationFullName=$ApplicationFullName.trim()

    #application Name 

    
      $NewCMApplication = @{
        'Name' = $ApplicationFullName
        'Owner' = $appScriptAuthor
        'SupportContact' = $appScriptAuthor
        'Publisher' = $appVendor
        'SoftwareVersion' = $appVersion
        }
 
        
 #deployment method

 
 
     $AddCMDeploymentTypeParams = @{
                    'ApplicationName' = $ApplicationFullName;
                     'ScriptType' = 'PowerShell';
                    'ScriptContent'=$Script;
                    'DeploymentTypeName' = $appName + " " + 'Install';
                    'ScriptInstaller' = $true;
                    'ManualSpecifyDeploymentType' = $true;
                    'InstallationProgram' = 'Deploy-Application.EXE -DeploymentType Install -DeployMode Silent';
                    'UninstallProgram' = 'Deploy-Application.EXE -DeploymentType Uninstall -DeployMode Silent';
                    'ContentLocation' = $directory;
                    'InstallationBehaviorType' = 'InstallForSystem';
                    'InstallationProgramVisibility' = 'Hidden';
                    'MaximumAllowedRunTimeMinutes' = '120';
                    'LogonRequirementType'='WhetherOrNotUserLoggedOn';
                    'EstimatedInstallationTimeMinutes' = '60';
                    'DetectDeploymentTypeByCustomScript' = $true;
                    'AllowClientsToUseFallbackSourceLocationForContent'=$True;
                    'AllowClientsToShareContentOnSameSubnet'=$True;
                    'OnSlowNetworkMode'='Download';

                                       
                    
                    }


 
 
 
   
  
 
 
Write-Host -Message "Creating $ApplicationFullName application container..."
        
 New-CMApplication @NewCMApplication -ErrorAction Stop | Out-Null	
Write-host -Message "Creating Deployment  method for $ApplicationFullName...."
 
   Add-CMDeploymentType @AddCMDeploymentTypeParams   -Verbose
 
$app =(Get-CMApplication -Name "$ApplicationFullName" | select LocalizedDisplayName).LocalizedDisplayName
write-host -message "Distributing applications $app"
Start-CMContentDistribution -ApplicationName "$app" -DistributionPointGroupName $DPG
 
 
 


 

 }
 
End{Set-Location C:

 
Set-Location c:
$APPScopeID = Get-WmiObject -Namespace Root\SMS\Site_NE1 -Class SMS_ApplicationLatest -Filter "LocalizedDisplayName='$ApplicationFullName'" -ComputerName inprestcmne1
$TargetFolderID = Get-WmiObject -Namespace Root\SMS\Site_NE1 -Class SMS_ObjectContainerNode -Filter "Name='$vendor'and ObjectType=6000" -ComputerName inprestcmne1
$CurrentFolderID = 0
$ObjectTypeID = 6000

$WMIConnection = [WMIClass]"\\inprestcmne1\root\SMS\Site_NE1:SMS_objectContainerItem"
    $MoveItem = $WMIConnection.psbase.GetMethodParameters("MoveMembers")
    $MoveItem.ContainerNodeID = $CurrentFolderID
    $MoveItem.InstanceKeys = $APPScopeID.ModelName
    $MoveItem.ObjectType = $ObjectTypeID
    $MoveItem.TargetContainerNodeID = $TargetFolderID.ContainerNodeID
$WMIConnection.psbase.InvokeMethod("MoveMembers",$MoveItem,$null)
 

}
}

 
 
