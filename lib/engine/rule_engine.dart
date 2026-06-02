import 'dart:convert';

class SelectorSpec {
  final String selector;
  final String? attr;

  const SelectorSpec({required this.selector, this.attr});
}

class BookSelectors {
  final SelectorSpec? title;
  final SelectorSpec? author;
  final SelectorSpec? cover;
  final SelectorSpec? description;

  const BookSelectors({this.title, this.author, this.cover, this.description});
}

class ChapterListSelectors {
  final SelectorSpec? url;
  final SelectorSpec container;
  final SelectorSpec item;
  final SelectorSpec title;
  final SelectorSpec href;

  const ChapterListSelectors({
    this.url,
    required this.container,
    required this.item,
    required this.title,
    required this.href,
  });
}

class ContentSelectors {
  final SelectorSpec? title;
  final SelectorSpec body;
  final SelectorSpec? nextPage;
  final List<String> filters;

  const ContentSelectors({
    this.title,
    required this.body,
    this.nextPage,
    this.filters = const [],
  });
}

class RuleConfig {
  final String name;
  final String? baseUrl;
  final String encoding;
  final String? mode;
  final BookSelectors? book;
  final ChapterListSelectors? chapterList;
  final ContentSelectors content;

  const RuleConfig({
    required this.name,
    this.baseUrl,
    this.encoding = 'utf-8',
    this.mode,
    this.book,
    this.chapterList,
    required this.content,
  });
}

class RuleEngine {
  /// Parse a CSS selector string, splitting off attribute if present.
  /// ".class @attr" -> SelectorSpec(selector: ".class", attr: "attr")
  /// "self::text" -> SelectorSpec(selector: "self::", attr: null)
  /// "self::@href" -> SelectorSpec(selector: "self::", attr: "href")
  static SelectorSpec _parseSelector(String raw) {
    if (raw.startsWith('self::')) {
      final rest = raw.substring(6);
      if (rest.startsWith('@')) {
        return SelectorSpec(selector: 'self::', attr: rest.substring(1));
      }
      return const SelectorSpec(selector: 'self::');
    }
    final parts = raw.split(' @');
    if (parts.length == 2) {
      return SelectorSpec(selector: parts[0].trim(), attr: parts[1].trim());
    }
    return SelectorSpec(selector: raw.trim());
  }

  static SelectorSpec? _parseOptionalSelector(dynamic value) {
    if (value == null) return null;
    return _parseSelector(value as String);
  }

  RuleConfig parse(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    final mode = map['mode'] as String?;

    BookSelectors? book;
    if (map['book'] != null) {
      final b = map['book'] as Map<String, dynamic>;
      book = BookSelectors(
        title: _parseOptionalSelector(b['title']),
        author: _parseOptionalSelector(b['author']),
        cover: _parseOptionalSelector(b['cover']),
        description: _parseOptionalSelector(b['description']),
      );
    }

    ChapterListSelectors? chapterList;
    if (map['chapterList'] != null) {
      final cl = map['chapterList'] as Map<String, dynamic>;
      chapterList = ChapterListSelectors(
        url: _parseOptionalSelector(cl['url']),
        container: _parseSelector(cl['container'] as String),
        item: _parseSelector(cl['item'] as String),
        title: _parseSelector(cl['title'] as String),
        href: _parseSelector(cl['href'] as String),
      );
    }

    final c = map['content'] as Map<String, dynamic>;
    final filters = (c['filters'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final content = ContentSelectors(
      title: _parseOptionalSelector(c['title']),
      body: _parseSelector(c['body'] as String),
      nextPage: _parseOptionalSelector(c['nextPage']),
      filters: filters,
    );

    return RuleConfig(
      name: map['name'] as String? ?? '',
      baseUrl: map['baseUrl'] as String?,
      encoding: map['encoding'] as String? ?? 'utf-8',
      mode: mode,
      book: book,
      chapterList: chapterList,
      content: content,
    );
  }

  /// Validate a rule JSON string. Returns empty string if valid,
  /// or an error message describing the problem.
  String validate(String jsonString) {
    Map<String, dynamic> map;
    try {
      map = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return 'JSON 格式错误: $e';
    }

    if (!map.containsKey('name')) {
      return '缺少必填字段: name';
    }

    if (!map.containsKey('content')) {
      return '缺少必填字段: content';
    }
    final content = map['content'] as Map<String, dynamic>?;
    if (content == null || !content.containsKey('body')) {
      return '缺少必填字段: content.body';
    }

    return '';
  }
}
