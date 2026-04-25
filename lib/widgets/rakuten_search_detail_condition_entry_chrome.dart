import 'package:flutter/material.dart';

import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';

/// 詳細条件シートを開く導線。値は [controller] に同期し、編集はシート内の
/// [RakutenSearchScreenUi.searchField] 装飾の TextField と同じトークンで表す。
class RakutenSearchPseudoSearchFieldEntry extends StatelessWidget {
  const RakutenSearchPseudoSearchFieldEntry({
    super.key,
    required this.controller,
    required this.onTap,
    required this.labelText,
    this.hintText,
    required this.prefixIcon,
  });

  final TextEditingController controller;
  final VoidCallback onTap;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final empty = text.trim().isEmpty;
        return Semantics(
          button: true,
          label: '$labelText、詳細条件',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(
                RakutenSearchScreenUi.searchFieldBorderRadius,
              ),
              onTap: onTap,
              child: InputDecorator(
                isEmpty: empty,
                decoration: RakutenSearchScreenUi.searchField(
                  labelText: null,
                  hintText: hintText,
                  prefixIcon: Icon(
                    prefixIcon,
                    color: HomeScreenColors.leadOnSection,
                  ),
                ),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RakutenSearchScreenUi.searchFieldValueStyle(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [RakutenSearchGenreDropdownField] と同系の見た目で、タップで詳細条件シートへ進む。
class RakutenSearchPseudoGenreDropdownEntry extends StatelessWidget {
  const RakutenSearchPseudoGenreDropdownEntry({
    super.key,
    required this.displayText,
    required this.onTap,
    required this.labelText,
  });

  final String displayText;
  final VoidCallback onTap;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$labelText、詳細条件',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            RakutenSearchScreenUi.searchFieldBorderRadius,
          ),
          onTap: onTap,
          child: InputDecorator(
            decoration: RakutenSearchScreenUi.searchField(
              labelText: labelText,
              prefixIcon: Icon(
                Icons.category_outlined,
                color: HomeScreenColors.leadOnSection,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RakutenSearchScreenUi.searchFieldValueStyle(context),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: HomeScreenColors.leadOnSection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
