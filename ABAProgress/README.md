# ABAProgress v0.9 — Consent, Server Connection and Release Verification

## 현재 구현

- AI는 Groq GPT-OSS 120B를 사용합니다. 아동명·생년월일·날짜·프로그램명·메모는 전송하지 않습니다.
- 요청마다 수신처·수치 배열·처리 목적을 확인하고 동의해야 전송합니다. 전송 취소 시 수동 기록과 보고서 작성은 계속 사용할 수 있습니다.
- AI가 번호로 설명한 학습 계열을 기기 안에서 프로그램명·레벨로 치환합니다. 이름을 서버에 보내지 않으면서 보고서 문구를 읽기 쉽게 합니다.
- 연결 확인, 만료되는 사용자별 서버 토큰, 요청 제한, Keychain 키 삭제/교체를 지원합니다.
- Xcode 26+/SDK 26+의 미서명 Release 아카이브와 iPhone/iPad 실제 PDF 생성 검사를 CI에서 수행합니다.
- 운영 서버와 새 Groq 키, Apple 배포 서명은 아직 연결하지 않았습니다. `RELEASE_READINESS.md` 및 `Server/DEPLOYMENT.md`에 준비 사항을 정리했습니다.

## v0.8 구현 이력

- SF Symbols 이름을 공통 정의로 통합하고 핑크 브랜드 색상과 벡터 ABA 앱 아이콘을 적용했습니다.
- 제공된 중간보고서의 표지, 영역별 막대그래프, 성장 추이, 단계별 목표 그래프, 서술란, 서명란을 기본 양식으로 구현했습니다.
- AI는 종합 현황과 주요 변화 두 항목만 초안을 제안합니다. 치료사 소견, 가정 연계, 다음 목표는 직접 작성합니다.
- v0.8의 Responses API 구현은 v0.8.1에서 Groq 숫자 전용 해석으로 변경되었습니다. 현재 `Server/GUIDE_SCRIPT.md`는 수치 근거만 서술하도록 제한합니다.
- Xcode 빌드, 임상 시나리오, 서버 단위 테스트 및 합성 데이터 HTML 미리보기가 통과했습니다: GitHub Actions run 34179188414.
- 원본 로고와 글꼴, 정확한 STO 집계 정의, 실제 iOS PDF 페이지 나눔은 추가 확인이 필요합니다. 원본과 완전히 동일한 결과를 보장하는 상태는 아닙니다. 상세 차이는 `REPORT_TEMPLATE_SPEC.md`를 참고하세요.
- 원본 보고서와 실제 아동 자료는 저장소에 포함하지 않습니다.

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
- v0.7 GitHub Actions Xcode iOS Simulator 대상 빌드: PASS
- v0.7 GitHub Actions 임상 규칙 시나리오: PASS
- v0.7 iPhone/iPad 화면·상호작용 검증: Xcode 또는 실기기에서 수행 필요

실제 iOS/iPadOS 렌더링, Long Press 체감, SwiftData 앱 라이프사이클은 iPad Swift Playgrounds에서 추가 실기기 검증이 필요합니다.
