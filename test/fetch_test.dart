import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:wildread/engine/rule_engine.dart';
import 'package:wildread/engine/content_fetcher.dart';

void main() async {
  // Load test config
  final configFile = File('test/test_config.json');
  if (!configFile.existsSync()) {
    print('ERROR: test/test_config.json not found');
    exit(1);
  }
  final config =
      json.decode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final ruleFile = config['rule_file'] as String;
  final bookUrl = config['book_url'] as String;

  // Load rule JSON
  if (!File(ruleFile).existsSync()) {
    print('ERROR: rule file "$ruleFile" not found');
    exit(1);
  }
  final ruleJson = File(ruleFile).readAsStringSync();

  // Parse rule
  final engine = RuleEngine();
  print('=== 规则校验 ===');
  final validateError = engine.validate(ruleJson);
  if (validateError.isNotEmpty) {
    print('❌ 规则校验失败: $validateError');
    exit(1);
  }
  print('✅ 规则校验通过');

  final rule = engine.parse(ruleJson);
  print('  name: ${rule.name}');
  print('  mode: ${rule.mode}');
  print('  encoding: ${rule.encoding}');
  print('  baseUrl: ${rule.baseUrl}');
  print('  book.title: ${rule.book?.title?.selector ?? "(未配置)"}');
  print('  book.author: ${rule.book?.author?.selector ?? "(未配置)"}');
  print('  book.cover: ${rule.book?.cover?.selector ?? "(未配置)"}');
  print('  book.description: ${rule.book?.description?.selector ?? "(未配置)"}');
  print('  chapterList.container: ${rule.chapterList?.container.selector ?? "(N/A)"}');
  print('  chapterList.item: ${rule.chapterList?.item.selector ?? "(N/A)"}');
  print('  content.body: ${rule.content.body.selector}');
  print('  content.filters: ${rule.content.filters}');

  // ── STEP 1: Download via curl ──
  print('\n=== 下载图书详情页 ===');

  // Try original URL, then try www/m variants
  var httpCode = await _curlDownload(bookUrl, 'test/raw_response.bin');
  var usedUrl = bookUrl;

  if (httpCode != '200') {
    final altUrl = bookUrl.replaceFirst('https://m.', 'https://www.');
    print('⚠️  $bookUrl → HTTP $httpCode, 尝试 $altUrl');
    httpCode = await _curlDownload(altUrl, 'test/raw_response.bin');
    usedUrl = altUrl;
  }
  if (httpCode != '200') {
    final altUrl = bookUrl.replaceFirst('https://www.', 'https://m.');
    print('⚠️  尝试 $altUrl');
    httpCode = await _curlDownload(altUrl, 'test/raw_response.bin');
    usedUrl = altUrl;
  }

  if (httpCode != '200') {
    print('❌ 所有域名都下载失败, HTTP $httpCode');
    exit(1);
  }
  final rawBytes = File('test/raw_response.bin').readAsBytesSync();
  print('✅ 下载成功 ($usedUrl), ${rawBytes.length} bytes');
  print('✅ 下载成功, ${rawBytes.length} bytes');

  // ── STEP 2: Auto-detect encoding ──
  String html;
  final detected = Charset.detect(rawBytes);
  if (detected != null) {
    html = detected.decode(rawBytes);
    print('✅ 检测到编码: ${detected.name}, 共 ${html.length} 字');
  } else {
    html = utf8.decode(rawBytes, allowMalformed: true);
    print('⚠️  未检测到编码, 回退 UTF-8');
  }
  File('test/decoded.html').writeAsStringSync(html);
  print('   完整 HTML → test/decoded.html');

  // ── STEP 3: Parse with RuleEngine ──
  final fetcher = ContentFetcher();
  final doc = fetcher.parseHtml(html);
  final baseUrl = rule.baseUrl != null && rule.baseUrl!.isNotEmpty
      ? rule.baseUrl!
      : bookUrl;

  print('\n=== 选择器提取测试 ===');
  final title = fetcher.extractText(doc, rule.book?.title);
  print('书名 "${rule.book?.title?.selector}": ${title ?? "(无结果)"}');
  print('作者 "${rule.book?.author?.selector}": ${fetcher.extractText(doc, rule.book?.author) ?? "(无结果)"}');
  print('封面 "${rule.book?.cover?.selector}": ${fetcher.extractAttr(doc, rule.book?.cover, baseUrl: baseUrl) ?? "(无结果)"}');
  final desc = fetcher.extractText(doc, rule.book?.description);
  print('简介 "${rule.book?.description?.selector}": ${desc?.substring(0, desc.length.clamp(0, 100)) ?? "(无结果)"}');

  // ── STEP 4: Extract chapter list ──
  print('\n=== 章节列表提取 ===');
  if (rule.chapterList == null) {
    print('❌ 规则未配置 chapterList');
    exit(1);
  }
  final chapters = fetcher.extractChapterList(doc, rule.chapterList!, bookUrl);
  print('章节数: ${chapters.length}');
  if (chapters.isEmpty) {
    print('❌ 未提取到任何章节！');
    print('   可能是 container="${rule.chapterList!.container.selector}" 或 item="${rule.chapterList!.item.selector}" 选择器不匹配');
    exit(1);
  }

  print('--- 前 10 章 ---');
  for (var i = 0; i < chapters.length && i < 10; i++) {
    print('  [${i + 1}] ${chapters[i].title}');
    print('      ${chapters[i].url}');
  }

  // ── STEP 5: Fetch first chapter content ──
  print('\n=== 抓取第一章正文 ===');
  final ch = chapters[0];
  print('章节: ${ch.title}');
  print('URL: ${ch.url}');

  final chHttpCode = await _curlDownload(ch.url, 'test/chapter_raw.bin');
  if (chHttpCode != '200') {
    print('❌ 章节下载失败, HTTP $chHttpCode');
    exit(1);
  }
  final chBytes = File('test/chapter_raw.bin').readAsBytesSync();
  final chDetected = Charset.detect(chBytes);
  final chHtml = chDetected != null
      ? chDetected.decode(chBytes)
      : utf8.decode(chBytes, allowMalformed: true);

  final chDoc = fetcher.parseHtml(chHtml);
  final contentTitle = fetcher.extractText(chDoc, rule.content.title);
  final body = fetcher.extractBody(chDoc, rule.content);
  final nextPage = fetcher.extractAttr(chDoc, rule.content.nextPage, baseUrl: baseUrl);

  print('章节标题: ${contentTitle ?? "(无)"}');
  print('下一页: ${nextPage ?? "(无)"}');
  print('正文字数: ${body.length}');
  print('\n--- 正文 (前 500 字) ---');
  print(body.substring(0, body.length.clamp(0, 500)));
  print('--- END ---');

  fetcher.dispose();
  print('\n✅ 测试完成');
}

Future<String> _curlDownload(String url, String outputPath) async {
  final result = await Process.run('curl', [
    '-sL',
    '--tlsv1.2',
    '--http1.1',
    '-H', 'User-Agent: Mozilla/5.0 (Linux; Android 13; V2454A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36',
    '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    '-H', 'Accept-Language: zh-CN,zh;q=0.9',
    '-H', 'Accept-Encoding: gzip, deflate',
    '-H', 'Cache-Control: no-cache',
    '-H', 'Connection: keep-alive',
    '--connect-timeout', '15',
    '--max-time', '20',
    '-o', outputPath,
    '-w', '%{http_code}::%{redirect_url}',
    url,
  ], runInShell: true);
  return result.stdout.toString().trim();
}
