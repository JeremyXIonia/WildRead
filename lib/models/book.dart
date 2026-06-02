class Book {
  final int? id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final String sourceUrl;
  final String ruleName;
  final int createdAt;

  const Book({
    this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    required this.sourceUrl,
    required this.ruleName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'author': author,
        'cover_url': coverUrl,
        'description': description,
        'source_url': sourceUrl,
        'rule_name': ruleName,
        'created_at': createdAt,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as int?,
        title: map['title'] as String,
        author: map['author'] as String?,
        coverUrl: map['cover_url'] as String?,
        description: map['description'] as String?,
        sourceUrl: map['source_url'] as String,
        ruleName: map['rule_name'] as String,
        createdAt: map['created_at'] as int,
      );

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverUrl,
    String? description,
    String? sourceUrl,
    String? ruleName,
    int? createdAt,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        coverUrl: coverUrl ?? this.coverUrl,
        description: description ?? this.description,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        ruleName: ruleName ?? this.ruleName,
        createdAt: createdAt ?? this.createdAt,
      );
}
