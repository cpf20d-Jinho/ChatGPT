# Groq 숫자 해석 서버 (v0.8.1)

모델은 Groq에서 제공하는 `openai/gpt-oss-120b`다. 앱과 서버는 이름·날짜·프로그램명·메모를 제외하는 기존 숫자 전송 경계를 유지한다.

## 사용자 연결

Groq는 현재 제3자 앱용 OAuth나 “Groq로 로그인” API를 제공하지 않는다. 모든 API 요청은 API 키로 인증된다. 따라서 ABAProgress가 사용자의 Groq 로그인 후 키를 자동으로 가져오는 기능은 구현할 수 없다.

지원하는 흐름은 다음과 같다.

1. 사용자가 앱의 링크로 Groq Console에 로그인한다.
2. 본인 프로젝트에서 API 키를 만들고 앱에 최초 한 번 붙여넣는다.
3. 앱은 키를 iOS Keychain의 `WhenUnlockedThisDeviceOnly` 접근 등급으로 저장한다.
4. 이후 보고서 요청 때 앱이 키를 HTTPS 서버에 자동으로 전달한다.
5. 서버는 키를 저장·로그하지 않고 해당 Groq 요청 한 번에만 사용한다.

키를 앱 설정이나 보고서 데이터에 평문으로 저장하지 않는다. 기기 백업으로 이동하지 않으며 앱을 다시 설치하거나 다른 기기를 사용하면 다시 등록해야 한다. 연결 해제와 키 폐기는 Groq Console에서 수행한다.

## 전송 데이터

앱은 프로그램의 단계별 측정값을 날짜순으로 정렬한 숫자 배열만 ABAProgress 서버로 보낸다. 서버는 버전 숫자와 0~100 숫자 배열 외의 필드를 거부한다. Groq에는 원시 배열 대신 계열 번호, 관측 개수, 처음/마지막 최대 3회 평균, 평균 차이, 최솟값, 최댓값, 비교 구간 중복 여부만 전달한다.

모델은 수치 변화만 한국어로 설명한다. 진단, 치료 효과, 인과관계, 중재 권고, 숙달 판단을 생성하지 않는다. 결과는 사용자가 검토한 후 두 보고서 항목에 적용한다.

숫자 요약만으로 완전한 익명성을 보장하지는 않는다. Groq의 현재 정책 및 기관 정책을 실제 배포 전에 확인한다. [Groq 데이터 정책](https://console.groq.com/docs/your-data)

## 서버 설정

Node.js 20 이상에서 무작위 32자 이상의 `REPORT_SERVER_TOKEN`을 환경변수로 설정하고 다음을 실행한다.

```sh
node ABAProgress/Server/server.mjs
```

기본 주소는 `127.0.0.1:8787`, 경로는 `POST /report/narrative`다. 인증과 사용자별 요청 제한이 적용된 HTTPS 프록시 뒤에 배치해야 한다. 앱은 `Authorization`에 ABAProgress 접속 토큰, `X-Groq-API-Key`에 사용자의 키를 전송한다. 서버가 Groq로 전달하기 전 키 형식을 검증한다.

배포 시 Xcode 빌드 설정의 `INFOPLIST_KEY_ABAReportServerHost`를 실제 HTTPS 서버 호스트로 바꿔야 한다. 현재 값 `reports.example.invalid`는 의도적으로 연결되지 않는 자리표시자다. 앱은 이 호스트와 정확히 일치하는 주소에만 Groq 키를 보낸다. 리버스 프록시에서도 `X-Groq-API-Key`를 접근 로그와 오류 추적에서 반드시 마스킹한다.

현재 `REPORT_SERVER_TOKEN`은 공용 배포용 사용자 인증 체계가 아니다. 여러 사용자가 실제로 이용하기 전 다음 작업이 필요하다.

- ABAProgress 사용자 로그인과 만료되는 사용자별 서버 토큰
- 서버 측 사용자별·IP별 속도 제한 및 동시 요청 제어
- 키·요청 본문·제공자 오류를 남기지 않는 로그 정책
- TLS, 감사 기록, 계정 폐기 및 접근 차단

## 무료 한도

무료 한도는 각 사용자의 Groq 조직에 적용된다. 한도를 넘으면 429를 반환하고 앱은 자동 재시도하거나 유료 모델로 전환하지 않는다. [Groq 한도](https://console.groq.com/docs/rate-limits)

## 검증

```sh
node --test ABAProgress/QA/report-ai.test.mjs
node ABAProgress/QA/report-template.test.cjs
```

합성 데이터와 모의 Groq 응답으로 숫자 전송 경계, 사용자별 키 전달, 인증·한도·응답 실패를 검사한다. 실제 키를 사용한 API 품질은 아직 검증하지 않았다.

[Groq 보안 안내](https://console.groq.com/docs/production-readiness/security-onboarding) · [API 키](https://console.groq.com/keys) · [구조화 출력](https://console.groq.com/docs/structured-outputs)
