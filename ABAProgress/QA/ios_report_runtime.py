"""Exercise the production WKWebView -> UIPrintPageRenderer path on iPhone and iPad."""
import json, os, shutil, subprocess, time
from pathlib import Path

def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()

temp = Path(os.environ['RUNNER_TEMP'])
out = temp / 'aba-ios-report-qa'
out.mkdir(exist_ok=True)
fixture = temp / 'qa-input.json'
run('node', 'ABAProgress/QA/report-template.test.cjs', '--fixture', str(fixture))
app = temp / 'ABAProgressDerivedData/Build/Products/Debug-iphonesimulator/ABAProgress.app'
data = json.loads(run('xcrun', 'simctl', 'list', '-j'))
runtimes = [r for r in data['runtimes'] if r.get('isAvailable') and 'iOS' in r['name'] and int(r['version'].split('.')[0]) >= 26]
runtime = max(runtimes, key=lambda r: tuple(map(int, r['version'].split('.'))))['identifier']
for family in ['iPhone', 'iPad']:
    device_type = next(d['identifier'] for d in reversed(data['devicetypes']) if family in d['name'] and ('SE' not in d['name']))
    device = run('xcrun', 'simctl', 'create', 'ABA Report QA ' + family, device_type, runtime)
    try:
        run('xcrun', 'simctl', 'boot', device)
        run('xcrun', 'simctl', 'bootstatus', device, '-b')
        run('xcrun', 'simctl', 'install', device, str(app))
        container = Path(run('xcrun', 'simctl', 'get_app_container', device, 'com.abaprogress.universal', 'data'))
        documents = container / 'Documents'
        documents.mkdir(exist_ok=True)
        shutil.copy2(fixture, documents / 'qa-input.json')
        env = dict(os.environ, SIMCTL_CHILD_ABA_REPORT_QA='1')
        run('xcrun', 'simctl', 'launch', device, 'com.abaprogress.universal', env=env)
        result = documents / 'qa-output'
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline and not (result / 'success.json').exists() and not (result / 'failure.txt').exists():
            time.sleep(2)
        target = out / family
        if result.exists():
            shutil.copytree(result, target, dirs_exist_ok=True)
        run('xcrun', 'simctl', 'io', device, 'screenshot', str(out / (family + '.png')))
        if (result / 'failure.txt').exists():
            raise RuntimeError((result / 'failure.txt').read_text())
        if not (result / 'success.json').exists():
            raise RuntimeError('iOS PDF generation timed out: ' + family)
        print(family, (result / 'success.json').read_text())
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], check=False)
        subprocess.run(['xcrun', 'simctl', 'delete', device], check=False)
