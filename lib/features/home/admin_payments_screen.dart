import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/payment_service.dart';

/// Admin backoffice: all CamPay transactions + manual status sync.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String _filter = 'all'; // all | completed | pending | failed
  final _payments = PaymentService();
  final Set<String> _syncing = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream {
    return FirebaseFirestore.instance
        .collection('transactions')
        .limit(200)
        .snapshots();
  }

  Future<void> _syncStatus(String reference) async {
    setState(() => _syncing.add(reference));
    try {
      final result = await _payments.getTransactionStatus(reference);
      final mapped = result.isSuccessful
          ? 'completed'
          : result.isFailed
              ? 'failed'
              : 'pending';

      await FirebaseFirestore.instance.collection('transactions').doc(reference).set({
        'status': mapped,
        'operator': result.operator,
        'campayCode': result.code,
        'operatorReference': result.operatorReference,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'syncedBy': 'admin',
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $reference: ${result.status}'),
          backgroundColor: result.isSuccessful ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _syncing.remove(reference));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'CamPay Payments',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = [...(snapshot.data?.docs ?? [])];
          docs.sort((a, b) {
            final aTs = a.data()['createdAt'];
            final bTs = b.data()['createdAt'];
            final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
            final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
            return bDate.compareTo(aDate);
          });
          final filtered = docs.where((d) {
            if (_filter == 'all') return true;
            return (d.data()['status'] ?? 'pending') == _filter;
          }).toList();

          final completed = docs.where((d) => d.data()['status'] == 'completed');
          final revenue = completed.fold<double>(
            0,
            (sum, d) => sum + ((d.data()['amount'] as num?)?.toDouble() ?? 0),
          );
          final pendingCount =
              docs.where((d) => (d.data()['status'] ?? '') == 'pending').length;
          final failedCount =
              docs.where((d) => (d.data()['status'] ?? '') == 'failed').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _kpi('Revenue', '${revenue.toInt()} XAF', Colors.green),
                    const SizedBox(width: 8),
                    _kpi('Paid', '${completed.length}', Colors.indigo),
                    const SizedBox(width: 8),
                    _kpi('Pending', '$pendingCount', Colors.orange),
                    const SizedBox(width: 8),
                    _kpi('Failed', '$failedCount', Colors.red),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final f in const [
                      ('all', 'All'),
                      ('completed', 'Completed'),
                      ('pending', 'Pending'),
                      ('failed', 'Failed'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          onSelected: (_) => setState(() => _filter = f.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No transactions yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data();
                          final status = (data['status'] ?? 'pending').toString();
                          final amount = data['amount'] ?? 0;
                          final userId = (data['userId'] ?? '-').toString();
                          final phone = (data['phone'] ?? '').toString();
                          final operator = (data['operator'] ?? '-').toString();
                          final description =
                              (data['description'] ?? 'Payment').toString();
                          final createdAt = data['createdAt'];
                          DateTime? date;
                          if (createdAt is Timestamp) date = createdAt.toDate();

                          final color = status == 'completed'
                              ? Colors.green
                              : status == 'failed'
                                  ? Colors.red
                                  : Colors.orange;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                '$amount XAF - $description',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  'User: $userId',
                                  if (phone.isNotEmpty) 'MoMo: $phone',
                                  'Operator: $operator',
                                  if (date != null)
                                    'Date: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                  'Ref: ${doc.id}',
                                ].join('\n'),
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 28,
                                    child: TextButton(
                                      onPressed: _syncing.contains(doc.id)
                                          ? null
                                          : () => _syncStatus(doc.id),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(48, 28),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: _syncing.contains(doc.id)
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Sync',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
