# Google Gemini 숫자 해석 서버 (v0.8.1)

모델: `gemini-3.8-flash`. 무료 할당량·정식 모델·구조화 출력 지원을 기준으로 선정했다. 실제 한국어 품질 비교나 API 호출은 아직 수행하지 않았다.

## 전송 범위
앱은 각 프로그램의 단계별 측정값을 날짜순으로 정렬한 숫자 배열만 서버에 전송한다. 이름, 생년월일, ID, 실제 날짜, 프로그램명, 영역명, 관찰 메모, 기관, 서명, 작성한 보고서 문장은 전송하지 않는다.
서버는 버전 숫자와 숫자 배열 외의 필드를 거부한다. Google에는 원시 배열 대신 계열 번호, 관측 개수, 처음/마지막 최대 3회 평균, 평균 차이, 최솟값, 최댓값, 비교 구간 중복 여부만 전달한다. 평균은 단계 사이를 합치지 않는다.
Google에는 수치 변화 설명만 요청한다. 진단, 치료 효과, 인과관계, 중재 권고, 숙달 판단은 요청하지 않는다. 응답은 두 문구를 검토한 후 사용자가 적용한다.

숫자 요약만으로 완전한 익명성이나 비민감성을 보장하지는 않는다. [Google 약관](https://ai.google.dev/gemini-api/terms)은 무료 서비스에 민감·개인정보를 제출하지 않도록 하며 임상 실무 사용도 제한한다. 식별정보 제거가 이 사용 제한을 없애지는 않는다. 실제 업무 적합성 확인 전 합성 데이터로 검증한다. 무료 요청/응답은 Google 제품 개선에 사용될 수 있다. `store:false`는 이 조건을 바꾸지 않는다.

## 발급 및 설정
1. [Google AI Studio](https://aistudio.google.com/apikey)에 본인 Google 계정으로 로그인하여 프로젝트와 API 키를 생성한다.
2. 프로젝트의 무료 티어와 사용 가능 모델을 확인한다. 무료 사용을 원하면 결제 계정을 연결하거나 유료 티어로 전환하지 않는다.
3. Node.js 20 이상인 서버에 비밀 환경변수 `GEMINI_API_KEY`와 무작위 32자 이상의 `REPORT_SERVER_TOKEN`을 설정한다. 키는 채팅·소스·앱에 넣지 않는다.
4. `node ABAProgress/Server/server.mjs`를 실행한다. 기본 `127.0.0.1:8787`, POST `/report/narrative`이다.
5. HTTPS 리버스 프록시와 인증/요청 제한을 구성한다. 앱에는 전체 HTTPS 경로와 서버 접속 토큰만 입력한다. 서버 배포는 아직 완료되지 않았다.

API 키의 결제 상태는 코드에서 확인할 수 없다. 유료 프로젝트 키를 사용하면 비용이 발생할 수 있다. 자동 재시도·유료 모델 전환은 없으며 429이면 수동 재시도를 안내한다. 무료 한도는 [AI Studio/공식 한도](https://ai.google.dev/gemini-api/docs/rate-limits)에서 확인한다. 서버 호스팅 비용은 별도다.
현재 서버당 키 하나를 사용한다. 치료사별 Google OAuth 로그인과 공용 서버의 개별 키 보관/사용량 분리는 구현하지 않았다. Google 로그인 자체가 이 서버의 API 설정을 대신하지 않는다.

## 검증
`node --test ABAProgress/QA/report-ai.test.mjs`: 합성 입력과 모의 Google 응답으로 12개 검사.
`node ABAProgress/QA/report-template.test.cjs`: 기존 보고서 템플릿 검사.
실제 API 키가 없어 실모델 출력과 한국어 품질은 미검증이다. Windows에서 iOS 실행은 불가능하므로 macOS CI 빌드를 별도 확인한다.

[모델](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash) · [가격](https://ai.google.dev/gemini-api/docs/pricing) · [API](https://ai.google.dev/api/generate-content)
