import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:dio/dio.dart';
import 'package:charset/charset.dart';
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

/// Debug info collected during a fetch operation
class _DecodeResult {
  final String html;
  final String encoding;
  _DecodeResult(this.html, this.encoding);
}

class FetchDebug {
  final List<FetchStep> steps = [];
  String? lastHtml;

  void log(String url, String method, int? statusCode,
      Map<String, String>? headers, String? encoding, String? error,
      String? htmlSnippet) {
    steps.add(FetchStep(
      url: url,
      method: method,
      statusCode: statusCode,
      headers: headers,
      usedEncoding: encoding,
      error: error,
      htmlSnippet: htmlSnippet,
    ));
  }

  String summarize() {
    final sb = StringBuffer();
    for (final s in steps) {
      sb.writeln('── ${s.method} ${s.url}');
      if (s.statusCode != null) sb.writeln('   status: ${s.statusCode}');
      if (s.headers != null) {
        final ct = s.headers?['content-type'] ?? s.headers?['Content-Type'];
        if (ct != null) sb.writeln('   content-type: $ct');
      }
      if (s.usedEncoding != null) sb.writeln('   encoding: ${s.usedEncoding}');
      if (s.htmlSnippet != null) {
        sb.writeln('   html preview (first 300 chars):');
        sb.writeln('   ${s.htmlSnippet!.substring(0, s.htmlSnippet!.length.clamp(0, 300))}');
      }
      if (s.error != null) sb.writeln('   ERROR: ${s.error}');
    }
    return sb.toString();
  }

  /// Clear steps for reuse
  void clear() => steps.clear();
}

class FetchStep {
  final String url;
  final String method;
  final int? statusCode;
  final Map<String, String>? headers;
  final String? usedEncoding;
  final String? error;
  final String? htmlSnippet;

  FetchStep({
    required this.url,
    required this.method,
    this.statusCode,
    this.headers,
    this.usedEncoding,
    this.error,
    this.htmlSnippet,
  });
}

class ContentFetcher {
  late final Dio _dio;
  bool debugMode = false;
  FetchDebug? debug;

  ContentFetcher() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      },
    ));

    try {
      (_dio.httpClientAdapter as dynamic).onHttpClientCreate =
          (HttpClient client) {
        client.badCertificateCallback = (cert, host, port) => true;
      };
    } catch (_) {}
  }

  /// Parse HTML string into a DOM document
  dom.Document parseHtml(String html) => html_parser.parse(html);

  /// Extract text from the first element matching [spec].
  /// Returns null if spec is null or selector is empty.
  String? extractText(dom.Document doc, SelectorSpec? spec) {
    if (spec == null) return null;
    if (spec.selector == 'self::' || spec.selector.isEmpty) return null;
    try {
      final el = doc.querySelector(spec.selector);
      return el?.text.trim();
    } catch (_) {
      return null; // invalid selector
    }
  }

  /// Extract attribute from the first element matching [spec].
  /// Returns null if spec is null or selector is empty.
  String? extractAttr(dom.Document doc, SelectorSpec? spec, {String? baseUrl}) {
    if (spec == null) return null;
    if (spec.selector.isEmpty) return null;
    try {
      final el = doc.querySelector(spec.selector);
      if (el == null) return null;
      final value = el.attributes[spec.attr ?? ''] ?? '';
      if (value.isEmpty) return null;
      return baseUrl != null ? resolveUrl(value, baseUrl) : value;
    } catch (_) {
      return null; // invalid selector
    }
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

    for (final filter in selectors.filters) {
      try {
        bodyEl.querySelectorAll(filter).forEach((el) => el.remove());
      } catch (_) {
        // skip invalid filter selector
      }
    }

    final buffer = StringBuffer();
    _walkNodes(bodyEl.nodes, buffer);
    return buffer.toString().trim();
  }

  void _walkNodes(List<dom.Node> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text;
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      } else if (node is dom.Element) {
        final tag = node.localName ?? '';
        if (tag == 'br') {
          buffer.writeln(); // single line break
        } else if (tag == 'p') {
          // Collect all text within this <p> as one paragraph
          final para = _collectText(node);
          if (para.isNotEmpty) {
            buffer.writeln(para);
            buffer.writeln(); // blank line after paragraph
          }
        } else {
          _walkNodes(node.nodes, buffer);
          if (tag == 'div') {
            buffer.writeln(); // blank line after div block
          }
        }
      }
    }
  }

  /// Recursively collect all text within an element, ignoring nested block tags
  String _collectText(dom.Element el) {
    final buf = StringBuffer();
    for (final child in el.nodes) {
      if (child is dom.Text) {
        buf.write(child.text);
      } else if (child is dom.Element) {
        final tag = child.localName ?? '';
        if (tag == 'br') {
          buf.write('\n');
        } else {
          buf.write(_collectText(child));
        }
      }
    }
    return buf.toString().trim();
  }

  /// Fetch book info: title, author, cover, description, and chapter list
  Future<BookInfo> fetchBookInfo(String url, RuleConfig rule) async {
    debug?.clear();
    final html = await _fetchHtml(url, rule.encoding, referer: rule.baseUrl);
    if (debugMode) debug?.lastHtml = html;
    final doc = parseHtml(html);
    final baseUrl = rule.baseUrl ?? url;

    final title = extractText(doc, rule.book?.title) ?? '';
    final author = extractText(doc, rule.book?.author);
    final coverUrl = extractAttr(doc, rule.book?.cover, baseUrl: baseUrl);
    final description = extractText(doc, rule.book?.description);

    // Detect if selectors matched
    final problems = <String>[];
    if (title.isEmpty && rule.book?.title != null) {
      problems.add('书名选择器 "${rule.book!.title!.selector}" 未匹配到内容');
    }
    if (author == null && rule.book?.author != null) {
      problems.add('作者选择器未匹配');
    }

    List<ChapterInfo> chapters = [];
    if (rule.chapterList != null) {
      String listUrl = url;
      if (rule.chapterList!.url != null) {
        listUrl =
            extractAttr(doc, rule.chapterList!.url, baseUrl: baseUrl) ?? url;
      }
      try {
        if (listUrl != url) {
          final listHtml = await _fetchHtml(listUrl, rule.encoding, referer: rule.baseUrl);
          final listDoc = parseHtml(listHtml);
          chapters = extractChapterList(listDoc, rule.chapterList!, listUrl);
        } else {
          chapters = extractChapterList(doc, rule.chapterList!, url);
        }
        if (rule.chapterList!.order == 'desc') {
          chapters = chapters.reversed.toList();
        }
        if (chapters.isEmpty) {
          problems.add(
              '章节列表为空: container="${rule.chapterList!.container.selector}" item="${rule.chapterList!.item.selector}"');
        }
      } catch (e) {
        throw Exception('抓取章节列表失败 [$listUrl]: $e');
      }
    }

    if (problems.isNotEmpty && title.isEmpty && chapters.isEmpty) {
      throw Exception('规则不匹配:\n${problems.join('\n')}');
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
  /// Fetch chapter content, optionally following in-chapter nextPage links.
  Future<String> fetchContent(String url, RuleConfig rule) async {
    final buffer = StringBuffer();
    String currentUrl = url;
    int pageCount = 0;
    const maxPages = 20; // safety limit

    while (pageCount < maxPages) {
      final html = await _fetchHtml(currentUrl, rule.encoding, referer: rule.baseUrl);
      final doc = parseHtml(html);
      final body = extractBody(doc, rule.content);

      if (pageCount == 0 && body.isEmpty) {
        final rawBody = doc.querySelector(rule.content.body.selector);
        if (rawBody == null) {
          throw Exception(
              '正文选择器 "${rule.content.body.selector}" 未匹配到元素 [$currentUrl]');
        }
        final rawText = rawBody.text.trim();
        if (rawText.isEmpty) {
          throw Exception('正文元素存在但内容为空 [$currentUrl]');
        }
        throw Exception(
            '正文过滤后为空 (filters: ${rule.content.filters}) [$currentUrl]');
      }

      buffer.write(body);
      pageCount++;

      // Check for next page
      if (rule.content.nextPage == null) break;
      final nextUrl =
          extractAttr(doc, rule.content.nextPage!, baseUrl: currentUrl);
      if (nextUrl == null || nextUrl == currentUrl) break;
      currentUrl = nextUrl;
    }

    return buffer.toString();
  }

  /// Fetch HTML with retry and encoding auto-detection.
  /// Checks response headers and HTML meta tags for charset.
  /// Tries HTTPS first, falls back to HTTP on TLS errors.
  Future<String> _fetchHtml(String url, String encoding, {String? referer}) async {
    int retries = 0;
    const maxRetries = 3;
    String currentUrl = url;

    while (retries < maxRetries) {
      try {
        final extraHeaders = <String, String>{};
        if (referer != null) extraHeaders['Referer'] = referer;

        final response = await _dio.get(
          currentUrl,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 15),
            headers: extraHeaders.isNotEmpty ? extraHeaders : null,
          ),
        );
        final bytes = response.data as List<int>;

        // 1. Detect encoding from HTTP Content-Type header
        String detected = encoding;
        final contentType = response.headers.value('content-type');
        if (contentType != null) {
          final match =
              RegExp(r'charset=([^\s;]+)', caseSensitive: false)
                  .firstMatch(contentType);
          if (match != null) {
            detected = match.group(1)!.toLowerCase().replaceAll('"', '');
          }
        }

        // 2. Always peek at HTML meta tag for charset
        final head = _decodeBytesPartial(bytes, 1024);
        final metaMatch =
            RegExp(r'charset[="\s]+([^\s";]+)', caseSensitive: false)
                .firstMatch(head);
        if (metaMatch != null) {
          final metaCharset = metaMatch.group(1)!.toLowerCase();
          // Prefer meta tag over HTTP header (more reliable for Chinese sites)
          if (detected == 'utf-8' || detected == 'utf8' ||
              metaCharset == 'gbk' || metaCharset == 'gb2312') {
            detected = metaCharset;
          }
        }

        final decoded = _decodeBytesDebug(bytes, detected);
        final statusCode = response.statusCode;

        if (debugMode) {
          final h = <String, String>{};
          response.headers.forEach((k, v) => h[k] = v.join(', '));
          debug?.log(currentUrl, 'GET', statusCode, h,
              '${decoded.encoding} (detected: $detected)', null,
              decoded.html.length > 300
                  ? decoded.html.substring(0, 300)
                  : decoded.html);
        }

        return decoded.html;

      } on DioException catch (e) {
        if (debugMode) {
          final h = <String, String>{};
          e.response?.headers.forEach((k, v) => h[k] = v.join(', '));
          debug?.log(currentUrl, 'GET', e.response?.statusCode, h, null,
              e.message, null);
        }
        if (_isTlsError(e) && currentUrl.startsWith('https://')) {
          currentUrl = currentUrl.replaceFirst('https://', 'http://');
          retries = 0;
          continue;
        }
        retries++;
        if (retries >= maxRetries) {
          throw DioException(
            requestOptions: e.requestOptions,
            message: '${e.message} [$currentUrl]',
            error: e.error,
          );
        }
        await Future.delayed(Duration(seconds: retries));
      }
    }
    throw Exception('Max retries exceeded');
  }

  /// Decode first [maxBytes] bytes using latin1 (safe) to peek at meta tags
  String _decodeBytesPartial(List<int> bytes, int maxBytes) {
    return latin1.decode(bytes.take(maxBytes).toList());
  }

  bool _isTlsError(DioException e) {
    final msg = e.message ?? '';
    return msg.contains('handshake') ||
        msg.contains('Certificate') ||
        msg.contains('TLS') ||
        msg.contains('SSL') ||
        e.error is HandshakeException ||
        e.error is TlsException;
  }

  _DecodeResult _decodeBytesDebug(List<int> bytes, String encoding) {
    // Use charset package to auto-detect encoding
    try {
      final detected = Charset.detect(bytes);
      if (detected != null) {
        return _DecodeResult(detected.decode(bytes), detected.name);
      }
    } catch (_) {}

    // Fallback: try utf-8, then latin1
    try {
      return _DecodeResult(utf8.decode(bytes, allowMalformed: true), 'utf-8');
    } catch (_) {
      return _DecodeResult(latin1.decode(bytes), 'latin1');
    }
  }

  /// Resolve a relative URL against a base URL
  static String resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Ensure baseUrl has trailing / if last segment isn't a file
    String base = baseUrl;
    if (!base.endsWith('/')) {
      final uri = Uri.parse(base);
      final lastSeg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (lastSeg.isNotEmpty && !lastSeg.contains('.')) {
        base = '$base/';
      }
    }
    return Uri.parse(base).resolve(url).toString();
  }

  void dispose() {
    _dio.close();
  }
}
