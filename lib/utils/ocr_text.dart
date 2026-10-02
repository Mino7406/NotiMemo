/// 인식된 글자를 입력창에 넣기 좋게 정리한다.
/// 줄 끝 공백을 없애고, 연속된 빈 줄은 한 줄로 줄이며, 앞뒤 빈 줄을 제거한다.
String cleanOcrText(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((l) => l.trimRight());
  // 정리된 줄을 모아 두는 목록
  final out = <String>[];
  for (final line in lines) {
    if (line.trim().isEmpty) {
      // 빈 줄이 여러 개 이어져도 한 줄만 남긴다
      if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
    } else {
      out.add(line);
    }
  }
  // 끝에 남은 빈 줄을 지운다
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}
