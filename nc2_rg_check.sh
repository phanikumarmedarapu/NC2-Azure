# Author : Andrew Nam 
# Email : andrew.nam@nutanix.com
# Date : 2024Feb26
# Goal : script is to validate NC2 prerequisit requirement : VNET, VNET Peering, NAT GW, Subnet delegation, and DNS configuration

#!/bin/bash

# Prompt user to enter resource group name
read -p "Enter the Azure Resource Group name: " resource_group

# Check if the resource group exists
az group show --name "$resource_group" &>/dev/null
if [ $? -ne 0 ]; then
    echo "Resource group '$resource_group' does not exist."
    exit 1
fi

# Get the list of VNets in the specified resource group
vnets=$(az network vnet list --resource-group "$resource_group" --query "[].name" -o tsv)

# Check if there are any VNets in the resource group
if [ -z "$vnets" ]; then
    echo "No VNets found in resource group '$resource_group'."
else
    echo "VNets found in resource group '$resource_group':"
    # Iterate over each VNet in the list
    for vnet in $vnets; do
        echo "VNet: $vnet"
        # Run Azure CLI command and check if it contains the desired fields
        output=$(az network vnet subnet list --resource-group "$resource_group" --vnet-name "$vnet")
        echo "$output" > subnet_delegation.txt
        #--- new starts--#
        if grep -q "Microsoft.Network/virtualNetworks/subnets/delegations" subnet_delegation.txt ; then
            echo "Microsoft.BareMetal.AzureHostedService subnet delegation found:"
            cat subnet_delegation.txt | grep BareMetal.AzureHostedService -A5
        else
            echo "No subnet delegation found in $vnet !!!!"
        fi 
        #--- new ends--#
        echo "subnet delegate to :"
        cat subnet_delegation.txt | grep serviceName
        if grep -q natGateway subnet_delegation.txt; then
            echo "NAT Gateway is attached :"
            cat subnet_delegation.txt | grep natGateway -B1
        else
            echo "NAT Gateway is not found!!!"
        fi
        output_peer=$(az network vnet peering list --resource-group "$resource_group" --vnet-name "$vnet")
        if echo "$output_peer" | jq -e 'any(.[]; select(has("peeringState") and .type == "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"))' >/dev/null; then
            echo "Entries found with 'peeringState' and 'type' as 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings':"
            echo "$output_peer" > vnet_peering.txt
            echo "vnet peering to :"
            cat vnet_peering.txt | grep peeringState -B1 -A5
            echo ""
        else
            echo "VNet peering is not found!!!"
        fi
        output_dns=$(az network vnet show --resource-group "$resource_group" --name "$vnet" --query 'dhcpOptions.dnsServers')
        if [ -z "$output_dns" ]; then
            echo "No DNS server IP addresses found."
        else
            echo "DNS server IP addresses found:"
            echo "$output_dns"
        fi  
    done
fi
