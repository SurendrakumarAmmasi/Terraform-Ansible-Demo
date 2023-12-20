import json
from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient

# Replace '551d4f9d-a651-4011-a550-f4cdcb4f653a' with your actual subscription ID
subscription_id = '551d4f9d-a651-4011-a550-f4cdcb4f653a'
resource_group_name = 'tf-ans-demo-rg'  # Replace with your actual resource group name

# Create a ComputeManagementClient with DefaultAzureCredential
credential = DefaultAzureCredential()
compute_client = ComputeManagementClient(credential, subscription_id)

# Create a NetworkManagementClient with DefaultAzureCredential
network_client = NetworkManagementClient(credential, subscription_id)

# Function to retrieve VM IP address without interface name
def get_vm_ip_address(network_client, vm_name, resource_group_name):
    # Retrieve network interfaces for the VM
    network_interfaces = network_client.network_interfaces.list(resource_group_name)

    # Implement logic to determine the primary or desired interface:
    primary_interface = next(
        (nic for nic in network_interfaces if nic.virtual_machine.id.endswith(vm_name)), None
    )  # Example: Use the first interface associated with the VM

    if primary_interface:
        return primary_interface.ip_configurations[0].private_ip_address  # Assuming single IP configuration
    else:
        raise ValueError(f"No network interface found for VM: {vm_name}")  # Handle missing network interface

# Retrieve virtual machines
vms = compute_client.virtual_machines.list(resource_group_name)

# Build inventory
inventory = {
    "all": {
        "hosts": {
            vm.name: {
                "ansible_host": get_vm_ip_address(network_client, vm.name, resource_group_name),
                "ansible_user": "azureuser",
                "ansible_ssh_private_key_file": "/home/azureuser/.ssh/azurekey"
            }
            for vm in vms
        }
    }
}

print(json.dumps(inventory, indent=2))
