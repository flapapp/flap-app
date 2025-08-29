import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isDeleting = false;

  Future<void> _deleteAllChallenges() async {
    setState(() => _isDeleting = true);
    
    try {
      // Delete submissions
      final submissions = await FirebaseFirestore.instance
          .collection('submissions')
          .get();
      
      final submissionBatch = FirebaseFirestore.instance.batch();
      for (final doc in submissions.docs) {
        submissionBatch.delete(doc.reference);
      }
      await submissionBatch.commit();
      
      // Delete challenges
      final challenges = await FirebaseFirestore.instance
          .collection('challenges')
          .get();
      
      final challengeBatch = FirebaseFirestore.instance.batch();
      for (final doc in challenges.docs) {
        challengeBatch.delete(doc.reference);
      }
      await challengeBatch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Всі челенджі видалено!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isDeleting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        backgroundColor: const Color(0xFF0f0f23),
      ),
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'Адміністрування',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _deleteAllChallenges,
                  icon: _isDeleting 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever),
                  label: Text(_isDeleting ? 'Видаляю...' : 'Видалити всі челенджі'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



