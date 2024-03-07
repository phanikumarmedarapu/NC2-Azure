# Author : Andrew Nam 
# Date : 2024Mar05
# Filename : AN_RG_Combined_Check_v4.sh
# Source : [resource_groups_check_4.sh + subnetmask_check.sh] + vnet_nsg_check_v2.sh + natgw_publicip_tag.sh

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
	local nat_gateway_info=$(az network nat gateway list --resource-group "$rg_name" --query "[?provisioningState=='Succeeded'].{Name:name}" --output json)
	
    az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep -q natGateway
    if [ $? -eq 0 ]; then
        echo "NAT Gateway is attached :"
        az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name | grep natGateway -B1
	    for nat_gateway_name in $(echo "$nat_gateway_info" | jq -r '.[].Name'); do
	       echo "NAT Gateway: $nat_gateway_name"

	       # Check if NAT gateway has a public IP address
	       public_ip=$(az network nat gateway show --resource-group "$rg_name" --name "$nat_gateway_name" --query "publicIpAddresses[0].id" --output tsv)
	       if [ -n "$public_ip" ]; then
                echo "Public IP is assigned to NAT gateway '$nat_gateway_name'."
	       else
	            echo "No public IP assigned to NAT gateway '$nat_gateway_name'."
	       fi

	       # Check if NAT gateway has tag 'fastpathenable' set to 'true'
	       fastpath_enabled=$(az network nat gateway show --resource-group "$rg_name" --name "$nat_gateway_name" --query "tags.fastpathenabled" --output tsv)
	       if [ "$fastpath_enabled" = "True" ]; then
	            echo "NAT gateway '$nat_gateway_name' has tag 'fastpathenable' set to 'true'."
	       else
	            echo "NAT gateway '$nat_gateway_name' does not have tag 'fastpathenable' set to 'true'."
	       fi

	       # Get connected subnets
           connected_subnets=$(az network nat gateway show --resource-group Andrew_Manual_RG --name an_pc_natgw | jq -r '.subnets[] | del(.resourceGroup)')
	       echo "Connected Subnets:"
	       echo "$connected_subnets"
	       done
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

# Function to check NSG association
check_nsg_association() {
    local rg_name=$1
    local vnet_name=$2
    local subnets=$(az network vnet subnet list --resource-group $rg_name --vnet-name $vnet_name --query "[].name" -o tsv)

    if [ -z "$subnets" ]; then
        echo "No subnets found in VNet '$vnet_name' of resource group '$rg_name'."
        return
    fi

    for subnet in $subnets; do
        local nsg=$(az network vnet subnet show --resource-group $rg_name --vnet-name $vnet_name --name $subnet --query "networkSecurityGroup.id" -o tsv)

        if [ -z "$nsg" ]; then
            echo "   Subnet '$subnet': No NSG associated"
        else
            echo "   Subnet '$subnet': NSG '$nsg' associated"
        fi
    done
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

            # Check NSG association
            check_nsg_association $resource_group $vnet_name
        done
    fi
}

# Run the main function
main
