#!/usr/bin/env python3
"""
Parse Terraform port_blueprints/main.tf and emit a JSON summary of blueprint identifiers
and their properties (with whether each property is marked required).

Usage:
  python scripts/parse_port_blueprints.py \
    --file terraform/modules/port_blueprints/main.tf \
    --output blueprints_local.json

The output is a JSON object mapping blueprint identifier -> {resource_name, properties: {name: {group, required}}}

This is a best-effort parser using simple brace-matching and regex; it should work for the
style used in this repo but is not a full HCL parser. For more robust parsing, consider
using `hcl2` Python package or `terraform show -json` on a real statefile.
"""

import argparse
import json
import re
from pathlib import Path


def parse_tf_file(path: Path):
    text = path.read_text()
    # Normalize newlines
    lines = text.splitlines()

    results = {}

    i = 0
    n = len(lines)
    while i < n:
        line = lines[i].strip()
        # Look for resource "port_blueprint" "<name>" {
        m = re.match(r'resource\s+"port_blueprint"\s+"([^"]+)"\s*\{', line)
        if m:
            resource_name = m.group(1)
            # capture block until matching closing brace
            brace_level = 0
            block_lines = []
            # include current line
            while i < n:
                l = lines[i]
                block_lines.append(l)
                brace_level += l.count('{') - l.count('}')
                i += 1
                if brace_level <= 0:
                    break
            block_text = "\n".join(block_lines)
            # find identifier = "..."
            id_m = re.search(r'identifier\s*=\s*"([^"]+)"', block_text)
            identifier = id_m.group(1) if id_m else resource_name

            # find properties = { ... } block
            props = {}
            props_m = re.search(r'properties\s*=\s*\{', block_text)
            if props_m:
                # find start index of properties block in block_lines
                # locate the line number where properties = { occurs
                start_line_idx = None
                for idx, l in enumerate(block_lines):
                    if re.search(r'properties\s*=\s*\{', l):
                        start_line_idx = idx
                        break
                if start_line_idx is not None:
                    # collect until matching brace
                    j = start_line_idx
                    brace_level = 0
                    prop_block_lines = []
                    while j < len(block_lines):
                        l = block_lines[j]
                        prop_block_lines.append(l)
                        brace_level += l.count('{') - l.count('}')
                        j += 1
                        if brace_level <= 0:
                            break
                    prop_block = "\n".join(prop_block_lines)
                    # Within properties, there are groups like string_props = { ... }
                    for group_match in re.finditer(r'([a-zA-Z0-9_]+)\s*=\s*\{', prop_block):
                        group_name = group_match.group(1)
                        # find the sub-block for this group
                        start = group_match.start()
                        # find matching braces from this position
                        k = prop_block[:start].count('\n')
                        # naive: extract text starting at group_match.start() and do brace matching
                        txt = prop_block[group_match.start():]
                        brace = 0
                        sub_lines = []
                        for ch in txt:
                            sub_lines.append(ch)
                        sub_text = ''.join(sub_lines)
                        # find the sub-block content by counting braces
                        brace_level = 0
                        content = ''
                        for idx_c, ch in enumerate(txt):
                            content += ch
                            if ch == '{':
                                brace_level += 1
                            elif ch == '}':
                                brace_level -= 1
                                if brace_level == 0:
                                    break
                        # now content holds the group's block
                        # find property keys at top level of this group's block
                        # look for lines like: name = { ... }
                        for prop_match in re.finditer(r'([A-Za-z0-9_\-]+)\s*=\s*\{', content):
                            prop_name = prop_match.group(1)
                            # extract the inner text for this prop to see if required = true exists
                            subtxt = content[prop_match.end():]
                            brace_level2 = 1
                            inner = ''
                            for ch2 in subtxt:
                                if ch2 == '{':
                                    brace_level2 += 1
                                elif ch2 == '}':
                                    brace_level2 -= 1
                                    if brace_level2 == 0:
                                        break
                                inner += ch2
                            required = bool(re.search(r'required\s*=\s*true', inner))
                            props[prop_name] = {'group': group_name, 'required': required}
            results[identifier] = {'resource_name': resource_name, 'properties': props}
            continue
        i += 1
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', '-f', default='terraform/modules/port_blueprints/main.tf')
    parser.add_argument('--output', '-o', default='blueprints_local.json')
    args = parser.parse_args()

    path = Path(args.file)
    if not path.exists():
        print(f"File not found: {path}")
        return

    parsed = parse_tf_file(path)
    out = Path(args.output)
    out.write_text(json.dumps(parsed, indent=2))
    print(f"Wrote {out} with {len(parsed)} blueprints")


if __name__ == '__main__':
    main()
