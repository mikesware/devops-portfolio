import json
import subprocess
import sys

# Simple, runner-friendly scan using nmap CLI.
# Adjust CIDR for your lab as needed.
CIDR = "192.168.0.0/24"

def run(cmd):
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout)
        print(res.stderr, file=sys.stderr)
        sys.exit(res.returncode)
    return res.stdout

if __name__ == "__main__":
    xml_out = "nmap_results.xml"
    json_out = "nmap_summary.json"

    run(["nmap", "-T4", "-F", "-oX", xml_out, CIDR])

    summary = {"scanned": CIDR, "xml_file": xml_out}
    with open(json_out, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"Scan complete. XML: {xml_out}  JSON: {json_out}")