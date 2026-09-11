# 0.12.0 — 보고서 화면 정합성 패치

- iPad 사이드바의 `ABA Progress` 제목을 워크스페이스와 같은 왼쪽 흐름에 배치했습니다.
- 보고서 상단을 `데이터 선택`으로 명확히 바꾸고 앱과 PDF의 가운데점 결합 문구를 읽기 쉬운 문장으로 교체했습니다.
- 보고서 그래프 카드에 프로그램명, 데이터 설명, 실제 기록일, 숙달 기준과 레벨 전환을 표시하고 세로 격자선과 불필요한 제목을 제거했습니다.
- 그래프 아래에 레벨별 학습 내용을 표시하고 과제명과 설명을 수정하는 편집 화면으로 연결했습니다.
- 기관명 등 보고서 기본정보를 한 열의 단일행 입력란으로 통일하고 프로그램 선택 칩을 제목의 보이지 않는 왼쪽 축에 맞췄습니다.
- UI 회귀 검사에 제목과 선택 칩 정렬, 단일행 입력, 새 그래프 및 학습 내용 구조를 추가했습니다.

# 0.11.0 · 사용자 흐름 및 정합성 패치

- 저장 오류를 더 이상 무시하지 않고 추가·수정·삭제·Trial 자동 저장에서 롤백과 재시도 안내를 제공합니다.
- 공통 `ABAAlignedField`의 보이지 않는 라벨/입력 축을 기준으로 보고서 날짜와 입력란을 정렬하고, 접근성 글자 크기에서는 같은 왼쪽 축으로 안전하게 접습니다.
- 보고서 프로그램 선택을 왼쪽부터 한 줄 가로 스와이프로 변경하고, 작성 화면을 기본 정보·서술·검토 3단계로 나눴습니다.
- L1→L2 전환을 끊어진 계열과 세로 점선으로 표시하며 새 레벨 정확도를 독립 집계합니다.
- 날짜별 평균의 전체/일부 과제 기록 범위를 명시하고, 일부 기록점은 빈 표식으로 표시합니다.
- 아동·프로그램·과제 메타데이터 편집 진입점을 추가하고 기존 Session의 Trial 수는 보존합니다.
- 아동 상세의 중복 프로그램 목록을 하나로 합치고 오늘 화면은 기록 가능한 프로그램을 우선 표시합니다.
- 레벨 완료/검토 결과와 저장 실패를 화면 내 안내로 표시하며 이후 레벨을 자동 삭제하거나 되돌리지 않습니다.
- 회전 완료를 화면 기하로 확인한 후 캡처하고 네 기기 before/after 시각 회귀 자료를 보존합니다.

# 0.10.0 · 도움말 정리와 보고서 웹 편집

- 긴 부가 설명을 접근 가능한 questionmark.circle 도움말로 이동하고 보고서 날짜·입력란 정렬을 통일했습니다. 전송 동의·오류·검토 항목은 계속 표시합니다.
- 사전 동의 후 여섯 서술 항목만 AES-GCM 암호화하여 무료 서버에 최대 30분 임시 보관하는 웹 편집을 추가했습니다. 링크 단위 권한·명시적 종료·수정 충돌 방지·앱 검토 후 반영을 지원합니다.
- 아동 정보·기록·그래프·서명 수정, 치료 계획 기능, 영구 서버 보관은 추가하지 않았습니다. AI 숫자 전송 계약은 그대로입니다.
- 웹 임시본은 서버 중지·재시작 때 소실될 수 있습니다. 앱 원본을 보존하고 별도 동의를 받으며, 새 기능의 검증은 BUILD_INFO와 PR의 해당 소스 실행을 확인합니다.

## 0.9.1 · 출시 준비

- 오늘 프로그램 행 전체 터치 및 Trial 접근성 식별자 개선.
- 보고서 입력 후 키보드를 닫는 입력 완료 버튼 추가.
- 아동 삭제 시 해당 보고서 초안 정리와 실패 알림.
- App Store 등록 문구·심사 안내·개인정보 방침 초안·서명 Archive 절차 준비.
- UI 흐름 검증은 최종 CI 결과를 참조. Apple 서명과 새 Groq 키 검증은 아직 필요.

# CHANGELOG

## v0.9 — Consent, server connection and release verification
- Request-specific consent and numeric-only transmission; never transmit child identity, dates, labels, notes or PDFs.
- Authenticated health check, redirect rejection, Keychain update/delete, expiring per-user tokens and rate limits.
- Xcode 26+/SDK 26+ Release archive gate, Universal orientations and privacy manifest.
- Actual iOS simulator PDF verification using synthetic baseline and long narrative fixtures.
- Production hosting, new provider key and Apple distribution signing still require operator configuration.

## v0.8.1 — Groq BYOK numeric-only interpretation
- Groq GPT-OSS 120B strict JSON with numeric summaries only; exclude dates, labels, notes and identifiers.
- Store each user's key in the iOS Keychain and forward it per request without server persistence.
- Link to Groq Console for the required one-time key creation; Groq does not provide third-party OAuth.
- Explicit quota/configuration errors; no automatic retry or paid fallback.
- 12 synthetic server/HTTP tests pass; live API pending key provisioning.

## v0.8 — Symbols, Rose Icon, Interim Report
- 화면별 SF Symbols를 공통 의미 기반 정의로 통합하고 대비 대응 상태 표시 강화
- 핑크 강조색, 독자적인 ABA 벡터 원본과 iOS 앱 아이콘 리소스 추가
- 기본 중간보고서의 표지·그래프·목표별 학습 내용·서술·서명 양식 구현
- 종합 현황/주요 변화에 한정된 AI 초안 미리보기 및 명시적 적용
- 치료사 소견 이후 수동 작성, 아동·보고기간별 로컬 자동 저장
- 서버 측 Responses API 연동 및 GUIDE_SCRIPT, 합성 데이터 검증 추가
- 원본 PDF와 실제 아동 기록은 저장소에 포함하지 않음
- 원본 로고, 집계 정의 확정, iOS 인쇄 렌더링, 실제 API 검증은 별도 필요

## v0.7 — Apple HIG Alignment
- GitHub v0.6 구현 범위와 배포 준비도 점검 문서 추가
- `오늘`을 iPhone/iPad 기본 진입점으로 변경
- iPhone TabView와 iPad NavigationSplitView 탐색 구조 정리
- iPad 사이드바 폭과 균형형 Split View 설정
- 아동 이름 검색 및 검색 결과 없음 상태 추가
- 시스템 그룹 배경과 공통 표면 스타일 적용
- 완료·진행·미기록 상태를 SF Symbol+텍스트 캡슐로 통일
- Trial 버튼에 상태 보조 텍스트, Dynamic Type 높이, 대비 증가 대응 추가
- Trial VoiceOver `NA로 초기화` 사용자 지정 동작 추가
- 캘린더 탐색/선택 접근성 정보 강화
- 기록 완료와 PDF 생성·공유 버튼의 전체 폭 터치 영역 확보
- 보고서 빈 상태 및 프로그램 미선택 상태 추가
- iOS/iPadOS 17 최소 지원과 기존 임상·데이터 동작 유지
- 저장소 루트에 Xcode 빌드·임상 시나리오 GitHub Actions CI 추가
- GitHub Actions iOS Simulator 대상 Xcode 빌드와 임상 규칙 시나리오 통과

## v0.6 — Field Workflow Validation
- 실시간 치료/과거기록 사용 시나리오 전면 점검
- Trial/Bulk 직전 입력 Undo 추가
- NA 잔여 상태 완료 경고 추가
- 날짜 전환 시 Undo cross-date 오작동 방지
- 미래 날짜 입력 제한
- 빈 Session의 캘린더 오염 방지
- Today 화면 프로그램 direct resume 추가
- 미완료 Session 집계 및 보고서 제외 정책 적용
- LevelProgressionService 분리
- 과거 수정으로 완료 Level 근거가 깨질 때 review 경고
- 완료 Level 자동 rollback 금지
- 역사적 Trial 수는 저장된 TrialRecord 수로 유지
- 과거 Session 삭제 및 아동/프로그램 삭제 확인 추가
- 월 이동/선택일 불일치 수정
- 날짜별 아동 검색 추가
- 사용자 액션에만 햅틱 발생하도록 수정
- SwiftUI Expert 기준 최신 API/상태/리스트/접근성 audit 반영

## v0.5 — UX Refined
- iPhone/iPad adaptive layout 개선
- Trial button/Dynamic Type/Chart axis/calendar metric 정렬 개선

## v0.4 — Personal Device
- 개인기기 실행 패키지 정리
