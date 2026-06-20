import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../theme/mypage_screen_tokens.dart';
import 'mypage/mypage_widgets.dart';

class PostStylePickerSheet extends StatefulWidget {
  const PostStylePickerSheet({super.key, required this.initialSelectedKeys});

  final List<String> initialSelectedKeys;

  @override
  State<PostStylePickerSheet> createState() => _PostStylePickerSheetState();
}

class _PostStylePickerSheetState extends State<PostStylePickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelectedKeys
        .where(UserProfile.postStyleKeys.contains)
        .cast<String?>()
        .firstWhere((e) => e != null, orElse: () => null);
  }

  void _select(String key) {
    setState(() {
      _selected = _selected == key ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Theme(
      data: MyPageScreenUi.overlayTheme(Theme.of(context)),
      child: SafeArea(
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
                  'おすすめ候補やショップ提案の調整に使います。1つ選べます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                for (final key in UserProfile.postStyleKeys) ...[
                  _PostStyleOptionTile(
                    styleKey: key,
                    selected: _selected == key,
                    enabled: true,
                    onTap: () => _select(key),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                MyPagePrimaryButton(
                  label: _selected == null ? '未選択で保存' : 'この探し方で保存',
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_selected == null ? <String>[] : <String>[_selected!]),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: MyPageScreenUi.outlineButtonStyle(height: 44),
                  child: const Text('閉じる'),
                ),
              ],
            ),
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
              ? MyPageScreenUi.primaryLight.withValues(alpha: 0.85)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? MyPageScreenUi.primaryBorder
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
                  ? MyPageScreenUi.primary
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
