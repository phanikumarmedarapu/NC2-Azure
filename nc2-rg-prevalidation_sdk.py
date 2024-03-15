# source : https://github.com/nutanix-core/nc2-deployment-wizard/blob/static_validations_rohan/src/nc2_deployment_wizard/static_checks/nc2-rg-prevalidation_sdk.py
# Date:2024Mar13
# Author : Andrew Nam
# Co-Author : Rohan Tiwari
# Step1 : First, make sure you've installed the necessary Azure SDK packages:
#        pip install azure-mgmt-network azure-identity
# Step2. Please replace **`<your-subscription-id>`** with your actual subscription ID.
# Note : This version of the script uses the Azure SDK for Python (**`azure-mgmt-network`**) to interact with Azure resources instead of using the Azure CLI commands directly. It should provide similar functionality as your original script but using the Azure SDK.


from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient
from azure.core.exceptions import ClientAuthenticationError
from azure.mgmt.resource import ResourceManagementClient
import json
import os



client_id=os.environ["AZURE_CLIENT_ID"]
client_secret=os.environ["AZURE_CLIENT_SECRET"]
tenant_id=os.environ["AZURE_TENANT_ID"]
subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
customer_resource_group = "rm_ntnx_test_rg"
region = "eastus"
# Azure authentication
credential = DefaultAzureCredential()

# Initialize network management client
network_client = NetworkManagementClient(credential, subscription_id)

resource_client = ResourceManagementClient(credential, subscription_id)

def get_subnet_info(network_client, rg_name, vnet_name):
    subnet_list = network_client.subnets.list(rg_name, vnet_name)
    subnets_info = []
    for subnet in subnet_list:
        subnets_info.append({
            "Name": subnet.name,
            "AddressPrefix": subnet.address_prefix
        })
    return subnets_info

def check_subnet_delegation(network_client, rg_name, vnet_name):
    subnet_list = network_client.subnets.list(rg_name, vnet_name)
    for subnet in subnet_list:
        if subnet.delegations:
            print(" ")
            print(" ")
            print(f"[RESULT] {subnet.delegations[0].name} subnet delegation found for {vnet_name} for subnet {subnet.name}:")
            print("[RESULT] subnet delegate to :")
            print(json.dumps(subnet.delegations[0].serialize(), indent=4))
            print("")
        else:
            print(" ")
            print(" ")
            print(f"[RESULT] No subnet delegation found in {vnet_name} !!!!")

def check_vnet_peering(network_client, rg_name, vnet_name):
    peering_list = network_client.virtual_network_peerings.list(rg_name, vnet_name)
    peering_found = any(peering for peering in peering_list if peering.peering_state)
    if peering_found:
        print(" ")
        print(" ")
        print("Entries found with 'peeringState' as 'Connected':")
        print(f"[RESULT] vnet {vnet_name} peering to :")
        print(json.dumps([peering.serialize() for peering in peering_list if peering.peering_state], indent=4))
        print("")
    else:
        print("[RESULT] VNet peering is not found!!!")

def check_dns_servers(network_client, rg_name, vnet_name):
    vnet = network_client.virtual_networks.get(rg_name, vnet_name)
    if not vnet.dhcp_options or not vnet.dhcp_options.dns_servers:
        print(" ")
        print(" ")
        print("[RESULT] No DNS server IP addresses found.")
        print("")
    else:
        print(" ")
        print(" ")
        print("DNS server IP addresses found:")
        print(f"[RESULT] DNS IP : {', '.join(vnet.dhcp_options.dns_servers)} for {vnet_name}")
        print("")

def check_nsg_association(network_client, rg_name, vnet_name):
    subnet_list = network_client.subnets.list(rg_name, vnet_name)
    print(" ")
    print(" ")
    print(" ")
    print("NSG Setting")
    if not subnet_list:
        print(" ")
        print(f"[RESULT] No subnets found in VNet '{vnet_name}' of resource group '{rg_name}'.")
        return

    for subnet in subnet_list:
        if not subnet.network_security_group:
            print(f"Subnet '{subnet.name}': No NSG associated")
        else:
            print(f"Subnet '{subnet.name}': NSG '{subnet.network_security_group.id}' associated")

def check_nat_gateway(network_client, rg_name, vnet_name):
    nat_gateways = network_client.nat_gateways.list(rg_name)
    print(" ")
    print(" ")
    print(" ")
    if not nat_gateways:
        print(f"[RESULT] No NAT Gateway found in VNet '{vnet_name}' of resource group '{rg_name}'.")
        return

    for nat_gateway in nat_gateways:
        print("NAT Gateway: ")
        print(f"[RESULT] NAT Gateway: {nat_gateway.name}")

        if nat_gateway.public_ip_addresses:
            print(f"[RESULT] Public IP is assigned to NAT gateway '{nat_gateway.name}'.")
        else:
            print(f"[RESULT] No public IP assigned to NAT gateway '{nat_gateway.name}'.")

        if nat_gateway.tags.get('fastpathenabled') == "True":
            print(f"[RESULT] NAT gateway '{nat_gateway.name}' has tag 'fastpathenabled' set to 'True'.")
            print(" ")
        else:
            print(f"[RESULT] NAT gateway '{nat_gateway.name}' does not have tag 'fastpathenabled' set to 'True'.")
            print(" ")

def check_resource_group(resource_client, rg_name):
    resource_group_exists = resource_client.resource_groups.check_existence(rg_name)
    if not resource_group_exists:
        print(f"Resource group '{rg_name}' does not exist.")
        exit(1)

def main():
    # Check if the resource group exists
    check_resource_group(resource_client, customer_resource_group)
    # Get the list of VNets in the specified resource group
    vnets = network_client.virtual_networks.list(customer_resource_group)

    # Check if there are any VNets in the resource group
    if not vnets:
        print(f"No VNets found in resource group '{customer_resource_group}'.")
    else:
        print(" ")
        print(" ")
        print(f"VNets found in resource group '{customer_resource_group}':")
        # Iterate over each VNet in the list
        for vnet in vnets:
            print(" ")
            print(" ")
            print("======================")
            print(f"VNet: {vnet.name}")
            print(f"Resource GUID: {vnet.resource_guid}")
            print(" ")
            # Get subnet information for the current VNet
            subnet_info = get_subnet_info(network_client, customer_resource_group, vnet.name)

            # Print subnet information
            print("Subnet")
            print(f"[RESULT] : {json.dumps(subnet_info, indent=4)}")

            # Check subnet delegation
            check_subnet_delegation(network_client, customer_resource_group, vnet.name)

            # Check VNet peering
            check_vnet_peering(network_client, customer_resource_group, vnet.name)

            # Check DNS servers
            check_dns_servers(network_client, customer_resource_group, vnet.name)

            # Check NSG association
            check_nsg_association(network_client, customer_resource_group, vnet.name)

            # Check NAT Gateway
            check_nat_gateway(network_client, customer_resource_group, vnet.name)

# Run the main function
if __name__ == "__main__":
    main()
