$CMModulePath = $Env:SMS_ADMIN_UI_PATH.ToString().SubString(0,$Env:SMS_ADMIN_UI_PATH.Length - 5) + "\ConfigurationManager.psd1" 
import-module $CMModulePath  
Set-location NE1:
$programs=Get-CMProgram -PackageId NE1000C5 | select ProgramName
$SiteServer="INPRESTCMNE1"
foreach($program in $programs)
{$pn=$program.programname
 $deploy=Get-CMDeployment -ProgramName "$pn" | select DeploymentID
 $dep=$deploy.DeploymentID
  $advertFilter = "AdvertisementID='$dep'"
  $advertFilter
   Get-WmiObject -Class SMS_Advertisement -Namespace root\sms\site_NE1 -ComputerName inprestcmne1 -filter $advertFilter |  % {$_.Delete()}
 
}