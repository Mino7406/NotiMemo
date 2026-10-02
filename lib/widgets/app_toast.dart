import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 모든 토스트 내용 줄의 높이(동작 버튼이 있는 토스트와 크기를 맞추는 기준).
const double toastContentHeight = 30;

/// 알림 토스트. [actionLabel]과 [onAction]을 주면 오른쪽에 "되돌리기" 같은 동작 버튼이 붙는다.
/// 동작 버튼은 흰 윤곽선으로 눌러야 할 곳이 눈에 보이게 한다.
///
/// 돌려주는 컨트롤러로 토스트를 직접 닫거나([ScaffoldFeatureController.close]) 닫힌 시점을
/// ([ScaffoldFeatureController.closed]) 알 수 있다. "되돌리기"처럼 상황이 바뀌면 더는 의미가 없는
/// 토스트를 그때 닫으려고 쓴다.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String msg, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar(); // 이전 토스트가 쌓이지 않게 바로 교체한다
  final hasAction = actionLabel != null && onAction != null;
  return messenger.showSnackBar(
    SnackBar(
      // 동작 버튼이 있든 없든 한 줄짜리 토스트의 크기가 같도록 내용 줄의 최소 높이를 고정한다.
      content: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: toastContentHeight),
        child: Row(
          children: [
            Icon(
              isError ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
            if (hasAction) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('toast-action'),
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.3),
                  // 높이는 토스트 내용 줄(30)에 딱 맞춘다. 더 크면 이 토스트만 커진다.
                  minimumSize: const Size(0, toastContentHeight),
                  maximumSize: const Size(double.infinity, toastContentHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}
