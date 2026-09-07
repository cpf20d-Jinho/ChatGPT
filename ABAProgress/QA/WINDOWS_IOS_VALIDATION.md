# Windows에서 ABAProgress 검증

Xcode와 iOS Simulator는 macOS에서 실행해야 합니다. 이 구성은 Windows에
Xcode를 설치하지 않고 GitHub Actions의 `macos-15` 환경에서 검증합니다.

## 실행 경로

- 저장소 루트의 `.github/workflows/abaprogress-ios.yml`이 진입점입니다.
- 해당 파일 또는 ABAProgress 변경을 포함한 PR에서 실행됩니다.
- 기본 브랜치에 병합한 뒤에는 Actions → ABAProgress iOS validation → Run workflow로 실행할 수 있습니다.
- Mac에서 직접 실행: 저장소 루트에서 `python3 ABAProgress/QA/validate_macos.py`.
- 요구 환경: 전체 Xcode 설치, iOS 런타임 및 iPhone/iPad Simulator 등록.

## 결과 범위

1. 기존 `scenario_tests.swift` 실행. 이 테스트는 앱 모델과 별도로 구현한
   시뮬레이션이며 실제 SwiftData/SwiftUI 동작을 보증하지 않습니다.
2. 실제 Xcode 프로젝트의 Simulator Debug 빌드.
3. 사용 가능한 iPhone/iPad 최대 4종에 앱 설치·시작.
4. 시작 8초 후 프로세스 생존 확인 및 화면 캡처.
5. 빌드/실행 로그, 화면 이미지, `summary.json`을 Actions artifact로 보존.
   커밋 SHA·실행 ID·재실행 번호가 이름에 포함됩니다.

전체 터치 시나리오, 저장 복원, 가로/세로, Dynamic Type, 작은 화면 적합성은
자동 시작 확인에 포함되지 않습니다. AGENTS.md의 상호작용 검증은 Mac의
Build iOS Apps 도구 또는 실제 iPhone/iPad에서 별도로 수행해야 합니다.
시뮬레이터 구성에 따라 선호한 화면 크기가 없어 다른 기종으로 대체될 수 있습니다.
이 검증은 Simulator용이며 실기기 설치용 서명/IPA를 생성하지 않습니다.

## 이번 Windows 점검

- 원본 체크아웃: `44cfb9fc414b89b921f33704914097159b22be83` (v0.6.0).
- 로컬 Xcode, xcrun, Swift 실행 환경 없음. 기존 PASS 기록은 이번 재실행 결과가 아닙니다.
- 기존 루트 CI는 Ubuntu에서 출력 예제만 실행합니다.
- 기존 unsigned IPA 워크플로는 하위 폴더에 있어 현재 저장소 구조에서 실행되지 않습니다.
- 이번 변경은 검증 설정이며 앱 릴리스가 아닙니다. 기존 릴리스 메타데이터는 유지합니다.

참고: [Apple Xcode 요구사항](https://developer.apple.com/xcode/system-requirements),
[GitHub workflow 위치](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows).
