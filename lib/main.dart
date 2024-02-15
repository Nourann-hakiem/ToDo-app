import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDirectory =
  await path_provider.getApplicationDocumentsDirectory();
  print('Hive database folder path: ${appDocumentDirectory.path}');
  Hive.init(appDocumentDirectory.path);
  Hive.registerAdapter(TodoAdapter());
  await Hive.openBox<Todo>('todos');
  runApp(MyApp());
}

class Todo extends HiveObject {
  String title;
  String description; // Added description field
  bool isDone;
  bool isDeleted;

  Todo({
    required this.title,
    this.description = '', // Initialized with an empty description
    this.isDone = false,
    this.isDeleted = false,
  });

  int get key => super.key as int;
}

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    try {
      return Todo(
        title: reader.read(),
        description: reader.read(),
        isDone: reader.readBool(),
      );
    } catch (e) {
      print('Error reading todo: $e');
      return Todo(
        title: 'Error',
        description: 'Error reading todo',
        isDone: false,
      );
    }
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer.write(obj.title);
    writer.write(obj.description);
    writer.writeBool(obj.isDone);
  }
}




class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: TodoScreen(
        toggleDarkMode: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
      ),
    );
  }
}

class TodoScreen extends StatefulWidget {
  final VoidCallback toggleDarkMode;

  TodoScreen({required this.toggleDarkMode});

  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late Box<Todo> todoBox;
  String filter = 'All';
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    todoBox = Hive.box<Todo>('todos');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'To-Do List',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Switch(
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
                widget.toggleDarkMode();
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_alt),
            iconSize: 50,
            onPressed: () {
              _showFilterOptions(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<BoxEvent>(
        stream: todoBox.watch(),
        builder: (context, snapshot) {
          final todos = todoBox.values.toList();

          final filteredTodos = _getFilteredTodos(todos);
          return ListView.builder(
            itemCount: filteredTodos.length,
            itemBuilder: (context, index) {
              final todo = filteredTodos[index];
              return Dismissible(
                key: Key(todo.title),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                onDismissed: (direction) {
                  _deleteTodo(todo);
                },
                child: Card(
                  elevation: 3,
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      todo.title,
                    ),
                    subtitle: Text( // Display description as subtitle
                      todo.description,
                    ),
                    leading: Checkbox(
                      value: todo.isDone,
                      onChanged: (bool? value) {
                        _toggleDone(todo);
                      },
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        _editTodo(todo); // Call function to edit todo
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        child: Icon(Icons.add),
      ),
    );
  }

  List<Todo> _getFilteredTodos(List<Todo> todos) {
    if (filter == 'Done') {
      return todos.where((todo) => todo.isDone && !todo.isDeleted).toList();
    } else if (filter == 'Not Done') {
      return todos.where((todo) => !todo.isDone && !todo.isDeleted).toList();
    } else {
      return todos.where((todo) => !todo.isDeleted).toList();
    }
  }

  void _addTodo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newTodoTitle = '';
        String newTodoDescription = ''; // Initialize description
        return AlertDialog(
          title: Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                onChanged: (value) {
                  newTodoTitle = value;
                },
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                onChanged: (value) {
                  newTodoDescription = value;
                },
                decoration: InputDecoration(labelText: 'Description'), // Add input field for description
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newTodoTitle.isNotEmpty) {
                  final newTodo = Todo(
                    title: newTodoTitle,
                    description: newTodoDescription, // Pass description to Todo object
                  );
                  todoBox.add(newTodo);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTodo(Todo todo) {
    todo.delete();
  }

  void _toggleDone(Todo todo) {
    todo.isDone = !todo.isDone;
    todo.save();
  }

  void _editTodo(Todo todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String updatedTitle = todo.title;
        String updatedDescription = todo.description; // Initialize with current description
        return AlertDialog(
          title: Text('Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: todo.title),
                onChanged: (value) {
                  updatedTitle = value;
                },
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller:
                TextEditingController(text: todo.description), // Set initial text
                onChanged: (value) {
                  updatedDescription = value; // Update the description as text changes
                },
                decoration: InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (updatedTitle.isNotEmpty) {
                  todo.title = updatedTitle;
                  todo.description = updatedDescription; // Update the description
                  todo.save();
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('All'),
              onTap: () {
                setState(() {
                  filter = 'All';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Done'),
              onTap: () {
                setState(() {
                  filter = 'Done';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Not Done'),
              onTap: () {
                setState(() {
                  filter = 'Not Done';
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
