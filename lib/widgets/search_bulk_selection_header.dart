import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/search_tab_ui_audit_log.dart';

/// 「探す」タブ内の一括選択ヘッダ（左上チェック＋件数）。
class SearchBulkSelectionHeader extends StatelessWidget {
  const SearchBulkSelectionHeader({
    super.key,
    required this.screen,
    required this.selectedCount,
    required this.totalSelectable,
    required this.onToggleAll,
    this.enabled = true,
  });

  final String screen;
  final int selectedCount;
  final int totalSelectable;
  final ValueChanged<bool> onToggleAll;
  final bool enabled;

  bool get _allSelected =>
      totalSelectable > 0 && selectedCount >= totalSelectable;

  bool get _partialSelected =>
      selectedCount > 0 && selectedCount < totalSelectable;

  @override
  Widget build(BuildContext context) {
    final checked = _allSelected;
    if (kDebugMode) {
      selectionUiAuditLog(
        'screen=$screen supportsBulkSelection=true selectAllVisible=true '
        'selectedCount=$selectedCount totalSelectable=$totalSelectable',
      );
    }
    return Theme(
      data: RakutenSearchScreenUi.overlayTheme(Theme.of(context)),
      child: Row(
        children: [
          Checkbox(
            tristate: true,
            value: _partialSelected ? null : checked,
            activeColor: RakutenSearchScreenUi.primary,
          onChanged: !enabled || totalSelectable == 0
              ? null
              : (v) {
                  final next = v == true;
                  if (kDebugMode) {
                    selectionToggleAllLog(
                      'screen=$screen checked=$next beforeSelected=$selectedCount '
                      'afterSelected=${next ? totalSelectable : 0} '
                      'totalSelectable=$totalSelectable',
                    );
                  }
                  onToggleAll(next);
                },
        ),
        Expanded(
          child: GestureDetector(
            onTap: !enabled || totalSelectable == 0
                ? null
                : () => onToggleAll(!checked),
            behavior: HitTestBehavior.opaque,
            child: Text(
              _partialSelected ? 'すべて選択（一部選択中）' : 'すべて選択',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomeScreenColors.titlePrimary,
                  ),
            ),
          ),
        ),
        Text(
          '選択中：$selectedCount件',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: HomeScreenColors.groupedSectionBody,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
      ),
    );
  }
}
