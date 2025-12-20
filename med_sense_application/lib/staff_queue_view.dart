import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffQueueView extends StatefulWidget {
  const StaffQueueView({super.key});

  @override
  State<StaffQueueView> createState() => _StaffQueueViewState();
}

class _StaffQueueViewState extends State<StaffQueueView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _queueEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
    _subscribeToQueueUpdates();
  }

  void _subscribeToQueueUpdates() {
    _supabase
        .channel('public:QueueEntry')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'QueueEntry',
          callback: (payload) {
            _fetchQueue();
          },
        )
        .subscribe();
  }

  Future<void> _fetchQueue() async {
    try {
      // Fetch active queues (Waiting or Serving)
      // We join with Patient to get names.
      // Note: Supabase syntax for joining might vary based on setup, 
      // but usually .select('*, Patient(*)') works if FK exists.
      final response = await _supabase
          .from('QueueEntry')
          .select('*, Patient(name)')
          .or('status.eq.Waiting,status.eq.Serving') // Only active
          .order('queue_number', ascending: true);

      if (mounted) {
        setState(() {
          _queueEntries = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching queue: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String queueId, String newStatus) async {
    try {
      await _supabase
          .from('QueueEntry')
          .update({'status': newStatus})
          .eq('queue_id', queueId);
      
      // The subscription will auto-refresh, but we can optimistically update too
      _fetchQueue();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate lists
    final serving = _queueEntries.where((q) => q['status'] == 'Serving').toList();
    final waiting = _queueEntries.where((q) => q['status'] == 'Waiting').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Queue Management"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchQueue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- NOW SERVING SECTION ---
                  if (serving.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "Now Serving / Calling",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                    ...serving.map((entry) => _buildQueueCard(entry, true)),
                    const SizedBox(height: 20),
                  ],

                  // --- WAITING SECTION ---
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Coming Up",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  if (waiting.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text("No patients in queue.")),
                    )
                  else
                    ...waiting.map((entry) => _buildQueueCard(entry, false)),
                ],
              ),
            ),
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> entry, bool isServing) {
    final patient = entry['Patient'] as Map<String, dynamic>?;
    final patientName = patient?['name'] ?? 'Unknown Patient';
    final queueNum = entry['queue_number'];
    final queueId = entry['queue_id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isServing ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isServing 
            ? const BorderSide(color: Colors.green, width: 2) 
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Number Circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isServing ? Colors.green : Colors.blueGrey[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "$queueNum",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isServing ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isServing ? "Status: Serving" : "Status: Waiting",
                    style: TextStyle(
                      color: isServing ? Colors.green : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            if (isServing)
              ElevatedButton(
                onPressed: () => _updateStatus(queueId, 'Completed'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text("Complete", style: TextStyle(color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: () => _updateStatus(queueId, 'Serving'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Call", style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
