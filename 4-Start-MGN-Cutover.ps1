$data = Import-Csv ./servers.csv

foreach ($object in $data) {

    $serverName = $object.server
    
    $itemsContent = (aws mgn describe-source-servers --filters isArchived=false | ConvertFrom-Json).items

    $sourceServerID = ($itemsContent | Where-Object { $_.tags -like "*$serverName*" }).sourceServerID

    Write-Output "Starting cutover on $serverName - $sourceServerId"
    aws mgn start-cutover --source-server-ids $sourceServerId

}