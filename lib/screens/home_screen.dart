import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/todo_item.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<TodoItem> _todos = [];
  List<Map<String, String>> _notes = [];
  final _todoController = TextEditingController();
  final _noteHeadingController = TextEditingController();
  final _noteContentController = TextEditingController();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _loadData(); // Call _loadData to load saved data when the screen starts
  }

  // Load todos and notes from SharedPreferences
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load todos
    final String? todosString = prefs.getString('todos');
    if (todosString != null) {
      final List<dynamic> todosJson = jsonDecode(todosString);
      setState(() {
        _todos = todosJson.map((json) => TodoItem.fromJson(json)).toList();
      });
    }

    // Load notes (THIS IS WHERE YOUR CODE GOES)
    final String? notesString = prefs.getString('notes');
    if (notesString != null) {
      final List<dynamic> notesJson = jsonDecode(notesString);
      setState(() {
        _notes = notesJson.map((json) => Map<String, String>.from(json)).toList();
      });
    }
  }

  // Save todos and notes to SharedPreferences
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = _todos.map((todo) => todo.toJson()).toList();
    await prefs.setString('todos', jsonEncode(todosJson));
    final notesJson = _notes;
    await prefs.setString('notes', jsonEncode(notesJson));
  }

  void _addTodo() {
    if (_todoController.text.isNotEmpty) {
      setState(() {
        _todos.add(TodoItem(title: _todoController.text));
        _todoController.clear();
      });
      _saveData();
    }
  }

  void _deleteTodo(int index) async {
    if (_todos[index].reminderTime != null) {
      await flutterLocalNotificationsPlugin.cancel(_todos[index].hashCode);
    }
    setState(() {
      _todos.removeAt(index);
    });
    _saveData();
  }

  void _addNote() {
    if (_noteHeadingController.text.isNotEmpty && _noteContentController.text.isNotEmpty) {
      setState(() {
        _notes.add({
          'heading': _noteHeadingController.text,
          'content': _noteContentController.text,
        });
        _noteHeadingController.clear();
        _noteContentController.clear();
      });
      _saveData();
    }
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
    _saveData();
  }

  Future<void> _setReminderForTask(BuildContext context, int index) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final reminderTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _todos[index].reminderTime = reminderTime;
        });
        await _scheduleNotification(_todos[index]);
        _saveData();
      }
    }
  }

  Future<void> _scheduleNotification(TodoItem todo) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'todo_channel_id',
      'To-Do Reminders',
      channelDescription: 'Notifications for To-Do tasks',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      todo.hashCode,
      'Task Reminder: ${todo.title}',
      'Time to complete your task!',
      tz.TZDateTime.from(todo.reminderTime!, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Welcome, ${widget.userName}!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _todoController,
              decoration: InputDecoration(
                labelText: 'Add a task',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addTodo,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _todos.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.white.withOpacity(0.9),
                    child: ListTile(
                      title: Text(
                        _todos[index].title,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      subtitle: _todos[index].reminderTime != null
                          ? Text(
                              'Reminder: ${_todos[index].reminderTime!.toString().substring(0, 16)}',
                              style: const TextStyle(color: Colors.black54),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.alarm, color: Colors.blue),
                            onPressed: () => _setReminderForTask(context, index),
                          ),
                          Checkbox(
                            value: _todos[index].isCompleted,
                            onChanged: (value) {
                              setState(() {
                                _todos[index].isCompleted = value!;
                              });
                              _saveData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTodo(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Your Notes',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteHeadingController,
              decoration: InputDecoration(
                labelText: 'Note Heading',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteContentController,
              decoration: InputDecoration(
                labelText: 'Note Content',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addNote,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.white.withOpacity(0.9),
                    child: ListTile(
                      title: Text(
                        _notes[index]['heading']!,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _notes[index]['content']!,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNote(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1A237E),
              Color(0xFF4A148C),
              Color(0xFF880E4F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: screens[_selectedIndex],
      ),
      appBar: AppBar(
        title: Text(
          'To-Do Master',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.black.withOpacity(0.2),
        indicatorColor: Colors.white.withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task, color: Colors.white),
            selectedIcon: Icon(Icons.task, color: Colors.yellowAccent),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.note, color: Colors.white),
            selectedIcon: Icon(Icons.note, color: Colors.yellowAccent),
            label: 'Notes',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedIndex == 0 ? _addTodo : _addNote,
        backgroundColor: const Color(0xFFFF4081),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _todoController.dispose();
    _noteHeadingController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }
}