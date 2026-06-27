import 'package:flutter/widgets.dart';

Element? elementForKey(Key key) {
  Element? matched;
  void visit(Element element) {
    if (element.widget.key == key) {
      matched = element;
      return;
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return null;
  visit(root);
  return matched;
}

/// [Key] から画面上の [Rect] を取得する（未レイアウト時は `null`）。
Rect? globalRectForKey(Key key) {
  final element = elementForKey(key);
  if (element == null) return null;
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox) return null;
  if (!renderObject.hasSize || !renderObject.attached) return null;
  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}

/// ハイライト対象が画面内に収まるようスクロールする。
Future<void> ensureTargetVisible(
  Key key, {
  Duration duration = const Duration(milliseconds: 280),
  double alignment = 0.25,
}) async {
  final element = elementForKey(key);
  if (element == null) return;
  await Scrollable.ensureVisible(
    element,
    duration: duration,
    curve: Curves.easeOutCubic,
    alignment: alignment,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}
