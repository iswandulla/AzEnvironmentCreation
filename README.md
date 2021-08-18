# AzEnvironmentCreation
PS Script used to create a Small Azure environment 
This will create a Virtual Network Gateway, resource groups, a vm, vnet..  everything needed to have a small functional environment.  After all of this you will still need to do things like and IPSEC tunnel to your on prem, or configure the vpn gateway.
I would reccomend going to like 40 and 41 and changing the password and user name.  The NSG rule on here will only allow rdp connections from your current external IP.  If others need to access the vm then they will need to havethier external IP added..  
