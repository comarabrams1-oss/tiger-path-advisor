class Instructor {
  final String id;
  final String name;
  final String department;

  const Instructor({
    required this.id,
    required this.name,
    required this.department,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
    };
  }
}