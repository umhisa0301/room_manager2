import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rakuten_product_search_condition.dart';
import '../models/rakuten_search_item.dart';
import '../repository/rakuten_search_repository.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/rakuten_search_screen_tokens.dart';
import '../utils/rakuten_ichiba_url_parse.dart';
import '../widgets/app_button.dart';
import '../widgets/rakuten_search_result_card.dart';
import '../widgets/search_group_screen_shell.dart';

/// 楽天市場の商品・ショップURLから [shopCode] / [itemCode] を推定しAPI検索して候補追加する。
class AddCandidateFromUrlScreen extends StatefulWidget {
  const AddCandidateFromUrlScreen({super.key});

  @override
  State<AddCandidateFromUrlScreen> createState() =>
      _AddCandidateFromUrlScreenState();
}

class _AddCandidateFromUrlScreenState extends State<AddCandidateFromUrlScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<RakutenSearchItem> _items = const [];
  RakutenIchibaUrlHints? _lastHints;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final urlText = _controller.text.trim();
    if (urlText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL を入力してください')),
      );
      return;
    }
    final hints = parseRakutenIchibaUrlHints(urlText);
    if (hints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('shopCode / itemCode を URL から読み取れませんでした'),
        ),
      );
      return;
    }

    RakutenProductSearchCondition condition;
    if (hints.itemCode != null && hints.itemCode!.isNotEmpty) {
      condition = RakutenProductSearchCondition(
        keyword: '',
        itemCode: hints.itemCode,
        shopCode: hints.shopCode,
      );
    } else if (hints.shopCode != null && hints.shopCode!.isNotEmpty) {
      condition = RakutenProductSearchCondition(
        keyword: '',
        shopCode: hints.shopCode,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('検索条件を組み立てられませんでした')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _lastHints = hints;
    });

    try {
      final repo = context.read<RakutenSearchRepository>();
      final items = await repo.search(condition: condition);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(title: const Text('URLから追加')),
      body: SearchGroupScreenShell(
        backgroundColor: HomeScreenColors.canvas,
        subtitle:
            '探すグループ · 楽天市場の商品・ショップURLを貼り付け、抽出した shopCode / itemCode で検索します。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '楽天市場のURL',
                hintText: 'https://item.rakuten.co.jp/...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
            SizedBox(height: RakutenSearchScreenUi.gapFieldStack),
            AppPrimaryButton(
              label: '解析して検索',
              isLoading: _loading,
              onPressed: () {
                _runSearch();
              },
              icon: const Icon(Icons.search_rounded),
            ),
            if (_lastHints != null) ...[
              SizedBox(height: RakutenSearchScreenUi.gapSection),
              Text(
                '抽出: shopCode=${_lastHints!.shopCode ?? '—'} / '
                'itemCode=${_lastHints!.itemCode ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: RakutenSearchScreenUi.gapSection),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: RakutenSearchScreenUi.gapListAfterDivider),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer<RakutenManagedProductProvider>(
                      builder: (context, managed, _) {
                        if (_items.isEmpty) {
                          return Center(
                            child: Text(
                              'ここに検索結果が表示されます',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            RakutenSearchScreenUi.listScrollTopPad,
                            0,
                            AppDimensions.spacingLg,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppDimensions.spacingSm),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return RakutenSearchResultCard(
                              item: item,
                              localStatus: managed.statusForProduct(
                                item.productId,
                              ),
                              isRegistering: managed.isRegistering(
                                item.productId,
                              ),
                              onRegisterCandidate: () async {
                                final err = await managed.registerCandidate(
                                  item,
                                );
                                if (!context.mounted) return;
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
