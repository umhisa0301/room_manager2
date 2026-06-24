import 'package:flutter/widgets.dart';

/// [Key] から画面上の [Rect] を取得する（未レイアウト時は `null`）。
Rect? globalRectForKey(Key key) {
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

  final element = matched;
  if (element == null) return null;
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox) return null;
  if (!renderObject.hasSize || !renderObject.attached) return null;
  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}
