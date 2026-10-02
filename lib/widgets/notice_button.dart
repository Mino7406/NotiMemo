import 'package:flutter/material.dart';
import 'memo_list_row.dart' show outlineColor;

/// 안내 창·안내 문구 옆에 놓이는 윤곽선 버튼. 눌러야 하는 영역이 눈에 보이도록 항상 테두리가 있다.
///
/// [color]가 null이면 취소처럼 덜 강조된 버튼(회색 윤곽선), 주면 확인·삭제처럼 강조된 버튼
/// (그 색의 윤곽선·글자와 옅은 배경)이다.
class NoticeButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const NoticeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color;
    final textColor =
        accent ?? (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: accent?.withAlpha(isDark ? 36 : 18),
        side: BorderSide(
          color: accent == null
              ? outlineColor(isDark)
              : accent.withAlpha(isDark ? 170 : 140),
          width: 1.3,
        ),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: accent == null ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
    );
  }
}
