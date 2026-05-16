import 'package:flutter/material.dart';

import '../services/genre_master_service.dart';
import '../theme/app_theme.dart';
import '../utils/genre_tree_builder.dart';

/// 親ジャンル → 子ジャンルへ掘れるジャンル選択シート。
class GenreDrilldownPickerSheet extends StatefulWidget {
  const GenreDrilldownPickerSheet({
    super.key,
    this.initialGenreId,
    this.source = 'search',
  });

  final String? initialGenreId;
  final String source;

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

  @override
  State<GenreDrilldownPickerSheet> createState() =>
      _GenreDrilldownPickerSheetState();
}

class _GenreDrilldownPickerSheetState extends State<GenreDrilldownPickerSheet> {
  final List<String> _stack = [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    GenreMasterService.instance.load();
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

  List<GenreTreeNode> get _currentNodes {
    if (_stack.isEmpty) return GenreTreeBuilder.rootNodes();
    return GenreTreeBuilder.childrenOf(_stack.last);
  }

  String get _breadcrumb {
    if (_stack.isEmpty && (_selectedId == null || _selectedId!.isEmpty)) {
      return 'ジャンルを選ぶ';
    }
    final parts = <String>[];
    for (final id in _stack) {
      final n = GenreTreeBuilder.nodeForId(id)?.genreName;
      if (n != null && n.isNotEmpty) parts.add(n);
    }
    final sel = _selectedId?.trim() ?? '';
    if (sel.isNotEmpty) {
      final sn = GenreTreeBuilder.nodeForId(sel)?.genreName ?? sel;
      if (!parts.contains(sn)) parts.add(sn);
    }
    return parts.join(' ＞ ');
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
      _selectedId = genreId;
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final nodes = _currentNodes;
    final canSearchWithSelection =
        _selectedId != null && _selectedId!.trim().isNotEmpty;

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
                        tooltip: 'ひとつ上に戻る',
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'ジャンルを選ぶ',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '選択中：$_breadcrumb',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
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
                          final selected = _selectedId == node.genreId;
                          return ListTile(
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
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
                                ? const Icon(Icons.chevron_right_rounded)
                                : null,
                            onTap: () {
                              _selectGenre(node.genreId);
                              if (node.hasChildren) {
                                _enterChild(node.genreId);
                              }
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: canSearchWithSelection
                      ? () => Navigator.pop(context, _selectedId!.trim())
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textOnAccent,
                  ),
                  child: const Text('このジャンルで検索'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
