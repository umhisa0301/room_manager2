import 'package:flutter/material.dart';

import '../models/rakuten_genre_master_entry.dart';
import '../services/rakuten_genre_master_service.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class FavoriteGenrePickerSheet extends StatefulWidget {
  const FavoriteGenrePickerSheet({super.key, required this.initialSelectedIds});

  final List<String> initialSelectedIds;

  @override
  State<FavoriteGenrePickerSheet> createState() =>
      _FavoriteGenrePickerSheetState();
}

class _FavoriteGenrePickerSheetState extends State<FavoriteGenrePickerSheet> {
  late final Set<String> _selected;
  late final List<RakutenGenreMasterEntry> _entries;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(
      widget.initialSelectedIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
    );
    _entries = RakutenGenreMasterService.instance.getAllGenres();
  }

  void _toggle(String genreId, bool? checked) {
    final id = genreId.trim();
    if (id.isEmpty) return;
    if (checked == true) {
      if (_selected.length >= 5) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ジャンルは最大5件まで選択できます')));
        return;
      }
      setState(() => _selected.add(id));
    } else {
      setState(() => _selected.remove(id));
    }
  }

  void _apply() {
    final ordered = <String>[];
    for (final e in _entries) {
      final id = e.genreId;
      if (_selected.contains(id)) ordered.add(id);
    }
    Navigator.of(context).pop(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final limitReached = _selected.length >= 5;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '好きなジャンルを選ぶ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.numbers_rounded,
                          size: 22,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '最大5件まで選べます（現在 ${_selected.length} / 5）',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'タップでON/OFF。上限に達している項目はこれ以上追加できません。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in _selected)
                          InputChip(
                            label: Text(_genreNameForId(id)),
                            onDeleted: () =>
                                setState(() => _selected.remove(id)),
                            backgroundColor: AppColors.surfaceVariant
                                .withValues(alpha: 0.7),
                            side: BorderSide(
                              color: AppColors.divider.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final e = _entries[index];
                  final id = e.genreId;
                  final selected = _selected.contains(id);
                  final disabledByLimit = limitReached && !selected;
                  return _GenreGridCell(
                    label: e.genreName,
                    icon: _iconForGenrePicker(e.genreName, e.genreId),
                    selected: selected,
                    disabled: disabledByLimit,
                    onTap: () {
                      if (disabledByLimit) return;
                      _toggle(id, !selected);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'キャンセル',
                      onPressed: () => Navigator.of(context).pop(),
                      expand: true,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppPrimaryButton(
                      label: '決定',
                      onPressed: _apply,
                      height: 48,
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

  String _genreNameForId(String id) {
    for (final entry in _entries) {
      if (entry.genreId == id) return entry.genreName;
    }
    return id;
  }
}

class _GenreGridCell extends StatelessWidget {
  const _GenreGridCell({
    required this.label,
    required this.icon,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentPrimary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.divider.withValues(alpha: 0.85),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppColors.accentLight.withValues(alpha: 0.38)
                : AppColors.surface,
          ),
          child: Opacity(
            opacity: disabled ? 0.42 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: selected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForGenrePicker(String genreName, String genreId) {
  final n = genreName;
  if (n.contains('食品') ||
      n.contains('スイーツ') ||
      n.contains('お菓子') ||
      n.contains('米')) {
    return Icons.restaurant_outlined;
  }
  if (n.contains('ファッション') ||
      n.contains('服') ||
      n.contains('靴') ||
      n.contains('バッグ')) {
    return Icons.checkroom_outlined;
  }
  if (n.contains('本') || n.contains('電子') || n.contains('書籍')) {
    return Icons.menu_book_outlined;
  }
  if (n.contains('家電') ||
      n.contains('PC') ||
      n.contains('スマホ') ||
      n.contains('カメラ')) {
    return Icons.devices_outlined;
  }
  if (n.contains('美容') || n.contains('コスメ') || n.contains('香水')) {
    return Icons.brush_outlined;
  }
  if (n.contains('スポーツ') || n.contains('アウトドア') || n.contains('ゴルフ')) {
    return Icons.hiking_outlined;
  }
  if (n.contains('花') || n.contains('ガーデン') || n.contains('園芸')) {
    return Icons.local_florist_outlined;
  }
  if (n.contains('おもちゃ') || n.contains('ホビー') || n.contains('ゲーム')) {
    return Icons.toys_outlined;
  }
  if (n.contains('車') || n.contains('バイク') || n.contains('自転車')) {
    return Icons.pedal_bike_outlined;
  }
  if (n.contains('インテリア') || n.contains('家具') || n.contains('寝具')) {
    return Icons.chair_outlined;
  }
  if (n.contains('ペット') || n.contains('動物')) {
    return Icons.pets_outlined;
  }
  if (n.contains('雑貨') || n.contains('日用品')) {
    return Icons.shopping_basket_outlined;
  }
  const fallbacks = <IconData>[
    Icons.category_outlined,
    Icons.shopping_bag_outlined,
    Icons.storefront_outlined,
    Icons.widgets_outlined,
    Icons.inventory_2_outlined,
    Icons.auto_awesome_outlined,
  ];
  return fallbacks[genreId.hashCode.abs() % fallbacks.length];
}
