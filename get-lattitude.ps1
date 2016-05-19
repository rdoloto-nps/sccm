$latts=Import-Csv D:\scripts\input\lattitude.csv
foreach ($model in $latts)
{ $model=$model.System
    
 D:\scripts\Download-DellDriverPacks.ps1   -DownloadFolder D:\cabs -TargetModel  "Latitude $model" -t

}

 