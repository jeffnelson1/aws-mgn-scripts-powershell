$data = Import-Csv ./servers.csv

foreach ($object in $data) {

    $serverName = $object.server
    
    $itemsContent = (aws mgn describe-source-servers --filters isArchived=false | ConvertFrom-Json).items

    $sourceServerID = ($itemsContent | Where-Object { $_.tags -like "*$serverName*" }).sourceServerID

    Write-Output "Updating status to Ready for Cutover for $serverName - $sourceServerId"
    $null = aws mgn change-server-life-cycle-state --source-server-id $sourceServerId --life-cycle "state=READY_FOR_CUTOVER"

}

Start-Sleep -s 5

foreach ($object in $data) {

    $serverName = $object.server
    
    $itemsContent = (aws mgn describe-source-servers --filters isArchived=false | ConvertFrom-Json).items

    $sourceServerID = ($itemsContent | Where-Object { $_.tags -like "*$serverName*" }).sourceServerID

    Write-Output "Terminating test instance for $serverName - $sourceServerId"
    $null = aws mgn terminate-target-instances --source-server-ids $sourceServerId

}