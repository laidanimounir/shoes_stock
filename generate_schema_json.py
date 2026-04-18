import os
import json

file_paths = {
    'columns': r'C:\Users\Mounir\.gemini\antigravity\brain\f53035e0-81b0-4d9d-b759-8c20c173358e\.system_generated\steps\482\output.txt',
    'fks':     r'C:\Users\Mounir\.gemini\antigravity\brain\f53035e0-81b0-4d9d-b759-8c20c173358e\.system_generated\steps\483\output.txt',
    'rpcs':    r'C:\Users\Mounir\.gemini\antigravity\brain\f53035e0-81b0-4d9d-b759-8c20c173358e\.system_generated\steps\484\output.txt',
    'rls':     r'C:\Users\Mounir\.gemini\antigravity\brain\f53035e0-81b0-4d9d-b759-8c20c173358e\.system_generated\steps\485\output.txt',
}

def extract_json(path):
    if not os.path.exists(path):
        return "[]"
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    start = content.find('[')
    end = content.rfind(']')
    if start != -1 and end != -1:
        return content[start:end+1]
    return "[]"

columns_data = extract_json(file_paths['columns'])
fks_data = extract_json(file_paths['fks'])
rpcs_data = extract_json(file_paths['rpcs'])
rls_data = extract_json(file_paths['rls'])

# Format exactly as requested
output = f"""━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUERY 1 — TABLES & COLUMNS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```json
{columns_data}
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUERY 2 — FOREIGN KEYS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```json
{fks_data}
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUERY 3 — RPC FUNCTIONS (FULL SOURCE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```json
{rpcs_data}
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUERY 4 — RLS POLICIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```json
{rls_data}
```
"""

output_path = r'C:\Users\Mounir\.gemini\antigravity\brain\f53035e0-81b0-4d9d-b759-8c20c173358e\database_schema_results.md'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(output)

print(f"Generated successfully with {len(columns_data)} bytes columns, {len(fks_data)} bytes fks, {len(rpcs_data)} bytes rpcs, {len(rls_data)} bytes rls.")
