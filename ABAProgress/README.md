# ABAProgress v0.7 — Apple HIG Alignment

iPhone + iPad 공용 ABA 치료 실시간 기록/경과관리 앱의 개인기기 테스트 패키지입니다.

## 패키지 구성
- `ABAProgress.swiftpm` — iPad Swift Playgrounds 실행용
- `XcodeProject` — iPhone/iPad Universal Xcode 프로젝트
- `SCENARIO_VALIDATION.md` — 치료/기록 검토 시나리오 검증 보고서
- `DESIGN_AUDIT.md` — 구현 진행도 및 Apple 디자인 적용 점검
- `QA/scenario_tests.swift` — 순수 Swift 자동 시뮬레이션
- `QA/scenario_test_output.txt` — 자동 시뮬레이션 실행 결과
- `PERSONAL_DEVICE_SETUP.md` — 개인기기 실행 안내
- `VERSION.txt`, `BUILD_INFO.json`, `CHANGELOG.md` — 버전/SHA 이력 관리

## v0.7 핵심 개선

### Apple 플랫폼에 맞는 탐색과 화면 계층
- iPhone 첫 화면과 iPad 기본 사이드바 목적지를 `오늘`로 변경
- iPhone TabView + iPad NavigationSplitView 적응형 구조 정리
- 시스템 그룹 배경, 네이티브 표면, SF Symbols 기반 상태 표현 통일
- 아동 이름 검색과 명확한 빈 상태 화면 추가

### 치료 중 저부담 입력
- Trial 버튼에 `정반응 / 촉구 / 미기록` 보조 텍스트 추가
- Dynamic Type에 따라 Trial 버튼 높이가 확장되도록 개선
- 대비 증가 설정에서 테두리와 상태 배경 구분 강화
- 기록 완료 버튼을 전체 폭의 큰 터치 대상으로 변경

### 접근성
- 완료·진행·미기록을 색상뿐 아니라 기호와 텍스트로 구분
- 캘린더 월 이동과 날짜 선택에 VoiceOver 레이블·힌트·선택 상태 추가
- Trial에 VoiceOver용 `NA로 초기화` 사용자 지정 동작 추가
- PDF 생성·공유 버튼의 레이블과 터치 영역 개선

## v0.6 핵심 개선
### 치료 중 실시간 기록
- Trial `NA → + → - → NA`, Long Press로 NA 초기화
- 직전 Trial 또는 전체입력 `실행 취소`
- NA가 남은 상태에서 완료 시 확인창
- 날짜 변경 시 Undo 상태 초기화하여 다른 날짜 오수정 방지
- 미래 날짜 기록 방지
- 빈 Session은 기록 캘린더에서 제외, 메모-only Session은 보존
- 완료/진행/미시작 상태 표시
- 오늘 화면에서 프로그램을 바로 열어 중단된 치료를 빠르게 재개
- 과거 종결 과제 재훈련 시 과거 Level을 변경하지 않고 현재 Level에 복사

### 기록 확인/수정
- 날짜 → 아동 → 프로그램/과제 → 동일 Trial UI로 수정
- 날짜별 미완료 Session 수 표시
- 날짜별 아동 검색
- 과거 수정 화면에 수정 모드/마지막 수정시각 표시
- 잘못 생성한 Session 삭제 + 확인창
- 과거 수정으로 완료 Level 기준이 깨지면 검토 경고
- 완료 Level 자동 rollback 금지
- 한 날짜에 L1/L2가 함께 존재하면 복수 Level 표시
- 월 이동 시 선택 날짜도 새 월로 동기화
- 아동/프로그램 삭제 시 데이터 삭제 확인

### 보고서 데이터 품질
- 미완료 Session은 화면/PDF 보고서 통계와 그래프에서 제외
- 선택 기간에 미완료 Session이 있으면 경고
- Level 판정 검토 필요 프로그램 표시

## 검증
- v0.6 전체 Xcode Swift source: `swiftc -frontend -parse` PASS
- v0.6 Swift Playgrounds 단일 source: parse PASS
- v0.6 순수 Swift 현장 시나리오 자동 테스트: ALL PASS
- v0.7 Xcode/Swift Playgrounds View 소스 동기화 및 정적 API 검사 완료
- v0.7 컴파일·시뮬레이터 검증: Xcode 런타임에서 수행 필요

실제 iOS/iPadOS 렌더링, Long Press 체감, SwiftData 앱 라이프사이클은 iPad Swift Playgrounds에서 추가 실기기 검증이 필요합니다.
