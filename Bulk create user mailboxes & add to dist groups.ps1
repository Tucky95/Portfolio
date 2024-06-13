

<#
    This script was used for importing another businesses AD users into our own organization. It performed the following:
    - import user information from targeted csv
    - creates given name value for each user
    - create mailbox alias for each user
    - creates the user mailbox & AD account
    - add's user AD account to groups that will create a homedrive for each user
    - adds users to email distribution groups based on account attributes
    

    Author: Jamie Tuck
    Date: 20/5/19

 #>



Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
$Data = @()

import-csv "C:\Scripts\Powershell\USER_AD_EXPORT.csv" | Foreach-object { 
	
	#set givenname to variable and remove spaces
	$givenname = $_.givenname -replace '\s',''
	#set surname to variable and remove spaces
	$surname = $_.surname -replace '\s',''
	#join givenname and surname for alias
	$alias = $_.Alias -replace '\s',''
    $Name = $_.Name
    $SamAccountName = $_. SamAccountName -replace '\s',''
    $GivenName = $_.GivenName 
    $Initials = $_.Initials 
    $Office = $_.OfficeName
    $Description = $_.Description 
    $EmailAddress = $_.eMail 
    $UserPrincipalName = $_.userPrincipalName -replace '\s',''
    $Company = $_.Company
    $Department = $_.Department 
    $EmployeeID = $_.ID 
    $Title = $_.title
    $Displayname = $_.displayName 
    $extensionAttribute2 = $_.CostCode
    $extensionAttribute5 = $_.Region
    $extensionAttribute6 = $_.Region
    $OU = $_.OU
    $company = $_.Company

  
    Write-Host "$SamAccountName now being created..." -foregroundcolor "Yellow"
   
   $database = "UKDB01"

    New-Mailbox -userPrincipalName $userPrincipalName -Alias $alias -Database $database -Name $Name -OrganizationalUnit $OU -Password (ConvertTo-SecureString -String "" -AsPlainText -Force) -FirstName $givenname -LastName $surname -DisplayName $Displayname -ResetPasswordOnNextLogon $false
    
    # Wait 4 seconds for attributes to be added.
    Start-Sleep -s 4
   
   # Add account to security groups 
   add-adgroupmember -Identity "HomeDrive_AD_Group" -Members $samaccountname
   add-adgroupmember -Identity "EU General Apps" -Members $samaccountname

   # Set extension attributes for user in AD
    Set-ADUser -Identity $samaccountname -Add @{extensionAttribute2 = $extensionAttribute2}
    Set-ADUser -Identity $samaccountname -Add @{extensionAttribute5 = $extensionAttribute5}
    Set-ADUser -Identity $samaccountname -Add @{extensionAttribute6 = $extensionAttribute6}
    Set-ADUser -Identity $samaccountname -company $Company


Write-Host "Now adding account to distribution groups..." -foregroundcolor "yellow"
# Adding account to relevent distribution group based on region

    IF($extensionAttribute5 -eq "A"){ 
        Add-DistributionGroupMember -Identity "#UK Region A Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "B"){ 
        Add-DistributionGroupMember -Identity "#UK Region B Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "C"){ 
        Add-DistributionGroupMember -Identity "#UK Region C Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "D"){ 
        Add-DistributionGroupMember -Identity "#UK Region D Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "E"){ 
        Add-DistributionGroupMember -Identity "#UK Region E Growth Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "F"){ 
        Add-DistributionGroupMember -Identity "#UK Region F Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "G"){ 
        Add-DistributionGroupMember -Identity "#UK Region G Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "H"){ 
        Add-DistributionGroupMember -Identity "#UK Region H Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "I"){ 
        Add-DistributionGroupMember -Identity "#UK Region I Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "J"){ 
        Add-DistributionGroupMember -Identity "#UK Region J Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "K"){ 
        Add-DistributionGroupMember -Identity "#UK Region K Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "L"){ 
        Add-DistributionGroupMember -Identity "#UK Region L Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "M"){ 
        Add-DistributionGroupMember -Identity "#UK Region M Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "N"){ 
        Add-DistributionGroupMember -Identity "#UK Region N Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "O"){ 
        Add-DistributionGroupMember -Identity "#UK Region O Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "P"){ 
        Add-DistributionGroupMember -Identity "#UK Region P Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "Q"){ 
        Add-DistributionGroupMember -Identity "#UK Region Q Centres" -Member $samaccountname}

    IF($extensionAttribute5 -eq "R"){ 
        Add-DistributionGroupMember -Identity "#UK Region R Centres" -Member $samaccountname}

        
            Write-Host "Successfully addeded account to it's Regional distribution group" -foregroundcolor "Green"


# Account created successfully

    Write-Host "Completed successfully" -foregroundcolor "Green"

   
    }


	
