class Rule {
  final int? id;
  final String name;
  final String config;
  final int updatedAt;

  const Rule({
    this.id,
    required this.name,
    required this.config,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'config': config,
        'updated_at': updatedAt,
      };

  factory Rule.fromMap(Map<String, dynamic> map) => Rule(
        id: map['id'] as int?,
        name: map['name'] as String,
        config: map['config'] as String,
        updatedAt: map['updated_at'] as int,
      );
}
