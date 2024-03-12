# Author : Andrew Nam
# Date : 2024Mar08
# source : natgw_publicip_tag_RG_all_4-3.sh
# Goal : convert natgw_publicip_tag_RG_all_4-2.sh to python
# fixed :
# 1. nat gateway info - Provisioning State, subnet, public ip, tags
# 2. delegation info included
# 3. dns per vnet
# 4. minor format improvement made


import subprocess
import json

def get_subnet_info(rg_name, vnet_name):
    subnet_info = subprocess.run(['az', 'network', 'vnet', 'subnet', 'list', '--resource-group', rg_name, '--vnet-name', vnet_name, '--query', "[].{Name:name, AddressPrefix:addressPrefix}", '--output', 'json'], capture_output=True, text=True)
    return subnet_info.stdout

def check_subnet_delegation(rg_name, vnet_name):
    subnet_list = subprocess.run(['az', 'network', 'vnet', 'subnet', 'list', '--resource-group', rg_name, '--vnet-name', vnet_name], capture_output=True, text=True)
    if "Microsoft.Network/virtualNetworks/subnets/delegations" in subnet_list.stdout:
        print(" ")
        print(" ")
        print(f"[RESULT] Microsoft.BareMetal.AzureHostedService subnet delegation found for {vnet_name}:")
        #subprocess.run(['az', 'network', 'vnet', 'subnet', 'list', '--resource-group', rg_name, '--vnet-name', vnet_name, '--query', "[?contains(@.delegations, 'Microsoft.Network/virtualNetworks/subnets/delegations')]", '--output', 'json'])
        with open('subnet_delegate.txt', 'w') as file:
            json.dump(json.loads(subnet_list.stdout), file, indent=4)
        print("[RESULT] subnet delegate to :")
        subprocess.run(['grep', 'Microsoft.Network/virtualNetworks/subnets/delegations', '-B5', 'subnet_delegate.txt'])
        # Microsoft.Network/virtualNetworks/subnets/delegations -B3
        print("")
    else:
        print(" ")
        print(" ")
        print(f"[RESULT] No subnet delegation found in {vnet_name} !!!!")

def check_vnet_peering(rg_name, vnet_name):
    output_peer = subprocess.run(['az', 'network', 'vnet', 'peering', 'list', '--resource-group', rg_name, '--vnet-name', vnet_name], capture_output=True, text=True)
    peering_found = any([p for p in json.loads(output_peer.stdout) if 'peeringState' in p and 'type' in p and p['type'] == 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'])
    if peering_found:
        print(" ")
        print(" ")
        print("Entries found with 'peeringState' and 'type' as 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings':")
        with open('vnet_peering.txt', 'w') as file:
            json.dump(json.loads(output_peer.stdout), file, indent=4)
        print(f"[RESULT] vnet {vnet_name} peering to :")
        subprocess.run(['grep', 'peeringState', '-B1', '-A5', 'vnet_peering.txt'])
        print("")
    else:
        print("[RESULT] VNet peering is not found!!!")

def check_dns_servers(rg_name, vnet_name):
    output_dns = subprocess.run(['az', 'network', 'vnet', 'show', '--resource-group', rg_name, '--name', vnet_name, '--query', 'dhcpOptions.dnsServers'], capture_output=True, text=True)
    if not output_dns.stdout:
        print(" ")
        print(" ")
        print("[RESULT] No DNS server IP addresses found.")
        print("")
    else:
        print(" ")
        print(" ")
        print("DNS server IP addresses found:")
        print(f"[RESULT] DNS IP : {output_dns.stdout} for {vnet_name}")
        print("")

def check_nsg_association(rg_name, vnet_name):
    subnets = subprocess.run(['az', 'network', 'vnet', 'subnet', 'list', '--resource-group', rg_name, '--vnet-name', vnet_name, '--query', "[].name", '-o', 'tsv'], capture_output=True, text=True).stdout.splitlines()
    print(" ")
    print(" ")
    print(" ")
    print("NSG Setting")
    if not subnets:
        print(" ")
        print(f"[RESULT] No subnets found in VNet '{vnet_name}' of resource group '{rg_name}'.")
        return

    for subnet in subnets:
        nsg = subprocess.run(['az', 'network', 'vnet', 'subnet', 'show', '--resource-group', rg_name, '--vnet-name', vnet_name, '--name', subnet, '--query', 'networkSecurityGroup.id', '-o', 'tsv'], capture_output=True, text=True).stdout
        print(" ")
        print("[RESULT] NSG Subnet Association :")

        if not nsg:
            print(f"Subnet '{subnet}': No NSG associated")
        else:
            print(f"Subnet '{subnet}': NSG '{nsg}' associated")

def check_nat_gateway(rg_name):
    # Check if NAT Gateway is configured
    nat_gateway_list_command = f"az network nat gateway list -g {rg_name}"
    try:
        nat_gateways_output = subprocess.check_output(nat_gateway_list_command, shell=True)
        nat_gateways = json.loads(nat_gateways_output)

        if len(nat_gateways) > 0:
            print("NAT Gateway is configured.")
            print("")
            #print(f"NAT Gateway Subnet ID: {nat_gateways[0].get('subnet', {}).get('id')}")
            for entry in nat_gateways:
                print("[RESULT] NAT Gateway Information ")
                print(f"Name: {entry['name']}")
                print(f"Provisioning State: {entry['provisioningState']}")
                print("")
                print(f"Public IP Address ID: {entry['publicIpAddresses'][0]['id']}")
                print("")
                print(f"Subnet ID: {entry['subnets'][0]['id']}")
                print("")
                print("Tags:")
                tags = entry.get('tags', {})
                fastpath_enabled = tags.get('fastpathenabled', 'Unknown')
                print(f"FastPathEnabled: {fastpath_enabled}")
                print("")
                print("")
                print("")
        else:
            print("NAT Gateway list is empty.")
    except subprocess.CalledProcessError as e:
        print("Error occurred while retrieving NAT gateways.")
        print(e.output.decode("utf-8"))


def main():
    # Prompt user for resource group name
    resource_group = input("Enter the Azure Resource Group name: ")

    # Check if the resource group exists
    rg_exists = subprocess.run(['az', 'group', 'show', '--name', resource_group], capture_output=True, text=True).returncode
    if rg_exists != 0:
        print(f"Resource group '{resource_group}' does not exist.")
        exit(1)

    # Get the list of VNets in the specified resource group
    vnets = subprocess.run(['az', 'network', 'vnet', 'list', '--resource-group', resource_group, '--query', "[].name", '--output', 'tsv'], capture_output=True, text=True).stdout.splitlines()

    # Check if there are any VNets in the resource group
    if not vnets:
        print(f"No VNets found in resource group '{resource_group}'.")
    else:
        print(" ")
        print(" ")
        print(f"VNets found in resource group '{resource_group}':")
        # Iterate over each VNet in the list
        for vnet_name in vnets:
            print(" ")
            print(" ")
            print("======================")
            print(f"VNet: {vnet_name}")
            print(" ")
            # Get subnet information for the current VNet
            subnet_info = get_subnet_info(resource_group, vnet_name)

            # Print subnet information
            print("Subnet")
            print(f"[RESULT] {subnet_info} : ")

            # Check subnet delegation
            check_subnet_delegation(resource_group, vnet_name)

            # Check VNet peering
            check_vnet_peering(resource_group, vnet_name)

            # Check DNS servers
            check_dns_servers(resource_group, vnet_name)

            # Check NSG association
            check_nsg_association(resource_group, vnet_name)

        # Check NAT Gateway
        check_nat_gateway(resource_group)


# Run the main function
if __name__ == "__main__":
    main()
