import '../models/post_style_settings.dart';
import '../utils/product_price_display.dart';
import 'post_comment_generation_service.dart';

/// スタブ用の投稿文組み立て（将来のAPI実装とは別経路）。
abstract final class StubPostCommentBuilder {
  StubPostCommentBuilder._();

  static String build({
    required PostCommentGenerationInput input,
    required PostStyleSettings style,
  }) {
    final limits = style.generationLimits;
    final name = input.itemName.trim().isNotEmpty
        ? input.itemName.trim()
        : 'この商品';
    final reason = input.recommendationReason.trim().isNotEmpty
        ? input.recommendationReason.trim()
        : '気になったので、ROOMで共有したい一品です';
    final price = ProductPriceDisplay.formatYen(input.itemPrice);
    final rating = input.reviewAverage.toStringAsFixed(1);
    final count = input.reviewCount;

    final body = _composeBody(
      style: style,
      name: name,
      reason: reason,
      price: price,
      rating: rating,
      reviewCount: count,
      genreName: input.genreName,
    );

    var adjusted = _applyToneMarkers(body, style.tone);
    adjusted = _applyEmoji(adjusted, style);
    adjusted = _fitBodyLength(adjusted, limits);

    final hashtags = _buildHashtags(
      style,
      name,
      titleKeywords: input.titleKeywords,
      genreName: input.genreName,
    );
    if (hashtags.isEmpty) return adjusted;

    final combined = '$adjusted\n\n$hashtags';
    if (combined.length <= limits.maxTotalChars) return combined;

    final allowedBody = limits.maxTotalChars - hashtags.length - 2;
    if (allowedBody < limits.minBodyChars) return adjusted;
    return '${_truncate(adjusted, allowedBody)}\n\n$hashtags';
  }

  static String _composeBody({
    required PostStyleSettings style,
    required String name,
    required String reason,
    required String price,
    required String rating,
    required int reviewCount,
    required String genreName,
  }) {
    final intro = _introSentence(style, name);
    final core = _reasonParagraph(style, reason);
    final detail = _optionalDetail(
      style,
      price: price,
      rating: rating,
      reviewCount: reviewCount,
      genreName: genreName,
    );
    final closing = _closing(style);

    return [
      intro,
      core,
      if (detail.isNotEmpty) detail,
      closing,
    ].join('\n');
  }

  static String _introSentence(PostStyleSettings style, String name) {
    return switch (style.tone) {
      PostTone.polite => '【$name】をご紹介します。',
      PostTone.friendlyPolite => '【$name】、気になって見つけました。',
      PostTone.casual => '【$name】、これ気になってる。',
    };
  }

  static String _reasonParagraph(PostStyleSettings style, String reason) {
    final normalized = reason.endsWith('。') ||
            reason.endsWith('！') ||
            reason.endsWith('!')
        ? reason
        : '$reason。';

    return switch (style.tone) {
      PostTone.polite =>
        normalized.endsWith('。') ? normalized : '$normalized。',
      PostTone.friendlyPolite => _softenReason(normalized),
      PostTone.casual => _casualizeReason(normalized),
    };
  }

  static String _softenReason(String reason) {
    return reason
        .replaceFirst('。', 'なんです。')
        .replaceFirst('！', 'なんです！');
  }

  static String _casualizeReason(String reason) {
    return reason
        .replaceAll('です。', 'なんだよね。')
        .replaceAll('ます。', 'るよ。')
        .replaceAll('。', '！');
  }

  static String _optionalDetail(
    PostStyleSettings style, {
    required String price,
    required String rating,
    required int reviewCount,
    required String genreName,
  }) {
    if (style.focusPoints.isEmpty) return '';

    final point = style.focusPoints.first;
    return switch (point) {
      PostFocusPoint.costPerformance =>
        switch (style.tone) {
          PostTone.polite => '価格は$priceで、コスパも気になるポイントです。',
          PostTone.friendlyPolite => '価格$priceなので、コスパも見てみたくなります。',
          PostTone.casual => '値段$priceで、コスパもいい感じ。',
        },
      PostFocusPoint.reviews when reviewCount > 0 =>
        switch (style.tone) {
          PostTone.polite => 'レビュー平均$rating（${reviewCount}件）も参考になりそうです。',
          PostTone.friendlyPolite =>
            'レビュー平均$rating（${reviewCount}件）もチェックしてみてください。',
          PostTone.casual => 'レビュー$rating（${reviewCount}件）も結構いい感じ。',
        },
      PostFocusPoint.design =>
        switch (style.tone) {
          PostTone.polite => '写真の雰囲気も、暮らしに馴染みやすそうです。',
          PostTone.friendlyPolite => '見た目も写真映えしそうで、好みに合いそうです。',
          PostTone.casual => '見た目も写真映えしそう。',
        },
      PostFocusPoint.convenience ||
      PostFocusPoint.dailyUse =>
        switch (style.tone) {
          PostTone.polite => '日常使いにも取り入れやすそうな印象です。',
          PostTone.friendlyPolite => '毎日の暮らしにも使いやすそうです。',
          PostTone.casual => '毎日使えそうなやつ。',
        },
      PostFocusPoint.cute =>
        switch (style.tone) {
          PostTone.polite => 'デザインもかわいらしく、手に取りたくなります。',
          PostTone.friendlyPolite => 'かわいいデザインで、つい見ちゃいます。',
          PostTone.casual => 'デザインかわいい。',
        },
      PostFocusPoint.gift =>
        switch (style.tone) {
          PostTone.polite => 'ギフトにも選びやすい雰囲気があります。',
          PostTone.friendlyPolite => 'プレゼントにも渡しやすそうです。',
          PostTone.casual => 'プレゼントにもよさそう。',
        },
      PostFocusPoint.parenting =>
        switch (style.tone) {
          PostTone.polite => '忙しい日にも助けてくれそうな実用性がありそうです。',
          PostTone.friendlyPolite => '忙しい日にも助かりそうな実用性があります。',
          PostTone.casual => '忙しい日にも助かりそう。',
        },
      _ => '',
    };
  }

  static String _closing(PostStyleSettings style) {
    if (style.avoidOverstatement) {
      return switch (style.tone) {
        PostTone.polite => '気になる方は、商品ページもご覧ください。',
        PostTone.friendlyPolite => '気になった方は、チェックしてみてください。',
        PostTone.casual => '気になったら見てみてね。',
      };
    }
    return switch (style.tone) {
      PostTone.polite => 'ぜひ一度ご覧ください。',
      PostTone.friendlyPolite => '気になったら、ぜひ見てみてください。',
      PostTone.casual => 'よかったら見てみて！',
    };
  }

  static String _applyToneMarkers(String body, PostTone tone) {
    return switch (tone) {
      PostTone.polite => body,
      PostTone.friendlyPolite => body,
      PostTone.casual => body.replaceAll('です。', 'だよ。').replaceAll('ですね。', 'だね。'),
    };
  }

  static String _applyEmoji(String body, PostStyleSettings style) {
    final emojis = switch (style.emojiLevel) {
      EmojiLevel.none => <String>[],
      EmojiLevel.low => const ['✨'],
      EmojiLevel.medium => const ['✨', '🛒'],
    };
    if (emojis.isEmpty && !style.kaomojiEnabled) return body;

    final buffer = StringBuffer(body);
    if (emojis.isNotEmpty) {
      buffer.write(' ${emojis.join(' ')}');
    }
    if (style.kaomojiEnabled) {
      buffer.write(' (´∀｀)');
    }
    return buffer.toString();
  }

  static String _buildHashtags(
    PostStyleSettings style,
    String name, {
    List<String> titleKeywords = const [],
    String genreName = '',
  }) {
    final count = style.hashtagCount;
    if (count <= 0) return '';

    final tags = <String>[];

    final genre = genreName.trim();
    if (genre.isNotEmpty) {
      tags.add('#${genre.replaceAll(RegExp(r'\s+'), '')}');
    }

    for (final keyword in titleKeywords) {
      final normalized = keyword.trim().replaceAll(RegExp(r'\s+'), '');
      if (normalized.isNotEmpty) {
        tags.add('#$normalized');
      }
    }

    final normalizedName = name
        .replaceAll(RegExp(r'[【】\s]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    if (normalizedName.isNotEmpty) {
      tags.add('#$normalizedName');
    }

    const fallbackTags = [
      '#整理整頓',
      '#暮らし',
      '#インテリア',
      '#収納',
      '#レビュー',
      '#ギフト',
      '#日用品',
    ];
    tags.addAll(fallbackTags);

    final uniqueTags = <String>[];
    for (final tag in tags) {
      if (!uniqueTags.contains(tag)) {
        uniqueTags.add(tag);
      }
    }

    return uniqueTags.take(count).join(' ');
  }

  static String _fitBodyLength(String body, PostGenerationLimits limits) {
    if (body.length <= limits.maxBodyChars) {
      if (body.length >= limits.minBodyChars) return body;
      return _padToMin(body, limits);
    }
    return _truncate(body, limits.maxBodyChars);
  }

  static String _padToMin(String body, PostGenerationLimits limits) {
    const filler = ' 詳しくは商品ページでご確認ください。';
    var padded = body;
    while (padded.length < limits.minBodyChars &&
        padded.length + filler.length <= limits.maxBodyChars) {
      padded += filler;
    }
    if (padded.length < limits.minBodyChars) {
      padded = _truncate(
        '$padded${'.' * (limits.minBodyChars - padded.length)}',
        limits.maxBodyChars,
      );
    }
    return padded;
  }

  static String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    if (maxChars <= 1) return text.substring(0, maxChars);
    return '${text.substring(0, maxChars - 1)}…';
  }
}
