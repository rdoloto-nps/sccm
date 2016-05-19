#========================================================================
# Created by:   Dustin Hedges
# Filename:     Download-DellDriverPacks.ps1
# Version: 		1.0.0.1
# Comment: 		This script will download the latest available Dell Driver
# 				Catalog file from the web, search for any matching OS or
# 				Model strings and download the appropriate Dell Driver
# 				CAB Files to the specified Download Folder.
#========================================================================
<#
.Synopsis
   Downloads the latest available Driver CAB files from Dell
.DESCRIPTION
   Downloads the latest Dell Driver Catalog file (unless a local copy is supplied) and downloads any new Driver CAB's listed in that catalog.
.EXAMPLE
   .\Download-DellDriverPacks.ps1 -DownloadFolder "E:\Dell\Drivers\DellCatalog" -TargetModel "Latitude E7240" -Verbose

.EXAMPLE
   .\Download-DellDriverPacks.ps1 -DownloadFolder "E:\Dell\Drivers\DellCatalog" -TargetOS 64-bit_-_WinPE_5.0 -Verbose

.EXAMPLE
   .\Download-DellDriverPacks.ps1 -DownloadFolder "E:\Dell\Drivers\DellCatalog" -TargetModel "Latitude E7440" -TargetOS Windows_8.1_64-bit -Verbose
#>
[CmdletBinding()]
Param
(
	[Parameter(Mandatory = $false,
			   ValueFromPipelineByPropertyName = $true,
			   Position = 0,
			   HelpMessage = "DriverPackCatalog.cab file.  By default will download from http://downloads.dell.com")]
	[string]$DriverCatalog = "http://downloads.dell.com/catalog/DriverPackCatalog.cab",
	
	[Parameter(Mandatory = $true,
			   ValueFromPipelineByPropertyName = $true,
			   Position = 1)]
	[string]$DownloadFolder,
	
	[Parameter(Mandatory = $false,
			   ValueFromPipelineByPropertyName = $true,
			   Position = 2,
			   HelpMessage = "The Model of System you wish to download files for.  Example: Latitude E7240.")]
	[string]$TargetModel = "WinPE",
	
	[Parameter(Mandatory = $false,
			   ValueFromPipelineByPropertyName = $true,
			   Position = 3,
			   HelpMessage = "The Operating System you wish to download files for.")]
	[ValidateSet("Windows_PE_3.0_x86", "Windows_PE_3.0_x64", "Windows_PE_4.0_x86", "Windows_PE_4.0_x64", "Windows_PE_5.0_x86", "Windows_PE_5.0_x64", "Windows_Vista_x64", "Windows_Vista_x64", "Windows_XP", "Windows_7_x86", "Windows_7_x64", "Windows_8_x86", "Windows_8_x64", "Windows_8.1_x86", "Windows_8.1_x64")]
	[string]$TargetOS,
	
	[Parameter(Mandatory = $false,
			   ValueFromPipelineByPropertyName = $true,
			   Position = 4,
			   HelpMessage = "The 'Expand' switch indicates if you wish to expand/extract the downloaded CAB files into the Download Folder.  Not compatable with the 'DontWaitForDownload switch.")]
	[switch]$Expand,
	
	[Parameter(Mandatory = $false,
			   Position = 5,
			   HelpMessage = "Tells the script to start the download and continue instead of waiting for each download to finish")]
	[switch]$DontWaitForDownload
)

Begin
{
	
	# Trim Trailing '\' from DownloadFolder if it exists
	if ($DownloadFolder.Substring($DownloadFolder.Length - 1, 1) -eq "\")
	{
		$DownloadFolder = $DownloadFolder.Substring(0, $DownloadFolder.Length - 1)
	}
	
	
	# Create DownloadFolder if it does not exist
	if (!(Test-Path $DownloadFolder))
	{
		Try
		{
			New-Item -Path $DownloadFolder -ItemType Directory -Force | Out-Null
		}
		Catch
		{
			Write-Error "$($_.Exception)"
		}
	}
	
	
	# Download Latest Catalog and Extract
	if ($DriverCatalog -match "ftp" -or $DriverCatalog -match "http")
	{
		
		# Cleanup Old Catalog Files
		if (Test-Path "$DownloadFolder\DriverPackCatalog.cab")
		{
			Remove-Item -Path "$DownloadFolder\DriverPackCatalog.cab" -Force -Verbose | Out-Null
		}
		if (Test-Path "$DownloadFolder\DriverPackCatalog.xml")
		{
			Remove-Item -Path "$DownloadFolder\DriverPackCatalog.xml" -Force -Verbose | Out-Null
		}
		
		
		# Download Driver CAB to a temp directory for processing
		Write-Verbose "Downloading Catalog: $DriverCatalog"
		$wc = New-Object System.Net.WebClient
		$wc.DownloadFile($DriverCatalog, "$DownloadFolder\DriverPackCatalog.cab")
		if (!(Test-Path "$DownloadFolder\DriverPackCatalog.cab"))
		{
			Write-Warning "Download Failed. Exiting Script."
			Exit
		}
		
		# Extract Catalog XML File from CAB
		write-Verbose "Extracting Catalog XML to $DownloadFolder"
		$CatalogCABFile = "$DownloadFolder\DriverPackCatalog.cab"
		$CatalogXMLFile = "$DownloadFolder\DriverPackCatalog.xml"
		EXPAND $CatalogCABFile $CatalogXMLFile | Out-Null
		
	}
	else
	{
		if (!(Test-Path -Path $DriverCatalog))
		{
			Write-Warning "$DriverCatalog Does Not Exist!"
			Exit
		}
		else
		{
			$CatalogXMLFile = "$DownloadFolder\DriverPackCatalog.xml"
			Remove-Item -Path $CatalogXMLFile -Force -Verbose | Out-Null
			Write-Verbose "Extracting DriverPackCatalog.xml to $DownloadFolder"
			EXPAND $DriverCatalog $CatalogXMLFile | Out-Null
			
		}
	}
	
	Write-Verbose "Target Model: $TargetModel"
	Write-Verbose "Target Operating System: $($TargetOS.ToString())"
	
	
}# /BEGIN
Process
{
	# Import Catalog XML
	Write-Verbose "Importing Catalog XML"
	[XML]$Catalog = Get-Content $CatalogXMLFile
	
	
	# Gather Common Data from XML
	$BaseURI = "http://$($Catalog.DriverPackManifest.baseLocation)"
	$CatalogVersion = $Catalog.DriverPackManifest.version
	Write-Verbose "Catalog Version: $CatalogVersion"
	
	
	# Create Array of Driver Packages to Process
	[array]$DriverPackages = $Catalog.DriverPackManifest.DriverPackage
	
	Write-Verbose "Begin Processing Driver Packages"
	# Process Each Driver Package
	foreach ($DriverPackage in $DriverPackages)
	{
		#Write-Verbose "Processing Driver Package: $($DriverPackage.path)"
		$DriverPackageVersion = $DriverPackage.dellVersion
		$DriverPackageDownloadPath = "$BaseURI/$($DriverPackage.path)"
		$DriverPackageName = $DriverPackage.Name.Display.'#cdata-section'.Trim()
		
		if ($DriverPackage.SupportedSystems)
		{
			$Brand = $DriverPackage.SupportedSystems.Brand.Display.'#cdata-section'.Trim()
			$Model = $DriverPackage.SupportedSystems.Brand.Model.Display.'#cdata-section'.Trim()
		}
		
		# Check for matching Target Operating System
		if ($TargetOS)
		{
			$osMatchFound = $false
			$sTargetOS = $TargetOS.ToString() -replace "_", " "
			# Look at Target Operating Systems for a match
			foreach ($SupportedOS in $DriverPackage.SupportedOperatingSystems)
			{
				if ($SupportedOS.OperatingSystem.Display.'#cdata-section'.Trim() -match $sTargetOS)
				{
					#Write-Debug "OS Match Found: $sTargetOS"
					$osMatchFound = $true
				}
				
			}
		}
		
		
		# Check for matching Target Model (Not Required for WinPE)
		if ($TargetModel -ne "WinPE")
		{
			$modelMatchFound = $false
			If ("$Brand $Model" -eq $TargetModel)
			{
				#Write-Debug "Target Model Match Found: $TargetModel"
				$modelMatchFound = $true
			}
		}
		
		
		# Check Download Condition Based on Input (Model/OS Combination)
		if ($TargetOS -and ($TargetModel -ne "WinPE"))
		{
			# We are looking for a specific Model/OS Combination
			if ($modelMatchFound -and $osMatchFound) { $downloadApproved = $true }
			else { $downloadApproved = $false }
		}
		elseif ($TargetModel -ne "WinPE" -and (-Not ($TargetOS)))
		{
			# We are looking for all Model matches
			if ($modelMatchFound) { $downloadApproved = $true }
			else { $downloadApproved = $false }
		}
		else
		{
			# We are looking for all OS matches
			if ($osMatchFound) { $downloadApproved = $true }
			else { $downloadApproved = $false }
		}
		
		
		if ($downloadApproved)
		{
			
			# Create Driver Download Directory
			if ($Brand -and $Model)
			{
				$DownloadDestination = "$DownloadFolder\$Brand $Model"
			}
			else
			{
				$DownloadDestination = "$DownloadFolder\$sTargetOS"
			}
			if (!(Test-Path $DownloadDestination))
			{
				Write-Verbose "Creating Driver Download Folder: $DownloadDestination"
				New-Item -Path $DownloadDestination -ItemType Directory -Force | Out-Null
			}
			
			
			# Download Driver Package
			if (!(Test-Path "$DownloadDestination\$DriverPackageName"))
			{
				Write-Verbose "Beging File Download: $DownloadDestination\$DriverPackageName"
				$wc = New-Object System.Net.WebClient
				
				if ($DontWaitForDownload)
				{
					$wc.DownloadFileAsync($DriverPackageDownloadPath, "$DownloadDestination\$DriverPackageName")
				}
				else
				{
					$wc.DownloadFile($DriverPackageDownloadPath, "$DownloadDestination\$DriverPackageName")
					
					if (Test-Path "$DownloadDestination\$DriverPackageName")
					{
						Write-Verbose "Driver Download Complete: $DownloadDestination\$DriverPackageName"
						
						
						# Expand Driver CAB
						if ($Expand)
						{
							Write-Verbose "Expanding Driver CAB: $DownloadDestination\$($DriverPackageName -replace ".cab",'')"
							$oShell = New-Object -ComObject Shell.Application
							
							$sourceFile = $oShell.Namespace("$DownloadDestination\$DriverPackageName").items()
							$destinationFolder = $oShell.Namespace("$DownloadDestination\$($DriverPackageName -replace ".cab",'')")
							$destinationFolder.CopyHere($sourceFile)
						}
					}
				}
			}
			
			
		}# Driver Download Section
		
	}
	
	
}# /PROCESS
End
{
	Write-Verbose "Finished Processing Dell Driver Catalog"
	Write-Verbose "Downloads will execute in the background and may take some time to finish"
}# /END



# SIG # Begin signature block
# MIIV3wYJKoZIhvcNAQcCoIIV0DCCFcwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUMBReFCCPN4ZpsmYjG5PBPjH
# 582gghNUMIIG3DCCBMSgAwIBAgITMQAAIefCTqRbo5i/xAACAAAh5zANBgkqhkiG
# 9w0BAQUFADA9MRMwEQYKCZImiZPyLGQBGRYDbmV0MRMwEQYKCZImiZPyLGQBGRYD
# ZG9pMREwDwYDVQQDEwhET0lJTUNBMjAeFw0xNDEyMjkyMDQ2NDJaFw0xNTEyMjky
# MDQ2NDJaMBQxEjAQBgNVBAMTCUFkbVJhZmFsRDCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAKkbUNw/iFRGWx3k+AetID0+Xk6K8eAESCw9DZZlR6ZKDPHV
# EdVUsYa/xAJlAspoptsWqjp5hVYUYDCIZCQyBjrvdfZ9aIEPTC6oVXjj16wpevpQ
# G4ulVM1jjUaR7u6kqJt9NAGbdi7UFPYc4SqIkIiibVbWBNvmnQFABmAG+etNa0G0
# T2LsuEy9HBJpvC64HkuaRvGo1cMFOcmqADVREnNnbggMQVVOry2blrVLjyYYLzT7
# 1rbtRAM7m3Gxg1EL2okDkZxkcVxWKeueX4OYQy+V+8EWcL5dqw/DbH7GtPxYj1JL
# mqvNoP3sn+zswsadxQN00iRxCxIS8lCiYKrSsH8CAwEAAaOCAvwwggL4MD0GCSsG
# AQQBgjcVBwQwMC4GJisGAQQBgjcVCIXe1UmigmiHqYcjh92HTIO11yiBIIHZyUCB
# 9vQ/AgFkAgEEMBMGA1UdJQQMMAoGCCsGAQUFBwMDMAsGA1UdDwQEAwIHgDAbBgkr
# BgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBSx7IJX3briyrSvV+ML
# 5aqtQtP1mTAfBgNVHSMEGDAWgBSb274d0R9OzmArssCSmx0ymlszmzCB+gYDVR0f
# BIHyMIHvMIHsoIHpoIHmhoGzbGRhcDovLy9DTj1ET0lJTUNBMigyKSxDTj1JSU5E
# RU5JTUNBMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNl
# cnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9ZG9pLERDPW5ldD9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnSGLmh0dHA6Ly9JSU5ERU5JTUNBMDEvQ2VydEVucm9sbC9ET0lJTUNBMigy
# KS5jcmwwggEHBggrBgEFBQcBAQSB+jCB9zCBowYIKwYBBQUHMAKGgZZsZGFwOi8v
# L0NOPURPSUlNQ0EyLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxD
# Tj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWRvaSxEQz1uZXQ/Y0FDZXJ0
# aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkw
# TwYIKwYBBQUHMAKGQ2h0dHA6Ly9JSU5ERU5JTUNBMDEvQ2VydEVucm9sbC9JSU5E
# RU5JTUNBMDEuZG9pLm5ldF9ET0lJTUNBMigyKS5jcnQwMAYDVR0RBCkwJ6AlBgor
# BgEEAYI3FAIDoBcMFUFkbVJhZmFsREBucHMuZG9pLm5ldDANBgkqhkiG9w0BAQUF
# AAOCAgEAQ/x4Pb91aAi3qmgdWbBNTxUZ7WDcxT/bXM56NqyACHuJmd9GXY8dt36y
# eBvuXTL5KNCafSgtQBA0nCiyD1J8Krk6bCRK5jniez83Y265mCr7/6w6jKIMLWFH
# jmC+642d1dkXT6qjFdpzVTDKOWlyGyHawSarZA1ZeTPdMLxXAwnQiQS5zQq9FzgE
# F+rbSEWp2f7k1pVZ1d2UZ63v1cGgU4kGmTdGt6xdtOeK6F3dItCraR9BD5cyjK0M
# CPSwGNiDPc6X3h8PpGKW/+2hknZTS4n7LZcs+23yUJmiv5hIB8Jvmfj8OABbSqFx
# /gwA+1KX9CdZeifVF/yHx9dHWaec8As9yBDrYrIesRuX3QYgcuM2e4XeecwfN2sM
# Izr+4kaAdJbqUoJ32VKYeSeHR048Lz3uU0w5y/p5dRctWScqc5bRisj+eHi2q6rL
# QreIuDUm7hoVzrxZm1lDZA2BdHTZjbzmca9VJnP/yhLP2PHErgNebC+F5lcxQy0R
# 2tfvZzE/MIPtgbNLtQE6BCZKsLlhFtVnFuxVLcwshUnBMHV0cs9YLL5bo040ln0a
# mhyWyf42jL5m8YruQKV9StQUqCF5HPLmJhZ+OMKIuLM3uemScUiLWImabmERzc0r
# VWBD0fGM0cwf8BeqsnkQSQ65crtkQoMM9iJOEeCYP16zUBN5RlIwggxwMIIKWKAD
# AgECAgphBxpTAAAAAAAHMA0GCSqGSIb3DQEBBQUAMBQxEjAQBgNVBAMTCURPSVJv
# b3RDQTAeFw0xMTAyMDcxODExMTBaFw0xNjAyMDcxODIxMTBaMD0xEzARBgoJkiaJ
# k/IsZAEZFgNuZXQxEzARBgoJkiaJk/IsZAEZFgNkb2kxETAPBgNVBAMTCERPSUlN
# Q0EyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAyP0SrWAgN+0wHHAW
# ATiHJoslNav13JnxsR8hc3ODYAf3DLuXggew9XBxKqAYCLZjrwN2YpSrYrDIAVO1
# /dqTM36vkgHCF4xiv3RM23ThTE4oKvEvVXe4IkMVceCs4voBdn85/c/kKbrvSlEG
# 8HExi72YPE3SBRLP9JNjqUWtF0CgXk9SxgOM+wPSwPH0pVzOoe8TfgZl283gqnfm
# AbXnXOJcgQr/KhROu3AyjivN763pXjsnsfwW/08CC398fdv21gmsxorZCv/ZHxs/
# fNXu1Z0IHhvbrga9tnBcbUaX7udrfZwrPBnLnzoeRmJ+jrogZgxLZlKLZumqvnqG
# tCkET6Yv3TgbYdrjjktXLXHGkd+d5I8S9XL3VrIYky7Qq5elzS5pI+tdKvWTP1Lk
# TW0yK00+7HuiMMraVmGO6Nt5j5nJiBncB2+Z03FbAKuMbtumqPXF4CX5laMpzOtt
# cLYxnQK+2Sz8a5PZqP4aXqZqqFCP/MHHyX9NcRig9hMcPpB+U7UEoHOUSDSms1We
# jetBsQ7pVH5mWtbF+cUnmoDv05alswDTdKNPhBquF5rO5Nu+FJDjLUsCynXQ1k6A
# tNhp9SqGotDC3pB2LIcZ8aasb99PtqQUm9042SpYg7nYhwCF5nM5qdpDB479iu6q
# UNT50W6DeVr/I32abrzRb20eyoECAwEAAaOCB5kwggeVMBIGCSsGAQQBgjcVAQQF
# AgMCAAIwIwYJKwYBBAGCNxUCBBYEFMM+IKANEz2Wktm+l90rkLFcJdgIMB0GA1Ud
# DgQWBBSb274d0R9OzmArssCSmx0ymlszmzCCBOkGA1UdIASCBOAwggTcMIICDQYJ
# YIZIAWUDAgETMIIB/jAuBggrBgEFBQcCARYiaHR0cDovL3BraS5kb2kubmV0L2xl
# Z2FscG9saWN5LmFzcDCCAcoGCCsGAQUFBwICMIIBvB6CAbgAQwBlAHIAdABpAGYA
# aQBjAGEAdABlACAAaQBzAHMAdQBlAGQAIABiAHkAIAB0AGgAZQAgAEQAZQBwAGEA
# cgB0AG0AZQBuAHQAIABvAGYAIAB0AGgAZQAgAEkAbgB0AGUAcgBpAG8AcgAgAGEA
# cgBlACAAbwBuAGwAeQAgAGYAbwByACAAaQBuAHQAZQByAG4AYQBsACAAdQBuAGMA
# bABhAHMAcwBpAGYAaQBlAGQAIABVAFMAIABHAG8AdgBlAHIAbgBtAGUAbgB0ACAA
# dQBzAGUAIABhAGwAbAAgAG8AdABoAGUAcgAgAHUAcwBlACAAaQBzACAAcAByAG8A
# aABpAGIAaQB0AGUAZAAuACAAVQBuAGEAdQB0AGgAbwByAGkAegBlAGQAIAB1AHMA
# ZQAgAG0AYQB5ACAAcwB1AGIAagBlAGMAdAAgAHYAaQBvAGwAYQB0AG8AcgBzACAA
# dABvACAAYwByAGkAbQBpAG4AYQBsACwAIABjAGkAdgBpAGwAIABhAG4AZAAvAG8A
# cgAgAGQAaQBzAGMAaQBwAGwAaQBuAGEAcgB5ACAAYQBjAHQAaQBvAG4ALjCCAscG
# CmCGSAFlAwIBEwEwggK3MDMGCCsGAQUFBwIBFidodHRwOi8vcGtpLmRvaS5uZXQv
# bGltaXRlZHVzZXBvbGljeS5hc3AwggJ+BggrBgEFBQcCAjCCAnAeggJsAFUAcwBl
# ACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGkAcwAg
# AGwAaQBtAGkAdABlAGQAIAB0AG8AIABJAG4AdABlAHIAbgBhAGwAIABHAG8AdgBl
# AHIAbgBtAGUAbgB0ACAAdQBzAGUAIABiAHkAIAAvACAAZgBvAHIAIAB0AGgAZQAg
# AEQAZQBwAGEAcgB0AG0AZQBuAHQAIABvAGYAIAB0AGgAZQAgAEkAbgB0AGUAcgBp
# AG8AcgAgAG8AbgBsAHkAIQAgAEUAeAB0AGUAcgBuAGEAbAAgAHUAcwBlACAAbwBy
# ACAAcgBlAGMAZQBpAHAAdAAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBp
# AGMAYQB0AGUAIABzAGgAbwB1AGwAZAAgAG4AbwB0ACAAYgBlACAAdAByAHUAcwB0
# AGUAZAAuACAAQQBsAGwAIABzAHUAcwBwAGUAYwB0AGUAZAAgAG0AaQBzAHUAcwBl
# ACAAbwByACAAYwBvAG0AcAByAG8AbQBpAHMAZQAgAG8AZgAgAHQAaABpAHMAIABj
# AGUAcgB0AGkAZgBpAGMAYQB0AGUAIABzAGgAbwB1AGwAZAAgAGIAZQAgAHIAZQBw
# AG8AcgB0AGUAZAAgAGkAbQBtAGUAZABpAGEAdABlAGwAeQAgAHQAbwAgAGEAIABE
# AGUAcABhAHIAdABtAGUAbgB0ACAAbwBmACAAdABoAGUAIABJAG4AdABlAHIAaQBv
# AHIAIABTAGUAYwB1AHIAaQB0AHkAIABPAGYAZgBpAGMAZQByAC4wGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUutgocNtzpxou0nmQUchKPce3DOkwgfQGA1UdHwSB7DCB6TCB
# 5qCB46CB4IaBsGxkYXA6Ly8vQ049RE9JUm9vdENBLENOPWlpbmlhZG9yY2ExLENO
# PUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1D
# b25maWd1cmF0aW9uLERDPWRvaSxEQz1uZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9u
# TGlzdD9iYXNlP29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hitodHRw
# Oi8vcGtpLmRvaS5uZXQvQ2VydEVucm9sbC9ET0lSb290Q0EuY3JsMIH8BggrBgEF
# BQcBAQSB7zCB7DCBpAYIKwYBBQUHMAKGgZdsZGFwOi8vL0NOPURPSVJvb3RDQSxD
# Tj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049
# Q29uZmlndXJhdGlvbixEQz1kb2ksREM9bmV0P2NBQ2VydGlmaWNhdGU/YmFzZT9v
# YmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MEMGCCsGAQUFBzAChjdo
# dHRwOi8vcGtpLmRvaS5uZXQvQ2VydEVucm9sbC9paW5pYWRvcmNhMV9ET0lSb290
# Q0EuY3J0MA0GCSqGSIb3DQEBBQUAA4ICAQBvU2goFw9os4nL3lC5Y0fQVsiDzjKZ
# g2EKJKtaCmLDBjxKNIZaY39rZSP8YbQnsa/uYtWDmvZCRb9CEUrfeW52ZgxYlwtY
# 4FrOjIvOlQjnGm7Ue2Gp3vEu9A7BwOTfpI0VYeFEf6h2AIs2cgDs8x2iAZKQ8i7J
# B0JaW0H8xBdkK3BgMuq5Ahl7mcjmD3OFHqfVxZ14XOmSKexeTVVHFklqXGgR7/fz
# OtDmZB08cO9jK6IRm8D9dl+JrY+erOD63JzbzYgVK04syse65HuiNwPtTn/TIhiK
# 09lXSnxOtt4vgmwhy/kFtt2NE9H1Mlou6aLErRNfxiRzKIDFloy40r//Vq7JOj+N
# ZHynwwCi1F7f3G7NBLxb/o6XzX8cEeXjdunJkGstm6Wt0VTu3t6Nr+5Y3hHvykcY
# Kzz2w2qXme7BdIlyM6KwNW6yOhuRrEmt6MyjETHpGqAP2xrqlMRb8NtoCrjAaR/V
# tHuxSJdA9T01AsZ9GTVSytv79idmIyw0xOB/JmGFX24OjaYqynM4S+iGe5I3haQR
# lck6zDntDZz5y7UpGU3HmGzr0N72qeii1rzlNlkAk7IcNMvPosEuhTVhYRYOnIhM
# /a7trguiUT45m7a8Za4BdnqI8eHD+q7LbzpykqdfYdDBhhR2wDwjD8gsKd3GFDfd
# JbD1/7IYekaVOjGCAfUwggHxAgEBMFQwPTETMBEGCgmSJomT8ixkARkWA25ldDET
# MBEGCgmSJomT8ixkARkWA2RvaTERMA8GA1UEAxMIRE9JSU1DQTICEzEAACHnwk6k
# W6OYv8QAAgAAIecwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKEC
# gAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFGpZ0QILioOUKWyBdu79cHq80WG3
# MA0GCSqGSIb3DQEBAQUABIIBAIoeHCVgpDA05eYcfuVCXFZ8SN/OPz5U2pDTiXR6
# LW74BNLaGVIBI+3DKNAHoiGBHGdQxnbAGk1iW0DuwVEGwRR3mNo+XsYvqcm0bvFe
# ds7YNbfz3EFLX9yPJ66la0KTO0Q8qSL92xCsOqubHCwCxHqnkkpXH5PQo4q9h8zQ
# oVQ3DzAa3pPE1J2qsHs/ycwWWCV5c8fvvvfTDX1UVFvLtZgYjdy7VH726NQ0m92R
# pan9rEFzlV/zkIIDzHYPbGx+S0dfWXMmpRFZtO946G69gmN1IJRV9kKsLcgRHSx6
# QTnJAxePfqO/I63q4t5jlzMbLS4DrzHhyywT9Yd+zH4pBhI=
# SIG # End signature block
