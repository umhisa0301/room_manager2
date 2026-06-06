import 'package:flutter/foundation.dart';

import '../services/genre_master_service.dart';
import 'genre_display_order.dart';

/// ジャンルマスタから親子ツリーを辿るためのノード。
class GenreTreeNode {
  const GenreTreeNode({
    required this.genreId,
    required this.genreName,
    required this.hasChildren,
  });

  final String genreId;
  final String genreName;
  final bool hasChildren;
}

/// 同梱 JSON の parentGenreId / childGenreIds から階層ナビゲーションを構築。
abstract final class GenreTreeBuilder {
  static List<GenreTreeNode> rootNodes() {
    final svc = GenreMasterService.instance;
    if (!svc.isLoaded) return const [];
    final nodes = svc.rootGenreIds
        .map((id) => nodeForId(id))
        .whereType<GenreTreeNode>()
        .toList();
    nodes.sort(
      (a, b) => GenreDisplayOrder.compareGenreIds(
        a.genreId,
        b.genreId,
        nameA: a.genreName,
        nameB: b.genreName,
      ),
    );
    return List<GenreTreeNode>.unmodifiable(nodes);
  }

  static GenreTreeNode? nodeForId(String genreId) {
    final svc = GenreMasterService.instance;
    final id = genreId.trim();
    if (id.isEmpty || !svc.isLoaded) return null;
    final name = svc.getGenreNameById(id);
    if (name == null || name.isEmpty) return null;
    final children = childIds(id);
    return GenreTreeNode(
      genreId: id,
      genreName: name,
      hasChildren: children.isNotEmpty,
    );
  }

  static List<String> childIds(String parentGenreId) {
    final svc = GenreMasterService.instance;
    final m = svc.getGenreById(parentGenreId);
    if (m == null) return const [];
    final raw = m['childGenreIds'];
    if (raw is! List) return const [];
    final out = <String>[];
    for (final e in raw) {
      final id = e.toString().trim();
      if (id.isNotEmpty) out.add(id);
    }
    out.sort((a, b) {
      final na = svc.getGenreNameById(a) ?? a;
      final nb = svc.getGenreNameById(b) ?? b;
      return na.compareTo(nb);
    });
    return out;
  }

  static List<GenreTreeNode> childrenOf(String parentGenreId) {
    return childIds(parentGenreId)
        .map((id) => nodeForId(id))
        .whereType<GenreTreeNode>()
        .toList(growable: false);
  }

  static List<String> pathNamesFor(String genreId) {
    final svc = GenreMasterService.instance;
    final fromJson = svc.getPathNames(genreId);
    if (fromJson.isNotEmpty) return fromJson;
    final names = <String>[];
    var cursor = genreId.trim();
    final seen = <String>{};
    while (cursor.isNotEmpty && seen.add(cursor)) {
      final n = svc.getGenreNameById(cursor);
      if (n != null && n.isNotEmpty) names.insert(0, n);
      final p = svc.getParentGenreId(cursor);
      if (p == null || p.isEmpty) break;
      cursor = p;
    }
    return names;
  }

  static void logOpen({required String source, required int rootCount}) {
    if (!kDebugMode) return;
    debugPrint('[GENRE_TREE_OPEN] rootCount=$rootCount source=$source');
  }

  static void logNavigate({
    required String fromGenreId,
    required String toGenreId,
    required int depth,
    required int childrenCount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_TREE_NAVIGATE] fromGenreId=$fromGenreId toGenreId=$toGenreId '
      'depth=$depth childrenCount=$childrenCount',
    );
  }

  static void logSelect({
    required String genreId,
    required String genreName,
    required int depth,
    required bool hasChildren,
    String screen = 'searchCondition',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GENRE_TREE_SELECT] screen=$screen genreId=$genreId genreName=$genreName '
      'depth=$depth hasChildren=$hasChildren',
    );
  }
}
