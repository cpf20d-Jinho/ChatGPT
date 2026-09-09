# v0.9 출시 준비

## 이번 변경
- 요청별 기본 미동의 화면. 수신처·목적·실제 수치 배열·제외 항목을 표시하고 체크 후 전송한다. 취소하면 AI 요청하지 않는다.
- 아동명·생년월일·날짜·프로그램명·메모·서명은 serializer에 포함하지 않는다. 서버는 추가 필드·문자열을 거부하고 Groq에는 통계만 보낸다.
- 서버 연결 확인은 인증/계약 확인만 수행하며 Groq 키나 학습 데이터를 보내지 않는다.
- 앱과 서버의 리디렉션 금지, Keychain 안전 교체·삭제, 사용자별 만료 토큰·분당 제한.
- Xcode 26+/iOS SDK 26+ 선택 및 미서명 Release 기기 아카이브 검사. iOS 17 최소 지원은 유지한다.
- iPhone/iPad 시뮬레이터에서 실제 보고서 PDF를 생성하고 합성 기본 양식 및 긴 문장 누락을 검사한다.

## 아직 운영자가 제공해야 하는 설정
1. Render 무료 서버 배포와 인증 health 확인 완료: https://abaprogress-reports.onrender.com. 사용자별 서버 접속 토큰은 비공개로 전달한다. `Server/DEPLOYMENT.md` 참고.
2. 공개된 적 없는 새 Groq 키. 키를 문서·PR·대화에 붙이지 말고 앱 또는 비밀 설정에 등록한다.
3. Apple Developer Team 및 등록 가능한 Bundle ID 확인. 코드 기본값은 Swift Playgrounds와 동일한 `com.abaprogress.universal`이며 등록·소유를 주장하지 않는다.
4. 개인정보 처리 책임자/연락처, 공개 방침 URL, 지원 URL. 앱의 전송 안내는 구현되어 있지만 운영자 미정인 상태에서 완성된 법적 방침으로 게시하지 않는다.

## 개인정보 공개 검토
반응 수치를 이름 없는 번호로 보내더라도 인증 토큰과 제공자 계정이 연결되므로 완전 익명을 주장하지 않는다. PrivacyInfo.xcprivacy는 건강 관련 데이터의 앱 기능 목적 처리를 보수적으로 선언한다. 직접 사용한 required-reason API는 현재 없으며, 종속성 추가/Archive Privacy Report 검토 시 수정한다. 서버/프록시/Groq의 실제 보존 설정을 App Store 개인정보 공개와 공개 방침에 일치시켜야 한다.

시스템 HTTPS 및 Keychain만 사용하는 현재 구현 기준으로 비면제 암호화를 사용하지 않음으로 설정했다. 향후 자체 암호화 추가 시 수출 규정 질문을 다시 검토한다.

## 배포 빌드
CI의 아카이브는 코드·리소스·SDK 검사이며 설치용 IPA나 Apple 제출 성공을 의미하지 않는다. Mac에서 Xcode 26+로 프로젝트를 열고 Signing & Capabilities의 Team을 지정한다. 운영 호스트를 `INFOPLIST_KEY_ABAReportServerHost`에 설정하고 Product > Archive > Validate App > Distribute App 순서로 진행한다. 인증서와 프로비저닝은 선택한 Apple 계정에서 발급한다.

## 검증 범위 및 남은 사항
실제 호스팅의 HTTPS 인증 및 잘못된 요청 차단은 검증했다. 새로운 키를 이용한 Groq 호출과 서명된 IPA 검증은 아직 필요하다. PDF 원본의 정확한 STO 정의·완료 목표 생애주기·기관 로고·특정 글꼴은 확정되지 않았다. 수치 계산 가정은 REPORT_TEMPLATE_SPEC.md를 확인한다. 기록 백업·복원과 전체 임상 흐름 실사용 검사는 출시 전 별도 필요하다.

근거 확인(2026-09-09):
- https://developer.apple.com/news/upcoming-requirements/
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/app-privacy-details/
- https://console.groq.com/docs/your-data
