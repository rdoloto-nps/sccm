$mwrnode= Get-CimInstance -ClassName  SMS_ObjectContainerNode -Filter "Name='MWR'and ObjectType=6000" -Namespace root/sms/site_NE1 -ComputerName INPRESTCMNE1
$Msnode= Get-CimInstance -ClassName  SMS_ObjectContainerNode -Filter "Name='Microsoft'and ObjectType=6000" -Namespace root/sms/site_NE1 -ComputerName INPRESTCMNE1
  

$POSHFolder = New-CimInstance -ClassName SMS_ObjectContainerNode -Property @{Name="powershell";ObjectType=6000;ParentContainerNodeid=$Msnode.ContainerNodeID;SourceSite="NE1"}  -Namespace root/sms/site_NE1 -ComputerName INPRESTCMNE1