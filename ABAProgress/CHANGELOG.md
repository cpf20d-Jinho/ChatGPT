# CHANGELOG

## v0.8.1 — Gemini numeric-only interpretation
- Gemini 3.8 Flash JSON with numeric summaries only; exclude dates, labels, notes and identifiers.
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
