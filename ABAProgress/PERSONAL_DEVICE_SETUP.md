# ABAProgress — 개인 기기 무료 테스트 준비

이 패키지는 두 경로를 포함합니다.

## A. iPad에서 바로 실행 — 권장

`ABAProgress.swiftpm`을 iPad의 **Swift Playgrounds**에서 엽니다.

1. ZIP 압축을 풉니다.
2. `ABAProgress.swiftpm`을 iCloud Drive 또는 iPad의 파일 앱에 둡니다.
3. Swift Playgrounds에서 프로젝트를 엽니다.
4. 앱 미리보기 또는 전체 화면 실행으로 동작을 확인합니다.

이 경로는 별도의 Mac이나 유료 Apple Developer Program이 필요하지 않습니다.

## B. iPhone / iPad에 일반 앱처럼 설치 — 무료 Personal Team / 사이드로드용

Apple의 무료 Personal Team은 개인 기기 테스트를 허용하지만 프로비저닝 프로파일은 7일 후 만료되므로 주기적으로 다시 서명/설치해야 합니다. 공식 Personal Team 방식은 Xcode가 필요합니다.

Mac이 없는 경우 이 패키지의 `XcodeProject/.github/workflows/build-unsigned-ipa.yml`을 사용해 GitHub의 macOS runner에서 **unsigned IPA**를 만들 수 있습니다. unsigned IPA는 기기에 바로 설치할 수 없고, 자신의 Apple 계정으로 다시 서명하는 단계가 필요합니다.

### GitHub Actions 빌드

1. `XcodeProject` 폴더 내용을 새 GitHub 저장소의 루트에 업로드합니다.
2. 저장소의 `Actions` 탭에서 **Build unsigned iOS IPA**를 실행합니다.
3. 성공하면 `ABAProgress-unsigned-ipa` artifact를 내려받습니다.
4. 내려받은 IPA를 무료 서명/사이드로드 도구로 자신의 Apple 계정으로 서명해 개인 iPhone/iPad에 설치합니다.

### 무료 계정의 Apple 제한

- Personal Team 앱 ID: 최대 10개, 7일 후 만료
- 등록 테스트 기기: 최대 3대, 7일 후 만료
- 기기당 설치 앱: 최대 3개
- 프로비저닝 프로파일: 발급 후 7일 만료

따라서 무료 개인 사용에서는 약 7일마다 재서명/재설치가 필요할 수 있습니다.

## 프로젝트 요구 사항

- iOS / iPadOS 17 이상
- iPhone + iPad Universal App
- SwiftUI + SwiftData + Swift Charts
- 외부 서버 없이 로컬 데이터 저장

## Bundle Identifier

현재 Xcode 프로젝트는 `com.example.ABAProgress`를 사용합니다. Xcode Personal Team을 사용할 때 충돌이 발생하면 프로젝트의 Signing & Capabilities에서 고유한 Bundle Identifier로 변경하십시오.

예: `com.yourname.ABAProgress`

## 주의

GitHub Actions가 IPA를 **컴파일**하는 것과 Apple 계정으로 앱을 **서명**하는 것은 별개입니다. unsigned IPA는 그대로 iOS에 설치할 수 없습니다.
