"""Assemble a source-only Playgrounds handoff. Does not build or run tests."""
import datetime
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
native = root / 'XcodeProject/ABAProgress'
mirror = root / 'ABAProgress.swiftpm/Sources/AppModule'
for path in native.rglob('*.swift'):
    target = mirror / path.relative_to(native)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
shutil.copyfile(native/'Resources/ReportTemplate.html', mirror/'Resources/ReportTemplate.html')

version = '1.1.0'
build = '18'
(root/'VERSION.txt').write_text(version+'\n', encoding='utf-8')
package = root/'ABAProgress.swiftpm/Package.swift'
s = package.read_text(encoding='utf-8')
s = s.replace('displayVersion: "1.0.0"', f'displayVersion: "{version}"')
s = s.replace('bundleVersion: "16"', f'bundleVersion: "{build}"').replace('bundleVersion: "17"', f'bundleVersion: "{build}"')
package.write_text(s, encoding='utf-8')
project = root/'XcodeProject/ABAProgress.xcodeproj/project.pbxproj'
s = project.read_text(encoding='utf-8')
s = s.replace('CURRENT_PROJECT_VERSION = 16;', f'CURRENT_PROJECT_VERSION = {build};').replace('CURRENT_PROJECT_VERSION = 17;', f'CURRENT_PROJECT_VERSION = {build};')
s = s.replace('MARKETING_VERSION = 1.0.0;', f'MARKETING_VERSION = {version};')
project.write_text(s, encoding='utf-8')

info_path = root/'BUILD_INFO.json'
info = json.loads(info_path.read_text(encoding='utf-8'))
info.update(version=version, buildNumber=build, sourceCommit='codex/easy-aba-schedule-lists working tree',
    githubMain='6dda6ea', branch='codex/easy-aba-schedule-lists', distribution='PLAYGROUNDS_SOURCE_ONLY')
info['validation'] = {'build': 'NOT_RUN_USER_REQUEST', 'tests': 'NOT_RUN_USER_REQUEST',
    'simulator': 'NOT_RUN_USER_REQUEST', 'migration': 'NOT_RUN', 'commit': 'NOT_CREATED', 'push': 'NOT_RUN'}
info_path.write_text(json.dumps(info, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
handoff_path = root/'HANDOFF_MANIFEST.json'
handoff = json.loads(handoff_path.read_text(encoding='utf-8'))
handoff['handoffPurpose'] = 'User requested Swift Playgrounds source-only handoff without build or tests'
handoff['readFirst'] = list(dict.fromkeys(['UPDATE_1_1_PLAYGROUNDS.md'] + handoff['readFirst']))
handoff_path.write_text(json.dumps(handoff, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

notes = (root/'UPDATE_1_1_PLAYGROUNDS.md').read_text(encoding='utf-8')
(root/'ABAProgress.swiftpm/README_iPad.txt').write_text(notes, encoding='utf-8')
changelog = root/'CHANGELOG.md'
entry = '''# 1.1.0 개발본 · 빌드 18 — Swift Playgrounds 빌드 수정

- 시간표의 동시 수업 배치를 안정적인 `Identifiable` 구조로 변경.
- 반복 수업 편집 행을 별도 SwiftUI View로 분리해 바인딩 컴파일 안정성 개선.
- 새 SwiftData 선택 속성의 초기값을 명시해 모델 생성과 마이그레이션 안정성 개선.

'''
previous = changelog.read_text(encoding='utf-8')
if not previous.startswith('# 1.1.0 개발본 · 빌드 18'):
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
    zipped.write(root/'UPDATE_1_1_PLAYGROUNDS.md', '시작하기.md')
    zipped.write(root/'BUILD_INFO.json', 'BUILD_INFO.json')
print(archive)
