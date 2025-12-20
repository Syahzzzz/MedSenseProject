import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_success_view.dart';

class OnlineBankingView extends StatefulWidget {
  final String clinicNameKey;
  final String serviceName;
  final String doctorName;
  final DateTime date;
  final String time;

  const OnlineBankingView({
    super.key,
    required this.clinicNameKey,
    required this.serviceName,
    required this.doctorName,
    required this.date,
    required this.time,
  });

  @override
  State<OnlineBankingView> createState() => _OnlineBankingViewState();
}

class _OnlineBankingViewState extends State<OnlineBankingView> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  final List<String> _banks = [
    'Maybank (Maybank2u)',
    'CIMB Bank (CIMB Clicks)',
    'Public Bank (PBe / PB engage)',
    'RHB Bank (RHB Now)',
    'Hong Leong Bank (HLB Connect)',
    'AmBank (AmOnline)',
    'Bank Islam (GO by Bank Islam)',
    'Bank Rakyat (i-Rakyat)',
    'UOB (UOB Personal Internet Banking)',
    'BSN (myBSN)',
    'OCBC Bank (OCBC Online Banking)',
    'Alliance Bank (allianceonline)',
    'Standard Chartered',
    'Affin Bank',
    'Bank Muamalat',
    'Agrobank',
    'HSBC Bank',
  ];

  Future<void> _handleBankSelection(String bankName) async {
    setState(() => _isProcessing = true);

    // Simulate Payment Gateway Delay
    await Future.delayed(const Duration(seconds: 2));

    // Proceed to Booking Logic
    await _createBooking(bankName);
  }

  Future<void> _createBooking(String bankName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login.')));
         setState(() => _isProcessing = false);
       }
       return;
    }

    try {
      // 1. Get Service ID
      final serviceRes = await _supabase
          .from('Service')
          .select('service_id')
          .eq('service_name', widget.serviceName)
          .maybeSingle();
      
      if (serviceRes == null) throw "Service not found: ${widget.serviceName}";
      final serviceId = serviceRes['service_id'];

      // 2. Get Doctor ID
      final doctorRes = await _supabase
          .from('Doctor')
          .select('doctor_id')
          .eq('name', widget.doctorName)
          .maybeSingle();

      if (doctorRes == null) throw "Doctor not found: ${widget.doctorName}";
      final doctorId = doctorRes['doctor_id'];

      // 3. Parse DateTime
      final DateTime fullDateTime = _parseDateTime(widget.date, widget.time);

      // 4. Insert Appointment
      await _supabase.from('Appointment').insert({
        'patient_id': user.id,
        'doctor_id': doctorId,
        'service_id': serviceId,
        'appointment_datetime': fullDateTime.toUtc().toIso8601String(),
        'status': 'Pending', 
        'payment_status': 'Paid',
        'payment_method': 'Online Banking',
        'predicted_wait_time_minutes': 0, 
      });

      if (!mounted) return;

      // Navigate to Success
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BookingSuccessView()),
        (route) => route.isFirst, 
      );

    } catch (e) {
      debugPrint('Booking Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment/Booking failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  DateTime _parseDateTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(' '); 
      final timeParts = parts[0].split(':'); 
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      if (parts[1] == 'PM' && hour != 12) hour += 12;
      if (parts[1] == 'AM' && hour == 12) hour = 0;

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      debugPrint("Time parsing error: $e");
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Bank', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isProcessing 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFFBC02D)),
                const SizedBox(height: 20),
                const Text("Contacting Bank...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Please do not close this screen", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                width: double.infinity,
                child: const Text(
                  "FPX Online Banking",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _banks.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bank = _banks[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.grey),
                      ),
                      title: Text(bank, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () => _handleBankSelection(bank),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}