from pathlib import Path
import argparse
import hashlib
import re

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()

def literal(data):
    escapes = {9: '\\t', 10: '\\n', 13: '\\r', 34: '\\"', 92: '\\\\'}
    return '"' + ''.join(escapes.get(b, chr(b) if 32 <= b < 127 else '\\%03d' % b) for b in data) + '"'

paths = [repo / 'main.luau', repo / 'rbxBundle.luau']
paths += [p for p in (repo / 'src').rglob('*') if p.suffix in ('.lua', '.luau') and 'tests' not in p.relative_to(repo / 'src').parts]
paths += [p for p in (repo / 'assets').rglob('*') if p.is_file()]
files = {}
digest = hashlib.sha256()
for path in sorted(paths):
    name = path.relative_to(repo).as_posix()
    data = path.read_bytes()
    if path.suffix in ('.lua', '.luau'):
        data = data.replace(b'\r\n', b'\n')
    files[name] = data
    digest.update(name.encode() + b'\x00' + data + b'\x00')
revision = digest.hexdigest()
parts = ['return {\nrevision = "' + revision + '",\nfiles = {\n']
for name, data in files.items():
    parts.append('[ ' + literal(name.encode()) + ' ] = ' + literal(data) + ',\n')
parts.append('},\n}\n')
payload = ''.join(parts).encode()
target = repo / 'runtime' / ('startup-' + revision[:16] + '.luau')
loader = repo / 'loader.luau'
old_loader = loader.read_text(encoding='utf-8')
new_loader, count = re.subn(r'local STARTUP_REVISION = "[^"]*"', 'local STARTUP_REVISION = "' + revision + '"', old_loader)
assert count == 1, 'Loader must have one STARTUP_REVISION field'
if args.check:
    assert target.read_bytes() == payload, 'Startup payload is stale; run python tools/build_startup.py'
    assert old_loader == new_loader, 'Loader revision is stale; run python tools/build_startup.py'
else:
    target.parent.mkdir(exist_ok=True)
    target.write_bytes(payload)
    loader.write_text(new_loader, encoding='utf-8', newline='\n')
print(f'PASS: startup payload matches {len(files)} files; {len(payload)} bytes; revision={revision[:16]}')
