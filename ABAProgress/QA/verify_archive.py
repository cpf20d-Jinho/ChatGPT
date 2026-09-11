import plistlib, re, sys
from pathlib import Path
app = Path(sys.argv[1]) / 'Products/Applications/ABAProgress.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert int(re.search(r'iphoneos(\d+)', info['DTSDKName']).group(1)) >= 26, info['DTSDKName']
assert int(info['DTXcode']) >= 2600, info['DTXcode']
assert info['CFBundleIdentifier'] == 'com.abaprogress.universal'
assert set(info['UIDeviceFamily']) == {1, 2}
assert 'CFBundleIcons' in info
assert (app / 'PrivacyInfo.xcprivacy').exists()
assert set(info['UISupportedInterfaceOrientations~ipad']) == {'UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
print('PASS: Release device archive, Xcode/SDK 26+, Universal, icon, privacy manifest and iPad orientations')
print('Unsigned archive only. Distribution signing, configured production host and App Store validation remain separate gates.')
