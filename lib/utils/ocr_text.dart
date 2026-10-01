/// 인식된 글자를 입력창에 넣기 좋게 정리한다.
/// 줄 끝 공백을 없애고, 연속된 빈 줄은 한 줄로 줄이며, 앞뒤 빈 줄을 제거한다.
String cleanOcrText(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n').map((l) => l.trimRight());
  final out = <String>[];
  for (final line in lines) {
    if (line.trim().isEmpty) {
      if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
    } else {
      out.add(line);
    }
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// 입력창의 기존 글 [current] 뒤에 인식 결과 [recognized]를 줄바꿈으로 이어 붙인다.
/// 기존 글이 비어 있으면 인식 결과만 돌려준다.
String appendRecognizedText(String current, String recognized) {
  final base = current.trimRight();
  if (base.isEmpty) return recognized;
  return '$base\n$recognized';
}
