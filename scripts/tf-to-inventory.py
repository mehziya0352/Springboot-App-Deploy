#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

# Load Terraform JSON output
with open(sys.argv[1]) as f:
    tf_output = json.load(f)

def extract_value(output_name):
    """Extract value from Terraform output, handle lists."""
    if output_name not in tf_output:
        return None
    val = tf_output[output_name].get('value')
    if isinstance(val, list):
        val = val[0]
    return val

# Extract IPs
app_ip = extract_value('app_public_ip')
rds_endpoint = extract_value('rds_private_ip')  # or rds_endpoint if using DNS

# Generate Ansible inventory
if rds_endpoint and app_ip:
    print("[rds]")
    # Use ProxyJump through app server for private RDS
    print(f"{rds_endpoint} ansible_user=ubuntu ansible_ssh_common_args='-o ProxyJump=ubuntu@{app_ip}'")
    print()

if app_ip:
    print("[app]")
    print(f"{app_ip} ansible_user=ubuntu")
