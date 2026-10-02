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
}
