class TodoItem {
  String title;
  bool isCompleted;
  DateTime? reminderTime;

  TodoItem({
    required this.title,
    this.isCompleted = false,
    this.reminderTime,
  });

  // Convert TodoItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }

  // Create TodoItem from JSON
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      title: json['title'],
      isCompleted: json['isCompleted'],
      reminderTime: json['reminderTime'] != null
          ? DateTime.parse(json['reminderTime'])
          : null,
    );
  }
}