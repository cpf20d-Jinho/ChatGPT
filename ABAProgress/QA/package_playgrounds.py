"""Assemble a source-only Playgrounds handoff. Does not build or run tests."""
import datetime
import argparse
import re
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--debug-result', default='PENDING', choices=['PENDING', 'PASSED'])
parser.add_argument('--run-url', default='')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
native = root / 'XcodeProject/ABAProgress'
mirror = root / 'ABAProgress.swiftpm/Sources/AppModule'
for path in native.rglob('*.swift'):
    target = mirror / path.relative_to(native)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
shutil.copyfile(native/'Resources/ReportTemplate.html', mirror/'Resources/ReportTemplate.html')

version = '1.1.5'
build = '24'
(root/'VERSION.txt').write_text(version+'\n', encoding='utf-8')
package = root/'ABAProgress.swiftpm/Package.swift'
s = package.read_text(encoding='utf-8')
s = re.sub(r'displayVersion: "[^"]+"', f'displayVersion: "{version}"', s)
s = re.sub(r'bundleVersion: "[^"]+"', f'bundleVersion: "{build}"', s)
package.write_text(s, encoding='utf-8')
project = root/'XcodeProject/ABAProgress.xcodeproj/project.pbxproj'
s = project.read_text(encoding='utf-8')
s = re.sub(r'CURRENT_PROJECT_VERSION = \d+;', f'CURRENT_PROJECT_VERSION = {build};', s)
s = re.sub(r'MARKETING_VERSION = [^;]+;', f'MARKETING_VERSION = {version};', s)
project.write_text(s, encoding='utf-8')

info_path = root/'BUILD_INFO.json'
info = json.loads(info_path.read_text(encoding='utf-8'))
info.update(version=version, buildNumber=build, sourceCommit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    githubMain='6dda6ea', branch='codex/easy-aba-schedule-lists', distribution='PLAYGROUNDS_SOURCE_ONLY')
info['validation'] = {'debugBuild': args.debug_result, 'clinicalAndNavigationChecks': args.debug_result,
    'runURL': args.run_url, 'imageRendering': 'NOT_RUN_USER_REQUEST',
    'simulatorInteraction': 'NOT_RUN_USER_REQUEST', 'playgroundsDeviceRun': 'USER_VERIFICATION_REQUIRED'}
info_path.write_text(json.dumps(info, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
handoff_path = root/'HANDOFF_MANIFEST.json'
handoff = json.loads(handoff_path.read_text(encoding='utf-8'))
handoff['handoffPurpose'] = 'Adaptive timetable, recorded lesson duration and consistent ivory pages; Debug-only validation without rendering'
handoff['readFirst'] = list(dict.fromkeys(['UPDATE_1_1_5_PLAYGROUNDS.md'] + handoff['readFirst']))
handoff_path.write_text(json.dumps(handoff, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

notes = (root/'UPDATE_1_1_5_PLAYGROUNDS.md').read_text(encoding='utf-8')
(root/'ABAProgress.swiftpm/README_iPad.txt').write_text(notes, encoding='utf-8')
changelog = root/'CHANGELOG.md'
entry = '''# 1.1.5 · 빌드 24 — 시간표와 아동 화면 개선

- iPad 시간표를 일곱 요일에 맞춰 배치하고 iPhone은 목록으로 표시.
- 완료 수·평균 대신 기록이 있는 수업 시간을 시간표 기준으로 집계.
- 아동 이름을 큰 중앙 제목으로 표시하고 페이지 배경을 아이보리로 통일.

'''
previous = changelog.read_text(encoding='utf-8')
if not previous.startswith('# 1.1.5 · 빌드 24'):
    changelog.write_text(entry + previous, encoding='utf-8')

# Hashing here records source identity for a unique archive; it is not a test.
subprocess.run([__import__('sys').executable, str(root/'QA/update_manifest.py')], check=True)
info = json.loads(info_path.read_text(encoding='utf-8'))
stamp = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).strftime('%Y%m%d_%H%M%S')
output = Path(r'C:\ChatGPT\ABAProgress\deliverables')
output.mkdir(exist_ok=True)
archive = output/f'Easy_ABA_v{version}_b{build}_{stamp}_{info["buildHash"]}_Playgrounds.zip'
with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as zipped:
    for path in sorted((root/'ABAProgress.swiftpm').rglob('*')):
        if path.is_file() and not any(part in {'.build', '.swiftpm', '__pycache__'} for part in path.relative_to(root/'ABAProgress.swiftpm').parts):
            zipped.write(path, Path('Easy_ABA.swiftpm') / path.relative_to(root/'ABAProgress.swiftpm'))
    zipped.write(root/'UPDATE_1_1_5_PLAYGROUNDS.md', '시작하기.md')
    zipped.write(root/'BUILD_INFO.json', 'BUILD_INFO.json')
print(archive)
