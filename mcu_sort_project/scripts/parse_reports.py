#!/usr/bin/env python3
"""Parse Vivado utilization and timing reports, compute cost = 6*LUT + 10*FF."""
import re, json, sys

def parse_util(path):
    with open(path) as f:
        text = f.read()
    lut = int(re.search(r'Slice LUTs\*?\s*\|\s*(\d+)', text).group(1))
    ff  = int(re.search(r'Slice Registers?\*?\s*\|\s*(\d+)', text).group(1))
    return {'LUT': lut, 'FF': ff, 'cost': 6*lut + 10*ff}

def parse_wns(path):
    with open(path) as f:
        text = f.read()
    m = re.search(r'sys_clk\s+(-?\d+\.?\d*)', text)
    return float(m.group(1)) if m else None

results = {}
for variant in ['efficiency', 'speed']:
    try:
        u = parse_util(f'../reports/{variant}_util.rpt')
    except:
        u = {'LUT': 0, 'FF': 0, 'cost': 0}
    try:
        w = parse_wns(f'../reports/{variant}_timing.rpt')
    except:
        w = None
    results[variant] = {**u, 'WNS_ns': w}

with open('../reports/summary.json', 'w') as f:
    json.dump(results, f, indent=2)

for v in ['efficiency', 'speed']:
    r = results[v]
    print(f"{v}: LUT={r['LUT']}, FF={r['FF']}, cost={r['cost']}, WNS={r['WNS_ns']}ns")
