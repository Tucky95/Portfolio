


<#
    This script will:
    - connect to the SCCM server
    - ask the user to enter the Name, MAC Address, GUID of the new server and the Device collection to add the new server to
    - search SCCM for devices that already contain the new MAC address or GUID
        - Will display an error message if it does. Useful as the machine will not pxe boot to sccm if the mac or guid is already assigned to a device (re-building server)
    - create the device in SCCM
    - add the new device to the device collection
    - update the membership of the collection after adding the device
    - search the collection to confirm the device has been added successfully
        - if it has not populated yet. The script will show a custom error message and ask the user to run the script again
    - errors will be logged to a txt file on the machine running the script


    Author: Jamie Tuck
    Date: 16/6/23

 #>


<# 

Status message colour code:
    
    DarkCyan      = Search
    Red + White   = Error with process
    Green         = Success with process 
    Yellow        = Script waiting
    Magenta       = Action with no output
    
#>


$logpath = “c:\temp”

$Name = Read-Host 'Enter Server Name Here'
$Mac_Address = Read-Host 'Enter MAC Address Here'
$Guid = Read-Host 'Enter SMBiosGuid Here'
$Collection = Read-Host 'Enter Collection Name Here'
$ResourceID = (get-cmdevice -Name $Name).ResourceID


## Search for dupe MAC Address in SCCM ##

    Write-Host 'Searching SCCM for duplicate entries of the entered MAC Address...' -ForegroundColor DarkCyan

$Search_mac = Get-CMDevice -Fast | Where-Object { $_.MACAddress -eq $Mac_Address } | Select -ExpandProperty Name


    if ( $Search_mac ) {write-host "This MAC Address is already assigned to $Search_mac" -ForegroundColor Red -BackgroundColor White }

        else { Write-Host "This MAC Address is not currently in SCCM" -ForegroundColor Green }

    
## Search for dupe GUID in SCCM ##
    
    Write-Host 'Searching SCCM for duplicate entries of the entered MAC Address...' -ForegroundColor DarkCyan

$Search_GUID = Get-CMDevice -Fast | Where-Object { $_.SMBIOSGUID -eq $Guid } | Select -ExpandProperty Name

    if ( $Search_GUID ) {write-host "This GUID is already assigned to $Search_GUID" -ForegroundColor Red -BackgroundColor White }

        else { Write-Host "This MAC Address is not currently in SCCM" -ForegroundColor Green }


## Creating device in SCCM ##

Write-Host Creating $Name -ForegroundColor Green

    Import-CMComputerInformation -ComputerName $Name -MacAddress $Mac_Address -SMBiosGuid $Guid

    Get-CMDevice -Name $Name -Resource | select Name, CreationDate, OperatingSystemNameandVersion, MACAddresses, SMBIOSGUID, ResourceID


        Write-Host "Waiting for 30 seconds" -ForegroundColor Yellow

        Start-Sleep -seconds 30


## Adding new device into SCCM Collection ##

try {

Write-Host “Adding $Name to $Collection” -ForegroundColor Cyan
Add-CMDeviceCollectionDirectMembershipRule -CollectionName $Collection -ResourceId $(get-cmdevice -Name $Name).ResourceID

}

catch {

Write-Warning “Cannot add client $Name object may not exist”
$Name | Out-File “$logpath\$Collection-invalid.log” -Append
$Error[0].Exception | Out-File “$logpath\$Collection-invalid.log” -Append


}

## Updating collection after adding device ##

Write-Host "Updating Collection Membership - Waiting for 30 seconds" -ForegroundColor Magenta

Start-Sleep -seconds 30

    Invoke-CMCollectionUpdate -Name $Collection



## Searching SCCM to confirm device has been added to collection successfully ##

Write-Host "Confirming $Name has been added to $Collection - Waiting for 30 seconds" -ForegroundColor Yellow

Start-Sleep -seconds 30

    $Get_collection_members = Get-CMCollectionMember -CollectionName $Collection -Name $Name | Where-Object { $_.Name -eq $Name } | Select -ExpandProperty Name

        if ( $Get_collection_members ) { Write-Host "The following device has been added to $Collection successfully - $Name" -ForegroundColor Green }
            
            else { Write-Host "$Name is not part of $Collection - Wait a few minutes for SCCM to catch up. Then run the script again to add to the collection. (Only enter the server name at this stage)" -ForegroundColor Red -BackgroundColor White }


