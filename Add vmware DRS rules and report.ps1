# Connect to vmware variables
$Server = Read-Host "Enter the vmware server name here: "
$creds = Get-StoredCredential -Target 'credentials'


# Cluster variables
$cluster = Read-Host "Enter the cluster name here: "

# DRS variables
$list_prompt = Read-Host "Enter the location of txt file with server names: "
$list = Get-Content $list_prompt
$site_A_drs_rule = "Site A VMs"
$site_B_drs_rule = "Site B VMs"

# Membership report variable
$output = "C:\SCRIPTS\drs_report.txt"


         ################## Unhash the below to connect to vmware ############

        #Connect-VIServer -Server $Server -Protocol https -Credential $creds
            
        ##################### Will prompt for MFA ###########################




$pre_run_report = foreach ($vm in $list) {

          #Get VM & Host info from vmware    
        
        $get_vm = get-vm -Name $vm | select Name, VMHost, PowerState


     #Create variables to seperate odd & even VM's. By dividing by 2, if whole number it is even       

        $n = $vm[-1]

        $Result = $n % 2

            IF ($Result -eq 0)  

                { echo "even_vm" -OutVariable EorO_vm | Out-Null }
 
            IF ($Result -eq 1)

                { echo "odd_vm" -OutVariable EorO_vm | Out-Null }

    
    #Create variables to seperate odd & even HOSTS's. By dividing by 2, if whole number it is even       

        $vhost = $get_vm.VMHost | select -ExpandProperty Name

        $h_short = $vhost-replace ".{17}$"

        $h = $h_short[-1]
        
        $h_Result = $h % 2

            IF ($h_Result -eq 0)  

                { echo "even_host" -OutVariable EorO_host | Out-Null }
 
            IF ($h_Result -eq 1)

                { echo "odd_host" -OutVariable EorO_host | Out-Null }

     #IF query to check if vm's are on correct HOSTs. Creates a variable to flag they will be moved when DRS rule is applied.                                         
                
                
             IF ( $EorO_vm -eq 'even_vm' -and $EorO_host -eq 'even_host') { echo "$vm will NOT move host" -OutVariable host_move  | Out-Null }

                elseif ( $EorO_vm -eq 'even_vm' -and $EorO_host -eq 'odd_host') { echo "$vm WILL move host" -OutVariable host_move  | Out-Null }

             IF ( $EorO_vm -eq 'odd_vm' -and $EorO_host -eq 'odd_host') { echo "$vm will NOT move host" -OutVariable host_move  | Out-Null }

                elseif ( $EorO_vm -eq 'odd_vm' -and $EorO_host -eq 'even_host') { echo "$vm WILL move host" -OutVariable host_move  | Out-Null }
       
       
       
        @( [pscustomobject]@{ VmName = $get_vm.Name ; VmHost = $get_vm.VMHost ; OddOrEvenVM = $EorO_vm ; OddorEvenHost = $EorO_host ; HostMoveStatus = $host_move ; PowerState = $get_vm.PowerState } )


            
            IF ( $host_move -eq "$vm WILL move host" ) { $question2 = $(Write-Host "$vm WILL MOVE HOST WHEN AFFINITY RULES ARE APPLIED" -ForegroundColor Red -BackgroundColor White )}

            
            


}


# Table of vm's current status
    $pre_run_report | FT -AutoSize

 
 # Question to user after displaying which VM's will move host after rule is applied. Will continue or stop script based off answer.

    $prompt = Read-Host "Do you want to continue with applying affinity rules? Y or N "

        if ( $prompt -eq "Y" ) { Write-Host "Setting affinity rules..." -ForegroundColor Cyan } 

            elseif ( $prompt -eq "N" ) { Return  }


    
    foreach ($vm in $list) {    
    
    
    
    #IF query to add vm's to DRS rules based off name


          #Get VM & Host info from vmware    
        
        $get_vm = get-vm -Name $vm | select Name, VMHost, PowerState


     #Create variables to seperate odd & even VM's. By dividing by 2, if whole number it is even    
                        
        $n = $vm[-1]

        $Result = $n % 2

            IF ($Result -eq 0)  

                { Write-Host "Adding $vm to $site_A_drs_rule" -ForegroundColor Green
        
                  Get-DrsClusterGroup $site_A_drs_rule -Cluster $cluster | Set-DrsClusterGroup -VM $vm -Add | Out-Null
                  #Add server to the DRS group for Site A servers 
                                                        }
 
            IF ($Result -eq 1)

                { Write-Host "Adding $vm to $site_B_drs_rule" -ForegroundColor Green
                  
                  Get-DrsClusterGroup $site_B_drs_rule -Cluster $cluster | Set-DrsClusterGroup -VM $vm -Add | Out-Null
                  #Add server to the DRS group for Site A servers }

                                             
                                             }
}



# Variables for generating report of DRS group members
    $get_A_drs_group_details = Get-DrsClusterGroup -Type VMGroup -Name $Site_A_drs_rule
    $get_B_drs_group_details = Get-DrsClusterGroup -Type VMGroup -Name $site_B_drs_rule


        # Progress prompt, details when report is being generated & where it will be saved
        Write-Host "
            DRS rules changes complete                         
                                                               
            Getting all DRS Rule members....                   
                                                               
            Report will be saved to $output      " -ForegroundColor DarkBlue -BackgroundColor White            
                


# Foreach loop that generates a list of all members of the Site A affinty rule group
        
    Foreach ($site_A in $get_A_drs_group_details) {

                $get_site_A_details = Get-VM -Name $get_A_drs_group_details.Member | Select Name , VMHost, PowerState

                    $A_report = foreach ( $A1 in $get_site_A_deets ) { 

        
                        @( [pscustomobject]@{ VmName = $A1.Name ; DRSGroup = $get_A_drs_group_details.Name ; VmHost = $A1.VMHost ; PowerState = $A1.PowerState } )

                                                } 
        } 

         


# Foreach loop that generates a list of all members of the Site B affinty rule group
        
    Foreach ($site_B in $get_B_drs_group_details) {

                $get_site_B_deets = Get-VM -Name $get_B_drs_group_details.Member | Select Name , VMHost, PowerState
                

                    $B_report = foreach ( $B1 in $get_site_B_deets ) { 

        
                        @( [pscustomobject]@{ VmName = $B1.Name ; DRSGroup = $get_B_drs_group_details.Name ; VmHost = $B1.VMHost ; PowerState = $B1.PowerState } )

                                                } 
        } 




    # Saves the list of members to the location specified in $ouput. Line 15. Will save the members of both groups in the same file
        
        $A_report | FT -AutoSize | Out-File $output
        $B_report | FT -AutoSize | Out-File $output -Append


        
        # Will open report file at the end of the script. Below location must match line 15 destination
            C:\SCRIPTS\drs_report.txt