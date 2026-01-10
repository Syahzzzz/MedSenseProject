import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_sense_application/screens/chat/chat_screen.dart';

class PatientSelectionView extends StatefulWidget {
  final String staffId;

  const PatientSelectionView({super.key, required this.staffId});

  @override
  State<PatientSelectionView> createState() => _PatientSelectionViewState();
}

class _PatientSelectionViewState extends State<PatientSelectionView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    try {
      final response = await _supabase
          .from('Patient')
          .select('patient_id, name, email, phone_number')
          .order('name', ascending: true);
      
      if (mounted) {
        setState(() {
          _allPatients = List<Map<String, dynamic>>.from(response);
          _filteredPatients = _allPatients;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching patients: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patients: $e')),
        );
      }
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        final name = (patient['name'] ?? '').toString().toLowerCase();
        final email = (patient['email'] ?? '').toString().toLowerCase();
        final phone = (patient['phone_number'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Patient"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                    ? const Center(child: Text("No patients found"))
                    : ListView.separated(
                        itemCount: _filteredPatients.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey.shade100,
                              child: Text(
                                (patient['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(patient['name'] ?? 'Unknown'),
                            subtitle: Text(patient['email'] ?? 'No Email'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    isBot: false,
                                    receiverId: patient['patient_id'],
                                    receiverName: patient['name'] ?? 'Patient',
                                    senderType: 'staff',
                                    customCurrentUserId: widget.staffId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
