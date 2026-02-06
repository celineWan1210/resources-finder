import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _selectedFilter = 'flagged';
  String _selectedRiskFilter = 'all';
  
  int _totalFlagged = 0;
  int _totalApproved = 0;
  int _totalRejected = 0;
  int _totalBlacklisted = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final flagged = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'flagged')
          .count()
          .get();
      
      final approved = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'approved')
          .count()
          .get();
      
      final rejected = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'rejected')
          .count()
          .get();
      
      final blacklisted = await _firestore
          .collection('users')
          .where('blacklisted', isEqualTo: true)
          .count()
          .get();

      setState(() {
        _totalFlagged = flagged.count ?? 0;
        _totalApproved = approved.count ?? 0;
        _totalRejected = rejected.count ?? 0;
        _totalBlacklisted = blacklisted.count ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _exportToCSV() async {
  try {
    final snapshot = await _firestore
        .collection('moderationLogs')
        .orderBy('timestamp', descending: true)
        .limit(1000)
        .get();

    if (snapshot.docs.isEmpty) {
      _showSnackBar('No data to export', Colors.orange);
      return;
    }

    final csvRows = <String>[];
    csvRows.add('Timestamp,Contribution ID,User ID,User Email,Description,Status,Risk Score,Reason,Reviewed By Human');

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final description = (data['description'] ?? 'N/A').replaceAll('"', '""');
      final reason = (data['moderationResult']?['reason'] ?? 'N/A').replaceAll('"', '""');
      
      final row = [
        DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp),
        data['contributionId'] ?? 'N/A',
        data['userId'] ?? 'N/A',
        data['userEmail'] ?? 'N/A',
        '"$description"',
        data['moderationResult']?['safe'] == true ? 'approved' : 'flagged',
        data['moderationResult']?['riskScore'] ?? 'N/A',
        '"$reason"',
        data['reviewedByHuman']?.toString() ?? 'false',
      ];
      csvRows.add(row.join(','));
    }

    final csvContent = csvRows.join('\n');
    
    // Share the CSV content
    _showSnackBar('CSV data prepared. Feature needs share package for mobile.', Colors.orange);
    // TODO: Implement sharing for mobile using share_plus package
    
  } catch (e) {
    _showSnackBar('Error exporting CSV: $e', Colors.red);
  }
}
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export Logs to CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Stats',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Center(
              child: Text(
                _auth.currentUser?.email ?? 'Moderator',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsDashboard(),
          _buildFilterBar(),
          Expanded(child: _buildContentList()),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.deepPurple.shade50,
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Pending Review', _totalFlagged, Colors.orange, Icons.flag)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard('Approved', _totalApproved, Colors.green, Icons.check_circle)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard('Rejected', _totalRejected, Colors.red, Icons.cancel)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard('Blacklisted Users', _totalBlacklisted, Colors.black87, Icons.block)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _buildFilterChip('Flagged', 'flagged', Colors.orange),
          _buildFilterChip('Approved', 'approved', Colors.green),
          _buildFilterChip('Rejected', 'rejected', Colors.red),
          _buildFilterChip('All', 'all', Colors.blue),
          
          const SizedBox(width: 32),
          const Text('Risk:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _buildRiskFilterChip('All', 'all'),
          _buildRiskFilterChip('High', 'high'),
          _buildRiskFilterChip('Medium', 'medium'),
          _buildRiskFilterChip('Low', 'low'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        selectedColor: color.withOpacity(0.3),
        checkmarkColor: color,
      ),
    );
  }

  Widget _buildRiskFilterChip(String label, String value) {
    final isSelected = _selectedRiskFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedRiskFilter = value;
          });
        },
        selectedColor: Colors.deepPurple.withOpacity(0.2),
      ),
    );
  }

  Widget _buildContentList() {
    Query query = _firestore.collection('contributions');

    // Apply filters
    bool hasStatusFilter = _selectedFilter != 'all';
    bool hasRiskFilter = _selectedRiskFilter != 'all';

    if (hasStatusFilter) {
      query = query.where('moderationStatus', isEqualTo: _selectedFilter);
    }

    if (hasRiskFilter) {
      query = query.where('riskScore', isEqualTo: _selectedRiskFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No contributions found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildContributionCard(doc.id, data);
          },
        );
      },
    );
  }

 Widget _buildContributionCard(String docId, Map<String, dynamic> data) {
  final status = data['moderationStatus'] ?? 'unknown';
  final riskScore = data['riskScore'] ?? 'unknown';
  final reason = data['moderationReason'] ?? 'No reason provided';
  
  // Handle both String and Timestamp formats for createdAt
  DateTime createdAt;
  try {
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else {
      createdAt = DateTime.now();
    }
  } catch (e) {
    createdAt = DateTime.now();
  }
  
  final categories = List<String>.from(data['categories'] ?? []);

  Color statusColor = status == 'flagged' ? Colors.orange : 
                     status == 'approved' ? Colors.green : Colors.red;
  
  Color riskColor = riskScore == 'high' ? Colors.red :
                   riskScore == 'medium' ? Colors.orange : Colors.green;

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      leading: Icon(
        status == 'flagged' ? Icons.flag : 
        status == 'approved' ? Icons.check_circle : Icons.cancel,
        color: statusColor,
        size: 32,
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categories.join(', '),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Posted ${DateFormat('MMM dd, yyyy HH:mm').format(createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskColor),
            ),
            child: Text(
              riskScore.toUpperCase(),
              style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('User Email', data['userEmail'] ?? 'N/A'),
              _buildDetailRow('Description', data['description'] ?? 'N/A'),
              _buildDetailRow('Quantity', data['quantity'] ?? 'N/A'),
              _buildDetailRow('Location', data['location'] ?? 'N/A'),
              _buildDetailRow('Contact', data['contact'] ?? 'Not provided'),
              _buildDetailRow('AI Reason', reason),
              
              if (data['tags'] != null && (data['tags'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (data['tags'] as List).map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blue[50],
                    );
                  }).toList(),
                ),
              ],
              
              if (status == 'flagged') ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _reviewContribution(docId, 'approve'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _reviewContribution(docId, 'reject'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _reviewContribution(String docId, String action) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == 'approve' ? 'Approve' : 'Reject'} Contribution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this contribution?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Moderator Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve' ? Colors.green : Colors.red,
            ),
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('contributions').doc(docId).update({
        'moderationStatus': action == 'approve' ? 'approved' : 'rejected',
        'verified': action == 'approve',
        'reviewedByModerator': true,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorNotes': notesController.text,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('moderationLogs').add({
        'contributionId': docId,
        'action': action,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorEmail': _auth.currentUser?.email,
        'moderatorNotes': notesController.text,
        'reviewedByHuman': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Contribution ${action}d successfully!', Colors.green);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
}