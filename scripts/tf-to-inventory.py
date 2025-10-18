#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

# Load Terraform JSON output
with open(sys.argv[1]) as f:
    tf_output = json.load(f)

def get_first_ip(key):
    """Extract first IP from Terraform output value (handles list or string)."""
    value = tf_output.get(key, {}).get("value")
    if isinstance(value, list):
        return value[0]
    return value

# Extract IPs
app_ip = get_first_ip("app_public_ip")       # EC2 app server (SSH)
rds_ip = get_first_ip("rds_private_ip")     # RDS private IP (MySQL only)

# Generate inventory
inventory_lines = []

# App server group
if app_ip:
    inventory_lines.append("[app]")
    inventory_lines.append(f"{app_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa")
    inventory_lines.append("")

# RDS group (MySQL connection only, no SSH)
if rds_ip:
    inventory_lines.append("[rds]")
    inventory_lines.append(f"{rds_ip}")

# Output final inventory
print("\n".join(inventory_lines))
