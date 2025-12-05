import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Global Configuration: Default Roster (Initial class data) ---
const String DEFAULT_CLASS_NAME = "Main Batch 2024";
const Map<String, List<int>> DEFAULT_CLASS_GROUPS = {
  "Main Batch Students": [160623733128, 160623733192],
  "Lateral Entries": [1606237333313, 1606237333318],
};

// --- 1. Data Model ---
class Student {
  final String id;
  final String name;
  bool isPresent;

  Student({required this.id, required this.name, this.isPresent = false});

  Student copyWith({bool? isPresent}) {
    return Student(id: id, name: name, isPresent: isPresent ?? this.isPresent);
  }
}

// --- 2. State Management (Provider) ---
class AttendanceProvider extends ChangeNotifier {
  // Key: Class Name (e.g., "M-Tech 101"), Value: Map of Grouped Students
  Map<String, Map<String, List<Student>>> _allClassData = {};
  String? _activeClassName;

  AttendanceProvider() {
    // Load the initial default class on startup
    _allClassData[DEFAULT_CLASS_NAME] = _generateStudentGroups(
      DEFAULT_CLASS_GROUPS,
    );
    _activeClassName = DEFAULT_CLASS_NAME;
    notifyListeners();
  }

  // Current active group data
  Map<String, List<Student>> get activeGroupedStudents {
    if (_activeClassName != null &&
        _allClassData.containsKey(_activeClassName)) {
      return _allClassData[_activeClassName]!;
    }
    return {};
  }

  // List of all class names for the dropdown selector
  List<String> get classNames => _allClassData.keys.toList();

  String? get activeClassName => _activeClassName;

  // Public method to switch the active class
  void setActiveClass(String className) {
    if (_allClassData.containsKey(className)) {
      _activeClassName = className;
      notifyListeners();
    }
  }

  // Public method called by the UI to define and load a new class
  void addNewClassRoster(String className, Map<String, List<int>> rollRanges) {
    // 1. Generate the student list based on the roll ranges
    final newGroupedStudents = _generateStudentGroups(rollRanges);

    // 2. Add or replace the class data in the master map
    _allClassData[className] = newGroupedStudents;

    // 3. Set the newly added class as active
    _activeClassName = className;

    notifyListeners();
  }

  // Utility to generate student data from the map of roll number ranges
  Map<String, List<Student>> _generateStudentGroups(
    Map<String, List<int>> rollRanges,
  ) {
    Map<String, List<Student>> newGroups = {};

    rollRanges.forEach((groupName, range) {
      if (range.length == 2 && range[0] <= range[1]) {
        int startId = range[0];
        int endId = range[1];
        List<Student> students = [];

        // Generate sequential student IDs
        for (int i = startId; i <= endId; i++) {
          String idString = i.toString();
          students.add(Student(id: idString, name: idString));
        }

        newGroups[groupName] = students;
      }
    });
    return newGroups;
  }

  // Flattens the active class's map into a single list for calculations
  List<Student> get allActiveStudents =>
      activeGroupedStudents.values.expand((list) => list).toList();

  // Calculated derived state for summary
  int get totalStudents => allActiveStudents.length;
  int get presentCount => allActiveStudents.where((s) => s.isPresent).length;
  int get absentCount => totalStudents - presentCount;

  // Toggles attendance for a student in the active class
  void toggleAttendance(String studentId, bool value) {
    bool updated = false;
    final groups = activeGroupedStudents;

    for (var groupName in groups.keys) {
      int index = groups[groupName]!.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        // Find the student and update their status using copyWith
        groups[groupName]![index] = groups[groupName]![index].copyWith(
          isPresent: value,
        );
        updated = true;
        break;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  // Marks all students in the active class as present/absent
  void markAll(bool present) {
    final groups = activeGroupedStudents;

    groups.forEach((key, list) {
      groups[key] = list.map((student) {
        return student.copyWith(isPresent: present);
      }).toList();
    });
    notifyListeners();
  }
}

// --- 3. Main Entry Point ---
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AttendanceProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Multi-Class Attendance Tracker',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: AttendanceScreen(),
    );
  }
}

// --- 4. UI Implementation (Screen) ---
class AttendanceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Attendance Groups"),
        // Use Consumer for real-time updates to the class selector
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Consumer<AttendanceProvider>(
            builder: (context, attendanceProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      "Active Class: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    DropdownButton<String>(
                      value: attendanceProvider.activeClassName,
                      items: attendanceProvider.classNames.map((
                        String className,
                      ) {
                        return DropdownMenuItem<String>(
                          value: className,
                          child: Text(
                            className,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newClass) {
                        if (newClass != null) {
                          attendanceProvider.setActiveClass(newClass);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Mark All Present',
            onPressed: () => provider.markAll(true),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Mark All Absent',
            onPressed: () => provider.markAll(false),
          ),
          // Button to define or manage classes
          IconButton(
            icon: const Icon(Icons.class_),
            tooltip: 'Define/Manage Classes',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => ChangeRosterDialog(),
            ),
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, child) {
          final groups = attendanceProvider.activeGroupedStudents;
          final groupKeys = groups.keys.toList();

          if (groupKeys.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No students loaded in this class. Use the dropdown or the class icon 👨‍🏫 to define a roster.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80.0),
            itemCount: groupKeys.length,
            itemBuilder: (context, index) {
              final groupName = groupKeys[index];
              final studentList = groups[groupName]!;
              return GroupedAttendanceTile(
                groupName: groupName,
                students: studentList,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.analytics),
        label: const Text("Daily Summary"),
        onPressed: () => _showSummaryDialog(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- UPDATED WIDGET: Dialog for User Input and Adding New Classes ---
class ChangeRosterDialog extends StatefulWidget {
  @override
  _ChangeRosterDialogState createState() => _ChangeRosterDialogState();
}

class _ChangeRosterDialogState extends State<ChangeRosterDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _group1NameController = TextEditingController(
    text: "Group A",
  );
  final TextEditingController _group1StartController = TextEditingController();
  final TextEditingController _group1EndController = TextEditingController();
  final TextEditingController _group2NameController = TextEditingController(
    text: "Group B",
  );
  final TextEditingController _group2StartController = TextEditingController();
  final TextEditingController _group2EndController = TextEditingController();

  // Simple validator to ensure input is a valid integer string
  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    if (int.tryParse(value) == null) {
      return 'Must be a number';
    }
    return null;
  }

  void _addNewClass() {
    if (_formKey.currentState!.validate()) {
      // 1. Collect and parse data
      final className = _classNameController.text.trim();

      // Prevent saving if class name is empty or just whitespace
      if (className.isEmpty) return;

      final newRollRanges = {
        _group1NameController.text.trim(): [
          int.parse(_group1StartController.text.trim()),
          int.parse(_group1EndController.text.trim()),
        ],
        _group2NameController.text.trim(): [
          int.parse(_group2StartController.text.trim()),
          int.parse(_group2EndController.text.trim()),
        ],
      };

      // 2. Call the provider method to add the class and set it as active
      Provider.of<AttendanceProvider>(
        context,
        listen: false,
      ).addNewClassRoster(className, newRollRanges);

      // 3. Close the dialog
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _group1NameController.dispose();
    _group1StartController.dispose();
    _group1EndController.dispose();
    _group2NameController.dispose();
    _group2StartController.dispose();
    _group2EndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Define New Class Roster"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // New Class Name Input
              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'New Class Name (e.g., M-Tech 101)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Class Name is Required'
                    : null,
              ),
              const SizedBox(height: 20),

              // Group 1: Roll Range Input
              _buildGroupFields(
                'First Student Group Definition',
                _group1NameController,
                _group1StartController,
                _group1EndController,
              ),
              const Divider(height: 30),

              // Group 2: Roll Range Input
              _buildGroupFields(
                'Second Student Group Definition',
                _group2NameController,
                _group2StartController,
                _group2EndController,
              ),
              const SizedBox(height: 16),
              const Text(
                "Warning: Adding a new class will save it and make it the active class. Attendance data for previous classes is preserved.",
                style: TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: _addNewClass,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          child: const Text(
            "ADD & LOAD CLASS",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupFields(
    String title,
    TextEditingController nameController,
    TextEditingController startController,
    TextEditingController endController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: 'Start Roll No.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _validateNumber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: endController,
                decoration: const InputDecoration(
                  labelText: 'End Roll No.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _validateNumber,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- 5. Grouped List Widget (No changes) ---
class GroupedAttendanceTile extends StatelessWidget {
  final String groupName;
  final List<Student> students;

  const GroupedAttendanceTile({
    required this.groupName,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final presentCount = students.where((s) => s.isPresent).length;
    final totalCount = students.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      child: ExpansionTile(
        initiallyExpanded: true,
        backgroundColor: Colors.indigo.shade50,
        collapsedBackgroundColor: Colors.white,
        title: Text(
          groupName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Present: $presentCount / Total: $totalCount',
          style: TextStyle(
            color: presentCount == totalCount
                ? Colors.green
                : Colors.grey.shade700,
          ),
        ),
        children: students
            .map((student) => StudentTile(student: student))
            .toList(),
      ),
    );
  }
}

// --- 6. Reusable Student Widget (No changes) ---
class StudentTile extends StatelessWidget {
  final Student student;
  const StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    return ListTile(
      tileColor: student.isPresent ? Colors.green.shade50 : Colors.red.shade50,
      leading: CircleAvatar(
        backgroundColor: student.isPresent ? Colors.green : Colors.red,
        child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
      ),
      title: Text(
        student.name, // Full Roll Number (ID)
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: student.isPresent
              ? Colors.green.shade900
              : Colors.red.shade900,
        ),
      ),
      trailing: Switch(
        value: student.isPresent,
        activeColor: Colors.green,
        inactiveThumbColor: Colors.red,
        onChanged: (value) {
          provider.toggleAttendance(student.id, value);
        },
      ),
    );
  }
}

// --- 7. Summary Dialog Function (No changes) ---
void _showSummaryDialog(BuildContext context) {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        "Daily Attendance Summary 📊 - ${provider.activeClassName ?? 'Class'}",
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(
            "Total Enrollment",
            provider.totalStudents,
            Colors.blue,
          ),
          const Divider(),
          _buildSummaryRow("Present", provider.presentCount, Colors.green),
          _buildSummaryRow("Absent", provider.absentCount, Colors.red),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CLOSE", style: TextStyle(color: Colors.indigo)),
        ),
      ],
    ),
  );
}

Widget _buildSummaryRow(String label, int count, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        Text(
          "$count",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
