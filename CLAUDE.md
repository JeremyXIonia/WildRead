# WildRead

个人安卓小说阅读器，通过 JSON 规则配置文件动态适配不同网站，支持章节模式和连续翻页模式。

## 技术栈

- Flutter 3.x + Dart 3.12
- Riverpod 2.6（状态管理）
- dio 5.x（HTTP 请求）
- html 0.15（HTML 解析，CSS 选择器提取）
- charset 2.0（编码自动检测）
- sqflite 2.4（本地 SQLite 存储）
- go_router 14.x（路由）

## 项目结构

```
lib/
├── main.dart                    # 入口，ProviderScope
├── app.dart                     # go_router 路由 + MaterialApp
├── models/
│   ├── book.dart                # 图书模型
│   ├── chapter.dart             # 章节模型
│   ├── rule.dart                # 规则模型（存 JSON 字符串）
│   └── reading_progress.dart    # 阅读进度模型
├── database/
│   └── database_helper.dart     # sqflite CRUD（4 张表）
├── engine/
│   ├── rule_engine.dart         # JSON 规则解析/校验 + SelectorSpec
│   └── content_fetcher.dart     # dio 抓取 + html 解析 + 编码检测
├── providers/
│   ├── database_provider.dart   # DatabaseHelper 单例
│   ├── books_provider.dart      # 图书列表 + 添加（含抓取）+ 删除
│   ├── rules_provider.dart      # 规则 CRUD
│   └── reader_provider.dart     # 阅读状态 + 分页 + 进度
├── pages/
│   ├── bookshelf_page.dart      # 书架首页（网格）
│   ├── add_book_page.dart       # URL 粘贴 + 规则选择 + 预览 + 调试面板
│   ├── reader_page.dart         # 沉浸式阅读器（三分区触摸 + 菜单）
│   ├── rules_page.dart          # 规则列表
│   ├── rule_editor_page.dart    # JSON 编辑器 + 校验
│   └── toc_page.dart            # 章节目录导航
└── widgets/
    └── reader_menu.dart         # 阅读菜单栏（字号/亮度/夜间/目录）
```

## JSON 规则 Schema

### 选择器语法

| 写法 | 含义 |
|------|------|
| `.class` | CSS 选择器，取第一个匹配元素 |
| `div.content @href` | 取元素的 href 属性值 |
| `self::text` | 当前元素自身的文本（仅 chapterList.item 内使用） |
| `self::@href` | 当前元素自身的属性（仅 chapterList.item 内使用） |

### 完整示例（含章节列表 + 章节内翻页，两者可共存）

```json
{
  "name": "规则名",
  "baseUrl": "https://www.example.com",
  "book": {
    "title": "#info h1",
    "author": "#info p:nth-child(2)",
    "cover": "#fmimg img @src",
    "description": "#intro"
  },
  "chapterList": {
    "container": "#list",
    "item": "dd a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "title": ".bookname h1",
    "body": "#content",
    "nextPage": ".bottem1 a:nth-child(4) @href",
    "filters": ["script", "style", "div[style]"]
  }
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| name | 是 | 规则唯一名称 |
| baseUrl | 否 | 站点根 URL，用于补全相对路径 |
| book.* | 否 | 书籍信息提取（不填则跳过） |
| chapterList | 否 | 章节目录提取（不填则无法跳转章节） |
| chapterList.url | 否 | 目录页 URL 选择器（目录在另一页面时用）；**注意：如果章节列表在图书详情同一页，不要填此字段，否则会导致错误的 URL 拼接** |
| chapterList.container | 是 | 章节列表容器选择器 |
| chapterList.item | 是 | 每个章节项的选择器 |
| chapterList.title | 是 | 章节标题在 item 内的选择器 |
| chapterList.href | 是 | 章节链接在 item 内的选择器 |
| chapterList.hrefPattern | 否 | 当链接为 `javascript:` 伪协议时，用此模板从 JS 参数重建真实 URL。`$1` `$2` 对应第 1、2 个参数，如 `"/book/$1/$2.html"` |
| chapterList.order | 否 | 章节排列顺序，`"asc"`（正序，默认）或 `"desc"`（倒序）。部分站点目录从新到旧排列，设为 `"desc"` 即可翻转 |
| content | 是 | 正文提取规则 |
| content.body | 是 | 正文容器选择器 |
| content.nextPage | 否 | 章节内翻页的"下一页"链接选择器（填了则自动跟随翻页，最多 20 页） |
| content.filters | 否 | 需要过滤的元素选择器列表 |

> **`chapterList` 和 `content.nextPage` 是独立功能，可以只用其中一个，也可以两个同时用。** 有章节列表的站点通常每章还有多页（下一页链接），两者共存是常态。

## 核心行为

- **编码**：用 `charset` 包自动检测（无需在规则里写 encoding）
- **章节内分页**：抓取时自动跟随 `content.nextPage` 链接，拼接多页正文（最多 20 页）
- **App 内分页**：用 TextPainter 按屏幕实际高度排版，每页恰好填满一屏，横向滑动翻页
- **进度记录**：章节号 + 页内页码，退出重进恢复到离开位置
- **TLS 兼容**：自动放宽证书校验，HTTPS 失败时回退 HTTP

## 开发命令

```bash
flutter pub get              # 安装依赖
flutter analyze              # 静态检查
flutter test                 # 运行测试
flutter build apk --debug    # 构建 debug APK
adb install -r build/app/outputs/flutter-apk/app-debug.apk  # 保留数据安装
```

## 限制

- 仅支持服务端渲染的 HTML 页面（SPA/JS 动态渲染不支持）
- WebView 或 JS 执行不在当前范围内
- 测试文件 `test/fetch_test.dart` 是 PC 端调试用的独立脚本
