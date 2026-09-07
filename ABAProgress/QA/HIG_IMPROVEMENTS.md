# HIG 개선 — v0.6.1

Apple HIG의 Typography, Buttons, Labels, Sidebars 지침을 참고했습니다.

| 원칙 | 적용 |
| --- | --- |
| 다음 행동이 명확한 버튼 | 아동·프로그램·과제의 빈 화면에 등록 버튼 배치 |
| 탐색의 일관성 | iPhone 탭 유지, iPad 사이드바 기본 표시 및 balanced split view |
| 검색 | 시스템 검색 필드와 검색 결과 없음 화면; 삭제 대상도 검색 결과 기준으로 매핑 |
| Dynamic Type | 시행 버튼 크기 확장, 접근성 글꼴에서 보조 작업 세로 배치, 캘린더는 시스템 날짜 선택기로 전환 |
| 읽기 쉬운 상태 | 시행 기호는 시스템 기본 텍스트 색 사용, 기호 설명 추가, 대비 증가 설정에 따른 테두리 강화 |
| 보조 기술 | VoiceOver 시행 상태·초기화 작업, 캘린더 선택 상태·월 이동 설명, 장식 요소 읽기 제외 |
| 입력 보존 | 아동 입력 중 실수로 시트를 쓸어 닫는 동작 방지, 저장 실패 시 입력 유지와 안내 |

`NA → + → - → NA`, 최대 시행 수, 정확도, Level 판정, 과거 기록 처리 규칙은 유지합니다.
Xcode와 Swift Playgrounds의 View 소스를 함께 변경했습니다. iOS 17 호환성을 유지합니다.

검증: GitHub macOS에서 기존 Swift 시나리오, 앱 빌드, 네 기종 시작 확인,
라이트/다크/접근성 글꼴 초기 화면 캡처, 아동 등록·검색과 시행 순환·터치 영역·재시작 저장 UI 테스트를 실행합니다.
결과는 실행 artifact를 기준으로 판단합니다. 전체 치료 시나리오와 실제 VoiceOver 사용성은
이 자동 테스트가 보증하지 않습니다.

출처:
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://developer.apple.com/design/human-interface-guidelines/buttons
- https://developer.apple.com/design/human-interface-guidelines/labels
- https://developer.apple.com/design/human-interface-guidelines/sidebars
