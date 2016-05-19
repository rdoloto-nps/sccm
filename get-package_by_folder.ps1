 function get-CMPackagebyfolder{ 

 <#$
	.SYNOPSIS
 List all the folderss in CM and the packages in the folder


	.DESCRIPTION
  List all the folderss in CM and the packages in the folder done by  wmi from coretech using for finding obselete object and list package ide 
	.EXAMPLE
	get-CMPackagebyfolder -ServerName INPRESTCMNE1 -SiteName NE1
	.Parameter ServerName  
	Server Name of the Primary
    .Parameter SiteName    
	Site NAMe
	.Notes
	 originally posted by coretech 
	.LINK
	http://blog.coretech.dk/jgs/how-to-list-configmgr-package-structure-in-powershell/

	#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1 )]
   [string]$ServerName,
      [Parameter(Mandatory=$True,Position=2)]
   [string]$SiteName
     )


cls

#//----------------------------------------------------------------------------
#//  Procedures
#//----------------------------------------------------------------------------

function ListFolderPackages([string]$strPath,[string]$folderID,[switch]$rootFolder)
{
	if ($rootfolder)
	{
		$Subfolders = Get-WmiObject -ComputerName $ServerName -Namespace "root\sms\site_$SiteName" -Query "SELECT Name,ContainerNodeID,ParentContainerNodeID FROM SMS_ObjectContainerNode WHERE SearchFolder = 0 AND ObjectType = 2 AND ParentContainerNodeID = 0 ORDER BY ContainerNodeID"
	}
	else
	{
		$Subfolders = Get-WmiObject -ComputerName $ServerName -Namespace "root\sms\site_$SiteName" -Query "SELECT Name,ContainerNodeID,ParentContainerNodeID FROM SMS_ObjectContainerNode WHERE SearchFolder = 0 AND ObjectType = 2 AND ParentContainerNodeID = $folderID ORDER BY ContainerNodeID"
	}
	if ($Subfolders -ne $null)
	{
		foreach ($folder in $Subfolders)
		{
			$strNewPath = $strPath + $folder.Name
			$strNewPath

			$packagesInFolder = $locationInfo | where {$_.ContainerNodeID -eq $folder.ContainerNodeID}

			if ($packagesInFolder -ne $null)
			{
				foreach ($packageinFolder in $packagesInFolder)
				{
					$package = $packagesInfo | where { $_.PackageID -eq $packageinFolder.InstanceKey }
					"`t{0} - ({1})" -f $package.Name, $package.PackageID
				}
			}
			else
			{
				"Contains no packages"
			}
			#ListSubFolders
			ListFolderPackages -strPath "$strNewPath\" -folderID  $folder.ContainerNodeID
		}
	}
}

#//----------------------------------------------------------------------------
#//  Main routines
#//----------------------------------------------------------------------------

#get package info (name etc.) once to keep load on server as low as possible.
$packagesInfo = Get-WmiObject -ComputerName $ServerName -Namespace "root\sms\site_$SiteName" -class SMS_Package

#get package and folder location info once to keep server load as low as possible
$locationInfo = Get-WmiObject -ComputerName $ServerName -Namespace "root\sms\site_$SiteName" -class SMS_ObjectContainerItem

ListFolderPackages -strPath "\" -folderID 0 -rootFolder

#//----------------------------------------------------------------------------
#//  End Script
#//----------------------------------------------------------------------------
}