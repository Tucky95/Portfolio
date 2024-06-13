
# Copy this script to server and run locally
## Run as admin
### Run this script manually. ONLY run this after both NIC's have been enabled in VCEM ##

<#
    This script automates:
    - The creation of a NIC team
        - Standardizes the name of the NIC team to "Team"
    - Disabling all un-used NIC's
    - Prompts the user to enter the Primary static IP
    - Prompts the user to enter the Secondary static IP
    - Sets the DNS servers to the newly created NIC team
    - Sets the DNS suffixes for each domain to use in order
    - Disables LMHOSTS lookup
    - Disables NetBIOS over TCP/IP
    - Creates reg keys for using Duo on the DMZ network
    - Copies the correct .net machine config 
    

    Author: Jamie Tuck
    Date: 14/7/23

 #>

<# 

Status message colour code:
    
    DarkCyan      = Search
    Red + White   = Error with process
    Green         = Success with process 
    Yellow        = Script waiting
    Magenta       = Action with no output
    
#>

## Disable unused NIC's ##

Write-Host "Disabling all disconnected Nic's..." -ForegroundColor Green

    Get-NetAdapter | select Name, InterfaceDescription, ifIndex, Status, MacAddress, LinkSpeed | where { $_.Status -ne 'up' -or $_.LinkSpeed -ne '10 Gbps' } | Disable-NetAdapter -Confirm:$false

 $enabled_nics = Get-NetAdapter | select Name, InterfaceDescription, ifIndex, Status, MacAddress, LinkSpeed | where { $_.Status -eq 'up' }
  

## Create NIC Team ##
   
Write-Host Creating NIC Team using $enabled_nics.Name -ForegroundColor Green
   
   New-NetLbfoTeam -Name "Team" -TeamMembers $enabled_nics.Name -Confirm:$false

 Write-Host "Waiting for 15 seconds while NIC Team is setup..." -ForegroundColor Yellow
 Start-Sleep -Seconds 15

    $team = Get-NetAdapter | select Name, ifIndex | where { $_.Name -eq 'Team' }
    $primary_ip = Read-Host "Enter Primary IP address here..."


## Setting static IP's ##

Write-Host Setting $primary_ip to $team.Name -ForegroundColor Magenta

    New-NetIPAddress -InterfaceIndex $team.ifIndex -IPAddress $primary_ip -AddressFamily IPv4 -PrefixLength 16 -DefaultGateway "GATEWAY_IP"

 
## Set DNS settings ## 
 
$DNS_Servers = "1.1.1.1" , "2.2.2.2" , "3.3.3.3" , "4.4.4.4" | Get-Random -Count 4
$shuffled_dns = $DNS_Servers | Sort-Object {Get-Random}

 
Write-Host Setting $shuffled_dns to $team.Name -ForegroundColor Magenta
    
    Set-DnsClientServerAddress -InterfaceIndex $team.ifIndex -ServerAddresses $shuffled_dns

$secondary_ip = Read-Host "Enter Secondary IP Address Here..."

Write-Host Setting $secondary_ip to $team.Name -ForegroundColor Magenta

    .\netsh.exe int ipv4 add address $team.Name $secondary_ip skipassource=true

    .\netsh.exe int ipv4 show ipaddresses level=verbose


## Setting DNS Suffixes ##

Write-Host Adding DNS suffixes to $team.Name -ForegroundColor Green

        Set-DnsClientGlobalSetting -SuffixSearchList @("DOMAIN-1.COM", "DOMAIN-2.COM", "DOMAIN-3.COM")


## Disable LMHOSTS lookup ##

Write-Host Disabling LMHOSTS lookup -ForegroundColor Green

    $DisableLMHosts_Class=Get-WmiObject -list Win32_NetworkAdapterConfiguration
    $DisableLMHosts_Class.EnableWINS($false,$false)


## Disable NetBIOS over TCP/IP ##

Write-Host Disabling NetBIOS over TCP/IP on $team.Name -ForegroundColor Green

    $NETBIOS_DISABLED=2

        Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled = 'true'" | ForEach-Object { $_.SetTcpipNetbios($NETBIOS_DISABLED)}


## Reg fix for Duo on DMZ ##

Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\REG KEY" /v HttpProxyHost /d 5.5.5.5 /t REG_SZ
Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\REG KEY" /v HttpProxyPort /d 9090 /t REG_DWORD


## Check machine.config has updated and is correct ##
Copy-Item -Path "C:\Installs\New Server Scripts\Source\.NET Config\machine.config" -Destination "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\machine.config" -Force

     
     
     
     Write-Host "   Reboot system after running script to ensure changes take affect   " -ForegroundColor Blue -BackgroundColor White