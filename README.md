# NC2-Azure
This script is designed to help NC2 customer who will be deploying cluster into existing Azure resouce.. Especially, if the customer has many exisiting VNets and VNet peering, it will validate if there is any missing prerequisite components.

Usage to run script

1. Open a terminal in Azure Portal
2. Copy the provided script into a shell script file (e.g. nc2_rg_check.sh)
3. Run chnod +x nc2_rg_check.sh
4. Execute the script.
5. The script will ask to enter "Azure Resource Groups Name" 
6. It will display the validation result
