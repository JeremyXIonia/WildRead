import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'rule_engine.dart';

class ChapterInfo {
  final String title;
  final String url;
  const ChapterInfo({required this.title, required this.url});
}

class BookInfo {
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final List<ChapterInfo> chapters;

  const BookInfo({
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    this.chapters = const [],
  });
}

class ContentFetcher {
  final Dio _dio;

  ContentFetcher()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
          },
        ));

  /// Parse HTML string into a DOM document
  dom.Document parseHtml(String html) => html_parser.parse(html);

  /// Extract text from the first element matching [spec]
  String? extractText(dom.Document doc, SelectorSpec spec) {
    if (spec.selector == 'self::') return null;
    final el = doc.querySelector(spec.selector);
    return el?.text.trim();
  }

  /// Extract attribute from the first element matching [spec]
  String? extractAttr(dom.Document doc, SelectorSpec spec, {String? baseUrl}) {
    final el = doc.querySelector(spec.selector);
    if (el == null) return null;
    final value = el.attributes[spec.attr ?? ''] ?? '';
    if (value.isEmpty) return null;
    return baseUrl != null ? resolveUrl(value, baseUrl) : value;
  }

  /// Extract chapter list from container > items
  List<ChapterInfo> extractChapterList(
    dom.Document doc,
    ChapterListSelectors selectors,
    String baseUrl,
  ) {
    final container = doc.querySelector(selectors.container.selector);
    if (container == null) return [];

    final items = container.querySelectorAll(selectors.item.selector);
    return items.map((item) {
      String title;
      if (selectors.title.selector == 'self::') {
        title = item.text.trim();
      } else {
        final el = item.querySelector(selectors.title.selector);
        title = el?.text.trim() ?? '';
      }

      String href;
      if (selectors.href.selector == 'self::') {
        href = item.attributes[selectors.href.attr ?? 'href'] ?? '';
      } else {
        final el = item.querySelector(selectors.href.selector);
        href = el?.attributes[selectors.href.attr ?? 'href'] ?? '';
      }

      return ChapterInfo(
        title: title,
        url: resolveUrl(href, baseUrl),
      );
    }).where((c) => c.title.isNotEmpty && c.url.isNotEmpty).toList();
  }

  /// Extract body text after removing filters
  String extractBody(dom.Document doc, ContentSelectors selectors) {
    final bodyEl = doc.querySelector(selectors.body.selector);
    if (bodyEl == null) return '';

    // Remove filtered elements
    for (final filter in selectors.filters) {
      bodyEl.querySelectorAll(filter).forEach((el) => el.remove());
    }

    final buffer = StringBuffer();
    _walkNodes(bodyEl.nodes, buffer);
    return buffer.toString().trim();
  }

  void _walkNodes(List<dom.Node> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      } else if (node is dom.Element) {
        final tag = node.localName ?? '';
        _walkNodes(node.nodes, buffer);
        if (tag == 'p' || tag == 'div') {
          buffer.writeln();
        }
      }
    }
  }

  /// Fetch book info: title, author, cover, description, and chapter list
  Future<BookInfo> fetchBookInfo(String url, RuleConfig rule) async {
    final html = await _fetchHtml(url, rule.encoding);
    final doc = parseHtml(html);
    final baseUrl = rule.baseUrl ?? url;

    final title = rule.book?.title != null
        ? (extractText(doc, rule.book!.title!) ?? '')
        : '';
    final author = rule.book?.author != null
        ? extractText(doc, rule.book!.author!)
        : null;
    final coverUrl = rule.book?.cover != null
        ? extractAttr(doc, rule.book!.cover!, baseUrl: baseUrl)
        : null;
    final description = rule.book?.description != null
        ? extractText(doc, rule.book!.description!)
        : null;

    List<ChapterInfo> chapters = [];
    if (rule.chapterList != null) {
      String listUrl = url;
      if (rule.chapterList!.url != null) {
        listUrl =
            extractAttr(doc, rule.chapterList!.url!, baseUrl: baseUrl) ?? url;
      }
      if (listUrl != url) {
        final listHtml = await _fetchHtml(listUrl, rule.encoding);
        final listDoc = parseHtml(listHtml);
        chapters = extractChapterList(listDoc, rule.chapterList!, baseUrl);
      } else {
        chapters = extractChapterList(doc, rule.chapterList!, baseUrl);
      }
    }

    return BookInfo(
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
      chapters: chapters,
    );
  }

  /// Fetch and extract chapter content
  Future<String> fetchContent(String url, RuleConfig rule) async {
    final html = await _fetchHtml(url, rule.encoding);
    final doc = parseHtml(html);
    return extractBody(doc, rule.content);
  }

  /// Fetch HTML with encoding fallback: UTF-8 → GBK
  Future<String> _fetchHtml(String url, String encoding) async {
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final response = await _dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data as List<int>;
        return _decodeBytes(bytes, encoding);
      } on DioException {
        retries++;
        if (retries >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: retries));
      }
    }
    throw Exception('Max retries exceeded');
  }

  String _decodeBytes(List<int> bytes, String encoding) {
    if (encoding.toLowerCase() == 'gbk' ||
        encoding.toLowerCase() == 'gb2312') {
      try {
        return gbk.decode(bytes);
      } catch (_) {}
    }

    try {
      return utf8.decode(bytes);
    } catch (_) {}

    try {
      return gbk.decode(bytes);
    } catch (_) {}

    return latin1.decode(bytes);
  }

  /// Resolve a relative URL against a base URL
  static String resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (url.startsWith('/')) {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${uri.host}$url';
    }
    final lastSlash = base.lastIndexOf('/');
    final dir = base.substring(0, lastSlash);
    return '$dir/$url';
  }

  void dispose() {
    _dio.close();
  }
}
