#!/usr/bin/env python3
import json, sys

if len(sys.argv) < 2:
    print("Usage: tf-to-inventory.py path/to/tfoutput.json")
    sys.exit(1)

obj = json.load(open(sys.argv[1]))
# Expect output name ec2_public_ip
if 'ec2_public_ip' in obj:
    ip = obj['ec2_public_ip']['value']
else:
    # fallback: take first value
    first = next(iter(obj.values()))
    ip = first.get('value')

print("[all]")
print(f"{ip} ansible_user=ubuntu")
