
 function setsmscache

 { <#$
	.SYNOPSIS
  changes the sms size to 25gb for via script for on  the fly adjustment  


	.DESCRIPTION
    changes the rsms cache on remote computer to 25gb

	.EXAMPLE
	setsmscache -computer INPTAPR000021 
	.Parameter computer  
	computer name which  you will change  com entry for SMS cache

	 
	.Notes
	 changed from enter-pssession to invoke command in this version 
	.LINK
	http://inpmwroxvm2:8080/tfs/Powershell/_git/NPSREPOSITORY#path=%2FMISC&version=GBmaster&_a=contents

	#>
 [CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1 )]
   [string]$computer
     )
   Invoke-Command -ComputerName $computer -ScriptBlock {
        
      $CCM = New-Object -com UIResource.UIResourceMGR 
     $size=25600
          ($ccm.GetCacheInfo()).totalsize = $Size   
          
        
    
    }
    }
    
    setsmscache -computer INPMWRO62870 
     
     
