# 서버 연결 절차 — v0.9

2026-09-09 My Workspace의 Singapore 무료 Node 서비스에 배포했다. HTTPS 인증 health 확인은 통과했으며, 새 Groq 키를 통한 제공자 응답 검증은 아직 필요하다.

서버: https://abaprogress-reports.onrender.com · Render 서비스: srv-dagldhqjnfac73e3asm0 공개 PR에 노출되었던 키를 재사용하지 않는다.

1. Node 22 또는 이 폴더의 Dockerfile을 지원하는 호스트에 배포한다. 외부 요청은 유효한 인증서의 HTTPS 프록시만 허용한다.
2. 사용자마다 암호학적으로 무작위인 32바이트 이상의 토큰을 발급하고 안전한 채널로 전달한다. 토큰 자체는 GitHub에 올리지 않는다.
3. 비밀 파일 `users.json`에 아래 형식으로 토큰 SHA-256과 만료일을 저장한다. `REPORT_USERS_FILE` 환경변수를 해당 파일 경로로 지정한다. `NODE_ENV=production`에서는 공용 토큰만으로 시작할 수 없다.

Render처럼 비밀 환경변수를 사용하는 호스트는 같은 JSON을 `REPORT_USERS_JSON`에 설정할 수 있다. 파일 설정이 있으면 파일이 우선한다. 현재 연결된 Render 계정에서 조회된 `My Workspace`의 선택 확인 후 아래 설정으로 생성한다. 조회만 했으며 아직 서비스를 만들지 않았다.

- 서비스: `abaprogress-reports`, Node, Free, Singapore
- 저장소: `https://github.com/cpf20d-Jinho/ChatGPT`
- 브랜치: `codex/abaprogress-release-readiness-v0.9`
- 빌드: `node --check ABAProgress/Server/server.mjs`
- 시작: `node ABAProgress/Server/server.mjs`
- 환경: `NODE_VERSION=22`, `NODE_ENV=production`, `LISTEN_HOST=0.0.0.0`, `REPORT_USERS_JSON` 비밀값
- Groq 키는 서버 환경에 저장하지 않는다. 앱의 사용자별 키를 요청에만 사용한다.

```json
[{"digest":"<token SHA-256 hex>","expiresAt":"<ISO-8601 UTC expiration>"}]
```

4. 계정 토큰 폐기는 해당 항목 삭제 후 서비스 재시작으로 적용한다. 현재는 기관 관리자가 발급하는 방식이다. 자동 로그인/재발급 서비스는 포함하지 않는다.
5. 프록시에서 Authorization, X-Groq-API-Key, 요청 본문 및 오류 본문 로그를 끈다. IP별 제한은 프록시에서 적용한다. 서버는 토큰별 분당 10요청, 프로세스당 AI 동시 1요청으로 제한한다. 여러 인스턴스로 늘리려면 중앙 속도 제한 저장소가 필요하다.
6. Xcode 빌드 설정 `INFOPLIST_KEY_ABAReportServerHost`에 해당 호스트만 넣는다. 앱은 URL을 자동 구성하고 HTTPS/443/정확한 경로만 허용하며 리디렉션은 거부한다.
7. 앱의 서버 접속 토큰 입력 후 '서버 연결 확인'을 실행한다. 이는 인증과 계약 버전만 확인하고 Groq를 호출하지 않는다.
8. 새 Groq 키를 앱 Keychain에 저장하고 가상 아동의 합성 수치로 매 요청 동의 → 생성 → 검토 → 두 항목 적용 → PDF를 확인한다. 실제 아동 데이터로 초기 연결 시험을 하지 않는다.

## 통신 계약
- GET `/report/health`: 서버 토큰만 필요. 성공은 Groq 키/모델 접근 성공을 의미하지 않는다.
- POST `/report/narrative`: Authorization, X-Groq-API-Key, X-ABA-Consent: numeric-v1 필요.
- 본문은 `{ "version": 1, "series": [[20, 40, 60]] }` 형태의 수치만 허용한다. 이름·생년월일·날짜·프로그램명·메모 등의 추가 필드와 문자열을 거부한다.
- 동의 헤더는 클라이언트 계약 검사이며 사람의 동의 사실을 독립적으로 입증하는 서명이 아니다. 앱은 요청별 기본 미동의 화면에서 전송을 승인받는다.
- 서버는 Groq에 원시 배열도 보내지 않고 통계만 전달한다. 치료사 소견·가정 연계·다음 목표는 응답에 허용하지 않는다.
