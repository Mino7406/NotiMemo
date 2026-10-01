import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/ocr_text.dart';

enum PhotoSource { camera, gallery }

/// 사진에서 글자를 읽는다. 온디바이스(ML Kit 한국어 모델)라 오프라인에서도 동작한다.
class OcrService {
  static final _picker = ImagePicker();

  /// 사진을 고르고 인식한 글자를 돌려준다.
  /// 사용자가 사진 선택을 취소하면 null, 글자가 없으면 빈 문자열이다.
  /// 사진 원본은 저장하지 않고, 임시 파일은 인식 직후 지운다.
  static Future<String?> readFromPhoto(PhotoSource source) async {
    final picked = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(picked.path));
      return cleanOcrText(result.text);
    } finally {
      await recognizer.close();
      try {
        await File(picked.path).delete();
      } catch (_) {
        // 임시 파일 삭제 실패는 무시한다.
      }
    }
  }
}
