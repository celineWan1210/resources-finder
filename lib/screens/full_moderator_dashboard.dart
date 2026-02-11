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
  
  // Tab control
  int _currentTab = 0; // 0 = Contributions, 1 = Requests
  
  // NEW: View mode control
  bool _showingBlacklist = false; // false = normal view, true = blacklist view
  
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
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
          Expanded(child: _showingBlacklist ? _buildBlacklistView() : _buildContentList()),
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
          _showingBlacklist = false; // Reset to normal view when switching tabs
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTab == 0 
                ? '📦 Contribution Moderation' 
                : '🆘 Request Help Moderation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  approved,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  rejected,
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Only show Status and Risk filters when NOT viewing blacklist
          if (!_showingBlacklist) ...[
            const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 12),
            _buildFilterChip('Flagged', 'flagged', Colors.orange),
            _buildFilterChip('Approved', 'approved', Colors.green),
            _buildFilterChip('Rejected', 'rejected', Colors.red),
            _buildFilterChip('All', 'all', Colors.blue),
            
            const SizedBox(width: 32),
            const Text('Risk:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 12),
            _buildRiskFilterChip('All', 'all'),
            _buildRiskFilterChip('High', 'high'),
            _buildRiskFilterChip('Medium', 'medium'),
            _buildRiskFilterChip('Low', 'low'),
          ],
          
          // If showing blacklist, show a title instead
          if (_showingBlacklist) 
            const Text(
              '🚫 Blacklisted Users',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
            ),
          
          // Blacklist toggle button on the right
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showingBlacklist = !_showingBlacklist;
              });
            },
            icon: Icon(_showingBlacklist ? Icons.arrow_back : Icons.block, size: 18),
            label: Text(_showingBlacklist ? 'Back to Content' : 'View Blacklisted Users'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showingBlacklist ? Colors.grey[700] : Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 2,
            ),
          ),
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
                
                // Show moderator notes if available (for approved/rejected items)
                if (data['moderatorNotes'] != null && data['moderatorNotes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_alt, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Moderator Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['moderatorNotes'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                
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
                
                // Show moderator notes if available (for approved/rejected items)
                if (data['moderatorNotes'] != null && data['moderatorNotes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_alt, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Moderator Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['moderatorNotes'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                
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

  // Helper function to get user email from contributions or help_requests
  Future<String> _getUserEmail(String userId, Map<String, dynamic> userData) async {
    // First try to get from userData
    if (userData.containsKey('email') && userData['email'] != null && userData['email'].toString().isNotEmpty) {
      return userData['email'];
    }

    // Try to get from contributions
    try {
      final contribQuery = await _firestore
          .collection('contributions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (contribQuery.docs.isNotEmpty) {
        final email = contribQuery.docs.first.data()['userEmail'];
        if (email != null && email.toString().isNotEmpty) {
          return email;
        }
      }

      // Try to get from help_requests
      final requestQuery = await _firestore
          .collection('help_requests')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (requestQuery.docs.isNotEmpty) {
        final email = requestQuery.docs.first.data()['userEmail'];
        if (email != null && email.toString().isNotEmpty) {
          return email;
        }
      }
    } catch (e) {
      debugPrint('Error fetching email: $e');
    }

    return 'No email';
  }

  // NEW: Blacklisted users view
  Widget _buildBlacklistView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              labelColor: Colors.red[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.red[700],
              tabs: const [
                Tab(
                  icon: Icon(Icons.block),
                  text: 'Currently Blacklisted',
                ),
                Tab(
                  icon: Icon(Icons.history),
                  text: 'Past Blacklisted',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCurrentlyBlacklistedList(),
                _buildPastBlacklistedList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyBlacklistedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('blacklisted', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'No blacklisted users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'All users are in good standing',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userId = userDoc.id;
            final userData = userDoc.data() as Map<String, dynamic>;
            
            return _buildBlacklistedUserCard(userId, userData);
          },
        );
      },
    );
  }

  Widget _buildPastBlacklistedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('unblocked', isEqualTo: true)
          .where('blacklisted', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.blue[300]),
                const SizedBox(height: 16),
                const Text(
                  'No past blacklisted users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No users have been unblocked yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userId = userDoc.id;
            final userData = userDoc.data() as Map<String, dynamic>;
            
            return _buildPastBlacklistedUserCard(userId, userData);
          },
        );
      },
    );
  }

  Widget _buildBlacklistedUserCard(String userId, Map<String, dynamic> userData) {
    final warningCount = userData['warningCount'] ?? 0;

    final lastWarningAt = userData['lastWarningAt'];
    DateTime? lastWarningDate;
    
    if (lastWarningAt is Timestamp) {
      // If it's already a Timestamp, convert to DateTime
      lastWarningDate = lastWarningAt.toDate();
    } else if (lastWarningAt is String) {
      // If it's a String (the problematic case), parse it
      try {
        lastWarningDate = DateTime.parse(lastWarningAt);
      } catch (e) {
        print('Error parsing timestamp string: $e');
        lastWarningDate = null;
      }
    } else {
      // If it's null or something else
      lastWarningDate = null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.block,
            color: Colors.red,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email - smart loading with minimum display duration
                  FutureBuilder<String>(
                    future: () async {
                      // If email exists in userData and contains @, use it (no fetch needed)
                      final storedEmail = userData['email'] as String?;
                      if (storedEmail != null && storedEmail.contains('@')) {
                        return storedEmail;
                      }
                      // Otherwise fetch from contributions/requests
                      // Add minimum delay so "Loading..." is visible (not a flash)
                      final startTime = DateTime.now();
                      final email = await _getUserEmail(userId, userData);
                      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
                      
                      // Ensure at least 400ms so user can see "Loading..." instead of flash
                      if (elapsed < 400) {
                        await Future.delayed(Duration(milliseconds: 400 - elapsed));
                      }
                      
                      return email;
                    }(),
                    builder: (context, emailSnapshot) {
                      final email = emailSnapshot.data ?? 'Loading...';
                      
                      return Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Warning count - bigger, bold, no bubble
                  Text(
                    '$warningCount WARNINGS',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date UNDER the warning
                  if (lastWarningDate != null)
                    Text(
                      'Blacklisted ${DateFormat('MMM dd, yyyy HH:mm').format(lastWarningDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // BIGGER Unblock button on the right
            ElevatedButton.icon(
              onPressed: () => _unblockUser(userId),
              icon: const Icon(Icons.lock_open, size: 20),
              label: const Text(
                'Unblock',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 2,
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
                const Text(
                  'Violation History:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                
                // Show violations from contributions
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('contributions')
                      .where('userId', isEqualTo: userId)
                      .where('moderationStatus', whereIn: ['flagged', 'rejected'])
                      .limit(10)
                      .get(),
                  builder: (context, contribSnapshot) {
                    if (contribSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!contribSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final contributions = contribSnapshot.data?.docs ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contributions.isNotEmpty) ...[
                          Text(
                            'Flagged/Rejected Contributions (${contributions.length}):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...contributions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            
                            // Handle createdAt - could be Timestamp or String
                            DateTime? createdAt;
                            final createdAtRaw = data['createdAt'];
                            if (createdAtRaw is Timestamp) {
                              createdAt = createdAtRaw.toDate();
                            } else if (createdAtRaw is String) {
                              createdAt = DateTime.tryParse(createdAtRaw);
                            }
                            
                            return _buildViolationItem(
                              type: 'Contribution',
                              description: data['description'] ?? 'N/A',
                              reason: data['moderationReason'] ?? 'No reason provided',
                              riskScore: data['riskScore'] ?? 'unknown',
                              createdAt: createdAt,
                            );
                          }).toList(),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Show violations from help requests
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('help_requests')
                      .where('userId', isEqualTo: userId)
                      .where('moderationStatus', whereIn: ['flagged', 'rejected'])
                      .limit(10)
                      .get(),
                  builder: (context, requestSnapshot) {
                    if (requestSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!requestSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final requests = requestSnapshot.data?.docs ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (requests.isNotEmpty) ...[
                          Text(
                            'Flagged/Rejected Help Requests (${requests.length}):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...requests.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final categories = (data['categories'] as List?)?.join(', ') ?? 'N/A';
                            
                            // Handle createdAt - could be Timestamp or String
                            DateTime? createdAt;
                            final createdAtRaw = data['createdAt'];
                            if (createdAtRaw is Timestamp) {
                              createdAt = createdAtRaw.toDate();
                            } else if (createdAtRaw is String) {
                              createdAt = DateTime.tryParse(createdAtRaw);
                            }
                            
                            return _buildViolationItem(
                              type: 'Help Request',
                              description: categories,
                              reason: data['moderationReason'] ?? 'No reason provided',
                              riskScore: data['riskScore'] ?? 'unknown',
                              createdAt: createdAt,
                            );
                          }).toList(),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationItem({
    required String type,
    required String description,
    required String reason,
    required String riskScore,
    DateTime? createdAt,
  }) {
    final riskColor = riskScore == 'high' 
        ? Colors.red 
        : riskScore == 'medium' 
            ? Colors.orange 
            : Colors.yellow;
    
    // Calculate how many warnings this violation gave
    final warningsGiven = riskScore == 'high' ? 2 : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  riskScore.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Show how many warnings this gave
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Text(
                  '+$warningsGiven WARNING${warningsGiven > 1 ? 'S' : ''}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Content: $description',
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'AI Reason: $reason',
                  style: TextStyle(fontSize: 12, color: Colors.red[700], fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastBlacklistedUserCard(String userId, Map<String, dynamic> userData) {
    final unblockedAt = userData['unblockedAt'];
    DateTime? unblockedDate;
    
    if (unblockedAt is Timestamp) {
      unblockedDate = unblockedAt.toDate();
    } else if (unblockedAt is String) {
      try {
        unblockedDate = DateTime.parse(unblockedAt);
      } catch (e) {
        print('Error parsing unblocked timestamp: $e');
        unblockedDate = null;
      }
    }

    final totalBlacklists = userData['totalBlacklistCount'] ?? 0;
    final currentPeriod = userData['currentViolationPeriod'] ?? 1;
    final unblockNotes = userData['unblockNotes'] ?? 'No notes provided';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.blue,
            size: 28,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _reblockUser(userId),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Re-block'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more), // This will be rotated by ExpansionTile
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email
                  FutureBuilder<String>(
                    future: () async {
                      final storedEmail = userData['email'] as String?;
                      if (storedEmail != null && storedEmail.contains('@')) {
                        return storedEmail;
                      }
                      final startTime = DateTime.now();
                      final email = await _getUserEmail(userId, userData);
                      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
                      
                      if (elapsed < 400) {
                        await Future.delayed(Duration(milliseconds: 400 - elapsed));
                      }
                      
                      return email;
                    }(),
                    builder: (context, emailSnapshot) {
                      final email = emailSnapshot.data ?? 'Loading...';
                      
                      return Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'UNBLOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (totalBlacklists > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            'Blacklisted $totalBlacklists time${totalBlacklists > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (unblockedDate != null)
                    Text(
                      'Unblocked ${DateFormat('MMM dd, yyyy HH:mm').format(unblockedDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
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
                // Moderator Notes
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Moderator Notes:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unblockNotes,
                        style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Violation History:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                
                // Show violations from contributions
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('contributions')
                      .where('userId', isEqualTo: userId)
                      .where('moderationStatus', whereIn: ['flagged', 'rejected'])
                      .limit(10)
                      .get(),
                  builder: (context, contribSnapshot) {
                    if (contribSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!contribSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final contributions = contribSnapshot.data?.docs ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contributions.isNotEmpty) ...[
                          Text(
                            'Flagged/Rejected Contributions (${contributions.length}):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...contributions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            
                            DateTime? createdAt;
                            final createdAtRaw = data['createdAt'];
                            if (createdAtRaw is Timestamp) {
                              createdAt = createdAtRaw.toDate();
                            } else if (createdAtRaw is String) {
                              createdAt = DateTime.tryParse(createdAtRaw);
                            }
                            
                            return _buildViolationItem(
                              type: 'Contribution',
                              description: data['description'] ?? 'N/A',
                              reason: data['moderationReason'] ?? 'No reason provided',
                              riskScore: data['riskScore'] ?? 'unknown',
                              createdAt: createdAt,
                            );
                          }).toList(),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Show violations from help requests
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('help_requests')
                      .where('userId', isEqualTo: userId)
                      .where('moderationStatus', whereIn: ['flagged', 'rejected'])
                      .limit(10)
                      .get(),
                  builder: (context, requestSnapshot) {
                    if (requestSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!requestSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final requests = requestSnapshot.data?.docs ?? [];
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (requests.isNotEmpty) ...[
                          Text(
                            'Flagged/Rejected Help Requests (${requests.length}):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...requests.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final categories = (data['categories'] as List?)?.join(', ') ?? 'N/A';
                            
                            DateTime? createdAt;
                            final createdAtRaw = data['createdAt'];
                            if (createdAtRaw is Timestamp) {
                              createdAt = createdAtRaw.toDate();
                            } else if (createdAtRaw is String) {
                              createdAt = DateTime.tryParse(createdAtRaw);
                            }
                            
                            return _buildViolationItem(
                              type: 'Help Request',
                              description: categories,
                              reason: data['moderationReason'] ?? 'No reason provided',
                              riskScore: data['riskScore'] ?? 'unknown',
                              createdAt: createdAt,
                            );
                          }).toList(),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(String userId) async {
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to unblock this user? They will be able to post again.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Moderator Notes (Optional)',
                hintText: 'Reason for unblocking...',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get current warning count and violation period before clearing
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final currentWarningCount = userData['warningCount'] ?? 0;
      final currentViolationPeriod = userData['currentViolationPeriod'] ?? 1;
      
      await _firestore.collection('users').doc(userId).update({
        'blacklisted': false,
        'warningCount': 0,
        'unblocked': true,
        'unblockedAt': FieldValue.serverTimestamp(),
        'unblockedBy': _auth.currentUser?.uid,
        'unblockNotes': notesController.text.trim().isNotEmpty ? notesController.text : 'No notes provided',
        // Save the previous state for potential re-blocking
        'previousWarningCount': currentWarningCount,
        'previousViolationPeriod': currentViolationPeriod,
      });

      // Log the unblock action
      await _firestore.collection('moderationLogs').add({
        'action': 'unblock_user',
        'userId': userId,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorEmail': _auth.currentUser?.email,
        'moderatorNotes': notesController.text.trim().isNotEmpty ? notesController.text : 'No notes provided',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('User unblocked successfully!', Colors.green);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _reblockUser(String userId) async {
    final notesController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-block User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to re-block this user? They will be blacklisted again.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reason for Re-blocking (Optional)',
                hintText: 'Enter reason for re-blocking...',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Re-block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get the user document to retrieve previous warning count and violation period
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      // Restore the previous warning count and violation period
      final previousWarningCount = userData['previousWarningCount'] ?? userData['warningCount'] ?? 0;
      final previousViolationPeriod = userData['previousViolationPeriod'] ?? userData['currentViolationPeriod'] ?? 1;
      
      await _firestore.collection('users').doc(userId).update({
        'blacklisted': true,
        'unblocked': false,
        'reblocked': true,
        'reblockedAt': FieldValue.serverTimestamp(),
        'reblockedBy': _auth.currentUser?.uid,
        'reblockReason': notesController.text.trim().isNotEmpty ? notesController.text.trim() : 'No reason provided',
        // Restore previous warning count and violation period
        'warningCount': previousWarningCount,
        'currentViolationPeriod': previousViolationPeriod,
      });

      // Log the re-block action
      await _firestore.collection('moderationLogs').add({
        'action': 'reblock_user',
        'userId': userId,
        'moderatorId': _auth.currentUser?.uid,
        'moderatorEmail': _auth.currentUser?.email,
        'reason': notesController.text.trim().isNotEmpty ? notesController.text.trim() : 'No reason provided',
        'restoredWarningCount': previousWarningCount,
        'restoredViolationPeriod': previousViolationPeriod,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('User re-blocked successfully!', Colors.red);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      notesController.dispose();
    }
  }
}