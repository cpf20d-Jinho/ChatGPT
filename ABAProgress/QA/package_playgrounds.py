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
build = '17'
(root/'VERSION.txt').write_text(version+'\n', encoding='utf-8')
package = root/'ABAProgress.swiftpm/Package.swift'
s = package.read_text(encoding='utf-8').replace('displayVersion: "1.0.0"', f'displayVersion: "{version}"').replace('bundleVersion: "16"', f'bundleVersion: "{build}"')
package.write_text(s, encoding='utf-8')
project = root/'XcodeProject/ABAProgress.xcodeproj/project.pbxproj'
s = project.read_text(encoding='utf-8').replace('CURRENT_PROJECT_VERSION = 16;', f'CURRENT_PROJECT_VERSION = {build};').replace('MARKETING_VERSION = 1.0.0;', f'MARKETING_VERSION = {version};')
project.write_text(s, encoding='utf-8')

info_path = root/'BUILD_INFO.json'
info = json.loads(info_path.read_text(encoding='utf-8'))
info.update(version=version, buildNumber=build, sourceCommit='74a308e + UNCOMMITTED_LOCAL_CHANGES',
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
entry = '''# 1.1.0 개발본 · 빌드 17 — 시간표와 List

- 아동 → 오늘 → 기록 → 보고서 순서 및 시간표 추가.
- 아동 상세 중복 이름 제거, 생년월일 형식 통일, 반복 수업 일정과 시작일 등록.
- 프로그램 영역 필수, 목표와 List 제목 구분, 이전 프로그램·과제 불러오기.
- List 완료 시 다음 List 생성 확인 및 기록을 유지하는 종료 처리.
- 주간 시간표, 날짜별 휴강·보강, 시간 중복 표시, 접근성 목록 보기.
- 사용자 최종 아이콘 및 아이보리·리프 그린·버터 옐로 색상 반영.
- 사용자 요청에 따라 빌드·테스트·시뮬레이터 검증과 커밋·푸시를 실행하지 않음.

'''
previous = changelog.read_text(encoding='utf-8')
if not previous.startswith('# 1.1.0'):
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
