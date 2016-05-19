
function create-dp{
	<#$
	.SYNOPSIS
	Creates new distribution point it assumes you have config manager admin console installed on your computer
	Create  the Drives shares add 

	.DESCRIPTION
	Creates new distribution point it assumes you have config manager admin console installed on your computer
	Create  the folders needed for install configures IIS  writes NO_SMS_ON_DRIVE.SMS on drives not designeted to be sms drive 
	Assigns  DP to Boundary Group  assumes you are using standard format for distribution group names "NPS-<REGION>-$ACRO Content Location"
	.EXAMPLE
	 create-dp -dp inpmwroxvm2 -acro MWRO -smsdrive E
	.Parameter Dp 
	computer name which will have  Distribution point installed on it  ex: inpmwroxvm02

	.Parameter ACRO
	4 letter park acronym for boundary assigment  ex: MWRO
	.Parameter SMSDRIVE
	Logical letter of the drive  where sms will be installed ex: E
	.Notes
	 version 2 of the script removed .net boxes and functionalied the script
	.LINK
	http://inpmwroxvm2:8080/tfs/Powershell/_git/NPSREPOSITORY#path=%2FMISC&version=GBmaster&_a=contents

	#>
	[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1 )]
   [string]$DP,
      [Parameter(Mandatory=$True,Position=2)]
   [string]$acro,
	[Parameter(Mandatory=$True,Position=2)]
   [string]$smsdrive

   )
#import Config manager module  this assumes it's installed from SCCm 
$CMModulePath = $Env:SMS_ADMIN_UI_PATH.ToString().SubString(0,$Env:SMS_ADMIN_UI_PATH.Length - 5) + "\ConfigurationManager.psd1" 
import-module $CMModulePath -verbose

$Dp= $DP+'.nps.doi.net'
$CMDrive =$smsdrive+':'
 

# Set SSL Cert to expire in 99 years
$certexp = (get-date).AddYears(99).ToUniversalTime()
# Set PXE password here
$pxepass = ConvertTo-SecureString -AsPlainText "P@ssw0rd" -Force

$NoSMSDriveFileContent = "DO NOT DELETE!"







write-host "Loaded: $DP"
write-host "Loaded: $ACRO"
Write-host "Loaded: $smsdrive"
 

 


$NewServerName = $DP
$NewServerDesc = "NPS-MWR/$ACRO Content Location"
$NewServerSite = "NE1"
write-host "Processing $NewServerName  at $acro to add to $NewServerSite"
write-host $NewServerDesc




Set-Location "$($NewServerSite):"
$BoundaryGroupName = "NPS-MWR-$ACRO Content Location"
    try{
        $BoundaryGroup = Get-CMBoundaryGroup -Name $BoundaryGroupName
    }
    catch {
        $BoundaryGroupName = Read-Host "Please specify the boundary group name"
    }

    invoke-command -computername $NewServerName -ScriptBlock  {
    param
    ([string]$drive_letter)
         
    write-host " - ISS Prequisites  and branch cache..."
         Add-WindowsFeature  BITS,RDC,Web-ASP-Net,Web-ASP,Web-Windows-Auth,Web-WMI,Web-Metabase,Branchcache
		$command="net localgroup administrators /add NPS\INPRESTCMNE1$"
        Invoke-Expression $command|Out-Null
           $CMDrive = $drive_letter+":"     
        write-host " - The drive for SCS content is $CMDrive"
         
        $NoSMSDrives = Get-WmiObject Win32_volume | Where-Object {$_.drivetype -eq 3 -and $_.driveletter -ne $CMDrive -and $_.driveletter -like '*:'} | Select-Object -property driveletter
        ForEach($NoSMSDrive in $NoSMSDrives)
        {
            $NoSMSFilePath = $NoSMSDrive.DriveLetter + '\' + 'NO_SMS_ON_DRIVE.SMS'
            write-host " - Writing $NoSMSFilePath"
            $NoSMSDriveFileContent | out-file $NoSMSFilePath
        }

        $foldername = "ConfigMgrClient"
        $folderpath = $CMDrive + '\' + $foldername
        $sharename = $foldername

        write-host " - Creating $folderpath"
        $folder = New-Item $folderpath -type directory
        
        $acl = get-acl $folderpath
        $acl.SetAccessRuleProtection($true, $false)
        
        $rule = new-object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)

        $rule = new-object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)

        $acl.AddAccessRule($rule)

        $rule = new-object System.Security.AccessControl.FileSystemAccessRule("Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)

        write-host " - Setting permissions on $folderpath"
        set-acl $folderpath $acl
        
        New-SmbShare -Name $sharename -Path $folderpath -FullAccess "Administrators", "Everyone"
    } -ArgumentList $smsdrive
    write-host " - Adding Site System Server..."
    $NewSSS = New-CMSiteSystemServer -ServerName $NewServerName -SiteCode $NewServerSite 
 
 

    write-host " - Adding Distribution Point Role..."
    $NewDP = Add-CMDistributionPoint -SiteSystemServerName $NewServerName -SiteCode $NewServerSite   -InstallInternetServer -PrimaryContentLibraryLocation $smsdrive -PrimaryPackageShareLocation $smsdrive -CertificateExpirationTimeUtc $certexp -MinimumFreeSpaceMB 50 -ComputersUsePxePassword $pxepass  
  # write-host " - Adding Site Assigment  Boundary..."
   # Set-CMDistributionPoint -InputObject $NewDP -AddBoundaryGroupName "NPS-MWR Site Assignment" -AllowFallbackForContent $false 
    write-host " - Adding Content location     Boundary..."
    Set-CMDistributionPoint  -SiteSystemServerName $NewServerName -SiteCode $NewServerSite  -AddBoundaryGroupName $BoundaryGroupName -AllowFallbackForContent $false -EnableValidateContent $true -EnableBranchCache $true
     write-host " - and Done!!!!!"
     set-location c:
}
 
# SIG # Begin signature block
# MIIVygYJKoZIhvcNAQcCoIIVuzCCFbcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/KW2jeBwFsVjXXlhL+iaNNY0
# C6GgghNIMIIG0DCCBLigAwIBAgIKaB0lAAACAAAb3TANBgkqhkiG9w0BAQUFADA9
# MRMwEQYKCZImiZPyLGQBGRYDbmV0MRMwEQYKCZImiZPyLGQBGRYDZG9pMREwDwYD
# VQQDEwhET0lJTUNBMjAeFw0xNDA2MDUxNjU1NTFaFw0xNTA2MDUxNjU1NTFaMBcx
# FTATBgNVBAMTDFJhZmFsIERvbG90bzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAOtLWaXDBzTMauVRvWQfjV9H3PWfKjpX8ZncCxhip1y9nv02nuPTDZqv
# fiP/LQphWvgxP80r4UKHWlWDrUNmcBL/ceEqAnoy7DKtleQpPiE8/U02nQ7RgkY2
# 8qDAEnI1vujgdv3iisgMuGWCVlkVWsp7zZMbh95iEGHFQVWNlYUi7/f4QBOU97/P
# Zp3kpDEJTiRSQkrLVqhqCUMEb57qUAyp2gT1vqL0Gco3JR5u+z162Ms481T1cOVH
# G1cfTmWYfbQjX3TyJRn2hHSrv+ha1g72s3bG0ZeyEZlS415ZqFIlb1itX5bvgdSG
# R3ilq01+Cs2Dzogo/+oPLz2030IkAkUCAwEAAaOCAvYwggLyMD0GCSsGAQQBgjcV
# BwQwMC4GJisGAQQBgjcVCIXe1UmigmiHqYcjh92HTIO11yiBIIHZyUCB9vQ/AgFk
# AgECMBMGA1UdJQQMMAoGCCsGAQUFBwMDMAsGA1UdDwQEAwIHgDAbBgkrBgEEAYI3
# FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBSZ1xRFdsPI2XnTDcFU3pUzzlc2
# eDAfBgNVHSMEGDAWgBSb274d0R9OzmArssCSmx0ymlszmzCB+gYDVR0fBIHyMIHv
# MIHsoIHpoIHmhoGzbGRhcDovLy9DTj1ET0lJTUNBMigyKSxDTj1JSU5ERU5JTUNB
# MDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9ZG9pLERDPW5ldD9jZXJ0aWZpY2F0ZVJldm9j
# YXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnSG
# Lmh0dHA6Ly9paW5kZW5pbWNhMDEvQ2VydEVucm9sbC9ET0lJTUNBMigyKS5jcmww
# ggEHBggrBgEFBQcBAQSB+jCB9zCBowYIKwYBBQUHMAKGgZZsZGFwOi8vL0NOPURP
# SUlNQ0EyLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2
# aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWRvaSxEQz1uZXQ/Y0FDZXJ0aWZpY2F0
# ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwTwYIKwYB
# BQUHMAKGQ2h0dHA6Ly9paW5kZW5pbWNhMDEvQ2VydEVucm9sbC9JSU5ERU5JTUNB
# MDEuZG9pLm5ldF9ET0lJTUNBMigyKS5jcnQwKgYDVR0RBCMwIaAfBgorBgEEAYI3
# FAIDoBEMD1JEb2xvdG9AbnBzLmdvdjANBgkqhkiG9w0BAQUFAAOCAgEAnciajY7J
# JEaypnJqxYMoZiaExQhMqm/kQCJy4RVGq8OCcSJi+VjoxAav+JJ9abVuv/mABYOy
# yG9BPgvmHlaA9XtZpInFHMqP9FKPFeCTa0ibY3F82m/XaEWyop3u4PAg7jtHifgC
# t10IsMvLbVuEtHsVsRX+Q1XTfU6mm79Hg8qttw+1Th2EQN/+teU0fOxIFsahdU/m
# 8EAR0HaE7u4rTlAVclnGtfws2HzZMlQ9PuZb38MGukpAbA6Sn4gDk0Gb9EjNBgJC
# 6LJvhwCkXjvW+zjsxFdgx3Z7hkH58rnEqJ9IJt5HB/ZNNXTcTTz8vKSXGKTA1+Kn
# vkAulk5aRnqtu1yv5oVVRAVQLr0BTe3WjOGbbntMOCOh+L2VH7yareJreKEkXvrm
# QXbkCRmcqvcwz7+oeFLbGnlHtsVybplBz816ThdglWP3w/6VucuR3yhiE7wH5Vyd
# mjYkUQYuokcMnUVpVZBIV8YXkIjDFZxlO7suJBxYXxCHqPZlW3IKtzL3ziPAmP5X
# zqjIMvk+7WQt18nC45ZW0BmMsIOoPw4zETNqru2Z5dnoeeZmBd+FCWY9bm6ZqdJg
# 4UbnwRWLThVPf6KMpB56ZVkUVYBRoDzZqLSx75FG+ACqzvbKQYOn0Q2sGHvtVjPE
# w8/OOa5URnSgqMwXGMjxGKzX7bXm2FVpP74wggxwMIIKWKADAgECAgphBxpTAAAA
# AAAHMA0GCSqGSIb3DQEBBQUAMBQxEjAQBgNVBAMTCURPSVJvb3RDQTAeFw0xMTAy
# MDcxODExMTBaFw0xNjAyMDcxODIxMTBaMD0xEzARBgoJkiaJk/IsZAEZFgNuZXQx
# EzARBgoJkiaJk/IsZAEZFgNkb2kxETAPBgNVBAMTCERPSUlNQ0EyMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAyP0SrWAgN+0wHHAWATiHJoslNav13Jnx
# sR8hc3ODYAf3DLuXggew9XBxKqAYCLZjrwN2YpSrYrDIAVO1/dqTM36vkgHCF4xi
# v3RM23ThTE4oKvEvVXe4IkMVceCs4voBdn85/c/kKbrvSlEG8HExi72YPE3SBRLP
# 9JNjqUWtF0CgXk9SxgOM+wPSwPH0pVzOoe8TfgZl283gqnfmAbXnXOJcgQr/KhRO
# u3AyjivN763pXjsnsfwW/08CC398fdv21gmsxorZCv/ZHxs/fNXu1Z0IHhvbrga9
# tnBcbUaX7udrfZwrPBnLnzoeRmJ+jrogZgxLZlKLZumqvnqGtCkET6Yv3TgbYdrj
# jktXLXHGkd+d5I8S9XL3VrIYky7Qq5elzS5pI+tdKvWTP1LkTW0yK00+7HuiMMra
# VmGO6Nt5j5nJiBncB2+Z03FbAKuMbtumqPXF4CX5laMpzOttcLYxnQK+2Sz8a5PZ
# qP4aXqZqqFCP/MHHyX9NcRig9hMcPpB+U7UEoHOUSDSms1WejetBsQ7pVH5mWtbF
# +cUnmoDv05alswDTdKNPhBquF5rO5Nu+FJDjLUsCynXQ1k6AtNhp9SqGotDC3pB2
# LIcZ8aasb99PtqQUm9042SpYg7nYhwCF5nM5qdpDB479iu6qUNT50W6DeVr/I32a
# brzRb20eyoECAwEAAaOCB5kwggeVMBIGCSsGAQQBgjcVAQQFAgMCAAIwIwYJKwYB
# BAGCNxUCBBYEFMM+IKANEz2Wktm+l90rkLFcJdgIMB0GA1UdDgQWBBSb274d0R9O
# zmArssCSmx0ymlszmzCCBOkGA1UdIASCBOAwggTcMIICDQYJYIZIAWUDAgETMIIB
# /jAuBggrBgEFBQcCARYiaHR0cDovL3BraS5kb2kubmV0L2xlZ2FscG9saWN5LmFz
# cDCCAcoGCCsGAQUFBwICMIIBvB6CAbgAQwBlAHIAdABpAGYAaQBjAGEAdABlACAA
# aQBzAHMAdQBlAGQAIABiAHkAIAB0AGgAZQAgAEQAZQBwAGEAcgB0AG0AZQBuAHQA
# IABvAGYAIAB0AGgAZQAgAEkAbgB0AGUAcgBpAG8AcgAgAGEAcgBlACAAbwBuAGwA
# eQAgAGYAbwByACAAaQBuAHQAZQByAG4AYQBsACAAdQBuAGMAbABhAHMAcwBpAGYA
# aQBlAGQAIABVAFMAIABHAG8AdgBlAHIAbgBtAGUAbgB0ACAAdQBzAGUAIABhAGwA
# bAAgAG8AdABoAGUAcgAgAHUAcwBlACAAaQBzACAAcAByAG8AaABpAGIAaQB0AGUA
# ZAAuACAAVQBuAGEAdQB0AGgAbwByAGkAegBlAGQAIAB1AHMAZQAgAG0AYQB5ACAA
# cwB1AGIAagBlAGMAdAAgAHYAaQBvAGwAYQB0AG8AcgBzACAAdABvACAAYwByAGkA
# bQBpAG4AYQBsACwAIABjAGkAdgBpAGwAIABhAG4AZAAvAG8AcgAgAGQAaQBzAGMA
# aQBwAGwAaQBuAGEAcgB5ACAAYQBjAHQAaQBvAG4ALjCCAscGCmCGSAFlAwIBEwEw
# ggK3MDMGCCsGAQUFBwIBFidodHRwOi8vcGtpLmRvaS5uZXQvbGltaXRlZHVzZXBv
# bGljeS5hc3AwggJ+BggrBgEFBQcCAjCCAnAeggJsAFUAcwBlACAAbwBmACAAdABo
# AGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGkAcwAgAGwAaQBtAGkAdABl
# AGQAIAB0AG8AIABJAG4AdABlAHIAbgBhAGwAIABHAG8AdgBlAHIAbgBtAGUAbgB0
# ACAAdQBzAGUAIABiAHkAIAAvACAAZgBvAHIAIAB0AGgAZQAgAEQAZQBwAGEAcgB0
# AG0AZQBuAHQAIABvAGYAIAB0AGgAZQAgAEkAbgB0AGUAcgBpAG8AcgAgAG8AbgBs
# AHkAIQAgAEUAeAB0AGUAcgBuAGEAbAAgAHUAcwBlACAAbwByACAAcgBlAGMAZQBp
# AHAAdAAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABz
# AGgAbwB1AGwAZAAgAG4AbwB0ACAAYgBlACAAdAByAHUAcwB0AGUAZAAuACAAQQBs
# AGwAIABzAHUAcwBwAGUAYwB0AGUAZAAgAG0AaQBzAHUAcwBlACAAbwByACAAYwBv
# AG0AcAByAG8AbQBpAHMAZQAgAG8AZgAgAHQAaABpAHMAIABjAGUAcgB0AGkAZgBp
# AGMAYQB0AGUAIABzAGgAbwB1AGwAZAAgAGIAZQAgAHIAZQBwAG8AcgB0AGUAZAAg
# AGkAbQBtAGUAZABpAGEAdABlAGwAeQAgAHQAbwAgAGEAIABEAGUAcABhAHIAdABt
# AGUAbgB0ACAAbwBmACAAdABoAGUAIABJAG4AdABlAHIAaQBvAHIAIABTAGUAYwB1
# AHIAaQB0AHkAIABPAGYAZgBpAGMAZQByAC4wGQYJKwYBBAGCNxQCBAweCgBTAHUA
# YgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# utgocNtzpxou0nmQUchKPce3DOkwgfQGA1UdHwSB7DCB6TCB5qCB46CB4IaBsGxk
# YXA6Ly8vQ049RE9JUm9vdENBLENOPWlpbmlhZG9yY2ExLENOPUNEUCxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPWRvaSxEQz1uZXQ/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29i
# amVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hitodHRwOi8vcGtpLmRvaS5u
# ZXQvQ2VydEVucm9sbC9ET0lSb290Q0EuY3JsMIH8BggrBgEFBQcBAQSB7zCB7DCB
# pAYIKwYBBQUHMAKGgZdsZGFwOi8vL0NOPURPSVJvb3RDQSxDTj1BSUEsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1kb2ksREM9bmV0P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1j
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MEMGCCsGAQUFBzAChjdodHRwOi8vcGtpLmRv
# aS5uZXQvQ2VydEVucm9sbC9paW5pYWRvcmNhMV9ET0lSb290Q0EuY3J0MA0GCSqG
# SIb3DQEBBQUAA4ICAQBvU2goFw9os4nL3lC5Y0fQVsiDzjKZg2EKJKtaCmLDBjxK
# NIZaY39rZSP8YbQnsa/uYtWDmvZCRb9CEUrfeW52ZgxYlwtY4FrOjIvOlQjnGm7U
# e2Gp3vEu9A7BwOTfpI0VYeFEf6h2AIs2cgDs8x2iAZKQ8i7JB0JaW0H8xBdkK3Bg
# Muq5Ahl7mcjmD3OFHqfVxZ14XOmSKexeTVVHFklqXGgR7/fzOtDmZB08cO9jK6IR
# m8D9dl+JrY+erOD63JzbzYgVK04syse65HuiNwPtTn/TIhiK09lXSnxOtt4vgmwh
# y/kFtt2NE9H1Mlou6aLErRNfxiRzKIDFloy40r//Vq7JOj+NZHynwwCi1F7f3G7N
# BLxb/o6XzX8cEeXjdunJkGstm6Wt0VTu3t6Nr+5Y3hHvykcYKzz2w2qXme7BdIly
# M6KwNW6yOhuRrEmt6MyjETHpGqAP2xrqlMRb8NtoCrjAaR/VtHuxSJdA9T01AsZ9
# GTVSytv79idmIyw0xOB/JmGFX24OjaYqynM4S+iGe5I3haQRlck6zDntDZz5y7Up
# GU3HmGzr0N72qeii1rzlNlkAk7IcNMvPosEuhTVhYRYOnIhM/a7trguiUT45m7a8
# Za4BdnqI8eHD+q7LbzpykqdfYdDBhhR2wDwjD8gsKd3GFDfdJbD1/7IYekaVOjGC
# AewwggHoAgEBMEswPTETMBEGCgmSJomT8ixkARkWA25ldDETMBEGCgmSJomT8ixk
# ARkWA2RvaTERMA8GA1UEAxMIRE9JSU1DQTICCmgdJQAAAgAAG90wCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFLTU0lIE67YDlGx0cPYZjpcO0+pRMA0GCSqGSIb3DQEBAQUABIIBAIOj
# Y/ZieF3CmVXlPRu1zw/EvSW07yxK5m8nxi6BoWImdiZN+3ss6Ni5u/KwnppO4/PP
# pZoOvSvKCsqQeQmn/vFb2w7KExnwqxulV21kDXw0vDtdV/NlxvfeVHXIT2cP5wwb
# pUkFQMNbA2m6Z+K/UC7Tc5n1RVDBCNSTn8+HeahagFwYflj5p0ucQ1dylycIMVAa
# klVgRUbR3hhYUcip/r4namO1gRmIfhovzw0fQFIWKXqI7mYxmqlWtssadUVuRrEc
# +mxuUjJOMaXC0lZC4Mw+Lfi0tQJNpccOfmq1prPSD3QbGo1zlrAWKO/PwC/okogT
# bVvotuCZTb4rsfEezHI=
# SIG # End signature block


 