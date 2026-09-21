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

version = '1.1.4'
build = '23'
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
handoff['handoffPurpose'] = 'Task and List learning progress; Debug-only validation without rendering'
handoff['readFirst'] = list(dict.fromkeys(['UPDATE_1_1_4_PLAYGROUNDS.md'] + handoff['readFirst']))
handoff_path.write_text(json.dumps(handoff, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

notes = (root/'UPDATE_1_1_4_PLAYGROUNDS.md').read_text(encoding='utf-8')
(root/'ABAProgress.swiftpm/README_iPad.txt').write_text(notes, encoding='utf-8')
changelog = root/'CHANGELOG.md'
entry = '''# 1.1.4 · 빌드 23 — 과제와 List별 학습 경과

- 학습 경과를 과제명 중심으로 표시하고 List별 독립 그래프와 제목 제공.
- 보고서·PDF·AI 숫자 계열에서 프로그램 단위의 과제 혼합 평균 제거.
- 학습 List별 평가군 분류와 준거 달성 표시, 기존 분류와 기록 보존.

'''
previous = changelog.read_text(encoding='utf-8')
if not previous.startswith('# 1.1.4 · 빌드 23'):
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
    zipped.write(root/'UPDATE_1_1_4_PLAYGROUNDS.md', '시작하기.md')
    zipped.write(root/'BUILD_INFO.json', 'BUILD_INFO.json')
print(archive)
