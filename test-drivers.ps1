Function Get-DellCAB {
[CmdletBinding()]
Param(
    [Parameter(Position=0,ValueFromPipeline=$True)]
    [ValidateNotNullorEmpty()]
    [Alias('Path')]
    [string[]]$CabFilePath,
    
    [string]$Make = 'Dell',
    
    [string]$Model,
    
    [String]$OperatingSystem,

    [string]$outputFilePath

)

Begin {
    Write-Verbose "Starting Get-DellCab"
}

Process {
    Foreach ($CAB in $CabFilePath) {
        Write-Verbose "Extracting $Cab"
        $caddir=((Get-ChildItem -path $CAB).Directory).ToString()
        Write-Verbose "this is the Directory of cab file $caddir "
        $caddir=$caddir.Split("\")
        $Model=$caddir[2]
       
        Write-Verbose "Model is $Model "

        $CABarray = ((Get-ChildItem -path $CAB).BaseName).split("-")
        $workmodel=$CABarray[0]
        $OperatingSystem = $CABarray[1]
        $cabver= $CABarray[2]
         
        Write-Verbose "Model is $Model, OS is $OperatingSystem and cab version is $cabver"
               
        if ($OperatingSystem -eq "Win7") {
            $x64filepath = $outputFilePath + "\" +  $workmodel +"\" +"win7" +"\" + "x64" 
            $x86filepath = $outputFilePath + "\" +  $workmodel +"\" +"win7" +"\" + "x86" 
            $DrivePackageX64 = "$outputFilePath\$Make\$Model\Win7x64_$cabver"
            $DrivePackageX86 = "$outputFilePath\$Make\$Model\Win7x86_$cabver"
        }  
          elseif ($OperatingSystem -eq "Win10")
          { $x64filepath = $outputFilePath + "\" +  $workmodel +"\" +"Win10" +"\" + "x64" 
            $x86filepath = $outputFilePath + "\" +  $workmodel +"\" +"win10" +"\" + "x86" 
            $DrivePackageX64 = "$outputFilePath\$Make\$Model\Win10x64_$cabver"
            $DrivePackageX86 = "$outputFilePath\$Make\$Model\Win10x86_$cabver"

          }
             Try
            {    
               Get-ChildItem $CabFilePath | % {& "C:\Program Files\7-Zip\7z.exe" "x" $_.fullname  "-o$outputFilePath" } -ErrorAction Stop   
                   if(!(Test-Path -Path $x64filepath))
                    {Write-Verbose "$x64filepath doesn't exists skipping ..."
                }else{
                 Copy-Item -path $x64filepath -Destination $DrivePackageX64 -Recurse -Force
                }
                if(!(Test-Path -Path $x86filepath))
                {Write-Verbose "$x86filepath doesn't exists skipping ..."
                }
                else{
                 Copy-Item -path $x86filepath -Destination $DrivePackageX86 -Recurse -Force
                }
                 Remove-Item -Path $outputFilePath\$workmodel -Force -Recurse
            }
        Catch [System.IO.IOException]
            {
                Write-Error "$outputFilePath already exists"
            }
        Catch
            {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                }
                 }

    }
    }
    
  Get-ChildItem -Path E:\cabs\*.cab -Recurse |  Get-DellCAB  -outputFilePath "E:\drivers" -Verbose

