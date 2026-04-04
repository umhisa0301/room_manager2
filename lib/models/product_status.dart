/// 商品のステータス。タブ（候補・コレ済・アーカイブ）と対応。
enum ProductStatus { candidate, collected, archived }

extension ProductStatusExtension on ProductStatus {
  /// 一覧・タブ表示用ラベル
  String get label {
    switch (this) {
      case ProductStatus.candidate:
        return '候補';
      case ProductStatus.collected:
        return 'コレ済';
      case ProductStatus.archived:
        return 'アーカイブ';
    }
  }

  /// JSON 保存用の文字列（enum 名と一致）
  String get value => name;

  /// JSON から復元。不正値は candidate にフォールバック。
  static ProductStatus fromString(String? v) {
    if (v == null) return ProductStatus.candidate;
    return ProductStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ProductStatus.candidate,
    );
  }
}
