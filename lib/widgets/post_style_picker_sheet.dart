import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class PostStylePickerSheet extends StatefulWidget {
  const PostStylePickerSheet({super.key, required this.initialSelectedKeys});

  final List<String> initialSelectedKeys;

  @override
  State<PostStylePickerSheet> createState() => _PostStylePickerSheetState();
}

class _PostStylePickerSheetState extends State<PostStylePickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelectedKeys
        .where(UserProfile.postStyleKeys.contains)
        .take(3)
        .toSet();
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else if (_selected.length < 3) {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '探し方を選ぶ',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'おすすめ候補やショップ提案の調整に使います。最大3件まで選べます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in _selected)
                      Chip(
                        label: Text(UserProfile.postStyleLabelJa(key)),
                        backgroundColor: AppColors.accentLight,
                        labelStyle: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              for (final key in UserProfile.postStyleKeys) ...[
                _PostStyleOptionTile(
                  styleKey: key,
                  selected: _selected.contains(key),
                  enabled: _selected.contains(key) || _selected.length < 3,
                  onTap: () => _toggle(key),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              AppPrimaryButton(
                label: _selected.isEmpty ? '未選択で保存' : '${_selected.length}件で保存',
                onPressed: () => Navigator.of(
                  context,
                ).pop(_selected.toList(growable: false)),
              ),
              const SizedBox(height: 8),
              AppSecondaryButton(
                label: '閉じる',
                onPressed: () => Navigator.of(context).pop(),
                expand: true,
                height: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostStyleOptionTile extends StatelessWidget {
  const _PostStyleOptionTile({
    required this.styleKey,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String styleKey;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentLight.withValues(alpha: 0.65)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accentPrimary.withValues(alpha: 0.45)
                : AppColors.divider.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? AppColors.accentPrimary
                  : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UserProfile.postStyleLabelJa(styleKey),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    UserProfile.postStyleDescriptionJa(styleKey),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
