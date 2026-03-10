import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halobus/core/theme/colors.dart';
import 'package:halobus/core/theme/typography.dart';
import 'package:halobus/core/widgets/app_scaffold.dart';
import 'package:halobus/core/widgets/profile_avatar.dart';
import 'package:halobus/data/providers.dart';
import 'package:halobus/data/models/user_profile.dart';
import 'package:halobus/data/datasources/api_ds.dart';

class DriverStudentsScreen extends ConsumerStatefulWidget {
  const DriverStudentsScreen({super.key});

  @override
  ConsumerState<DriverStudentsScreen> createState() => _DriverStudentsScreenState();
}

class _DriverStudentsScreenState extends ConsumerState<DriverStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;
  String _searchQuery = '';
  
  // Local state for batch attendance (optimistic UI)
  Set<String> _localAttendedIds = {};
  // IDs verified by backend for "today" - these will be locked/disabled
  final Set<String> _lockedIds = {};
  // Track students currently being submitted to show loading state
  Set<String> _pendingIds = {};
  bool _isLoadingPrefs = true;

  // EMERGENCY FIX: Race condition guard
  // Tracks the direction of the LATEST sync request to discard stale results.
  String? _currentSyncDirection;

  @override
  void initState() {
    super.initState();
    _loadLocalAttendance();
  }

  Future<void> _loadLocalAttendance({String? forcedDirection}) async {
    // 1. AGGRESSIVE RESET: Clear UI immediately before any async work
    if (mounted) {
      setState(() {
        _lockedIds.clear();
        _localAttendedIds.clear();
        _pendingIds.clear();
        _isLoadingPrefs = true;
      });
      debugPrint('[DriverStudentsScreen] State reset triggered');
    }

    final activeTripId = ref.read(activeTripIdProvider).value;
    final assignedBus = ref.read(assignedBusProvider).value;
    final profile = ref.read(userProfileProvider).value;
    
    if (activeTripId == null) {
      if (mounted) setState(() => _isLoadingPrefs = false);
      return;
    }

    // 2. Determine direction
    String? direction = forcedDirection;
    if (direction == null) {
      final tripData = ref.read(tripProvider(activeTripId)).value;
      direction = tripData?['direction'];
    }

    // 3. DIRECTION GUARD: Verify direction is actually known
    if (direction == null) {
      debugPrint('[DriverStudentsScreen] Direction unknown, waiting for trip data before sync...');
      if (mounted) setState(() => _isLoadingPrefs = false);
      return;
    }

    final effectiveDirection = direction;
    final driverBusId = assignedBus?.id ?? profile?.assignedBusId;

    // 4. Load from SharedPreferences using direction-aware key
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'shared_attendance_${activeTripId}_$effectiveDirection';
    final localList = prefs.getStringList(cacheKey) ?? [];
    
    if (mounted) {
      setState(() {
        _localAttendedIds = localList.toSet();
      });
    }

    // 5. Load from Backend (source of truth)
    if (driverBusId != null) {
      try {
        _currentSyncDirection = effectiveDirection;
        final apiDS = await _buildApiDataSource();
        final remoteList = await apiDS.getTodayAttendance(driverBusId, effectiveDirection);
        
        // GUARD: If the direction changed while we were waiting, DISCARD the stale result.
        if (_currentSyncDirection != effectiveDirection) {
           debugPrint('[DriverStudentsScreen] Discarding stale sync for $effectiveDirection');
           return;
        }

        if (mounted) {
          setState(() {
            _lockedIds.clear(); 
            _localAttendedIds.clear();
            if (remoteList.isNotEmpty) {
              _localAttendedIds.addAll(remoteList);
              _lockedIds.addAll(remoteList);
            }
          });
          await _saveLocalAttendance(activeTripId, effectiveDirection);
        }
      } catch (e) {
        debugPrint('[DriverStudentsScreen] Remote sync failed: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoadingPrefs = false);
    }
  }

  Future<void> _saveLocalAttendance(String activeTripId, String direction) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'shared_attendance_${activeTripId}_$direction';
    await prefs.setStringList(cacheKey, _localAttendedIds.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<ApiDataSource> _buildApiDataSource() async {
    final dio = Dio();
    // Try Firebase token first, fall back to stored JWT
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          dio.options.headers['Authorization'] = 'Bearer $token';
          return ApiDataSource(dio, FirebaseFirestore.instance);
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return ApiDataSource(dio, FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return const AppScaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(userProfileProvider);
    final assignedBusAsync = ref.watch(assignedBusProvider);

    return profileAsync.when(
      data: (userProfile) {
        if (userProfile == null) {
          return const AppScaffold(body: Center(child: Text('User profile not found')));
        }

        final collegeId = userProfile.collegeId;
        final activeTripId = ref.watch(activeTripIdProvider).value;
        
        // Listen for trip changes to trigger re-sync (crucial for trip transition)
        ref.listen(activeTripIdProvider, (previous, next) {
          if (next.value != previous?.value) {
            _loadLocalAttendance();
          }
        });

        // Also listen for trip data (especially direction) to trigger re-sync if it arrived late
        if (activeTripId != null) {
          ref.listen(tripProvider(activeTripId), (previous, next) {
            final prevDirection = previous?.value?['direction'];
            final nextDirection = next.value?['direction'];
            if (nextDirection != null && nextDirection != prevDirection) {
              _loadLocalAttendance(forcedDirection: nextDirection);
            }
          });
        }

        return assignedBusAsync.when(
          data: (assignedBus) {
            final driverBusId = assignedBus?.id ?? userProfile.assignedBusId;
            final tripAsync = activeTripId != null
                ? ref.watch(tripProvider(activeTripId))
                : const AsyncValue<Map<String, dynamic>?>.data(null);

            final busStudentsAsync = driverBusId != null
                ? ref.watch(busStudentsProvider(driverBusId))
                : const AsyncValue<List<UserProfile>>.data([]);

            final allStudentsAsync = ref.watch(studentsProvider(collegeId));
            final busesAsync = ref.watch(busesProvider(collegeId));

            final Map<String, String> busIdToNumber = {};
            busesAsync.whenData((buses) {
              for (var b in buses) {
                busIdToNumber[b.id] = b.busNumber;
              }
            });

            return tripAsync.when(
              data: (tripData) {
                final direction = tripData?['direction'] ?? 'pickup';

                return AppScaffold(
                  appBar: AppBar(
                    title: Text('Students', style: AppTypography.h2),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  body: Column(
                    children: [
                      // Search
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search all students...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _isSearchMode = false;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                              _isSearchMode = _searchQuery.isNotEmpty;
                            });
                          },
                        ),
                      ),

                      if (!_isSearchMode && activeTripId != null)
                        busStudentsAsync.maybeWhen(
                          data: (assignedStudents) =>
                              _buildAttendanceSummary(assignedStudents, direction),
                          orElse: () => const SizedBox.shrink(),
                        ),

                      Expanded(
                        child: _isSearchMode
                            ? allStudentsAsync.when(
                                data: (allStudents) {
                                  final q = _searchQuery.toLowerCase();
                                  final displayList = allStudents.where((s) {
                                    final nameMatch =
                                        (s.name ?? '').toLowerCase().contains(q);
                                    final emailMatch =
                                        (s.email ?? '').toLowerCase().contains(q);
                                    return nameMatch || emailMatch;
                                  }).toList();
                                  return _buildStudentList(displayList, activeTripId,
                                      direction, busIdToNumber);
                                },
                                loading: () =>
                                    const Center(child: CircularProgressIndicator()),
                                error: (err, stack) =>
                                    Center(child: Text('Error: $err')),
                              )
                            : busStudentsAsync.when(
                                data: (assignedStudents) => _buildStudentList(
                                    assignedStudents, activeTripId, direction,
                                    busIdToNumber),
                                loading: () =>
                                    const Center(child: CircularProgressIndicator()),
                                error: (err, stack) =>
                                    Center(child: Text('Error: $err')),
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () =>
                  const AppScaffold(body: Center(child: CircularProgressIndicator())),
              error: (err, stack) =>
                  AppScaffold(body: Center(child: Text('Error loading trip: $err'))),
            );
          },
          loading: () =>
              const AppScaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) =>
              AppScaffold(body: Center(child: Text('Error loading bus: $err'))),
        );
      },
      loading: () =>
          const AppScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          AppScaffold(body: Center(child: Text('Error loading profile: $err'))),
    );
  }

  Widget _buildStudentList(List<UserProfile> displayList, String? activeTripId,
      String direction, Map<String, String> busIdToNumber) {
    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _isSearchMode
                  ? 'No students found matching "$_searchQuery"'
                  : 'No students assigned to your bus',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final student = displayList[index];
        final assignedBus = ref.watch(assignedBusProvider).value;
        final driverBusId = assignedBus?.id;
        final isOnOtherBus = student.assignedBusId != null && student.assignedBusId != driverBusId;
        final isAttended = _localAttendedIds.contains(student.id);
        final isLocked = _lockedIds.contains(student.id);
        final isPending = _pendingIds.contains(student.id);

        return StudentItem(
          student: student,
          isOnOtherBus: isOnOtherBus,
          busLabel: _getBusLabel(student.assignedBusId, busIdToNumber),
          isAttended: isAttended,
          isLocked: isLocked,
          isPending: isPending,
          activeTripId: activeTripId,
          direction: direction,
          onAttendanceChanged: (val) => _onAttendanceChanged(student, val, direction, activeTripId!),
          onCall: () => _showCallDialog(student),
          onTap: () => _showStudentDetails(student, busIdToNumber, activeTripId, direction, isAttended, isLocked),
          isMyBus: student.assignedBusId == driverBusId && driverBusId != null,
        );
      },
    );
  }

  Widget _buildBusTag(String label, Color bg, Color border, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAttendanceSummary(List<UserProfile> students, String direction) {
    final total = students.length;
    final marked = students.where((s) => _localAttendedIds.contains(s.id)).length;
    final pending = total - marked;
    final label = direction == 'pickup' ? 'Picked Up' : 'Dropped Off';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total', total, Colors.black87),
          _buildSummaryItem(
              label, marked, direction == 'pickup' ? Colors.green : Colors.blue),
          _buildSummaryItem('Pending', pending, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// Called when driver taps a student checkbox.
  /// Immediately writes to Firestore attendance DB AND sends FCM notification to the student.
  void _onAttendanceChanged(
      UserProfile student, bool checked, String direction, String activeTripId) async {
    // If unchecking, show confirmation dialog
    if (!checked) {
      final label = direction == 'pickup' ? 'not picked up' : 'not dropped off';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Action'),
          content: Text('Do you want to mark ${student.name} as $label?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, keep it')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes, mark as $label',
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Optimistic UI update
    setState(() {
      if (checked) {
        _localAttendedIds.add(student.id);
      } else {
        _localAttendedIds.remove(student.id);
      }
      _pendingIds.add(student.id);
    });

    // Persist locally (for trip end upload safety net)
    await _saveLocalAttendance(activeTripId, direction);

    try {
      final apiDS = await _buildApiDataSource();

      // Use markPickup / markDropoff — these write to DB AND send FCM immediately.
      // Only call for "checked" state; unchecking is local-only (records remain in DB
      // to avoid confusion, driver can re-check if needed).
      if (checked) {
        if (direction == 'pickup') {
          await apiDS.markStudentPickup(
            tripId: activeTripId,
            studentId: student.id,
          );
        } else {
          await apiDS.markStudentDropoff(
            tripId: activeTripId,
            studentId: student.id,
          );
        }
      }
    } catch (e) {
      debugPrint('[DriverStudentsScreen] Attendance API failed: $e');
      // Show snack bar but keep optimistic state — historyUpload at trip end is the safety net
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Saved locally. Will sync on trip end.'),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingIds.remove(student.id));
      }
    }
  }

  void _showStudentDetails(UserProfile student, Map<String, String> busIdToNumber,
      String? activeTripId, String direction, bool isAttended, bool isLocked) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 4),
                      ),
                      child: ProfileAvatar(
                        photoUrl: student.photoUrl,
                        name: student.name,
                        radius: 42,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.name ?? 'Unknown Student', style: AppTypography.h2.copyWith(fontWeight: FontWeight.bold)),
                          Text(student.email, style: AppTypography.bodyMd.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (activeTripId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAttended
                          ? (direction == 'pickup' ? Colors.green[50] : Colors.blue[50])
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAttended
                            ? (direction == 'pickup' ? Colors.green[200]! : Colors.blue[200]!)
                            : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked ? Icons.verified : (isAttended ? Icons.check_circle : Icons.watch_later_outlined),
                          size: 18,
                          color: isAttended
                              ? (direction == 'pickup' ? Colors.green[700] : Colors.blue[700])
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isLocked 
                              ? 'Verified'
                              : (isAttended
                                  ? (direction == 'pickup' ? 'Picked Up' : 'Dropped Off')
                                  : 'Pending Record'),
                          style: TextStyle(
                            color: isAttended
                                ? (direction == 'pickup' ? Colors.green[700] : Colors.blue[700])
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),
                if (student.phone != null)
                  _detailRow(Icons.phone_android, 'Personal Contact', student.phone!),
                
                _detailRow(Icons.directions_bus_filled_outlined, 'Assigned Vehicle', _getBusLabel(student.assignedBusId, busIdToNumber, isFull: true)),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                
                _detailRow(
                  Icons.location_on_outlined, 
                  'Home Address', 
                  (student.homeAddress != null && student.homeAddress!.isNotEmpty) ? student.homeAddress! : 'Address Not Provided'
                ),

                _infoSection(
                  'Parent / Guardian',
                  (student.parentName != null && student.parentName!.isNotEmpty) ? student.parentName! : 'Contact Not Set',
                  student.parentContact,
                  Icons.person_pin_circle_outlined,
                  Colors.indigo,
                ),

                _infoSection(
                  'Emergency Contact 1',
                  (student.emergencyContactName1 != null && student.emergencyContactName1!.isNotEmpty) ? student.emergencyContactName1! : 'Contact 1 Not Set',
                  student.emergencyContactPhone1,
                  Icons.shield_outlined,
                  Colors.orange,
                  isHandoverEnabled: activeTripId != null && direction == 'dropoff' && !isLocked,
                  onHandover: () {
                    Navigator.pop(context);
                    _handleHandover(student, activeTripId!, initialName: student.emergencyContactName1, initialPhone: student.emergencyContactPhone1);
                  },
                ),

                _infoSection(
                  'Emergency Contact 2',
                  (student.emergencyContactName2 != null && student.emergencyContactName2!.isNotEmpty) ? student.emergencyContactName2! : 'Contact 2 Not Set',
                  student.emergencyContactPhone2,
                  Icons.security_outlined,
                  Colors.red,
                  isHandoverEnabled: activeTripId != null && direction == 'dropoff' && !isLocked,
                  onHandover: () {
                    Navigator.pop(context);
                    _handleHandover(student, activeTripId!, initialName: student.emergencyContactName2, initialPhone: student.emergencyContactPhone2);
                  },
                ),

                if (isLocked)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Daily attendance verified. This record is locked.',
                            style: TextStyle(fontSize: 13, color: Colors.amber[900], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _makePhoneCall(student.phone);
                        },
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call Student'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    if (activeTripId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLocked ? null : () {
                            Navigator.pop(context);
                            _onAttendanceChanged(student, !isAttended, direction, activeTripId);
                          },
                          icon: Icon(isAttended ? Icons.undo_rounded : Icons.check_circle_rounded),
                          label: Text(isAttended ? 'Reset' : (direction == 'pickup' ? 'Mark Pickup' : 'Mark Dropoff')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLocked ? Colors.grey[300] : (isAttended ? Colors.red[50] : (direction == 'pickup' ? Colors.green[600] : Colors.blue[600])),
                            foregroundColor: isLocked ? Colors.grey[600] : (isAttended ? Colors.red : Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: isLocked || isAttended ? 0 : 2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (activeTripId != null && direction == 'dropoff' && !isLocked) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleHandover(student, activeTripId);
                      },
                      icon: const Icon(Icons.handshake_rounded),
                      label: const Text('Handover to other (OTP Verification)'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: Colors.orange[800],
                        backgroundColor: Colors.orange[50],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCallDialog(UserProfile student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call ${student.name ?? 'Student'}?'),
        content: Text('Phone: ${student.phone ?? 'N/A'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(student.phone);
            },
            icon: const Icon(Icons.call),
            label: const Text('Call'),
          ),
        ],
      ),
    );
  }

  String _getBusLabel(String? busId, Map<String, String> busMap, {bool isFull = false}) {
    if (busId == null) return 'No Bus';
    final number = busMap[busId];
    if (number != null) return isFull ? 'Bus $number' : 'Bus $number';
    return isFull ? 'Assigned' : 'Assigned';
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String name, String? phone, IconData icon, Color color, {VoidCallback? onHandover, bool isHandoverEnabled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (phone != null && phone.isNotEmpty)
                        Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(Icons.call, size: 20, color: color.withOpacity(0.7)),
                    onPressed: () => _makePhoneCall(phone),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (isHandoverEnabled) ...[
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: onHandover,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Icon(Icons.handshake_outlined, size: 20, color: color),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleHandover(UserProfile student, String activeTripId, {String? initialName, String? initialPhone}) async {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);

    // If both are provided, we can either skip the dialog or just show it pre-filled
    // Given the user wants a "checkbox to drop off", showing a quick confirmation or pre-filled dialog is safest.
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName != null ? 'Confirm Handover' : 'Neighbor Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Recipient Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameController.text,
              'phone': phoneController.text,
            }),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final apiDS = await _buildApiDataSource();
      await apiDS.generateHandoverOTP(
        tripId: activeTripId,
        studentId: student.id,
        neighborName: result['name'],
        neighborPhone: result['phone'],
      );
      
      if (mounted) {
        _showHandoverOtpDialog(student, activeTripId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate OTP: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showHandoverOtpDialog(UserProfile student, String activeTripId) {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Verify Handover'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter the 6-digit OTP sent to ${student.name}\'s phone to complete the handover.'),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '......',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: errorText,
                ),
                textAlign: TextAlign.center,
                onChanged: (_) {
                  if (errorText != null) {
                    setModalState(() => errorText = null);
                  }
                },
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (otpController.text.length != 6) {
                        setModalState(() => errorText = 'Enter 6 digits');
                        return;
                      }
                      setModalState(() {
                        isVerifying = true;
                        errorText = null;
                      });
                      try {
                        final apiDS = await _buildApiDataSource();
                        await apiDS.verifyHandoverOTP(
                          tripId: activeTripId,
                          studentId: student.id,
                          otp: otpController.text,
                        );
                        
                        if (mounted) {
                          Navigator.pop(context); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Handover verified successfully'), backgroundColor: Colors.green),
                          );
                          // Refresh attendance state
                          _loadLocalAttendance();
                        }
                      } catch (e) {
                        if (mounted) {
                          String newErrorMsg = e.toString();
                          if (e is DioException) {
                            newErrorMsg = e.response?.data?['message'] ?? e.message ?? e.toString();
                          }
                          setModalState(() {
                            isVerifying = false;
                            errorText = newErrorMsg;
                          });
                        }
                      }
                    },
              child: isVerifying
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentItem extends StatelessWidget {
  final UserProfile student;
  final bool isOnOtherBus;
  final bool isMyBus;
  final String busLabel;
  final bool isAttended;
  final bool isLocked;
  final bool isPending;
  final String? activeTripId;
  final String direction;
  final ValueChanged<bool> onAttendanceChanged;
  final VoidCallback onCall;
  final VoidCallback onTap;

  const StudentItem({
    super.key,
    required this.student,
    required this.isOnOtherBus,
    required this.isMyBus,
    required this.busLabel,
    required this.isAttended,
    required this.isLocked,
    required this.isPending,
    this.activeTripId,
    required this.direction,
    required this.onAttendanceChanged,
    required this.onCall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ProfileAvatar(
          photoUrl: student.photoUrl,
          name: student.name,
          radius: 30,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    student.name ?? 'Unknown Student',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isLocked)
                  const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            if (isOnOtherBus)
              _BusTag(label: busLabel, color: Colors.orange)
            else if (isMyBus)
              const _BusTag(label: 'My Bus', color: Colors.green),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.email),
            if (student.phone != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  student.phone!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: activeTripId != null
            ? (isPending
                ? const SizedBox(
                    width: 48, height: 48,
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : SizedBox(
                    width: 48, height: 48,
                    child: Checkbox(
                      value: isAttended,
                      activeColor: isLocked ? Colors.grey : (direction == 'pickup' ? Colors.green : Colors.blue),
                      onChanged: isLocked ? null : (val) => onAttendanceChanged(val ?? false),
                    ),
                  ))
            : SizedBox(
                width: 48, height: 48,
                child: IconButton(
                  icon: const Icon(Icons.call, color: AppColors.primary),
                  onPressed: onCall,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _BusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _BusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
