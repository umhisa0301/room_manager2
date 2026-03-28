import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/rakuten_api_config.dart';
import '../state/rakuten_search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rakuten_search_result_card.dart';

/// 楽天API商品検索画面（最小構成）。
class RakutenSearchScreen extends StatefulWidget {
  const RakutenSearchScreen({super.key});

  @override
  State<RakutenSearchScreen> createState() => _RakutenSearchScreenState();
}

class _RakutenSearchScreenState extends State<RakutenSearchScreen> {
  final TextEditingController _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('楽天商品検索'),
      ),
      body: SafeArea(
        child: Consumer<RakutenSearchProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(context),
                          decoration: const InputDecoration(
                            hintText: 'キーワードを入力',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: provider.status == RakutenSearchStatus.loading
                            ? null
                            : () => _runSearch(context),
                        child: const Text('検索'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildResultArea(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _runSearch(BuildContext context) {
    context.read<RakutenSearchProvider>().search(_keywordController.text);
  }

  Widget _buildResultArea(RakutenSearchProvider provider) {
    switch (provider.status) {
      case RakutenSearchStatus.idle:
        return _centerText('キーワードを入力して検索してください');
      case RakutenSearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RakutenSearchStatus.error:
        return _centerText(
          '検索に失敗しました。\n${provider.errorMessage}',
          isError: true,
        );
      case RakutenSearchStatus.success:
        if (provider.results.isEmpty) {
          return _centerText('検索結果は0件でした');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kDebugMode) _buildAffiliateDebugBanner(provider),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                itemCount: provider.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return RakutenSearchResultCard(item: provider.results[index]);
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildAffiliateDebugBanner(RakutenSearchProvider provider) {
    final req = RakutenApiConfig.requestIncludesAffiliateId;
    final n = provider.resultsWithAffiliateUrlCount;
    final total = provider.results.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        'DEBUG: リクエストにaffiliateId付与=$req / レスポンスaffiliateUrlあり $n/$total 件 '
        '（APIはaffiliateId文字列を返しません。affiliateUrlの有無で判断）',
        style: TextStyle(
          fontSize: 11,
          height: 1.25,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _centerText(String text, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

