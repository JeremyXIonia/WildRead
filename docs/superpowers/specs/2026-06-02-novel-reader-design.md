# 小说阅读器设计文档

**日期:** 2026-06-02
**项目:** novel-transfer

## 概述

个人使用的 Android 小说阅读器，通过 JSON 规则配置文件动态适配不同网站，支持章节模式和连续翻页模式。

## 技术栈决策

| 维度 | 选择 | 理由 |
|------|------|------|
| 框架 | Flutter | 跨平台、开发效率高、个人项目首选 |
| 状态管理 | Riverpod | Flutter 社区当前标准，类型安全 |
| HTTP 请求 | dio | 成熟稳定，拦截器/重试机制完善 |
| HTML 解析 | dart `html` 包 | 纯 Dart 实现，服务端 DOM 解析 |
| 本地存储 | sqflite (SQLite) | 结构化数据持久化 |
| 配置格式 | JSON | 原生支持，无需额外依赖 |

## 规则 Schema

### 章节模式规则

```json
{
  "name": "规则名称",
  "baseUrl": "https://www.example.com",
  "encoding": "utf-8",
  "mode": "chapter",
  "book": {
    "title": ".book-info h1",
    "author": ".book-info .author",
    "cover": ".book-cover img @src",
    "description": ".book-desc"
  },
  "chapterList": {
    "url": ".book-nav a @href",
    "container": ".chapter-list",
    "item": "li a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "title": ".chapter-title",
    "body": "#content",
    "nextPage": ".next-chapter @href",
    "filters": [".ad", ".popup", "script", "style"]
  }
}
```

### 翻页模式规则

```json
{
  "name": "某轻小说站",
  "mode": "scroll",
  "content": {
    "title": ".page-title",
    "body": ".page-content",
    "nextPage": "a.next @href",
    "filters": [".comment", "script"]
  }
}
```

### 选择器语法

- `selector` — CSS 选择器定位元素
- `selector @attr` — 提取元素的属性值（href、src 等）
- `self::text` — 当前匹配元素的文本内容
- `self::@attr` — 当前匹配元素的属性值
- `filters` — 提取正文后需要删除的元素列表

**关键设计约束:**
- 所有 CSS 选择器返回第一个匹配元素
- `filters` 在正文提取后执行 DOM 删除操作
- 相对 URL 自动基于 `baseUrl` 或当前页面 URL 补全为绝对 URL
- `encoding` 默认为 utf-8，通过 HTTP 响应头 Content-Type 自动检测

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────┐ │
│  │ 书架页面  │  │ 规则管理页 │  │ 添加图书页 │  │ 阅读器  │ │
│  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └───┬────┘ │
│       │              │              │            │      │
│       └──────────────┴──────────────┴────────────┘      │
│                          │                               │
│                    ┌─────▼─────┐                         │
│                    │  Riverpod  │                         │
│                    └─────┬─────┘                         │
│                          │                               │
│       ┌──────────────────┼──────────────────┐            │
│       │                  │                  │            │
│  ┌────▼─────┐    ┌───────▼───────┐   ┌─────▼──────┐     │
│  │ RuleEngine│    │ContentFetcher │   │  BookRepo   │     │
│  │ (规则解析) │    │  (dio+html)  │   │  (SQLite)   │     │
│  └──────────┘    └───────────────┘   └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### 模块职责

| 模块 | 职责 | 输入 | 输出 |
|------|------|------|------|
| RuleEngine | 解析 JSON 规则，生成提取指令 | JSON 规则字符串 | 结构化提取指令对象 |
| ContentFetcher | HTTP 抓取 + HTML 解析 | URL + 规则 | 结构化内容（书名/章节/正文） |
| BookRepo | 图书/章节/进度的增删改查 | SQL 操作 | 数据对象 |

### 数据流

1. **添加图书:** 用户粘贴 URL → 选规则 → ContentFetcher 抓取书名/封面/章节目录 → 展示确认 → BookRepo.insert(book)
2. **阅读章节:** 点击章节 → 检查 SQLite 中 `chapters.content` → 有则直接展示，无则 ContentFetcher 抓取 → 存入 SQLite → 展示
3. **翻页模式:** 正文按屏幕高度分页 → 到最后一页时 ContentFetcher 抓取 `nextPage` → 追加内容 → 用户无感

## 数据库 Schema

```sql
CREATE TABLE books (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT NOT NULL,
  author      TEXT,
  cover_url   TEXT,
  description TEXT,
  source_url  TEXT NOT NULL,
  rule_name   TEXT NOT NULL,
  created_at  INTEGER NOT NULL
);

CREATE TABLE chapters (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id  INTEGER NOT NULL REFERENCES books(id),
  title    TEXT NOT NULL,
  url      TEXT NOT NULL,
  index    INTEGER NOT NULL,
  content  TEXT,                    -- NULL = 未抓取
  UNIQUE(book_id, url)
);

CREATE TABLE reading_progress (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id        INTEGER NOT NULL UNIQUE REFERENCES books(id),
  chapter_index  INTEGER NOT NULL,
  scroll_offset  REAL DEFAULT 0.0,
  updated_at     INTEGER NOT NULL
);

CREATE TABLE rules (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL UNIQUE,
  config     TEXT NOT NULL,         -- 完整 JSON
  updated_at INTEGER NOT NULL
);
```

## 阅读器 UI

### 布局

- 沉浸式全屏（隐藏状态栏）
- 顶部：章节标题（小字、灰色）
- 中部：正文区（白底黑字，可调字号/行距）
- 底部：进度信息栏（淡入淡出）：页码/章节数 + 当前时间
- 支持日间/夜间模式切换

### 触摸交互

| 区域 | 行为 |
|------|------|
| 屏幕左 1/3 | 上一页 / 上一章 |
| 屏幕中 1/3 | 呼出/隐藏菜单栏 |
| 屏幕右 1/3 | 下一页 / 下一章 |

### 菜单栏（点击中部弹出）

- 字号调节 A- / A+
- 亮度调节滑块
- 日间/夜间模式切换
- 目录跳转按钮

### 章节模式 vs 翻页模式

- **章节模式:** 加载完整章节，有 `nextPage` 时支持章节内翻页，无 `nextPage` 时右滑跳转下一章
- **翻页模式:** 按固定字数/屏幕高度分页，`nextPage` 抓完后自动衔接，用户无感知

## 页面路由

| 路由 | 页面 | 说明 |
|------|------|------|
| `/` | 书架 | 首页，展示已添加图书的网格列表 |
| `/add` | 添加图书 | URL 输入框 + 规则选择下拉 + 预览确认 |
| `/reader/:bookId` | 阅读器 | 核心阅读界面，全屏沉浸 |
| `/rules` | 规则管理 | 规则列表 + 新建/编辑/删除 |
| `/rules/edit/:id` | 规则编辑器 | JSON 文本编辑 + 格式校验 + 测试抓取 |
| `/toc/:bookId` | 章节目录 | 从阅读器菜单跳转，章节列表导航 |

## 错误处理策略

| 场景 | 处理 |
|------|------|
| 网络请求失败 | dio 重试 3 次 → 提示用户检查网络 |
| HTML 选择器无匹配 | 记录日志 → 提示「规则可能已失效」 |
| JSON 规则格式错误 | 保存前实时校验 → 错误行高亮 |
| 编码检测失败 | 尝试 utf-8 → gbk → gb2312 回退 |
| SQLite 写入失败 | 捕获异常 → 提示用户检查存储空间 |

## 不做的

- 不做预置规则库（规则完全由用户自行编写管理）
- 不做登录/账号系统
- 不做书源市场/规则分享功能
- 不做阅读统计/时长记录
- 不做 EPUB/PDF 导出
