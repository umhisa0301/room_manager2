import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_messenger.dart';
import '../models/rakuten_managed_product.dart';
import '../navigation/app_shell_controller.dart';
import '../repository/rakuten_search_repository.dart';
import '../services/app_action_service.dart';
import '../services/rakuten_item_page_url_item_code_service.dart';
import '../state/rakuten_managed_product_provider.dart';
import '../theme/app_theme.dart';
import '../theme/home_screen_colors.dart';
import '../theme/room_colle_list_accent.dart';
import '../widgets/app_button.dart';

enum _UrlSheetMode { ichibaItem, roomProduct }

/// 楽天市場の商品URLから itemCode を解決し、コレ済・候補・未登録を即判定する。
class AddCandidateFromUrlScreen extends StatefulWidget {
  const AddCandidateFromUrlScreen({super.key});

  @override
  State<AddCandidateFromUrlScreen> createState() =>
      _AddCandidateFromUrlScreenState();
}

class _AddCandidateFromUrlScreenState extends State<AddCandidateFromUrlScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentUrlSheet();
    });
  }

  Future<void> _presentUrlSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => const _AddCandidateUrlBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeScreenColors.canvas,
      appBar: AppBar(title: const Text('URLから追加')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_link_rounded,
                size: 48,
                color: AppColors.textTertiary.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 16),
              Text(
                '楽天の商品URLで状態を判定するか、ROOMの商品ページURLからコレ済として取り込めます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'URLを入力',
                onPressed: _presentUrlSheet,
                icon: const Icon(Icons.link_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCandidateUrlBottomSheet extends StatefulWidget {
  const _AddCandidateUrlBottomSheet();

  @override
  State<_AddCandidateUrlBottomSheet> createState() =>
      _AddCandidateUrlBottomSheetState();
}

class _AddCandidateUrlBottomSheetState extends State<_AddCandidateUrlBottomSheet> {
  final _urlController = TextEditingController();
  final _urlFocus = FocusNode();

  _UrlSheetMode _sheetMode = _UrlSheetMode.ichibaItem;
  final _roomUrlController = TextEditingController();
  final _roomUrlFocus = FocusNode();
  bool _roomBusy = false;

  bool _judging = false;
  bool _actionBusy = false;
  String? _parseOrJudgeError;
  String? _actionError;
  RakutenItemPageUrlParseSuccess? _parsed;

  @override
  void dispose() {
    _roomUrlFocus.dispose();
    _roomUrlController.dispose();
    _urlFocus.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _syncFromRoomPage(BuildContext outerContext) async {
    FocusScope.of(context).unfocus();
    setState(() => _roomBusy = true);
    final managed = context.read<RakutenManagedProductProvider>();
    final raw = _roomUrlController.text;
    final result = await managed.registerCollectedFromRoomProductPage(raw);
    if (!mounted) return;
    setState(() => _roomBusy = false);

    if (result.isError) {
      if (!outerContext.mounted) return;
      await showDialog<void>(
        context: outerContext,
        builder: (ctx) => AlertDialog(
          title: const Text('取り込めませんでした'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    final messenger = appRootScaffoldMessengerKey.currentState;
    messenger?.showSnackBar(SnackBar(content: Text(result.message)));

    if (!outerContext.mounted) return;
    await showModalBottomSheet<void>(
      context: outerContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '取り込み結果',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.message,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
                  ),
                  if (result.productId != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      'itemCode: ${result.productId}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                  if (result.rakutenUrl != null &&
                      result.rakutenUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      '楽天URL: ${result.rakutenUrl}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                  if (result.roomUrl != null &&
                      result.roomUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'ROOM URL: ${result.roomUrl}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _judge() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _judging = true;
      _parseOrJudgeError = null;
      _actionError = null;
      _parsed = null;
    });
    await Future<void>.delayed(Duration.zero);
    final raw = _urlController.text;
    final result = RakutenItemPageUrlItemCodeService.tryParseItemRakutenPageUrl(
      raw,
    );
    if (!mounted) return;
    if (result is RakutenItemPageUrlParseFailure) {
      setState(() {
        _judging = false;
        _parseOrJudgeError = result.userMessage;
        _parsed = null;
      });
      return;
    }
    final success = result as RakutenItemPageUrlParseSuccess;
    setState(() {
      _judging = false;
      _parsed = success;
      _parseOrJudgeError = null;
    });
  }

  Future<void> _openRakutenForParsed(
    BuildContext context,
    RakutenItemPageUrlParseSuccess s,
  ) async {
    final managed = context.read<RakutenManagedProductProvider>();
    final found = RakutenItemPageUrlItemCodeService.findManagedProductForParsedUrl(
      items: managed.items,
      parsed: s,
    );
    if (found != null) {
      final err = await managed.openRakutenItemPage(context, found.productId);
      if (!context.mounted) return;
      if (err != null) {
        setState(() => _actionError = err);
      }
    } else {
      final url =
          'https://item.rakuten.co.jp/${s.shopCode}/${s.itemId}/';
      await AppActionService.openUrl(context, url: url);
    }
  }

  Future<String?> _registerFromApi(
    BuildContext context,
    RakutenItemPageUrlParseSuccess parsed,
  ) async {
    final repo = context.read<RakutenSearchRepository>();
    final managed = context.read<RakutenManagedProductProvider>();
    final outcome = await repo.resolveProductForUrlSearch(
      inputUrl: _urlController.text,
      shopCode: parsed.shopCode,
      pureItemCode: parsed.itemId,
      isApiStyleItemCode: parsed.isApiStyleItemCode,
      normalizedUrl: parsed.normalizedUrl,
    );
    if (outcome.item == null) {
      return outcome.userMessage ??
          '商品情報を取得できませんでした。itemCode を確認するか、しばらくしてからお試しください。';
    }
    return managed.registerCandidate(outcome.item!);
  }

  void _closeSheetAndPopScreenAndOpenRoomCollect({
    required int initialTabIndex,
    String? focusCandidateProductId,
  }) {
    final shell = context.read<AppShellController>();
    final nav = Navigator.of(context);
    nav.pop();
    if (nav.canPop()) {
      nav.pop();
    }
    shell.openRoomCollect(
      initialTabIndex: initialTabIndex,
      focusCandidateProductId: focusCandidateProductId,
    );
  }

  Widget _stateChip(BuildContext context, RakutenUrlRegistryClassification k) {
    late final String label;
    late final Color fg;
    late final Color bg;
    switch (k) {
      case RakutenUrlRegistryClassification.collectedDone:
        label = 'コレ済み';
        fg = RoomColleListAccent.done;
        bg = RoomColleListAccent.done.withValues(alpha: 0.14);
        break;
      case RakutenUrlRegistryClassification.candidate:
        label = 'コレ候補';
        fg = RoomColleListAccent.candidate;
        bg = RoomColleListAccent.candidate.withValues(alpha: 0.12);
        break;
      case RakutenUrlRegistryClassification.unregistered:
        label = '未登録';
        fg = AppColors.textSecondary;
        bg = AppColors.textTertiary.withValues(alpha: 0.12);
        break;
    }
    return Chip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.28)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _resultCard(
    BuildContext context, {
    required RakutenItemPageUrlParseSuccess parsed,
    required RakutenUrlRegistryClassification klass,
  }) {
    RakutenManagedProduct? product;
    final managed = context.read<RakutenManagedProductProvider>();
    product = RakutenItemPageUrlItemCodeService.findManagedProductForParsedUrl(
      items: managed.items,
      parsed: parsed,
    );
    final title = product?.itemName.trim().isNotEmpty == true
        ? product!.itemName.trim()
        : parsed.itemCode;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _stateChip(context, klass),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              parsed.itemCode,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Consumer<RakutenManagedProductProvider>(
        builder: (context, managed, _) {
          final klass = _parsed == null
              ? null
              : RakutenItemPageUrlItemCodeService.classifyAgainstManagedProducts(
                  items: managed.items,
                  itemCode: _parsed!.itemCode,
                );
          final matchedProduct = _parsed == null
              ? null
              : RakutenItemPageUrlItemCodeService.findManagedProductForParsedUrl(
                  items: managed.items,
                  parsed: _parsed!,
                );
          final actionProductId =
              matchedProduct?.productId.trim() ?? _parsed?.itemCode ?? '';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'URLから追加',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_UrlSheetMode>(
                    segments: const [
                      ButtonSegment(
                        value: _UrlSheetMode.ichibaItem,
                        label: Text('楽天商品URL'),
                      ),
                      ButtonSegment(
                        value: _UrlSheetMode.roomProduct,
                        label: Text('ROOM商品URL'),
                      ),
                    ],
                    selected: {_sheetMode},
                    onSelectionChanged: (next) {
                      setState(() {
                        _sheetMode = next.first;
                        _parseOrJudgeError = null;
                        _actionError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_sheetMode == _UrlSheetMode.ichibaItem) ...[
                  Text(
                    '楽天商品ページ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'item.rakuten.co.jp の商品ページ、affiliateUrl、または slug URL を対象にしています。'
                    '楽天BOOKS・ファッション等は対象外です。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlController,
                    focusNode: _urlFocus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: '楽天市場の商品URL',
                      hintText: 'https://item.rakuten.co.jp/…',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onSubmitted: (_) {
                      if (!_judging && !_actionBusy) _judge();
                    },
                  ),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: '判定する',
                    isLoading: _judging,
                    onPressed: (_judging || _actionBusy) ? null : _judge,
                    icon: const Icon(Icons.fact_check_rounded),
                  ),
                  if (_parseOrJudgeError != null) ...[
                    const SizedBox(height: 14),
                    _InlineMessagePanel(
                      icon: Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      text: _parseOrJudgeError!,
                    ),
                  ],
                  if (_actionError != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessagePanel(
                      icon: Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                      text: _actionError!,
                    ),
                  ],
                  if (!_judging && _parsed != null && klass != null) ...[
                    const SizedBox(height: 16),
                    _resultCard(
                      context,
                      parsed: _parsed!,
                      klass: klass,
                    ),
                    const SizedBox(height: 14),
                    _ActionButtonsForClassification(
                      klass: klass,
                      parsed: _parsed!,
                      actionBusy: _actionBusy,
                      onSetActionBusy: (v) => setState(() => _actionBusy = v),
                      onClearActionError: () => setState(() => _actionError = null),
                      onActionError: (msg) => setState(() => _actionError = msg),
                      onOpenRakuten: () => _openRakutenForParsed(context, _parsed!),
                      onRegisterFromApi: () => _registerFromApi(context, _parsed!),
                      onCollectToDone: () async {
                        final managed = context.read<RakutenManagedProductProvider>();
                        return managed.collectRoomAndLaunch(
                          context,
                          actionProductId,
                          notifyInsteadOfDialogs: (msg) {
                            if (context.mounted) {
                              setState(() => _actionError = msg);
                            }
                          },
                        );
                      },
                      onCloseSheetOnly: () => Navigator.of(context).pop(),
                      onGoDoneList: () =>
                          _closeSheetAndPopScreenAndOpenRoomCollect(
                            initialTabIndex: 1,
                          ),
                      onGoCandidateList: () =>
                          _closeSheetAndPopScreenAndOpenRoomCollect(
                            initialTabIndex: 0,
                            focusCandidateProductId: actionProductId,
                          ),
                      afterRegistration: () {
                        if (context.mounted) {
                          setState(() => _actionError = null);
                        }
                      },
                    ),
                  ],
                  ] else ...[
                    Text(
                      'ROOM 商品ページ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'room.rakuten.co.jp の投稿済み商品ページを貼り付けると、'
                      '楽天商品URLを検出してコレ済として登録します（HTTP で HTML を取得します）。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _roomUrlController,
                      focusNode: _roomUrlFocus,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'ROOM の商品ページURL',
                        hintText: 'https://room.rakuten.co.jp/…',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onSubmitted: (_) {
                        if (!_roomBusy) {
                          _syncFromRoomPage(context);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    AppPrimaryButton(
                      label: 'ROOM投稿を取り込む',
                      isLoading: _roomBusy,
                      onPressed: _roomBusy
                          ? null
                          : () => _syncFromRoomPage(context),
                      icon: const Icon(Icons.download_done_rounded),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InlineMessagePanel extends StatelessWidget {
  const _InlineMessagePanel({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonsForClassification extends StatelessWidget {
  const _ActionButtonsForClassification({
    required this.klass,
    required this.parsed,
    required this.actionBusy,
    required this.onSetActionBusy,
    required this.onClearActionError,
    required this.onActionError,
    required this.onOpenRakuten,
    required this.onRegisterFromApi,
    required this.onCollectToDone,
    required this.onCloseSheetOnly,
    required this.onGoDoneList,
    required this.onGoCandidateList,
    required this.afterRegistration,
  });

  final RakutenUrlRegistryClassification klass;
  final RakutenItemPageUrlParseSuccess parsed;
  final bool actionBusy;
  final void Function(bool) onSetActionBusy;
  final VoidCallback onClearActionError;
  final void Function(String) onActionError;
  final Future<void> Function() onOpenRakuten;
  final Future<String?> Function() onRegisterFromApi;
  final Future<bool> Function() onCollectToDone;
  final VoidCallback onCloseSheetOnly;
  final VoidCallback onGoDoneList;
  final VoidCallback onGoCandidateList;
  final VoidCallback afterRegistration;

  @override
  Widget build(BuildContext context) {
    Future<void> guard(Future<void> Function() fn) async {
      onClearActionError();
      onSetActionBusy(true);
      try {
        await fn();
      } finally {
        onSetActionBusy(false);
      }
    }

    Widget gap() => const SizedBox(height: 10);

    switch (klass) {
      case RakutenUrlRegistryClassification.collectedDone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrimaryButton(
              label: 'コレ済一覧で見る',
              isLoading: actionBusy,
              onPressed: actionBusy ? null : () => guard(() async => onGoDoneList()),
              icon: const Icon(Icons.collections_bookmark_rounded),
            ),
            gap(),
            AppSecondaryButton(
              label: '楽天で見る',
              expand: true,
              onPressed: actionBusy ? null : () => guard(onOpenRakuten),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            gap(),
            AppSecondaryButton(
              label: '閉じる',
              expand: true,
              onPressed: actionBusy ? null : onCloseSheetOnly,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        );
      case RakutenUrlRegistryClassification.candidate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrimaryButton(
              label: '候補を見る',
              isLoading: actionBusy,
              onPressed: actionBusy
                  ? null
                  : () => guard(() async => onGoCandidateList()),
              icon: const Icon(Icons.visibility_rounded),
            ),
            gap(),
            AppPrimaryButton(
              label: 'コレ済みに変更',
              isLoading: actionBusy,
              onPressed: actionBusy
                  ? null
                  : () => guard(() async {
                      final shell = context.read<AppShellController>();
                      final nav = Navigator.of(context);
                      final ok = await onCollectToDone();
                      if (ok) {
                        nav.pop();
                        if (nav.canPop()) {
                          nav.pop();
                        }
                        shell.openRoomCollect(initialTabIndex: 1);
                      }
                    }),
              icon: const Icon(Icons.task_alt_rounded),
            ),
            gap(),
            AppSecondaryButton(
              label: '楽天で見る',
              expand: true,
              onPressed: actionBusy ? null : () => guard(onOpenRakuten),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        );
      case RakutenUrlRegistryClassification.unregistered:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrimaryButton(
              label: 'コレ候補に追加',
              isLoading: actionBusy,
              onPressed: actionBusy
                  ? null
                  : () => guard(() async {
                      final err = await onRegisterFromApi();
                      if (!context.mounted) return;
                      if (err != null) {
                        onActionError(err);
                      } else {
                        afterRegistration();
                        onGoCandidateList();
                      }
                    }),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
            gap(),
            AppPrimaryButton(
              label: 'コレ済みにする',
              isLoading: actionBusy,
              onPressed: actionBusy
                  ? null
                  : () => guard(() async {
                      final shell = context.read<AppShellController>();
                      final nav = Navigator.of(context);
                      var err = await onRegisterFromApi();
                      if (!context.mounted) return;
                      if (err != null) {
                        onActionError(err);
                        return;
                      }
                      final managed = context.read<RakutenManagedProductProvider>();
                      final registered =
                          RakutenItemPageUrlItemCodeService.findManagedProductForParsedUrl(
                            items: managed.items,
                            parsed: parsed,
                          );
                      final collectId =
                          registered?.productId.trim() ?? parsed.itemCode;
                      final ok = await managed.collectRoomAndLaunch(
                        context,
                        collectId,
                        notifyInsteadOfDialogs: onActionError,
                      );
                      if (!context.mounted) return;
                      if (ok) {
                        nav.pop();
                        if (nav.canPop()) {
                          nav.pop();
                        }
                        shell.openRoomCollect(initialTabIndex: 1);
                      }
                    }),
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
            gap(),
            AppSecondaryButton(
              label: '楽天で見る',
              expand: true,
              onPressed: actionBusy ? null : () => guard(onOpenRakuten),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        );
    }
  }
}
