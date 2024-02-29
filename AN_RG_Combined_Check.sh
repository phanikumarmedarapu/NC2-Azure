# Author : Andrew Nam
# Email : andrew.nam@nutanix.com
# Date : 2024Feb28
# Goal : script is to validate NC2 prerequisit requirement : VNET, VNET Peering, NAT GW, Subnet delegation, DNS configuration, and subnet mask

#!/bin/bash

# Function to get subnet information for a given VNet
get_subnet_info() {
    local rg_name=$1
    local vnet_name=$2
    local subnet_info=$(az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name --query "[].{Name:name, AddressPrefix:addressPrefix}" --output tsv)
    echo "$subnet_info"
}

# Function to check subnet delegation
check_subnet_delegation() {
    local rg_name=$1
    local vnet_name=$2
    az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep -q "Microsoft.Network/virtualNetworks/subnets/delegations"
    if [ $? -eq 0 ]; then
        echo "Microsoft.BareMetal.AzureHostedService subnet delegation found:"
        az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep BareMetal.AzureHostedService -A5
    else
        echo "No subnet delegation found in $vnet_name !!!!"
    fi
}

# Function to check NAT Gateway
check_nat_gateway() {
    local rg_name=$1
    local vnet_name=$2
    az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep -q natGateway
    if [ $? -eq 0 ]; then
        echo "NAT Gateway is attached :"
        az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep natGateway -B1
    else
        echo "NAT Gateway is not found!!!"
    fi
}

# Function to check VNet peering
check_vnet_peering() {
    local rg_name=$1
    local vnet_name=$2
    output_peer=$(az network vnet peering list --resource-group "$rg_name" --vnet-name "$vnet_name")
    if echo "$output_peer" | jq -e 'any(.[]; select(has("peeringState") and .type == "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"))' >/dev/null; then
        echo "Entries found with 'peeringState' and 'type' as 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings':"
        echo "$output_peer" > vnet_peering.txt
        echo "vnet peering to :"
        cat vnet_peering.txt | grep peeringState -B1 -A5
        echo ""
    else
        echo "VNet peering is not found!!!"
    fi
}

# Function to check DNS servers
check_dns_servers() {
    local rg_name=$1
    local vnet_name=$2
    output_dns=$(az network vnet show --resource-group "$rg_name" --name "$vnet_name" --query 'dhcpOptions.dnsServers')
    if [ -z "$output_dns" ]; then
        echo "No DNS server IP addresses found."
    else
        echo "DNS server IP addresses found:"
        echo "$output_dns"
    fi
}

# Main function
main() {
    # Prompt user for resource group name
    read -p "Enter the Azure Resource Group name: " resource_group

    # Check if the resource group exists
    az group show --name "$resource_group" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Resource group '$resource_group' does not exist."
        exit 1
    fi

    # Get the list of VNets in the specified resource group
    vnets=$(az network vnet list --resource-group "$resource_group" --query "[].name" --output tsv)

    # Check if there are any VNets in the resource group
    if [ -z "$vnets" ]; then
        echo "No VNets found in resource group '$resource_group'."
    else
        echo "VNets found in resource group '$resource_group':"
        # Iterate over each VNet in the list
        for vnet_name in $vnets; do
            echo "VNet: $vnet_name"

            # Get subnet information for the current VNet
            subnet_info=$(get_subnet_info $resource_group $vnet_name)

            # Print subnet information
            echo "$subnet_info"

            # Check subnet delegation
            check_subnet_delegation $resource_group $vnet_name

            # Check NAT Gateway
            check_nat_gateway $resource_group $vnet_name

            # Check VNet peering
            check_vnet_peering $resource_group $vnet_name

            # Check DNS servers
            check_dns_servers $resource_group $vnet_name
        done
    fi
}

# Run the main function
main
