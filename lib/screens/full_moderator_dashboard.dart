import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:resource_finder/screens/stub_csv_download.dart'
    if (dart.library.html) 'package:resource_finder/utils/web_csv_download.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Tab control
  int _currentTab = 0; // 0 = Contributions, 1 = Requests
  
  String _selectedFilter = 'flagged';
  String _selectedRiskFilter = 'all';
  
  // Stats for Contributions
  int _contribFlagged = 0;
  int _contribApproved = 0;
  int _contribRejected = 0;
  
  // Stats for Requests
  int _requestFlagged = 0;
  int _requestApproved = 0;
  int _requestRejected = 0;
  
  int _totalBlacklisted = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Contributions Stats
      final contribFlagged = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'flagged')
          .count()
          .get();
      
      final contribApproved = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'approved')
          .count()
          .get();
      
      final contribRejected = await _firestore
          .collection('contributions')
          .where('moderationStatus', isEqualTo: 'rejected')
          .count()
          .get();

      // Requests Stats
      final requestFlagged = await _firestore
          .collection('help_requests')
          .where('moderationStatus', isEqualTo: 'flagged')
          .count()
          .get();
      
      final requestApproved = await _firestore
          .collection('help_requests')
          .where('moderationStatus', isEqualTo: 'approved')
          .count()
          .get();
      
      final requestRejected = await _firestore
          .collection('help_requests')
          .where('moderationStatus', isEqualTo: 'rejected')
          .count()
          .get();
      
      final blacklisted = await _firestore
          .collection('users')
          .where('blacklisted', isEqualTo: true)
          .count()
          .get();

      setState(() {
        _contribFlagged = contribFlagged.count ?? 0;
        _contribApproved = contribApproved.count ?? 0;
        _contribRejected = contribRejected.count ?? 0;
        
        _requestFlagged = requestFlagged.count ?? 0;
        _requestApproved = requestApproved.count ?? 0;
        _requestRejected = requestRejected.count ?? 0;
        
        _totalBlacklisted = blacklisted.count ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }
  Future<void> _exportToCSV() async {
    try {
      final collection = _currentTab == 0 ? 'contributions' : 'help_requests';
      final snapshot = await _firestore
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(1000)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnackBar('No data to export', Colors.orange);
        return;
      }

      final csvRows = <String>[];
      csvRows.add('Timestamp,ID,User Email,Description,Status,Risk Score,Reason');

      for (var doc in snapshot.docs) {
        final data = doc.data();
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
        
        final description = (data['description'] ?? data['quantity'] ?? 'N/A').replaceAll('"', '""');
        final reason = (data['moderationReason'] ?? 'N/A').replaceAll('"', '""');
        
        final row = [
          DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt),
          doc.id,
          data['userEmail'] ?? 'N/A',
          '"$description"',
          data['moderationStatus'] ?? 'unknown',
          data['riskScore'] ?? 'N/A',
          '"$reason"',
        ];
        csvRows.add(row.join(','));
      }

      final csvContent = csvRows.join('\n');
      
      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${collection}_moderation_report_$timestamp.csv';
      
      // Create blob and trigger download
      downloadCsv(filename, csvContent);
            
      _showSnackBar('✓ Downloaded: $filename (${csvRows.length - 1} records)', Colors.green);
      
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
        toolbarHeight: 80, // INCREASED HEIGHT
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield, size: 32), // LARGER ICON
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moderator Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), // LARGER TEXT
                ),
                Text(
                  'Content Review & Management',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.indigo[700], // BRIGHTER COLOR
        elevation: 4,
        shadowColor: Colors.indigo.withOpacity(0.5),
        actions: [
          // LARGER, MORE VISIBLE BUTTONS
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 8),
                Text(
                  _auth.currentUser?.email ?? 'Moderator',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          _buildStatsDashboard(),
          _buildFilterBar(),
          Expanded(child: _buildContentList()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[600]!, Colors.indigo[800]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Provide Help (Contributions)',
              icon: Icons.card_giftcard,
              index: 0,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Request Help',
              icon: Icons.help_outline,
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentTab = index;
          _selectedFilter = 'flagged'; // Reset filter
          _selectedRiskFilter = 'all';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20), // INCREASED PADDING
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.indigo[700] : Colors.white,
              size: 28, // LARGER ICON
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18, // LARGER TEXT
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.indigo[700] : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsDashboard() {
    final flagged = _currentTab == 0 ? _contribFlagged : _requestFlagged;
    final approved = _currentTab == 0 ? _contribApproved : _requestApproved;
    final rejected = _currentTab == 0 ? _contribRejected : _requestRejected;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[50]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTab == 0 
                ? '📦 Contribution Moderation' 
                : '🆘 Help Request Moderation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending Review',
                  flagged,
                  Colors.orange,
                  Icons.flag,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  approved,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  rejected,
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Blacklisted Users',
                  _totalBlacklisted,
                  Colors.black87,
                  Icons.block,
                ),
              ),
            ],
          ),
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
        selectedColor: Colors.indigo.withOpacity(0.2),
      ),
    );
  }

  Widget _buildContentList() {
    final collection = _currentTab == 0 ? 'contributions' : 'help_requests';
    Query query = _firestore.collection(collection);

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
                  _currentTab == 0 
                      ? 'No contributions found'
                      : 'No help requests found',
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
            return _currentTab == 0
                ? _buildContributionCard(doc.id, data)
                : _buildRequestCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildContributionCard(String docId, Map<String, dynamic> data) {
    final status = data['moderationStatus'] ?? 'unknown';
    final riskScore = data['riskScore'] ?? 'unknown';
    final reason = data['moderationReason'] ?? 'No reason provided';
    
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
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.card_giftcard,
            color: statusColor,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['userEmail'] ?? 'Unknown',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                          onPressed: () => _reviewContent(docId, 'approve', 'contributions'),
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
                          onPressed: () => _reviewContent(docId, 'reject', 'contributions'),
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

  Widget _buildRequestCard(String docId, Map<String, dynamic> data) {
    final status = data['moderationStatus'] ?? 'unknown';
    final riskScore = data['riskScore'] ?? 'unknown';
    final reason = data['moderationReason'] ?? 'No reason provided';
    
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
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.help_outline,
            color: statusColor,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['userEmail'] ?? 'Unknown',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                _buildDetailRow('Quantity Needed', data['quantity'] ?? 'N/A'),
                _buildDetailRow('Remarks', data['remarks'] ?? 'N/A'),
                _buildDetailRow('Location', data['location'] ?? 'N/A'),
                _buildDetailRow('Contact', data['contact'] ?? 'Not provided'),
                _buildDetailRow('AI Reason', reason),
                
                if (data['tags'] != null && (data['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Preferences:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (data['tags'] as List).map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.purple[50],
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
                          onPressed: () => _reviewContent(docId, 'approve', 'help_requests'),
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
                          onPressed: () => _reviewContent(docId, 'reject', 'help_requests'),
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

  Future<void> _reviewContent(String docId, String action, String collection) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == 'approve' ? 'Approve' : 'Reject'} ${collection == 'contributions' ? 'Contribution' : 'Request'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this ${collection == 'contributions' ? 'contribution' : 'request'}?'),
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
      await _firestore.collection(collection).doc(docId).update({
        'moderationStatus': action == 'approve' ? 'approved' : 'rejected',
        'verified': action == 'approve',
        'reviewedByModerator': true,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorNotes': notesController.text,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('moderationLogs').add({
        'contentId': docId,
        'contentType': collection,
        'action': action,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorEmail': _auth.currentUser?.email,
        'moderatorNotes': notesController.text,
        'reviewedByHuman': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('${collection == 'contributions' ? 'Contribution' : 'Request'} ${action}d successfully!', Colors.green);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
}