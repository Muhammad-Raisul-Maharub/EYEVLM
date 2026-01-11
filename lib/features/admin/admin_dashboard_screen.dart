import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_notifications.dart';
import '../../core/providers/connectivity_provider.dart';
import '../auth/auth_service.dart';
import 'admin_service.dart';
import 'admin_scan_details_dialog.dart';

/// Admin Dashboard Screen
/// Provides admin users with a view of all scans from all users
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Map<String, dynamic>> _scans = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  Set<int> _selectedScanIds = {};
  
  final TextEditingController _searchController = TextEditingController();

  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _subscription = Supabase.instance.client
        .channel('admin_dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scans',
          callback: (payload) {
            // Reload silently on any change (insert/update/delete)
            if (mounted) _loadData(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final adminService = ref.read(adminServiceProvider);
      
      final scans = await adminService.getAllScans(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final stats = await adminService.getStatistics();
      
      if (mounted) {
        setState(() {
          _scans = scans;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          // _isLoading = false; // Handled in finally
        });
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadData();
  }

  void _toggleSelection(int scanId) {
    setState(() {
      if (_selectedScanIds.contains(scanId)) {
        _selectedScanIds.remove(scanId);
      } else {
        _selectedScanIds.add(scanId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedScanIds.length == _scans.length) {
        _selectedScanIds.clear();
      } else {
        _selectedScanIds = _scans.map((s) => s['id'] as int).toSet();
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedScanIds.isEmpty) return;
    
    // Check connectivity for write actions
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppNotifications.showError(context, "Cannot delete scans while offline");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Scans'),
        content: Text(
          'Are you sure you want to delete ${_selectedScanIds.length} scan(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final adminService = ref.read(adminServiceProvider);
    final deletedCount = await adminService.deleteMultipleScans(
      _selectedScanIds.toList(),
    );

    if (mounted) {
      AppNotifications.showSuccess(context, 'Deleted $deletedCount scan(s)');
      _selectedScanIds.clear();
      _loadData();
    }
  }

  void _viewScanDetails(Map<String, dynamic> scan) {
    showDialog(
      context: context,
      builder: (ctx) => AdminScanDetailsDialog(
        scan: scan,
        onUpdate: () => _loadData(),
        onDelete: () => _loadData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_selectedScanIds.isNotEmpty)
            IconButton(
              onPressed: _deleteSelected,
              icon: Badge(
                label: Text('${_selectedScanIds.length}'),
                child: const Icon(Icons.delete_sweep),
              ),
              tooltip: 'Delete Selected',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Scans', icon: Icon(Icons.list_alt)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              color: Colors.orange.shade100,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Text(
                    "Offline Mode - Showing cached data",
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScansTab(),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScansTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by prediction, symptoms...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: _onSearch,
                ),
              ),
              const SizedBox(width: 8),
              if (_scans.isNotEmpty)
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: Icon(
                    _selectedScanIds.length == _scans.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  label: Text(
                    _selectedScanIds.length == _scans.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: (_isLoading && _scans.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading scans',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _scans.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No scans found'
                                    : 'No results for "$_searchQuery"',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _scans.length,
                            itemBuilder: (context, index) {
                              return _buildScanCard(_scans[index]).animate()
                                  .fadeIn(delay: Duration(milliseconds: index * 50))
                                  .slideX(begin: 0.1);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan) {
    final scanId = scan['id'] as int;
    final prediction = scan['prediction'] ?? 'Unknown';
    final confidence = scan['confidence'] ?? 0;
    // Fix: Convert to local time for display
    final createdAt = DateTime.tryParse(scan['created_at'] ?? '')?.toLocal();
    final imageUrl = scan['image_url'] ?? '';
    final userId = scan['user_id'] ?? '';
    final isSelected = _selectedScanIds.contains(scanId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _viewScanDetails(scan),
        onLongPress: () => _toggleSelection(scanId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox for selection
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(scanId),
              ),
              
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildThumbnail(imageUrl, 60, 60),
              ),
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          prediction,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(confidence).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${confidence}%',
                            style: TextStyle(
                              color: _getConfidenceColor(confidence),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $scanId • User: ${userId.toString().substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Actions
              IconButton(
                onPressed: () => _viewScanDetails(scan),
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_isLoading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalScans = _stats['total_scans'] ?? 0;
    final uniqueUsers = _stats['unique_users'] ?? 0;
    final recentScans = _stats['recent_scans'] ?? 0;
    final predictions = _stats['predictions'] as Map<String, int>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Scans',
                    totalScans.toString(),
                    Icons.document_scanner,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Unique Users',
                    uniqueUsers.toString(),
                    Icons.people,
                    Colors.green,
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 12),
            _buildStatCard(
              'Scans This Week',
              recentScans.toString(),
              Icons.trending_up,
              Colors.orange,
              fullWidth: true,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
            
            const SizedBox(height: 24),
            
            // Predictions breakdown
            Text(
              'Predictions Breakdown',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: 12),
            
            if (predictions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No prediction data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...predictions.entries.map((entry) {
                final percentage = totalScans > 0
                    ? (entry.value / totalScans * 100).toStringAsFixed(1)
                    : '0';
                return _buildPredictionBar(
                  entry.key,
                  entry.value,
                  '$percentage%',
                ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.1);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionBar(String label, int count, String percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '$count scans',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  percentage,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(dynamic confidence) {
    final value = (confidence is int) ? confidence : int.tryParse(confidence.toString()) ?? 0;
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildThumbnail(String pathOrUrl, double width, double height) {
    if (pathOrUrl.isEmpty) {
        return Container(width: width, height: height, color: Colors.grey[200], child: const Icon(Icons.image));
    }
    
    // Check if it's a URL
    bool isUrl = pathOrUrl.startsWith('http') || pathOrUrl.startsWith('https');

    if (isUrl) {
      return Image.network(
        pathOrUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
      );
    } else {
      // Assume local file
      return Image.file(
        File(pathOrUrl),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: width, height: height, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
      );
    }
  }
}
