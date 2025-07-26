import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalHistoryView extends StatelessWidget {
  const WithdrawalHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Inicia sesión para ver tu historial."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: user.uid)
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
              'Aún no se han realizado solicitudes de retiro.',
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
                ? "${timestamp.toLocal().day.toString().padLeft(2, '0')}/${timestamp.toLocal().month.toString().padLeft(2, '0')}/${timestamp.toLocal().year}"
                : 'N/A';
            final status = data['status'] ?? 'desconocido';

            IconData statusIcon;
            Color statusColor;
            switch (status) {
              case 'pending':
                statusIcon = Icons.hourglass_empty;
                statusColor = Colors.orange;
                break;
              case 'completed':
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
                break;
              case 'rejected':
                statusIcon = Icons.cancel;
                statusColor = Colors.red;
                break;
              default:
                statusIcon = Icons.help_outline;
                statusColor = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor),
                title: Text('Retiro de ${data['coinsToWithdraw']} monedas'),
                subtitle: Text(
                    'Monto: \$${(data['amountInPesos'] as num).toStringAsFixed(2)} - Estado: $status'),
                trailing: Text(dateString),
              ),
            );
          },
        );
      },
    );
  }
}