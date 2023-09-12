$data = Import-Csv ./servers.csv

foreach ($object in $data) {

    ## Define variables
    $serverName = $object.server
    $instanceType = $object.instanceType
    $subnetId = $object.subnet_id
    $securityGroupId = $object.securitygroup_id
    $diskType = $object.disk_type
    $appName = $object.tag_appname
    $env = $object.tag_env

    $json = '{\"TagSpecifications\":[{\"ResourceType\":\"instance\",\"Tags\":[{\"Key\":\"Name\",\"Value\":\"' + $serverName + '\"},{\"Key\":\"AppName\",\"Value\":\"' + $appName + '\"},{\"Key\":\"Environment\",\"Value\":\"' + $env + '\"}]}],\"InstanceType\":\"' + $instanceType + '\",\"UserData\":\"' + $userDataEncoded + '\",\"NetworkInterfaces\":[{\"DeviceIndex\":0,\"SubnetId\":\"' + $subnetId + '\",\"Groups\":[\"' + $securityGroupId + '\"]}]}'

    $itemsContent = (aws mgn describe-source-servers --filters isArchived=false | ConvertFrom-Json).items

    Write-Output "Getting source server ID for $serverName..."
    $sourceServerID = ($itemsContent | Where-Object { $_.tags -like "*$serverName*" }).sourceServerID

    Write-Output "Updating the launch configuration for $serverName..."
    aws mgn update-launch-configuration --source-server-id $sourceServerID --target-instance-type-right-sizing-method NONE

    Write-Output "Getting launch template ID for $serverName..."
    $launchTemplateId = (aws mgn get-launch-configuration --source-server-id $sourceServerId | ConvertFrom-Json).ec2LaunchTemplateID

    Write-Output "Getting latest template version for $serverName..."
    $latestTemplateVersion = (aws ec2 describe-launch-templates --launch-template-ids $launchTemplateId  | ConvertFrom-Json).LaunchTemplates.LatestVersionNumber

    Write-Output "Getting disk configuration for $serverName..."
    $diskConfig = (aws ec2 describe-launch-template-versions --launch-template-id $launchTemplateId --versions $latestTemplateVersion | ConvertFrom-Json).LaunchTemplateVersions.LaunchTemplateData.BlockDeviceMappings
    
    $i = 0
    foreach ($disk in $diskConfig) {

    [Int]$diskSize = $disk.Ebs.VolumeSize
 
        if ($i -eq 0) {
            Write-Output "Updating JSON for $($disk.DeviceName) on $serverName..."
            $jsonDiskConfig = '{\"BlockDeviceMappings\":[{\"DeviceName\":\"' + $disk.DeviceName + '\",\"Ebs\":{\"VolumeSize\":' + [int]$diskSize + ',\"VolumeType\":\"' + $diskType + '\"}}'
        }

        else {
            Write-Output "Updating JSON for $($disk.DeviceName) on $serverName..."
            $jsonDiskConfig += ","
            $jsonOtherDiskConfig = '{\"DeviceName\":\"' + $disk.DeviceName + '\",\"Ebs\":{\"VolumeSize\":' + [int]$diskSize + ',\"VolumeType\":\"' + $diskType + '\"}}'
            $jsonDiskConfig += $jsonOtherDiskConfig
        }
        $i++
    }

    $jsonDiskConfig += "]}"     

    Write-Output "Getting latest template version for $serverName..."
    $latestTemplateVersion = (aws ec2 describe-launch-templates --launch-template-ids $launchTemplateId | ConvertFrom-Json).LaunchTemplates.LatestVersionNumber

    Write-Output "Creating new launch template version with updated disks for $serverName..."
    (aws ec2 create-launch-template-version --launch-template-id $launchTemplateId --source-version $latestTemplateVersion --launch-template-data $jsonDiskConfig | ConvertFrom-Json).LaunchTemplateVersion.VersionNumber

    Write-Output "Getting latest template version for $serverName..."
    $latestTemplateVersion = (aws ec2 describe-launch-templates --launch-template-ids $launchTemplateId | ConvertFrom-Json).LaunchTemplates.LatestVersionNumber

    Write-Output "Creating new launch template version for $serverName..."
    $latestTemplateVersion = (aws ec2 create-launch-template-version --launch-template-id $launchTemplateId --source-version $latestTemplateVersion --launch-template-data $json | ConvertFrom-Json).LaunchTemplateVersion.VersionNumber

    Write-Output "Setting default template version for $serverName to version $templateVersion..."
    aws ec2 modify-launch-template --launch-template-id $launchTemplateId --default-version $latestTemplateVersion

}