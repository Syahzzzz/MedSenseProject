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
      // We join with Patient to get names, Service to get service details, Appointment to get time, and Doctor for name.
      final response = await _supabase
          .from('QueueEntry')
          .select('*, Patient(name), Service(service_name), Appointment(appointment_datetime), Doctor(name)')
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
      Map<String, dynamic> updates = {'status': newStatus};

      // Room Assignment Logic when Calling
      if (newStatus == 'Serving') {
        // ... (existing room logic)
        final servingRes = await _supabase
            .from('QueueEntry')
            .select('assigned_room')
            .eq('status', 'Serving');
        
        final List<dynamic> data = servingRes; 
        final usedRooms = data
            .map((e) => e['assigned_room'] as int?)
            .where((e) => e != null)
            .toSet();

        int assignedRoom = 101;
        if (usedRooms.contains(101)) {
          assignedRoom = 102;
        } 
        
        updates['assigned_room'] = assignedRoom;
      }
      
      // Auto-update Appointment status if Queue is Completed
      if (newStatus == 'Completed') {
         // Get appointment_id linked to this queue
         final queueRecord = await _supabase
             .from('QueueEntry')
             .select('appointment_id')
             .eq('queue_id', queueId)
             .maybeSingle();
         
         if (queueRecord != null && queueRecord['appointment_id'] != null) {
            final String apptId = queueRecord['appointment_id'];
            await _supabase
                .from('Appointment')
                .update({'status': 'Completed'})
                .eq('appointment_id', apptId);
         }
      }

      await _supabase
          .from('QueueEntry')
          .update(updates)
          .eq('queue_id', queueId);
      
      // The subscription will auto-refresh, but we can optimistically update too
      _fetchQueue();
      
      if (mounted) {
         String msg = 'Status updated to $newStatus';
         if (newStatus == 'Serving') msg = 'Calling Patient to Room ${updates['assigned_room']}';
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

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
    final service = entry['Service'] as Map<String, dynamic>?;
    final appointment = entry['Appointment'] as Map<String, dynamic>?;
    final doctor = entry['Doctor'] as Map<String, dynamic>?;

    final patientName = patient?['name'] ?? 'Unknown Patient';
    final serviceName = service?['service_name'] ?? 'Consultation';
    final doctorName = doctor != null ? doctor['name'] : 'Any Doctor';
    final queueNum = entry['queue_number'];
    final queueId = entry['queue_id'];
    final assignedRoom = entry['assigned_room'];
    
    // Check-in Time Display (Actual Arrival)
    final arrivalTimeStr = entry['arrival_time'] as String?;
    String arrivalDisplay = "Not arrived yet";
    if (arrivalTimeStr != null) {
      final dt = DateTime.parse(arrivalTimeStr).toLocal();
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      arrivalDisplay = "Arrived at $hour:${dt.minute.toString().padLeft(2, '0')} $amPm";
    }

    // Expected Arrival (Appointment Time - 15 mins)
    String expectedDisplay = "N/A";
    if (appointment != null) {
      final apptStr = appointment['appointment_datetime'] as String;
      final apptDt = DateTime.parse(apptStr).toLocal();
      // Suggest 15 mins early
      final expectedDt = apptDt.subtract(const Duration(minutes: 15));
      final amPm = expectedDt.hour >= 12 ? 'PM' : 'AM';
      final hour = expectedDt.hour > 12 ? expectedDt.hour - 12 : (expectedDt.hour == 0 ? 12 : expectedDt.hour);
      expectedDisplay = "$hour:${expectedDt.minute.toString().padLeft(2, '0')} $amPm";
    }

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
                    "$serviceName • $doctorName",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (assignedRoom != null)
                     Padding(
                       padding: const EdgeInsets.only(bottom: 4.0),
                       child: Text(
                         "Assigned Room: $assignedRoom",
                         style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                       ),
                     ),
                  
                  // Row 1: Actual Arrival
                  Row(
                    children: [
                      Icon(
                        arrivalTimeStr != null ? Icons.check_circle : Icons.access_time, 
                        size: 12, 
                        color: arrivalTimeStr != null ? Colors.green : Colors.orange
                      ),
                      const SizedBox(width: 4),
                      Text(
                        arrivalDisplay,
                        style: TextStyle(
                          color: arrivalTimeStr != null ? Colors.green[700] : Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // Row 2: Expected Arrival
                  Row(
                    children: [
                      const Icon(Icons.event_available, size: 12, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(
                        "Expected: $expectedDisplay",
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                onPressed: () {
                  if (entry['arrival_time'] == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Patient not arrived yet"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Check if Doctor is already serving someone else
                  final currentDoctorId = entry['doctor_id'];
                  if (currentDoctorId != null) {
                    final servingEntry = _queueEntries.firstWhere(
                      (q) => q['status'] == 'Serving' && q['doctor_id'] == currentDoctorId,
                      orElse: () => {},
                    );

                    if (servingEntry.isNotEmpty) {
                      final servingPatientName = servingEntry['Patient']?['name'] ?? 'another patient';
                      final servingDoctorName = servingEntry['Doctor']?['name'] ?? 'Doctor';
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                          content: Text("$servingDoctorName is currently serving $servingPatientName"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                  }

                  _updateStatus(queueId, 'Serving');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Call", style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
