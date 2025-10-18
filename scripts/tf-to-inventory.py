#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

with open(sys.argv[1]) as f:
    tf_output = json.load(f)

def get_first_ip(key):
    value = tf_output.get(key, {}).get("value")
    if isinstance(value, list):
        return value[0]
    return value

# App server (jump host)
app_ip = get_first_ip("app_public_ip")
# RDS private IP
rds_ip = get_first_ip("rds_private_ip")

# Generate inventory
if app_ip:
    print("[app]")
    print(f"{app_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa")
    print()

if rds_ip:
    print("[rds]")
    # Use ProxyJump via app server to reach private RDS
    print(f"{rds_ip} ansible_user=root ansible_ssh_common_args='-o ProxyJump=ubuntu@{app_ip}'")
    print()


if app_ip:
    print("[app]")
    print(f"{app_ip} ansible_user=ubuntu")
