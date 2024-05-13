import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/todologo.png', height: 20),
            SizedBox(width: 10),
            Text('TODO'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: _showProfileDialog,
          ),
          IconButton(
            icon: Icon(Icons.vpn_key),
            onPressed: _showChangePasswordDialog,
          ),
        ],
      ),
      body: user == null ? Center(child: Text('Please log in.')) : _buildTaskList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () => _addOrEditTask(context),
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.done_all), label: 'Completed'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildTaskList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tasks')
          .where('userId', isEqualTo: user!.uid)
          .where('completed', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        var tasks = snapshot.data!.docs;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            var task = tasks[index].data() as Map<String, dynamic>;
            DateTime dueTime = (task['dueTime'] as Timestamp).toDate();
            bool isOverdue = dueTime.isBefore(DateTime.now());
            return ListTile(
              title: Text(task['title'], style: TextStyle(color: isOverdue ? Colors.red : null)),
              subtitle: Text('Due by: ${DateFormat('yyyy-MM-dd HH:mm').format(dueTime)}', style: TextStyle(color: isOverdue ? Colors.red : null)),
              trailing: _taskActions(tasks[index].id),
            );
          },
        );
      },
    );
  }

  Row _taskActions(String taskId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(Icons.edit, color: Colors.black), onPressed: () => _editTask(context, taskId)),
        IconButton(icon: Icon(Icons.check, color: Colors.blue), onPressed: () => _completeTask(taskId)),
        IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTask(taskId)),
      ],
    );
  }

  void _addOrEditTask(BuildContext context, [String? taskId]) {
    var editing = taskId != null;
    TextEditingController _titleController = TextEditingController();
    TextEditingController _dueTimeController = TextEditingController();
    if (editing) {
      _firestore.collection('tasks').doc(taskId).get().then((snapshot) {
        var data = snapshot.data() as Map<String, dynamic>;
        _titleController.text = data['title'];
        DateTime dueTime = (data['dueTime'] as Timestamp).toDate();
        _dueTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dueTime);
      });
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(editing ? 'Update Task' : 'Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: _titleController, decoration: InputDecoration(labelText: 'Task Title')),
              TextField(
                controller: _dueTimeController,
                decoration: InputDecoration(labelText: 'Due Time (yyyy-MM-dd HH:mm)'),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      picked = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                      _dueTimeController.text = DateFormat('yyyy-MM-dd HH:mm').format(picked);
                    }
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                DateTime dueTime = DateFormat('yyyy-MM-dd HH:mm').parse(_dueTimeController.text);
                if (!editing) {
                  _firestore.collection('tasks').add({
                    'title': _titleController.text,
                    'dueTime': Timestamp.fromDate(dueTime),
                    'completed': false,
                    'userId': user!.uid,
                  });
                } else {
                  _firestore.collection('tasks').doc(taskId).update({
                    'title': _titleController.text,
                    'dueTime': Timestamp.fromDate(dueTime),
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _editTask(BuildContext context, String taskId) {
    _addOrEditTask(context, taskId);
  }

  void _completeTask(String taskId) {
    _firestore.collection('tasks').doc(taskId).update({'completed': true});
  }

  void _deleteTask(String taskId) {
    _firestore.collection('tasks').doc(taskId).delete();
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Profile Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Email: ${user?.email ?? "Not available"}'),
              // Add other user details here if available
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController _passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'New Password',
            ),
            obscureText: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Change'),
              onPressed: () async {
                try {
                  await user?.updatePassword(_passwordController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Password changed successfully!")),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to change password.")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please log in to access this feature")));
      return;
    }
    switch (index) {
      case 0: Navigator.pushNamed(context, '/tasks'); break;
      case 1: Navigator.pushNamed(context, '/completedTasks'); break;
      case 2: Navigator.pushNamed(context, '/settings'); break;
    }
  }
}
