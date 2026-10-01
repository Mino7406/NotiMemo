# ML Kit 텍스트 인식 플러그인이 참조하지만 앱에 포함하지 않는 언어 모델(중국어·일본어·데바나가리).
# release 빌드에서 R8이 누락 클래스로 실패하지 않도록 경고를 무시한다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
