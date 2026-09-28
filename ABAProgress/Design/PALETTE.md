# 쉬운 ABA 색상

대표 팔레트는 [뚜띠콜로리의 「5월의 색, 제주 감귤꽃」](https://www.tutticolori.co.kr/89/?bmode=view&idx=15317724)에서 가져왔습니다. 원본 색상은 아이보리 `#F9F1DC`, 버터 옐로 `#FDDE6A`, 리프 그린 `#758756`입니다. 상업적 사용 시 원본 페이지의 색상 데이터 출처 표시 조건을 확인하고 이 출처를 유지합니다.

UI 색상은 Xcode와 Swift Playgrounds 양쪽의 sRGB 색상 에셋으로 저장합니다. 다크 모드와 대비 증가 모드 변형을 따로 제공하며 SwiftUI에서는 의미별 에셋 이름으로 참조합니다. 버터 옐로는 앱 안의 경고와 알림 등 강조 영역에 사용하며 아이보리는 기본 배경입니다. 리프 그린은 카드 윤곽선과 구분선에 사용합니다. 아이보리 위의 작은 글자나 시스템 tint에는 가독성을 위해 어두운 황토색 `#795900`을 사용합니다. 아이콘은 사용자가 최종 제공한 이미지로 교체했으며 아이보리 배경과 리프 그린 ABA 글자 및 데이터 표시를 사용합니다. 차트의 데이터 계열과 상태 색상은 의미 구분을 위해 유지합니다.

Apple의 ColorSync는 이 sRGB 에셋을 디스플레이 색 공간에 맞게 처리하는 시스템 경로에서 활용됩니다. 정적인 인터페이스 색상에 직접 ICC 변환이나 Accelerate 이미지 연산을 넣을 필요는 없습니다. 아이콘 PNG에는 sRGB 프로파일을 포함했습니다. 향후 사진 색 보정이나 대용량 이미지 변환 기능이 생기면 Core Image 또는 Accelerate/vImage를 해당 이미지 처리 단계에 적용할 수 있습니다.

참고: [Apple HIG Color](https://developer.apple.com/design/human-interface-guidelines/color), [ColorSync](https://developer.apple.com/documentation/colorsync), [Accelerate](https://developer.apple.com/documentation/accelerate).
