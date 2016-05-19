
function set-dppriority{
<#$
	.SYNOPSIS
 Changes the DP priority  from standard 200 to whatever you set it in the setvalue paramater.  


	.DESCRIPTION
     Changes the DP priority  from standard 200 to whatever you set it in the setvalue paramater.  This is done via WMI on primary server 
	.EXAMPLE
	set-dppriority -server inpmwroxvm2 -setvalue 150 -sitecode ABC -primary sccmprimarysvr
	.Parameter computer  
	Server name of the server you will be changing 
   .parameter setvalue 
    set the value in the distribution point info to what you specify 
   .parameter  sitecode
	SCCM primary site code 
   .parameter primary
	SCCM primary server name 
	 
	.Notes
	 changed from enter-pssession to invoke command in this version 

	.LINK
	http://inpmwroxvm2:8080/tfs/Powershell/_git/NPSREPOSITORY#path=%2FMISC&version=GBmaster&_a=contents

	#>



 [CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1 )]
   [string]$server,
   [Parameter(Mandatory=$True,Position=2 )]
  [string]$setvalue,
 [Parameter(Mandatory=$True,Position=3 )]
	[string]$sitecode,
 [Parameter(Mandatory=$True,Position=4 )]
	[string]$primary

     )


 

$fqdns= $server+'.nps.doi.net'
$fqdns
$targetDp='\\\\'+$fqdns

$property="Priority"
$dp = gwmi -computer $primary -namespace "root\sms\site_$sitecode" -query "select * from SMS_SCI_SysResUse where RoleName = 'SMS Distribution Point' and NetworkOSPath = '$targetDp'" 
 
$props = $dp.Props  
 
 $prop = $props | where {$_.PropertyName -eq $property}


Write-Output "Current DistributionPoint Priority = " $prop.Value
$prop.Value = $setvalue


Write-Output "Updating the DistributionPoint Priority to = " $setvalue
$dp.props= $props
$dp.put()

 

 
 




}