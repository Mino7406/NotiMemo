import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/utils/ocr_text.dart';

void main() {
  group('cleanOcrText', () {
    test('앞뒤 공백과 줄 끝 공백을 없앤다', () {
      expect(cleanOcrText('\n\n  숙제   \n수학 문제집  \n\n'), '  숙제\n수학 문제집');
    });

    test('연속된 빈 줄은 한 줄로 줄인다', () {
      expect(cleanOcrText('가\n\n\n\n나'), '가\n\n나');
    });

    test('공백만 있는 줄도 빈 줄로 취급한다', () {
      expect(cleanOcrText('가\n   \n\t\n나'), '가\n\n나');
    });

    test('윈도우 줄바꿈을 통일한다', () {
      expect(cleanOcrText('가\r\n나'), '가\n나');
    });

    test('글자가 없으면 빈 문자열', () {
      expect(cleanOcrText(''), '');
      expect(cleanOcrText('\n \n'), '');
    });
  });

  group('appendRecognizedText', () {
    test('기존 글이 비어 있으면 인식 결과만', () {
      expect(appendRecognizedText('', '새 글'), '새 글');
      expect(appendRecognizedText('  \n', '새 글'), '새 글');
    });

    test('기존 글이 있으면 줄바꿈 후 이어 붙인다', () {
      expect(appendRecognizedText('우유 사기', '준비물'), '우유 사기\n준비물');
    });

    test('기존 글 끝의 공백·줄바꿈은 정리하고 붙인다', () {
      expect(appendRecognizedText('우유 사기\n\n', '준비물'), '우유 사기\n준비물');
    });
  });
}
