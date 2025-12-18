import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffServicesManagementView extends StatefulWidget {
  const StaffServicesManagementView({super.key});

  @override
  State<StaffServicesManagementView> createState() => _StaffServicesManagementViewState();
}

class _StaffServicesManagementViewState extends State<StaffServicesManagementView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];

  // Theme Colors
  final Color _primaryYellow = const Color(0xFFFBC02D);
  final Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('Service')
          .select()
          .order('service_name', ascending: true);

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching services: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteService(String id) async {
    try {
      await _supabase.from('Service').delete().eq('service_id', id);
      _fetchServices(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service deleted successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting service: $e')),
        );
      }
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? service}) {
    final isEditing = service != null;
    final nameController = TextEditingController(text: service?['service_name']);
    final descController = TextEditingController(text: service?['description']);
    final durationController = TextEditingController(text: service?['estimated_duration_minutes']?.toString());
    final priceController = TextEditingController(text: service?['price']?.toString());
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Service' : 'Add New Service'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Service Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (RM)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryYellow),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  
                  final name = nameController.text.trim();
                  final desc = descController.text.trim();
                  final duration = int.tryParse(durationController.text.trim());
                  final price = double.tryParse(priceController.text.trim());

                  if (name.isEmpty || duration == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill Name and Duration')),
                    );
                    setStateDialog(() => isSaving = false);
                    return;
                  }

                  try {
                    final data = {
                      'service_name': name,
                      'description': desc,
                      'estimated_duration_minutes': duration,
                      'price': price,
                    };

                    if (isEditing) {
                      await _supabase
                          .from('Service')
                          .update(data)
                          .eq('service_id', service['service_id']);
                    } else {
                      await _supabase.from('Service').insert(data);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _fetchServices();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Service updated' : 'Service added')),
                    );
                  } catch (e) {
                    debugPrint('Error saving service: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  } finally {
                    if (context.mounted) {
                       setStateDialog(() => isSaving = false);
                    }
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.black)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteService(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Services', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _primaryYellow))
          : _services.isEmpty 
              ? const Center(child: Text("No services found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          service['service_name'] ?? 'Unknown Service',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(service['description'] ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("${service['estimated_duration_minutes']} mins"),
                                const SizedBox(width: 15),
                                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(service['price'] != null ? "RM ${service['price']}" : "N/A"),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEditDialog(service: service),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(service['service_id'], service['service_name']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryYellow,
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
