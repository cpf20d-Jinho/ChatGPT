"""Regenerate a versioned handoff without including metadata in its own digest."""
import datetime, hashlib, json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
excluded = {'BUILD_INFO.json', 'HANDOFF_MANIFEST.json', 'SHA256SUMS.txt'}
def digest(path):
    data = path.read_bytes()
    try:
        data = data.decode('utf8').replace('\r\n', '\n').encode('utf8')
    except UnicodeDecodeError:
        pass
    return hashlib.sha256(data).hexdigest()
files = sorted(p for p in root.rglob('*') if p.is_file() and p.name not in excluded and '__pycache__' not in p.parts)
checks = [(digest(p), p.relative_to(root).as_posix()) for p in files]
source = hashlib.sha256(''.join(f'{h}  ABAProgress/{p}\n' for h,p in checks).encode()).hexdigest()
now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec='seconds')
for name in ['BUILD_INFO.json', 'HANDOFF_MANIFEST.json']:
    path = root/name
    data = json.loads(path.read_text())
    if name == 'BUILD_INFO.json':
        data.update(version='0.9.1', buildTimeKST=now, buildHash=source[:10], sourceSHA256=source, previousBuild='v0.8.1_7f6dbc4e88')
    else:
        data.update(sourceVersion='0.9.1', sourceBuild=now, sourceBuildHash=source[:10])
        data['readFirst'] = list(dict.fromkeys(data['readFirst'] + ['RELEASE_READINESS.md','Server/DEPLOYMENT.md']))
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
(root/'SHA256SUMS.txt').write_text(''.join(f'{h}  {p}\n' for h,p in checks))
print('v0.9.1', source[:10])
