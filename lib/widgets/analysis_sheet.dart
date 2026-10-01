import 'package:flutter/material.dart';
import '../models/memo_analysis.dart';
import '../models/memo_entry.dart';
import '../theme/app_theme.dart';
import '../utils/analysis_labels.dart';

/// 결과 시트에서 사용자가 고른 동작.
enum AnalysisDecision {
  /// 카테고리·우선순위·요약만 메모에 적용
  apply,

  /// 적용하고, 제안된 예약 시각으로 예약 시트를 연다
  applyAndSchedule,
}

/// 자동 정리 결과를 보여주고 적용 여부를 묻는다. 닫으면 null.
Future<AnalysisDecision?> showAnalysisSheet(
  BuildContext context,
  MemoAnalysis analysis,
) {
  return showModalBottomSheet<AnalysisDecision>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AnalysisSheet(analysis: analysis),
  );
}

class AnalysisSheet extends StatelessWidget {
  final MemoAnalysis analysis;
  const AnalysisSheet({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final due = analysis.due;
    final isAi = analysis.source == AnalysisSource.ai;
    final reason = analysis.fallbackReason;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '자동 정리',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                _SourceBadge(isAi: isAi, isDark: isDark, subColor: subColor),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: subColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fallbackMessage(reason),
                      key: const Key('fallback-message'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: analysis.category,
                  color: AppColors.gradStart,
                  isDark: isDark,
                  keyName: 'category-chip',
                ),
                _Chip(
                  label: '우선순위 ${priorityLabel(analysis.priority)}',
                  color: switch (analysis.priority) {
                    MemoPriority.high => AppColors.danger,
                    MemoPriority.normal => subColor,
                    MemoPriority.low => subColor,
                  },
                  isDark: isDark,
                  keyName: 'priority-chip',
                ),
              ],
            ),
            if (analysis.summary.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('요약', subColor),
              const SizedBox(height: 4),
              Text(
                analysis.summary,
                key: const Key('summary-text'),
                style: TextStyle(fontSize: 14.5, color: textColor, height: 1.5),
              ),
            ],
            if (due != null) ...[
              const SizedBox(height: 16),
              _Label('예약 시각 제안', subColor),
              const SizedBox(height: 4),
              Text(
                formatDueLabel(due.at),
                key: const Key('due-text'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (!due.hasTime)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '시각이 없어 오전 9시로 채웠어요. 다음 화면에서 고칠 수 있어요.',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),
            ],
            const SizedBox(height: 22),
            if (due != null) ...[
              _PrimaryButton(
                label: '적용하고 예약 시각 확인',
                onTap: () =>
                    Navigator.pop(context, AnalysisDecision.applyAndSchedule),
              ),
              const SizedBox(height: 8),
              _OutlineButton(
                label: '적용만 하기',
                isDark: isDark,
                color: subColor,
                onTap: () => Navigator.pop(context, AnalysisDecision.apply),
              ),
            ] else
              _PrimaryButton(
                label: '적용',
                onTap: () => Navigator.pop(context, AnalysisDecision.apply),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final bool isAi;
  final bool isDark;
  final Color subColor;
  const _SourceBadge({
    required this.isAi,
    required this.isDark,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: isAi ? AppColors.brandGradient : null,
        color: isAi
            ? null
            : (isDark ? AppColors.elevatedDark : const Color(0xFFEEF2FF)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAi ? 'AI 분석' : '기본 분석',
        key: const Key('source-badge'),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isAi ? Colors.white : subColor,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.4,
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final String keyName;
  const _Chip({
    required this.label,
    required this.color,
    required this.isDark,
    required this.keyName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 36 : 22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(isDark ? 110 : 80)),
      ),
      child: Text(
        label,
        key: Key(keyName),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color color;
  final VoidCallback onTap;
  const _OutlineButton({
    required this.label,
    required this.isDark,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
