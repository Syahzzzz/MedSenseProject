import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffManagementView extends StatefulWidget {
  const StaffManagementView({super.key});

  @override
  State<StaffManagementView> createState() => _StaffManagementViewState();
}

class _StaffManagementViewState extends State<StaffManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // Data Lists
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _doctorList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final staffRes = await _supabase
          .from('Staff')
          .select()
          .order('name', ascending: true);
      
      final docRes = await _supabase
          .from('Doctor')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(staffRes);
          _doctorList = List<Map<String, dynamic>>.from(docRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- STAFF OPERATIONS ---

  Future<bool> _confirmDeletionWithPassword() async {
    final codeCtrl = TextEditingController();
    // Generate random 5-digit number
    final String randomCode = (10000 + (DateTime.now().microsecondsSinceEpoch % 90000)).toString();

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This action cannot be undone. To confirm, please enter the code below:"),
            const SizedBox(height: 15),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Text(
                  randomCode,
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 5,
                    color: Colors.black87
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Enter Code',
                border: OutlineInputBorder(),
                hintText: 'XXXXX'
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (codeCtrl.text.trim() == randomCode) {
                 Navigator.pop(context, true);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Incorrect code. Please try again."), backgroundColor: Colors.red),
                 );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteStaff(String id) async {
    final confirmed = await _confirmDeletionWithPassword();
    if (!confirmed) return;

    try {
      await _supabase.from('Staff').delete().eq('staff_id', id);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showStaffDialog({Map<String, dynamic>? staff}) {
    final nameCtrl = TextEditingController(text: staff?['name']);
    final emailCtrl = TextEditingController(text: staff?['email']);
    final passCtrl = TextEditingController(text: staff != null ? '' : ''); // Don't show hash
    final roleCtrl = TextEditingController(text: staff?['role'] ?? 'Staff');
    
    bool isActive = staff?['is_active'] ?? true;
    bool isAdmin = staff?['is_admin'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  TextField(
                    controller: passCtrl, 
                    decoration: InputDecoration(labelText: staff == null ? 'Password' : 'New Password (leave empty to keep)'),
                    obscureText: true,
                  ),
                  TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role (e.g. Admin, Nurse)')),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text("Is Active"),
                    value: isActive,
                    onChanged: (v) => setState(() => isActive = v!),
                  ),
                  CheckboxListTile(
                    title: const Text("Is Admin"),
                    value: isAdmin,
                    onChanged: (v) => setState(() => isAdmin = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final Map<String, dynamic> data = {
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'role': roleCtrl.text,
                    'is_active': isActive,
                    'is_admin': isAdmin,
                  };
                  
                  if (passCtrl.text.isNotEmpty) {
                    data['password_hash'] = passCtrl.text; // Storing plain for now as per schema implication or simple mock
                  }

                  try {
                    if (staff == null) {
                      await _supabase.from('Staff').insert(data);
                    } else {
                      await _supabase.from('Staff').update(data).eq('staff_id', staff['staff_id']);
                    }
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _fetchData();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- DOCTOR OPERATIONS ---

  Future<void> _deleteDoctor(String id) async {
    final confirmed = await _confirmDeletionWithPassword();
    if (!confirmed) return;

    try {
      await _supabase.from('Doctor').delete().eq('doctor_id', id);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showDoctorDialog({Map<String, dynamic>? doctor}) {
    final nameCtrl = TextEditingController(text: doctor?['name']);
    final specCtrl = TextEditingController(text: doctor?['specialization']);
    final expCtrl = TextEditingController(text: doctor?['years_experience']?.toString() ?? '0');
    bool isAvailable = doctor?['is_available'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(doctor == null ? 'Add Doctor' : 'Edit Doctor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specialization')),
                  TextField(
                    controller: expCtrl, 
                    decoration: const InputDecoration(labelText: 'Years Experience'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text("Is Available"),
                    value: isAvailable,
                    onChanged: (v) => setState(() => isAvailable = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final Map<String, dynamic> data = {
                    'name': nameCtrl.text,
                    'specialization': specCtrl.text,
                    'years_experience': int.tryParse(expCtrl.text) ?? 0,
                    'is_available': isAvailable,
                  };

                  try {
                    if (doctor == null) {
                      await _supabase.from('Doctor').insert(data);
                    } else {
                      await _supabase.from('Doctor').update(data).eq('doctor_id', doctor['doctor_id']);
                    }
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _fetchData();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFBC02D);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Doctor Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          indicatorColor: primaryYellow,
          tabs: const [
            Tab(text: "Staff Members", icon: Icon(Icons.badge)),
            Tab(text: "Doctors", icon: Icon(Icons.medical_services)),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryYellow))
        : TabBarView(
            controller: _tabController,
            children: [
              // STAFF TAB
              Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _staffList.length,
                    itemBuilder: (context, index) {
                      final item = _staffList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: const Icon(Icons.person, color: Colors.orange),
                          ),
                          title: Text(item['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['role']} • ${item['email']}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showStaffDialog(staff: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteStaff(item['staff_id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: primaryYellow,
                      onPressed: () => _showStaffDialog(),
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                  )
                ],
              ),
              
              // DOCTORS TAB
              Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _doctorList.length,
                    itemBuilder: (context, index) {
                      final item = _doctorList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: const Icon(Icons.medical_services, color: Colors.blue),
                          ),
                          title: Text(item['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['specialization']} • ${item['years_experience']} yrs exp"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showDoctorDialog(doctor: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteDoctor(item['doctor_id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: primaryYellow,
                      onPressed: () => _showDoctorDialog(),
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                  )
                ],
              ),
            ],
          ),
    );
  }
}
