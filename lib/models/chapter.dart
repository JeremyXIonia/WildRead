class Chapter {
  final int? id;
  final int bookId;
  final String title;
  final String url;
  final int index;
  final String? content;
  final String? pages;

  const Chapter({
    this.id,
    required this.bookId,
    required this.title,
    required this.url,
    required this.index,
    this.content,
    this.pages,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'title': title,
        'url': url,
        'index': index,
        'content': content,
        'pages': pages,
      };

  factory Chapter.fromMap(Map<String, dynamic> map) => Chapter(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        title: map['title'] as String,
        url: map['url'] as String,
        index: map['index'] as int,
        content: map['content'] as String?,
        pages: map['pages'] as String?,
      );
}
