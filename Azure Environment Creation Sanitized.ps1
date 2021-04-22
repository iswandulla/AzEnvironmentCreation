# Azure Environment Creation script
# Will Mason-01-05-20
# The intent of this script is to create a small environment for veeam office 365 deployments
# The objects created will be stored in resource groups specific to the functions of VM, Storage and Networking


######### Location and Resource Groupss
$azureLocation = "EastUS"
[String]$RG1Name = "Servers"
[String]$RG2Name = "Networking"
[String]$RG3Name = "Storage"

######### Vnet Config
$VnetName = "Prod-net"
[String]$SubnetName = "Server"
[String]$Supernet = '10.0.0.0/16'
[String]$SubnetScope = '10.0.240.0/24'
[String]$GWSubnet = '10.0.0.0/24'

#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"
 
########## Network Securty Group
 $NSG = "Admin-NSG"
 $Exip = Invoke-RestMethod -Method Get -Uri http://ipinfo.io/ip #get your external IP and store it for NSG rules

########## Storage Group
 $SG1 = "veeamtorage01021"

########## Virtual Machine Creation Variables 
 $VM1 = "Veeam0365-MP"
 $azureVmOsDiskName = "Veeam-Os"
 $azureVmSize = "Standard_D2s_v4"

######### Define the VM NIC and User Names
 $azureNicName = "Veeam-nic"
 $azurePublicIpName = "Veeam-PIP"
 $vmAdminUsername = "rofladmin"
 $vmAdminPassword = ConvertTo-SecureString "Passwords!" -AsPlainText -Force

##################################################################################################################################################
########## Begin Execution
 Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true" #Suppres Some Useless Warnings
 Connect-Azaccount #Connection to the Azure Subscription


########Create Resource Groups
 $RG1 = New-AzResourceGroup -Name $RG1Name -Location $azureLocation -Tag @{Object="Server"; Application="Veeam"}
 $RG2 = New-AzResourceGroup -Name $RG2Name -Location $azureLocation -Tag @{Object="Networking"; Application="Veeam"}
 $RG3 = New-AzResourceGroup -Name $RG3Name -Location $azureLocation -Tag @{Object="Storage"; Application="Veeam"}

 Start-sleep -Seconds 30

########Create NSG Rules then NSG
 $Rule1 = New-AzNetworkSecurityRuleConfig -Name "RDP-Admin" -Description "Allow RDP from WM ip" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $Exip -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
 New-AzNetworkSecurityGroup -Name $NSG -ResourceGroupName $RG2Name  -Location  $azureLocation -SecurityRules $Rule1 -Tag @{Object="NSG"; Application="Veeam"} -Verbose
 Start-Sleep -seconds 15
 $nsgId = get-AzNetworkSecurityGroup -name $NSG -ResourceGroupName $RG2Name

Start-sleep -seconds 30

##########Create VNet
 $Subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $($SubnetScope) -networksecuritygroupid $nsgId.id
 $VPNsubnet = New-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -AddressPrefix $($GWsubnet) #No Network Security Group

 Start-sleep -Seconds 30
 New-AzVirtualNetwork -ResourceGroupName $RG2Name -Location $azureLocation -Name $VnetName -AddressPrefix $Supernet -Subnet $Subnet, $VPNsubnet -Tag @{Object="Vnet"; Application="Veeam"} -Verbose 

Start-Sleep -Seconds 30

#############Define the existing VNet information.
 
  $GetVnetSubnetName = (Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $RG2.ResourceGroupName).Subnets | Where-Object {$_.Name -eq $Subnet.Name}
  #$SubnetId = $GetVnetSubnetName.id 
 
#############Create the public IP address.
  $azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $RG1.ResourceGroupName -Location $azureLocation -AllocationMethod Dynamic
 
#############Wait for the above to be completed
  Start-Sleep -Seconds 45

#############Create the NIC and associate the public IpAddress.
  $azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $RG1.ResourceGroupName -Location $azureLocation -SubnetId $GetVnetSubnetName.id -PublicIpAddressId $azurePublicIp.Id -NetworkSecurityGroupId $nsgId.Id
 
#############Wait for the above to be completed
  Start-Sleep -Seconds 60

#############Store the credentials for the local admin account.
  $vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#############Define the parameters for the new virtual machine.
  $VirtualMachine = New-AzVMConfig -VMName $VM1 -VMSize $azureVmSize
  $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VM1 -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
  $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id
  $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
  $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
  $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
 #############Create the virtual machine.
  New-AzVM -ResourceGroupName $RG1Name -Location $azureLocation -VM $VirtualMachine -Verbose
  Start-Sleep -Seconds 30

#############Stop the VM
  Stop-AzVM -ResourceGroupName $RG1Name -Name $VM1 -Force


############Create Storage Account
New-AzStorageAccount -ResourceGroupName $RG3.ResourceGroupName `
  -Name $SG1 `
  -Location $azureLocation `
  -SkuName Standard_LRS `
  -Kind StorageV2 `

##############Create Virtual Network Gateway
 $GWPIP = New-AzPublicIpAddress -Name GwPip -ResourceGroupName $RG2.ResourceGroupName -Location $azureLocation -AllocationMethod Dynamic
 $GetGWsubnet = (Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $RG2Name).Subnets | Where-Object {$_.Name -eq "GatewaySubnet"}
 Start-Sleep -seconds 30
 $GWconfig = new-azvirtualnetworkgatewayipconfig -Name Gwipgatewayconfig -SubnetId $GetGWsubnet.Id -PublicIpAddressId $GWPIP.Id
 New-AzVirtualNetworkGateway -Name VNG01 -ResourceGroupName $RG2.ResourceGroupName -Location $azureLocation -IpConfigurations $GWconfig -GatewayType Vpn `
 -VpnType RouteBased -GatewaySku VpnGw1 -Verbose





