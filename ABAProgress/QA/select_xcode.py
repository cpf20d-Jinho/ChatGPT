"""Select an installed stable Xcode supporting Apple's minimum submission SDK."""
import glob, os, re, subprocess
from pathlib import Path

choices = []
for app in glob.glob('/Applications/Xcode*.app'):
    if 'beta' in app.lower():
        continue
    env = dict(os.environ, DEVELOPER_DIR=app + '/Contents/Developer')
    try:
        version = subprocess.check_output(['xcodebuild', '-version'], env=env, text=True)
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], env=env, text=True).strip()
        number = re.search(r'Xcode (\d+(?:\.\d+)*)', version).group(1)
        if int(number.split('.')[0]) >= 26 and int(sdk.split('.')[0]) >= 26:
            choices.append((tuple(map(int, number.split('.'))), env['DEVELOPER_DIR'], sdk))
    except (subprocess.CalledProcessError, AttributeError):
        continue
if not choices:
    raise SystemExit('Xcode 26+ and iOS SDK 26+ are required; no eligible installation found')
_, selected, sdk = max(choices)
with open(os.environ['GITHUB_ENV'], 'a') as f:
    f.write('DEVELOPER_DIR=' + selected + '\n')
print('Selected:', selected, 'iOS SDK', sdk)
