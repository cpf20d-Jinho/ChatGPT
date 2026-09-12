# App Store 등록 내용 — 운영자 확인 전 초안

앱 이름: ABA 경과관리
부제: 아동별 학습 기록과 경과 보고서
분류 제안: 생산성 (치료사 기록 도구). 최종 분류·연령 등급은 실제 App Store Connect 질문에 답하여 확정한다. 아동이 직접 사용하는 Kids 앱으로 분류하지 않는다.
키워드: ABA,행동분석,치료사,학습기록,정반응률,경과보고서,프로그램,과제

## 설명
ABA 경과관리는 치료사가 아동별 프로그램과 과제 수행을 기록하고, 지정한 기간의 경과를 살펴보는 iPhone·iPad 앱입니다.

• 과제별 최대 10회 반응을 NA, 정반응(+), 촉구반응(-)으로 기록합니다.
• 프로그램별 단계와 목표를 관리합니다.
• 기록이 있는 날짜를 중심으로 정반응률 그래프를 확인합니다.
• 완료된 기록으로 사용자 지정 기간의 보고서를 작성하고 PDF로 공유합니다.
• 치료사 소견, 가정 연계, 다음 목표를 직접 작성합니다.
• 필요한 설명은 동그라미 물음표 도움말에서 확인합니다.
• 선택적으로 보고서의 서술 항목을 웹에서 수정하고 앱에서 검토해 반영합니다. 서버 접속 정보와 별도 동의가 필요하며, 편집본은 암호화된 임시본으로 기본 1시간 보관됩니다. 30분씩 연장할 수 있지만 사용자 서버 토큰 만료 시각을 넘길 수 없고, 서버 중지·재시작 시 더 일찍 사라질 수 있습니다.

기본 기록과 수동 보고서는 기기에서 사용할 수 있습니다. 선택적인 AI 초안 기능은 별도의 서버 접속 정보와 Groq API 키가 필요합니다. 요청마다 전송 내용을 확인하고 동의한 경우 학습 반응 수치를 이용해 현황·주요 변화의 초안을 작성합니다. 아동명·생년월일·프로그램명·메모·서명과 PDF는 AI에 보내지 않습니다.

AI 초안과 집계는 사용자가 검토해야 합니다. 이 앱은 진단하거나 치료 효과를 보장하는 도구가 아닙니다.

## 등록 전에 채울 내용
- 판매자/저작권자: 운영자 확정 필요
- 지원 URL / 개인정보처리방침 URL: 운영자 확인 후 공개 HTTPS URL 등록
- 가격과 판매 지역: 운영자 확정 필요
- 심사 연락처: 운영자 입력
- AI 기능에 필요한 심사용 제한 계정: 새 키로 별도 구성, 공개 저장소에 입력 금지
- 스크린샷: 실제 최신 출시 후보 빌드에서 가상 데이터로 촬영. 기존 실패 영상 프레임을 완성 기능 증빙으로 사용하지 않는다.

## 심사 메모 (영문 초안)
ABA Progress is a record-keeping app for adult practitioners, available on iPhone and iPad. Core records and manually written PDF reports work without an account or an AI key. Trial states are NA (excluded from the denominator), correct (+), and prompted (-). Only completed eligible sessions are included in reports.

Optional narrative drafting uses a report server and Groq. Every request requires explicit consent. The app transmits numeric response-rate arrays only; the server sends aggregate statistics to Groq. Names, dates of birth, program names, notes, signatures and PDFs are excluded. AI output is limited to current status and major changes and must be reviewed before application. Later clinical narrative fields remain manual.

Review path: Children > Add child > Add program > Add target > record trials > Complete > Reports > select child and date range > write narrative > confirm review > Generate PDF > Share. Provide working review credentials privately if the AI feature remains enabled in the submitted build.

Optional web editing: Reports > Report web editing > review the six text fields and recipient > explicitly consent > create a temporary link > edit in a trusted browser > save > return to the app > review and apply > end the link > review and regenerate PDF. This uses only the report-server credential, not an AI key. Profile, raw treatment records, graphs, cover and signatures are not editable through this link. Text is AES-GCM encrypted with a key kept in the link fragment, with one hour of initial in-memory relay storage; 30-minute extensions cannot exceed the report-server credential expiry, and restart may erase it earlier. This feature is not a cloud backup. Free-form text is not automatically anonymized. Provide review credentials privately, never in the public repository.

