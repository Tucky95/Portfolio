<#
    This powershell script was used in a prod enviroment to automate the below tasks:
        
        - Moving of a SQL Database and isntance to a different server. 
        - Creation of new DNS records
        - Creating new plugin services for instances
        - Delete old plugin service
        - Remove App pools from app server
        - Clear backup directory
        - delete the original databases
        - recreates & move document stores


    Author: Jamie Tuck
    Date: 25/01/22

#> 

<#
# Pre-reqs
    - dbatools is installed - Install-Module dbatools
    - this powershell session is running as admin
    - your user is a sysadmin on the source and destination sql servers
#>

# INPUTS - please fill these out
$sharedPath = "\\EXAMPLE\LOCATION\"; # Databases will be backed up and restored from here. You SQL server must be able to read/write to this path.
$sourceSqlServer = "EXAMLPE.SOURCE.SERVER";
$destinationSqlServer = "EXAMLPE.DESTINATION.SERVER";
$instanceName = "EXAMPLE.INSTANCE";
$plugserv = "EXAMPLE.SERVER"
$appserv = "EXAMPLE.SERVER"
$backupserv = "EXAMPLE.SERVER"
$Credential = "EXAMPLE\CREDENTIALS"
$FileApi_app_pool = $instanceName + ".EXAMPLE.Api"
$app_pool = $instanceName + ".DOMAIN.COM"

# Stop services
Write-Output 'Stop and Remove Services'

# Stop plugin service
Try{
(Get-WmiObject Win32_Service -filter "Name='EXAMPLE.PLUGIN_$InstanceName'" -ComputerName $appserv).StopService()
(Get-WmiObject Win32_Service -filter "Name='EXAMPLE.PLUGIN_$InstanceName'" -ComputerName $plugserv).StopService()
}Catch{Write-Output 'Cannot stop service'
}

# Pause for 3 mins to ensure service stops and deletes
Write-Host "Waiting for 3 minutes" -ForegroundColor Cyan
Start-Sleep -seconds 180

# Delete plugin service
Try{
(Get-WmiObject Win32_Service -filter "Name='EXAMPLE.PLUGIN_$InstanceName'" -ComputerName $appserv) | Remove-WmiObject
(Get-WmiObject Win32_Service -filter "Name='EXAMPLE.PLUGIN_$InstanceName'" -ComputerName $plugserv) | Remove-WmiObject
}Catch{Write-Output 'Cannot remove service, Plugin service does not exist'
}


# Opens session to App Server to remove App pools from app server & confirm they have been deletion.

$appserv_session = New-PSSession -ComputerName $appserv -Credential $credential

Invoke-Command -Session $appserv_session -ScriptBlock {
 
Write-Host "$Using:FileApi_app_pool FileApi app pool removed from $Using:appserv" -ForegroundColor Green
Get-IISAppPool -Name $Using:FileApi_app_pool -ErrorAction SilentlyContinue 
Remove-WebAppPool -Name $Using:FileApi_app_pool -ErrorAction SilentlyContinue

Write-Host "$Using:app_pool App pool removed from $appserv" -ForegroundColor Green
Get-IISAppPool -Name $Using:app_pool -ErrorAction SilentlyContinue
Remove-WebAppPool -Name $Using:app_pool -ErrorAction SilentlyContinue

}

Remove-PSSession $appserv_session



# Script
$gvDbName = "NAME$($instanceName)";
$databases = @($gvDbName,"EXAMPLE.DATABASE$($instanceName)","EXAMPLE.PLUGIN_prod_$($instanceName)","NAME$($instanceName)");

# Clear backup directory
Get-ChildItem -Path $sharedpath -File -Recurse | Remove-Item -Verbose

# Move (kill DB connections, backup, restore to destination, delete source, delete from secondary server
foreach($database in $databases)
{
    $foundDbs = Find-DbaDatabase -SqlInstance $sourceSqlServer -Pattern $database -Exact;
    if ($foundDbs)
    {
        $sqlProcesses = Get-DbaProcess -SqlInstance $sourceSqlServer -Database $database;
        if ($sqlProcesses.Count -gt 0)
        {
            Write-Error "Active connections found in database '$($database)'. Attempting to stop them...";
            $sqlProcesses | Stop-DbaProcess;
        }
        Write-Information "Copying database '$($database)' from '$($sourceSqlServer)' to '$($destinationSqlServer)'...";
        
        Try{
        $bkppath = "$($sharedpath+$database+'.bak')"
        Backup-SqlDatabase -ServerInstance $sourceSqlServer -Database $database -BackupFile "$bkppath" 
        Restore-SqlDatabase -ServerInstance $destinationSqlServer -Database $database -BackupFile "$bkppath"
        }Catch{Write-Output 'Copy Failed'
        }

        Write-Information "Copy complete. Dropping source database...";
        Remove-DbaDatabase -SqlInstance $sourceSqlServer -Database $database -Confirm:$false; 
        Write-Information "Source dropped."
        
        Write-Host "Deleting DB's from Secondary backup server" -ForegroundColor Green
        Remove-DbaDatabase -SqlInstance $backupserv -Database $database -Confirm:$false
                
        Write-Output "Move complete for db '$($database)'.";
    }
    else
    {
        
        Write-Warning "Database '$($database)' was not found on server '$($sourceSqlServer)', skipping.";
    }
}

# Opens a session on DNS SERVER to change public DNS entries
$s = New-PSSession -ComputerName "DNS-SERVER" -Credential $credential

Invoke-Command -Session $s -ScriptBlock {

# Set variables against different DNS records
$instance = "INSTANCE_NAME"
$docs = $instance + "-docs"
$integdocs = $instance + "-integdocs"

# Set DNS command for each record
$Record_instance = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$instance" -RRType "CName"
$Record_docs = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$docs" -RRType "CName"
$Record_integdocs = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$integdocs" -RRType "CName"

#Set variables for new server locations
$NewRecord = $Record_instance.Clone()
$NewRecord.RecordData.HostNameAlias = 'APP-SERVER.DOMAIN.com.'
$NewRecord2 = $Record_docs.Clone()
$NewRecord2.RecordData.HostNameAlias = 'Doc-SERVER.DOMAIN.com.'
$NewRecord3 = $Record_integdocs.Clone()
$NewRecord3.RecordData.HostNameAlias = 'Doc-SERVER.DOMAIN.com.'

# Run command to change DNS records
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_instance -NewInputObject $NewRecord
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_docs -NewInputObject $NewRecord2
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_integdocs -NewInputObject $NewRecord3

# Check DNS records have changed to new location
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$instance" -RRType "CName"
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$docs" -RRType "CName"
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$integdocs" -RRType "CName"
}
Remove-PSSession $s

# Opens a session on DOMAIN CONTROLLER to change internal DNS entries
$s = New-PSSession -ComputerName "DC-SERVER" -Credential $credential

Invoke-Command -Session $s -ScriptBlock {

# Set variables against different DNS records
$instance = "INSTANCE.NAME"
$docs = $instance + "-docs"
$integdocs = $instance + "-integdocs"

# Set DNS command for each record
$Record_instance = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$instance" -RRType "CName"
$Record_docs = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$docs" -RRType "CName"
$Record_integdocs = Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$integdocs" -RRType "CName"

# Set variables for new server locations
$NewRecord = $Record_instance.Clone()
$NewRecord.RecordData.HostNameAlias = 'NEW-APP-SERVER'
$NewRecord2 = $Record_docs.Clone()
$NewRecord2.RecordData.HostNameAlias = 'NEW-DOC-SERVER'
$NewRecord3 = $Record_integdocs.Clone()
$NewRecord3.RecordData.HostNameAlias = 'NEW-DOC-SERVER'
        
# Run command to change DNS records
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_instance -NewInputObject $NewRecord
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_docs -NewInputObject $NewRecord2
        Set-DnsServerResourceRecord -ZoneName "DOMAIN.com" -OldInputObject $Record_integdocs -NewInputObject $NewRecord3

# Check DNS records have changed to new location
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$instance" -RRType "CName"
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$docs" -RRType "CName"
        Get-DnsServerResourceRecord -ZoneName "DOMAIN.com" -Name "$integdocs" -RRType "CName"
}
Remove-PSSession $s 

# Move Docs and attachments
# Set the drive letters as variables
$docs = "D"
$attach = "E"
$archive = "F"
$integ = "G"

$source_doc_server = "source_doc_server"
$destination_doc_server = "source_doc_server"

#Runs robocopy
Robocopy "\\$source_doc_server\D$\Documents\INSTANCE01" "\\$destination_doc_server\D$\Documents\INSTANCE01" /E  /COPY:DATS /SECFIX /MIR /R:3 /W:7 /MT:32
Robocopy "\\$source_doc_server\E$\Attachments\INSTANCE01" "\\$destination_doc_server\E$\Attachments\INSTANCE01" /E  /COPY:DATS /SECFIX /MIR /R:3 /W:7 /MT:32
Robocopy "\\$source_doc_server\F$\Archive\INSTANCE01" "\\$destination_doc_server\F$\Archive\INSTANCE01" /E  /COPY:DATS /SECFIX /MIR /R:3 /W:7 /MT:32
Robocopy "\\$source_doc_server\G$\Integdocs\INSTANCE01" "\\$destination_doc_server\G$\Integdocs\INSTANCE01" /E  /COPY:DATS /SECFIX /MIR /R:3 /W:7 /MT:32 
