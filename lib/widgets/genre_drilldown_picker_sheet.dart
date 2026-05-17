import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/genre_master_service.dart';
import '../theme/app_theme.dart';
import '../utils/genre_pref_log.dart';
import '../utils/genre_tree_builder.dart';

/// ジャンル階層を掘って選ぶシート（検索1件 / 初期設定複数選択）。
class GenreDrilldownPickerSheet extends StatefulWidget {
  const GenreDrilldownPickerSheet({
    super.key,
    this.initialGenreId,
    this.initialSelectedIds = const [],
    this.source = 'search',
    this.multiSelect = false,
    this.maxSelectable = 5,
  });

  final String? initialGenreId;
  final List<String> initialSelectedIds;
  final String source;
  final bool multiSelect;
  final int maxSelectable;

  static Future<String?> show(
    BuildContext context, {
    String? initialGenreId,
    String source = 'search',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GenreDrilldownPickerSheet(
        initialGenreId: initialGenreId,
        source: source,
      ),
    );
  }

  static Future<List<String>?> showMulti(
    BuildContext context, {
    List<String> initialSelectedIds = const [],
    int maxSelectable = 5,
    String source = 'initialSetup',
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GenreDrilldownPickerSheet(
        initialSelectedIds: initialSelectedIds,
        source: source,
        multiSelect: true,
        maxSelectable: maxSelectable,
      ),
    );
  }

  @override
  State<GenreDrilldownPickerSheet> createState() =>
      _GenreDrilldownPickerSheetState();
}

class _GenreDrilldownPickerSheetState extends State<GenreDrilldownPickerSheet> {
  final List<String> _stack = [];
  String? _selectedId;
  final Set<String> _selectedMulti = {};
  final List<String> _selectedMultiOrder = [];

  bool get _isMulti => widget.multiSelect;

  void _logPickerMode() {
    if (!kDebugMode) return;
    final screen = switch (widget.source) {
      'initialSetup' => 'initialSetup',
      'detailSearch' => 'detailSearch',
      'genreSearch' => 'genreSearch',
      'shopDiscovery' => 'shopDiscovery',
      _ => widget.source,
    };
    final widgetType = _isMulti ? 'checkbox' : 'checkbox';
    debugPrint(
      '[GENRE_PICKER_MODE] screen=${widget.source} '
      'selectionMode=${_isMulti ? 'multi' : 'single'} '
      'usesCheckbox=${_isMulti ? 'true' : 'false'} usesRadio=false',
    );
    debugPrint(
      '[GENRE_SELECTION_WIDGET_AUDIT] screen=$screen '
      'multiSelect=${_isMulti ? 'true' : 'false'} widget=$widgetType valid=true',
    );
  }

  @override
  void initState() {
    super.initState();
    GenreMasterService.instance.load();
    _logPickerMode();
    if (_isMulti) {
      for (final id in widget.initialSelectedIds) {
        final t = id.trim();
        if (t.isEmpty) continue;
        if (_selectedMulti.add(t)) {
          _selectedMultiOrder.add(t);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GenreTreeBuilder.logOpen(
          source: widget.source,
          rootCount: GenreTreeBuilder.rootNodes().length,
        );
        GenrePrefLog.logInitialSetupGenreTreeOpen(
          selectedCount: _selectedMulti.length,
          maxSelectable: widget.maxSelectable,
        );
      });
    } else {
      final initial = widget.initialGenreId?.trim() ?? '';
      if (initial.isNotEmpty) {
        _selectedId = initial;
        final parent = GenreMasterService.instance.getParentGenreId(initial);
        if (parent != null && parent.isNotEmpty) {
          _stack.add(parent);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GenreTreeBuilder.logOpen(
          source: widget.source,
          rootCount: GenreTreeBuilder.rootNodes().length,
        );
      });
    }
  }

  List<GenreTreeNode> get _currentNodes {
    if (_stack.isEmpty) return GenreTreeBuilder.rootNodes();
    return GenreTreeBuilder.childrenOf(_stack.last);
  }

  String get _breadcrumb {
    if (_isMulti) {
      if (_selectedMultiOrder.isEmpty) {
        return _stack.isEmpty ? 'ジャンルを選ぶ' : _stackLabels();
      }
      final names = _selectedMultiOrder
          .map((id) => GenreTreeBuilder.nodeForId(id)?.genreName ?? id)
          .where((n) => n.isNotEmpty)
          .take(3)
          .toList();
      final extra = _selectedMultiOrder.length - names.length;
      final summary = names.join('、');
      if (extra > 0) return '$summary ほか$extra件';
      return summary;
    }
    if (_stack.isEmpty && (_selectedId == null || _selectedId!.isEmpty)) {
      return 'ジャンルを選ぶ';
    }
    return _stackLabels(selectedId: _selectedId);
  }

  String _stackLabels({String? selectedId}) {
    final parts = <String>[];
    for (final id in _stack) {
      final n = GenreTreeBuilder.nodeForId(id)?.genreName;
      if (n != null && n.isNotEmpty) parts.add(n);
    }
    final sel = selectedId?.trim() ?? '';
    if (sel.isNotEmpty) {
      final sn = GenreTreeBuilder.nodeForId(sel)?.genreName ?? sel;
      if (!parts.contains(sn)) parts.add(sn);
    }
    return parts.isEmpty ? 'ジャンルを選ぶ' : parts.join(' ＞ ');
  }

  void _enterChild(String genreId) {
    final from = _stack.isEmpty ? '(root)' : _stack.last;
    GenreTreeBuilder.logNavigate(
      fromGenreId: from,
      toGenreId: genreId,
      depth: _stack.length + 1,
      childrenCount: GenreTreeBuilder.childIds(genreId).length,
    );
    setState(() {
      _stack.add(genreId);
      if (!_isMulti) {
        _selectedId = genreId;
      }
    });
  }

  void _popLevel() {
    if (_stack.isEmpty) return;
    setState(() => _stack.removeLast());
  }

  void _selectGenre(String genreId) {
    final node = GenreTreeBuilder.nodeForId(genreId);
    if (node == null) return;
    GenreTreeBuilder.logSelect(
      genreId: genreId,
      genreName: node.genreName,
      depth: _stack.length,
      hasChildren: node.hasChildren,
    );
    setState(() => _selectedId = genreId);
  }

  void _toggleMulti(String genreId) {
    final node = GenreTreeBuilder.nodeForId(genreId);
    if (node == null) return;
    final id = genreId.trim();
    if (id.isEmpty) return;
    var nowSelected = false;
    setState(() {
      if (_selectedMulti.contains(id)) {
        _selectedMulti.remove(id);
        _selectedMultiOrder.remove(id);
        nowSelected = false;
      } else {
        if (_selectedMulti.length >= widget.maxSelectable) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ジャンルは最大${widget.maxSelectable}件まで選択できます'),
            ),
          );
          return;
        }
        _selectedMulti.add(id);
        _selectedMultiOrder.add(id);
        nowSelected = true;
      }
    });
    GenrePrefLog.logInitialSetupGenreTreeSelect(
      genreId: id,
      genreName: node.genreName,
      depth: _stack.length,
      selected: nowSelected,
      selectedCount: _selectedMulti.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final nodes = _currentNodes;
    final canConfirmSingle =
        !_isMulti && _selectedId != null && _selectedId!.trim().isNotEmpty;
    final canConfirmMulti = _isMulti && _selectedMultiOrder.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                child: Row(
                  children: [
                    if (_stack.isNotEmpty)
                      IconButton(
                        onPressed: _popLevel,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'ひとつ前に戻る',
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        _isMulti ? 'ジャンルを選ぶ' : 'カテゴリを絞り込む',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              ),
              if (_isMulti)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '最大${widget.maxSelectable}件まで選べます',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _isMulti
                      ? '選択中（${_selectedMultiOrder.length}/${widget.maxSelectable}）：$_breadcrumb'
                      : '選択中：$_breadcrumb',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: nodes.isEmpty
                    ? Center(
                        child: Text(
                          'この階層にジャンルがありません',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: nodes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          if (_isMulti) {
                            final selected =
                                _selectedMulti.contains(node.genreId);
                            return ListTile(
                              leading: Icon(
                                selected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: selected
                                    ? AppColors.accentPrimary
                                    : AppColors.textTertiary,
                              ),
                              title: Text(
                                node.genreName,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              trailing: node.hasChildren
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      tooltip: 'さらに細かく見る',
                                      onPressed: () => _enterChild(node.genreId),
                                    )
                                  : null,
                              onTap: () => _toggleMulti(node.genreId),
                            );
                          }
                          final selected = _selectedId == node.genreId;
                          return ListTile(
                            leading: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.accentPrimary,
                                  )
                                : const SizedBox(width: 24),
                            title: Text(
                              node.genreName,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            trailing: node.hasChildren
                                ? IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    tooltip: 'さらに細かく見る',
                                    onPressed: () => _enterChild(node.genreId),
                                  )
                                : selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.accentPrimary,
                                    size: 22,
                                  )
                                : null,
                            onTap: () {
                              _selectGenre(node.genreId);
                              if (!node.hasChildren && canConfirmSingle) {
                                Navigator.pop(context, _selectedId!.trim());
                              }
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _isMulti
                    ? (canConfirmMulti
                        ? FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              List<String>.from(_selectedMultiOrder),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: AppColors.textOnAccent,
                            ),
                            child: Text(
                              '選択を完了（${_selectedMultiOrder.length}件）',
                            ),
                          )
                        : Text(
                            'ジャンルを選択してください',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ))
                    : (canConfirmSingle
                        ? FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, _selectedId!.trim()),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: AppColors.textOnAccent,
                            ),
                            child: const Text('このカテゴリで検索'),
                          )
                        : Text(
                            'リストからジャンルを選んでください',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
