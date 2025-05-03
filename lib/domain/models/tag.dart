
class Tag {
  final int? id;
  final String name;

  Tag({
    this.id,
    required this.name,
  });

  // Factory method to create Tag from a Map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['_id'],
      name: map['NAME'],
    );
  }

  // Convert Tag to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'NAME': name,
    };
  }

  // Create a copy of this Tag with given fields replaced with new values
  Tag copyWith({
    int? id,
    String? name,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}