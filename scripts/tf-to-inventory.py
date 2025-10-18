#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

# Load Terraform JSON output
with open(sys.argv[1]) as f:
    obj = json.load(f)

def extract_ip(output_name):
    """Extract IP from Terraform output, handle lists."""
    if output_name not in obj:
        return None
    ip = obj[output_name].get('value')
    if isinstance(ip, list):
        ip = ip[0]
    return ip

# Extract IPs / endpoints
app_ip = extract_ip('app_public_ip')
mysql_endpoint = extract_ip('rds_endpoint')

# Generate Ansible inventory
if app_ip:
    print("[app]")
    print(f"{app_ip} ansible_user=ubuntu")
    print()

if mysql_endpoint:
    print("[rds]")
    # No SSH, just for DB connection in playbook
    print(f"{mysql_endpoint} ansible_user=admin ansible_password='{{ vault_rds_password }}' ansible_port=3306")
    print()
