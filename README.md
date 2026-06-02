# WildRead

个人安卓小说阅读器，通过 JSON 规则动态适配不同网站。

## 技术栈

Flutter + Riverpod + dio + html + sqflite

## 使用流程

1. **创建规则** — 规则管理页 → 新建 → 手写 JSON 规则（参考下面 Schema）
2. **添加图书** — 粘贴小说详情页 URL → 选择规则 → 预览 → 加入书架
3. **开始阅读** — 点击图书 → 横向滑动翻页，点击屏幕中间呼出菜单

## JSON 规则 Schema

### 选择器语法

| 写法 | 含义 |
|------|------|
| `.class` | CSS 选择器，取第一个匹配元素 |
| `div.content @href` | 取元素的 href 属性值 |
| `self::text` | 当前元素自身的文本（仅 chapterList.item 内使用） |
| `self::@href` | 当前元素自身的属性（仅 chapterList.item 内使用） |

### 完整示例

```json
{
  "name": "完整站规则",
  "baseUrl": "https://www.example.com",
  "encoding": "utf-8",
  "book": {
    "title": ".book-info h1",
    "author": ".book-info .author",
    "cover": ".book-cover img @src",
    "description": ".book-desc"
  },
  "chapterList": {
    "url": ".book-nav a @href",
    "container": "#list",
    "item": "dd a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "title": ".bookname h1",
    "body": "#content",
    "nextPage": ".bottem1 a:nth-child(4) @href",
    "filters": ["script", "style", ".ad"]
  }
}
```

### 最简示例（只有翻页、没有目录）

```json
{
  "name": "翻页站",
  "content": {
    "title": ".page-title",
    "body": ".page-content",
    "nextPage": "a.next @href",
    "filters": [".comment", "script"]
  }
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 规则唯一名称 |
| `baseUrl` | 否 | 基础 URL，用于补全相对路径 |
| `encoding` | 否 | 网页编码，默认 utf-8，支持 gbk/gb2312 |
| `book` | 否 | 书籍信息（不填则跳过书籍信息提取） |
| `book.title` | 否 | 书名选择器 |
| `book.author` | 否 | 作者选择器 |
| `book.cover` | 否 | 封面图选择器 |
| `book.description` | 否 | 简介选择器 |
| `chapterList` | 否 | 章节目录提取（**章节间跳转**）。不填则没有目录，只能顺序翻页 |
| `chapterList.url` | 否 | 目录页 URL 选择器（目录在另一页面时用） |
| `chapterList.container` | 是 | 章节列表容器选择器 |
| `chapterList.item` | 是 | 列表项选择器 |
| `chapterList.title` | 是 | 章节标题在当前项内的选择器 |
| `chapterList.href` | 是 | 章节链接在当前项内的选择器 |
| `chapterList.order` | 否 | 章节排列顺序，`"asc"`（正序，默认）或 `"desc"`（倒序）。目录从新到旧的站点设 `"desc"` |
| `content` | 是 | 正文提取 |
| `content.title` | 否 | 章节标题选择器 |
| `content.body` | 是 | 正文容器选择器 |
| `content.nextPage` | 否 | **章节内翻页**的"下一页"链接选择器（章节跨多页时用） |
| `content.filters` | 否 | 需过滤的元素选择器列表 |

> **`chapterList` 和 `content.nextPage` 是独立功能，可以单独用也可以同时用。**
> - `chapterList` 控制**章节之间**的跳转（提取目录 → 按章节阅读）
> - `content.nextPage` 控制**一个章节内**的翻页（章节内容跨多个 HTML 页时自动拼接，最多 20 页）
> - 大多数小说站**两者都需要**：有章节目录 + 每章又分多页

## 开发

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter install --debug
```

## 限制

- 仅支持**服务端渲染**的 HTML 页面（SPA/JS 动态渲染网站不支持）
- 编码自动检测（charset 包），无需手动指定
- 网络请求自动重试 3 次，HTTPS 失败自动回退 HTTP
