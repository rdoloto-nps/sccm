function Remove-SCCMDPContent
{
[cmdletbinding()]
Param(
     
    [Parameter(Mandatory=$true)]
    [String]
    [ValidateNotNullOrEmpty()]
    $DistPoint,
     [Parameter(Mandatory=$true)]
    [String]
    [ValidateNotNullOrEmpty()]
    $siteserver
)


 Begin
    {
        Write-Verbose -Message "[BEGIN]"
        try
        {
           
            $sccmProvider = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $siteserver -errorAction Stop
            # Split up the namespace path
            $Splits = $sccmProvider.NamespacePath -split "\\", 4
            Write-Verbose "Provider is located on $($sccmProvider.Machine) in namespace $($splits[3])"
 
            # Create a new hash to be passed on later
            $hash= @{"ComputerName"=$siteserver;"NameSpace"=$Splits[3];"Class"="SMS_DistributionPoint";"ErrorAction"="Stop"}
            
            #add the filter to get the packages there in the DP only
            $hash.Add("Filter","ServerNALPath LIKE '%$DistPoint%'")
           
            
        }
          catch
        {
            Write-Warning "Something went wrong while getting the SMS ProviderLocation"
            throw $_.Exception
        }


}
 Process
    {
        
            
           Write-Verbose -Message "[PROCESS] Working to remove packages from DP --> $DistPoint  "
          
          $PackagesINDP = Get-WmiObject @hash
          Write-Verbose $PackagesINDP.count()
          $PackagesINDP  | ForEach-Object -Process { 
          
          try
          { 
          Remove-WmiObject  -InputObject $_  -ErrorAction Stop -ErrorVariable WMIRemoveError 
          Write-Verbose -Message "Removed $($_.PackageID) from $DistPoint"
          [pscustomobject]@{"DP"=$DPname;"PackageId"=$($_.PackageID);"Action"="Removed"}
          }
          catch
                {
                    Write-Verbose "[PROCESS] Something went wrong while removing the Package  from $DPname"
                    throw $_.exception
                }

     }


}
  End
    {
        Write-Verbose "[END] Ending the Function"
    }
}