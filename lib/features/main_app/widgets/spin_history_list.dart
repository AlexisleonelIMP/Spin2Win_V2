import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpinHistoryView extends StatelessWidget {
  const SpinHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Inicia sesión para ver tu historial."));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('rouletteHistory')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no hay giros registrados. ¡Ve a jugar!',
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            final dateString = timestamp != null
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year} ${timestamp.toLocal().hour.toString().padLeft(2, '0')}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}"
                : 'Fecha no disponible';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Image.asset(
                  'assets/monedas.png',
                  width: 24,
                  height: 24,
                  color: isDarkMode ? Colors.white : null,
                ),
                title: Text(data['prize'] ?? 'Premio no disponible'),
                subtitle: Text(dateString),
              ),
            );
          },
        );
      },
    );
  }
}