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
        : '気になった一品です';
    final price = ProductPriceDisplay.formatYen(input.itemPrice);
    final rating = input.reviewAverage.toStringAsFixed(2);
    final count = input.reviewCount;

    final segments = <String>[
      _opening(style, name),
      reason,
      ..._focusSegments(style, price: price, rating: rating, count: count),
      _closing(style),
    ];

    var body = segments.where((s) => s.trim().isNotEmpty).join('\n');
    body = _applyToneMarkers(body, style.tone);
    body = _applyEmoji(body, style);
    body = _fitBodyLength(body, limits);

    final hashtags = _buildHashtags(
      style,
      name,
      titleKeywords: input.titleKeywords,
      genreName: input.genreName,
    );
    if (hashtags.isEmpty) return body;

    final combined = '$body\n\n$hashtags';
    if (combined.length <= limits.maxTotalChars) return combined;

    final allowedBody = limits.maxTotalChars - hashtags.length - 2;
    if (allowedBody < limits.minBodyChars) return body;
    return '${_truncate(body, allowedBody)}\n\n$hashtags';
  }

  static String _opening(PostStyleSettings style, String name) {
    final audience = switch (style.targetAudience) {
      PostTargetAudience.women => '女性の方にも使いやすそうな',
      PostTargetAudience.men => '男性にも選びやすい',
      PostTargetAudience.parents => '子育て中の方にも助かる',
      PostTargetAudience.singleLife => '一人暮らしにもちょうどいい',
      PostTargetAudience.roomBeginner => 'ROOM初心者の方にも紹介しやすい',
      PostTargetAudience.general => '気になった',
    };
    return switch (style.tone) {
      PostTone.polite => '【$name】をご紹介いたします。$audience一品です。',
      PostTone.friendlyPolite => '【$name】、$audienceアイテムですね。',
      PostTone.casual => '【$name】、$audienceやつ見つけたよ。',
    };
  }

  static List<String> _focusSegments(
    PostStyleSettings style, {
    required String price,
    required String rating,
    required int count,
  }) {
    return style.focusPoints.map((point) {
      return switch (point) {
        PostFocusPoint.costPerformance => '価格は$priceで、コスパも気になります。',
        PostFocusPoint.convenience => '使い勝手がよさそうで、日常に取り入れやすいです。',
        PostFocusPoint.reviews =>
          'レビュー平均 $rating（$count件）も参考になります。',
        PostFocusPoint.design => '見た目のバランスもよく、写真映えしそうです。',
        PostFocusPoint.cute => 'デザインがかわいく、手に取りたくなります。',
        PostFocusPoint.gift => 'ギフトにも渡しやすい雰囲気があります。',
        PostFocusPoint.parenting => '忙しい日にも助けてくれそうな実用性があります。',
        PostFocusPoint.dailyUse => '毎日の暮らしに自然に馴染みそうです。',
      };
    }).toList();
  }

  static String _closing(PostStyleSettings style) {
    if (style.avoidOverstatement) {
      return switch (style.tone) {
        PostTone.polite => '気になる方は、ご確認いただければ幸いです。',
        PostTone.friendlyPolite => '気になった方は、チェックしてみてください。',
        PostTone.casual => '気になったら見てみてね。',
      };
    }
    return switch (style.tone) {
      PostTone.polite => 'ぜひ一度ご覧ください。きっと気に入っていただけると思います。',
      PostTone.friendlyPolite => 'かなりおすすめなので、ぜひチェックしてみてください！',
      PostTone.casual => 'マジでいい感じだから、見てみて！',
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
      EmojiLevel.low => const ['✨', '🛒'],
      EmojiLevel.medium => const ['✨', '🛒', '💡', '😊'],
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
