# Author : Phani Medarapu
# Email : phanikumar.medarapu@nutanix.com
# Date : 2024Aug6
# Goal : script is to validate NC2 prerequisit requirement for FGW vmtype: Standard_D4_v4 & Standard_D32_v4


#!/bin/bash

# Define a list of Azure regions
regions=("australiaeast" "eastus" "eastus2" "germanywestcentral" "japaneast" "northcentralus" "southeastasia" "uksouth" "westcentralus" "westeurope" "westus2")

echo "Available Azure Regions:"
for i in "${!regions[@]}"; do
  echo "$i) ${regions[$i]}"
done

read -p "Select a region by entering the corresponding number: " region_index

if ! [[ "$region_index" =~ ^[0-9]+$ ]] || [ "$region_index" -lt 0 ] || [ "$region_index" -ge "${#regions[@]}" ]; then
  echo "Invalid selection. Please run the script again and select a valid region."
  exit 1
fi

REGION="${regions[$region_index]}"
vm_types=("Standard_D4_v4" "Standard_D32_v4")

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_vm_availability() {
  local region=$1
  local vm_type=$2

  echo ""
  echo "Checking availability of $vm_type in $region..."
  available_vm_sizes=$(az vm list-sizes --location $region --query "[].name" --output tsv)

  if echo "$available_vm_sizes" | grep -q "^$vm_type$"; then
    echo -e "${vm_type} = ${GREEN}available${NC}"
  else
    echo -e "${vm_type} = ${RED}not available${NC}"
  fi
}

for vm_type in "${vm_types[@]}"; do
  check_vm_availability "$REGION" "$vm_type"
done
