# ABAProgress 진행도 및 Apple 디자인 점검

점검 기준: GitHub `main`의 `44cfb9f` 커밋에 포함된 ABAProgress v0.6.0
점검일: 2026-09-08

## 요약

- 기능 MVP 구현도: 약 **76%**
- 실제 기기 검증을 포함한 배포 준비도: 약 **50%**
- 핵심 치료 기록 흐름은 구현되어 있으나, 실제 iOS/iPadOS 런타임 검증과 보고서 확장, 배포 자산이 남아 있다.

위 수치는 아래 항목을 가중 평가한 프로젝트 관리용 추정치이며 App Store 심사 통과율을 의미하지 않는다.

| 영역 | 비중 | v0.6 구현도 | 확인 근거 |
| --- | ---: | ---: | --- |
| 데이터·임상 규칙 | 20% | 90% | Child → Program → Level → Target → Session → Trial, NA 제외 계산, 레벨 판정 서비스 |
| 실시간 Trial 기록 | 25% | 90% | NA → + → -, 자동 저장, Undo, 전체 입력 확인, 완료 확인 |
| 캘린더·과거 수정 | 15% | 85% | 날짜별 조회, 동일 편집기 수정, 삭제 확인, 판정 검토 경고 |
| 보고서·내보내기 | 15% | 55% | 기간 그래프와 PDF는 구현, 구조화 ReportData·XLSX·HWPX·서술 작성은 미구현 |
| iPhone·iPad UI·접근성 | 15% | 70% | 적응형 Tab/SplitView와 기본 VoiceOver 지원, 실제 화면 검증은 미완료 |
| 테스트·배포 준비 | 10% | 35% | 순수 Swift 시나리오 결과는 존재, Xcode 빌드·UI 테스트·서명·앱 아이콘 미완료 |

## 이미 구현된 핵심 범위

1. SwiftUI, SwiftData, Swift Charts 기반 iOS/iPadOS 17+ 공용 앱
2. 아동·프로그램·레벨·과제·세션·Trial 데이터 계층
3. 최대 10회 Trial의 즉시 저장과 정반응률 계산
4. 실제 기록일만 사용하는 레벨 연속 달성 판정
5. 오늘 기록, 날짜별 기록 조회와 과거 데이터 수정
6. 완료된 세션만 사용하는 경과 그래프와 PDF 생성
7. Xcode 프로젝트와 iPad Swift Playgrounds 프로젝트 제공

## 남은 주요 범위

1. Xcode에서 iPhone/iPad 빌드 및 실제 화면·상호작용 검증
2. 앱 종료·잠금·백그라운드 후 SwiftData 복원 검증
3. Dynamic Type 최대 크기, VoiceOver, 대비 증가, 색상 없이 구분 검증
4. 공통 `ReportData` 계층과 XLSX/HWPX 템플릿 매퍼
5. 치료사·슈퍼바이저 서술 및 보고서 확정/재생성 정책
6. XCTest/UI Test, 마이그레이션 테스트, 오류 처리 강화
7. 실제 Bundle ID, 서명 설정, 앱 아이콘, 개인정보 안내와 배포 구성

## Apple 디자인 적용 원칙

Apple의 [디자인 허브](https://developer.apple.com/kr/design/), [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [iPad 앱 디자인 향상하기](https://developer.apple.com/kr/videos/play/wwdc2025/208/)를 기준으로 다음을 적용한다.

- 가장 빈번한 치료 업무인 `오늘`을 기본 진입점으로 배치한다.
- iPhone은 TabView, 넓은 iPad는 NavigationSplitView를 사용한다.
- 창 너비 변화에 따라 내용이 재배치되도록 적응형 Grid와 ViewThatFits를 유지한다.
- 시스템 배경색, 시스템 서체, SF Symbols와 네이티브 버튼·목록을 우선한다.
- 상태를 색상만으로 전달하지 않고 텍스트와 기호를 함께 사용한다.
- 핵심 Trial과 완료 버튼은 충분한 터치 영역을 확보한다.
- Dynamic Type, VoiceOver 레이블·힌트·사용자 지정 동작을 제공한다.
- iOS 17 최소 지원을 유지하므로 iOS 26 전용 Liquid Glass API는 이번 버전에 직접 적용하지 않는다. 최신 SDK에서 네이티브 컨테이너가 제공하는 시스템 외형을 우선 사용한다.

## v0.7 HIG 개선 내역

- `오늘`을 iPhone 첫 탭 및 iPad 기본 사이드바 선택으로 변경
- iPad 사이드바 폭과 균형형 Split View 지정
- 아동 목록에 시스템 검색과 검색 결과 없음 상태 추가
- 스크롤 화면에 시스템 그룹 배경과 공통 표면 스타일 적용
- 완료·진행·미기록 상태를 기호+텍스트 캡슐로 통일
- Trial 버튼에 정반응·촉구·미기록 보조 텍스트와 Dynamic Type 대응 높이 추가
- 대비 증가 설정에서 Trial 테두리와 배경 구분 강화
- VoiceOver용 Trial NA 초기화 사용자 지정 동작 추가
- 기록 완료와 PDF 생성·공유 버튼의 전체 폭 터치 영역 확보
- 캘린더 월 이동·날짜 선택의 VoiceOver 레이블, 힌트, 선택 상태 추가
- 빈 보고서/미선택 보고서 상태를 ContentUnavailableView로 명확히 표시

## 검증 상태

- Xcode/Swift Playgrounds 대응 View 소스 동기화 확인
- 기존 임상 모델과 레벨 판정·보고서 계산 로직은 변경하지 않음
- 정적 최신 API·안정 ID·레거시 API 검사 수행
- 현재 실행 환경에 Swift/Xcode 런타임이 없어 컴파일 및 시뮬레이터 렌더링은 보류
