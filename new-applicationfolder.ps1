#will add foldertypes

$mwrnode= Get-CimInstance -ClassName  SMS_ObjectContainerNode -Filter "Name='Production'and ObjectType=6000" -Namespace root/sms/site_NE1 -ComputerName INPRESTCMNE1

 $mwrnode 

$POSHFolder = New-CimInstance -ClassName SMS_ObjectContainerNode -Property @{Name="IBM";ObjectType=6000;ParentContainerNodeid=$mwrnode.ContainerNodeID;SourceSite="NE1"}  -Namespace root/sms/site_NE1 -ComputerName INPRESTCMNE1