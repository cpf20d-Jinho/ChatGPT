# 출시 후보 검증 및 제출 순서

## 쉬운 ABA 1.0.0 (빌드 15) 상태

- PR #8은 2026-09-12 main에 병합됨. 병합 전 최신 커밋의 기본 CI, iOS CI, 보고서 레이아웃, 사용 영상 검사는 모두 통과함.
- 표시 이름과 내부 앱 진입 이름을 변경한 1.0.0 후보는 별도 검증이 필요함. 기존 Bundle ID `com.abaprogress.universal`은 유지함.
- 미서명 아카이브만으로 App Store Connect에 업로드할 수 없음. Apple Distribution 인증서·App Store 프로파일·Team ID·앱 레코드가 필요함.
- 개인정보처리방침은 운영자·문의처·보관/국외이전 사항이 비어 있는 초안이므로 공개하거나 제출하지 않음.
- 실제 Groq 호출 및 실기기 TestFlight 확인은 아직 완료되지 않음.

## 현재 제공 가능한 결과
- Xcode 프로젝트와 Swift Playgrounds 소스 유지
- iPhone/iPad 시뮬레이터 빌드·미서명 Release 아카이브·실제 PDF 출력 검증
- Render 무료 서버 생성 및 HTTPS 인증/입력 차단 확인
- iPhone 자동 UI 조작 통과 (run 34439190347): 반응 입력 → 완료 → 현황/주요 변화/소견 수동 입력 → 검토 → PDF 생성 → 시스템 공유 화면. 가상 데이터만 사용했으며 외부 제출/실제 AI 호출은 수행하지 않았다.
- 시연 PDF 10쪽 및 그래프 40→50→60→70→80%와 수동 문구 확인. 일반 양식 합성 PDF는 iPhone/iPad 16쪽·긴 문장 18쪽 검증 통과 (run 34439193086).

## 운영자에게 필요한 정보
1. Apple Developer 멤버십, Team ID, 등록 가능한 Bundle ID.
2. 서명 인증서·프로비저닝을 사용할 수 있는 Mac/Xcode 또는 비공개 macOS CI 설정.
3. 새 Groq 키. 공개 대화나 저장소에 입력하지 말고 앱/비밀 설정에 저장.
4. 판매자명, 개인정보 처리 책임자·연락처, 지원 연락처, 판매 지역·가격.
5. 최종 개인정보처리방침과 지원 페이지의 공개 HTTPS URL.

## 배포 순서
1. PR의 실패 항목 해결 및 코드 검토 → 검증한 커밋을 출시 후보로 지정.
2. Xcode Signing & Capabilities에서 Team 및 Bundle ID 확인.
3. `APPLE_TEAM_ID=... bash ABAProgress/Release/archive_signed.sh`로 서명된 Archive 및 배포 IPA 생성. 자동 업로드하지 않는다.
4. Xcode Organizer에서 Validate App. 개인정보 보고서·암호화 응답·서명·리소스 오류 수정.
5. App Store Connect에 앱 레코드와 등록 문구 입력. 새 연령 등급 질문에 실제 기능 기준으로 응답.
6. 동작하는 AI 심사 정보는 App Review 비공개 입력란으로 제공. 심사에 필요한 기능을 임의로 숨기지 않는다.
7. TestFlight 업로드 및 실기기 테스트. 안정성 확인 후에 심사 제출과 공개 일정 결정.

## 실기기 합격 조건
- 작은/일반 iPhone 및 11형/큰 iPad: 세로·가로·큰 글자에서 버튼/본문 접근 가능.
- 아동→프로그램→과제→10회 반응, NA 제외 분모와 +/− 상태를 확인.
- 입력 후 화면 이동·백그라운드·재시작에도 보존됨을 확인.
- NA 잔여 상태의 완료 경고, 기존 값 전체 변경 확인, 실행 취소·길게 눌러 초기화 확인.
- 달력의 과거 날짜 수정, 연속 기록일 기준 숙달, 이후 레벨의 비파괴 검토 경고 확인.
- 기간 경계·미완료 제외·날짜 간격 없는 그래프 및 PDF 일치.
- AI 동의 기본 해제, 취소 시 전송 없음, 새 키 실제 생성, 오래된 데이터 결과 적용 방지.
- PDF 공유 취소와 파일 저장 확인. 외부 제출은 실제 수신처와 별도 권한 확인 후 수행.
- 기록·보고서 초안·내보낸 PDF의 삭제 및 백업 복구 동작 확인.

현재 미서명 Archive는 설치용 IPA나 심사 승인 증거가 아니다. 무료 서버의 유휴 후 기동 지연, 새 AI 키 검증, 개인정보 운영 절차는 출시 전 확인해야 한다.

## 확인한 공식 기준 (2026-09-10)
- Xcode 26 및 iOS/iPadOS 26 SDK 이상: https://developer.apple.com/news/upcoming-requirements/
- 심사 및 제3자 AI 동의: https://developer.apple.com/app-store/review/guidelines/
- 개인정보 공개: https://developer.apple.com/app-store/app-privacy-details/

## Mac이 없는 경우: GitHub에서 서명 IPA 생성
`.github/workflows/abaprogress-distribution.yml`을 수동 실행한다. 자동 업로드·심사 제출은 하지 않는다. GitHub `app-store` environment에 아래 비밀값을 먼저 등록해야 한다. 환경 접근은 소유자에게 제한하고 승인 규칙을 설정하는 것이 좋다.
- APPLE_TEAM_ID
- APPLE_DISTRIBUTION_P12_BASE64 / APPLE_DISTRIBUTION_P12_PASSWORD
- APPLE_PROFILE_BASE64 (com.abaprogress.universal용 App Store 배포 프로파일)

Apple 계정에서 발급한 유효한 인증서와 개인 키가 들어 있는 P12가 필요하다. 비밀값이 없으면 작업은 명확한 오류로 종료한다. 팀·앱 ID·만료·프로파일 종류를 확인한 뒤 임시 Keychain에서 서명하고 작업 종료 시 서명 자료를 정리한다. 결과 IPA는 보관 기간 3일의 GitHub artifact로 제공되므로 저장소 접근 권한을 확인한다. 아직 실제 서명 실행으로 검증하지 않은 준비용 workflow다.

