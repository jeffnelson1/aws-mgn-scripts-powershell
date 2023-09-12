$data = Import-Csv ./servers.csv

foreach ($object in $data) {

    $serverName = $object.Server
    
    $itemsContent = (aws mgn describe-source-servers --filters isArchived=false | ConvertFrom-Json).items

    $sourceServerID = ($itemsContent | Where-Object { $_.tags -like "*$serverName*" }).sourceServerID

    Write-Output "Starting test instance for $serverName - $sourceServerId"
    aws mgn start-test --source-server-ids $sourceServerId

}