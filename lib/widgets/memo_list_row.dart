import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 눈에 잘 보이는 윤곽선 색(터치 영역을 알아보기 쉽게). 라이트/다크 공통으로 쓴다.
Color outlineColor(bool isDark) =>
    isDark ? const Color(0xFF3F4157) : const Color(0xFFD1D5DB);

/// 윤곽선이 있는 작은 정사각 아이콘 버튼. 알림 내역·예약 목록의 항목별 동작과
/// 슬라이드 메뉴의 닫기에 쓴다. 터치 영역이 눈에 보이게 하는 게 목적이다.
class OutlinedIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isDark;

  /// 아이콘 색. 윤곽선도 같은 색을 옅게 써서 동작의 성격(다시 고정 = 브랜드색 등)을 살린다.
  final Color? color;
  final double size;

  const OutlinedIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.isDark,
    this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
    final border = color == null
        ? outlineColor(isDark)
        : color!.withAlpha(isDark ? 150 : 120);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1.3),
          ),
          child: Icon(icon, size: size * 0.5, color: iconColor),
        ),
      ),
    );
  }
}

/// 목록 맨 위의 `전체삭제` 윤곽선 버튼(알림 내역·예약 목록 공통).
class ClearAllButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isDark;
  final Key? buttonKey;

  const ClearAllButton({
    super.key,
    required this.onPressed,
    required this.isDark,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: BorderSide(
          color: AppColors.danger.withAlpha(isDark ? 140 : 110),
          width: 1.2,
        ),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '전체삭제',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 알림 내역·예약 목록의 항목 한 줄. 두 화면이 같은 정렬을 갖도록 한 곳에서 만든다.
///
/// 정렬: 아이콘은 **메모 글줄**과 같은 높이에 놓이고(행 전체의 중앙이 아니다), 위의 분류 줄과
/// 아래의 시간 줄은 메모 글자와 같은 왼쪽 선에 맞춘다. 구조로 맞추기 때문에 글꼴·줄 수가
/// 달라져도 어긋나지 않는다.
class MemoListRow extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Key? labelKey;
  final String memo;
  final int? memoMaxLines;
  final String? timeText;
  final Color textColor;
  final Color subColor;
  final List<Widget> actions;

  const MemoListRow({
    super.key,
    required this.icon,
    required this.label,
    required this.memo,
    required this.textColor,
    required this.subColor,
    required this.actions,
    this.labelKey,
    this.memoMaxLines,
    this.timeText,
  });

  static const iconSize = 15.0;
  static const iconGap = 10.0;
  static const memoFontSize = 16.0;
  static const memoLineHeight = 1.45;

  /// 분류·시간 줄을 메모 글자와 같은 선에 맞추는 들여쓰기.
  static const indent = iconSize + iconGap;

  /// 오른쪽 동작 버튼(↻·✕) 사이 간격. 삭제를 잘못 누르지 않게 넉넉하게 둔다.
  static const actionGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: indent),
                  child: Text(
                    label!,
                    key: labelKey,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gradStart,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 줄의 높이(글자 크기 × 줄 간격)만큼의 칸 안에서 가운데에 놓는다.
                  SizedBox(
                    width: iconSize,
                    height: memoFontSize * memoLineHeight,
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.brandGradient.createShader(b),
                        child: Icon(icon, color: Colors.white, size: iconSize),
                      ),
                    ),
                  ),
                  const SizedBox(width: iconGap),
                  Expanded(
                    child: Text(
                      memo,
                      maxLines: memoMaxLines,
                      overflow: memoMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: memoFontSize,
                        color: textColor,
                        height: memoLineHeight,
                      ),
                    ),
                  ),
                ],
              ),
              if (timeText != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: indent),
                  child: Text(
                    timeText!,
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor.withAlpha(160),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: actionGap),
          actions[i],
        ],
      ],
    );
  }
}
