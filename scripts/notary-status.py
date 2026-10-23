"""Only an explicitly Accepted Apple notarization report may continue."""
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    report = json.load(handle)
if report.get('status') != 'Accepted':
    print('Notarization was not Accepted. Inspect the report and retrieve the Apple notary log before retrying.', file=sys.stderr)
    sys.exit(1)
print('Notarization Accepted.')
