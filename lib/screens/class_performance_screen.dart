// lib/screens/class_performance_screen.dart
//
// Teacher screen: Class Performance Overview (see BLUEPRINT.md 5.5). Per
// subject the teacher teaches, shows an overall class health score, a
// Safe / At-Risk / Barred category breakdown (derived from each student's
// latest percentage), and every enrolled student's trend (Steady / Dropping
// / Critical — derived from the change since their last recorded
// percentage, not stored history). Students with a "Critical" trend can be
// sent a Warning Letter, which is written to the `warningLetters`
// collection against the student's linked parent.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Percentage below which a student counts as "Safe" / "At-Risk" / "Barred".
const int _kSafeMinPercentage = 70;
const int _kAtRiskMinPercentage = 50;
// A drop of this many points (or more) since the last recorded percentage
// marks the student's trend as "Critical" instead of just "Dropping".
const int _kCriticalDropThreshold = -15;

class ClassPerformanceScreen extends StatefulWidget {
  const ClassPerformanceScreen({super.key});

  @override
  State<ClassPerformanceScreen> createState() => _ClassPerformanceScreenState();
}

class _ClassPerformanceScreenState extends State<ClassPerformanceScreen> {
  bool _loadingSubjects = true;
  List<String> _teacherSubjects = [];
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadTeacherSubjects();
  }

  Future<void> _loadTeacherSubjects() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final subjects = List<String>.from(doc.data()?['subjects'] ?? []);

    if (mounted) {
      setState(() {
        _teacherSubjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _loadingSubjects = false;
      });
    }
  }

  CollectionReference<Map<String, dynamic>> _performanceRef(
    String subjectLevel,
  ) => FirebaseFirestore.instance
      .collection('performance')
      .doc(subjectLevel)
      .collection('students');

  String _categoryFor(num percentage) {
    if (percentage >= _kSafeMinPercentage) return 'safe';
    if (percentage >= _kAtRiskMinPercentage) return 'at_risk';
    return 'barred';
  }

  String _trendFor(num? oldPercentage, num newPercentage) {
    if (oldPercentage == null) return 'steady';
    final diff = newPercentage - oldPercentage;
    if (diff <= _kCriticalDropThreshold) return 'critical';
    if (diff < 0) return 'dropping';
    return 'steady';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'safe':
        return Colors.green;
      case 'at_risk':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'safe':
        return 'Safe';
      case 'at_risk':
        return 'At-Risk';
      default:
        return 'Barred';
    }
  }

  Color _trendColor(String trend) {
    switch (trend) {
      case 'critical':
        return Colors.red;
      case 'dropping':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'critical':
        return Icons.trending_down_rounded;
      case 'dropping':
        return Icons.south_east_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'critical':
        return 'Critical';
      case 'dropping':
        return 'Dropping';
      default:
        return 'Steady';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _editPercentage(
    String subjectLevel,
    String studentUid,
    String studentName,
    num? currentPercentage,
  ) async {
    final controller = TextEditingController(
      text: currentPercentage?.round().toString() ?? '',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(studentName),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Percentage (0-100)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 100) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a number between 0 and 100.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;

    final trend = _trendFor(currentPercentage, result);

    await _performanceRef(subjectLevel).doc(studentUid).set({
      'name': studentName,
      'percentage': result,
      'trend': trend,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendWarningLetter(
    String studentUid,
    String studentName,
    String subjectLevel,
    num percentage,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .get();
    final parentUid = studentDoc.data()?['parentUid'] as String?;

    if (parentUid == null || parentUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$studentName has no parent linked to their account yet.',
          ),
        ),
      );
      return;
    }

    final reasonController = TextEditingController(
      text:
          "$studentName's performance in $subjectLevel has dropped sharply "
          '(now $percentage%). Please follow up with your child regarding this subject.',
    );

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Warning Letter'),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    await FirebaseFirestore.instance.collection('warningLetters').add({
      'studentUid': studentUid,
      'teacherUid': currentUser.uid,
      'parentUid': parentUid,
      'subjectLevel': subjectLevel,
      'reason': reason,
      'sentAt': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Warning letter sent for $studentName.')),
    );
  }

  void _showWarningHistory(String studentUid, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Warning Letters — $studentName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('warningLetters')
                    .where('studentUid', isEqualTo: studentUid)
                    .orderBy('sentAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final letters = snapshot.data!.docs;
                  if (letters.isEmpty) {
                    return Center(
                      child: Text(
                        'No warning letters sent yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: letters.length,
                    itemBuilder: (context, index) {
                      final data =
                          letters[index].data() as Map<String, dynamic>;
                      final sentAt = data['sentAt'] as Timestamp?;
                      final acknowledged = data['acknowledged'] == true;
                      return ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: acknowledged ? Colors.grey : Colors.red,
                        ),
                        title: Text(data['reason'] ?? ''),
                        subtitle: Text(
                          sentAt != null ? _formatDate(sentAt.toDate()) : '',
                        ),
                        trailing: acknowledged
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Performance'),
        backgroundColor: Colors.green,
      ),
      body: _loadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : _teacherSubjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No subjects assigned to your account yet. Ask an '
                      'Admin to set your subjects first.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject / Class',
                    ),
                    items: _teacherSubjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSubject = value),
                  ),
                ),
                Expanded(
                  child: _selectedSubject == null
                      ? const SizedBox.shrink()
                      : _buildSubjectBody(_selectedSubject!),
                ),
              ],
            ),
    );
  }

  Widget _buildSubjectBody(String subjectLevel) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .where('subjects', arrayContains: subjectLevel)
          .snapshots(),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.hasError) {
          return Center(child: Text('Error: ${studentsSnapshot.error}'));
        }
        if (!studentsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = studentsSnapshot.data!.docs;

        if (students.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 56,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'No students enrolled in this subject yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _performanceRef(subjectLevel).snapshots(),
          builder: (context, perfSnapshot) {
            final perfDocs = {
              for (final d
                  in perfSnapshot.data?.docs ?? <QueryDocumentSnapshot>[])
                d.id: d.data() as Map<String, dynamic>,
            };

            final graded = <num>[];
            final categoryCounts = {'safe': 0, 'at_risk': 0, 'barred': 0};
            for (final s in students) {
              final perf = perfDocs[s.id];
              final percentage = perf?['percentage'] as num?;
              if (percentage != null) {
                graded.add(percentage);
                categoryCounts[_categoryFor(percentage)] =
                    (categoryCounts[_categoryFor(percentage)] ?? 0) + 1;
              }
            }
            final healthScore = graded.isEmpty
                ? null
                : graded.reduce((a, b) => a + b) / graded.length;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        healthScore == null
                            ? 'No data yet'
                            : '${healthScore.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'Class Health Score',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['safe', 'at_risk', 'barred'].map((cat) {
                          return Column(
                            children: [
                              Text(
                                '${categoryCounts[cat]}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _categoryColor(cat),
                                ),
                              ),
                              Text(
                                _categoryLabel(cat),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final studentDoc = students[index];
                      final studentName = studentDoc['name'] ?? 'Unnamed';
                      final perf = perfDocs[studentDoc.id];
                      final percentage = perf?['percentage'] as num?;
                      final trend = perf?['trend'] as String? ?? 'steady';
                      final isCritical =
                          percentage != null && trend == 'critical';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Text(
                                      studentName.isNotEmpty
                                          ? studentName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (percentage != null)
                                          Row(
                                            children: [
                                              Icon(
                                                _trendIcon(trend),
                                                size: 14,
                                                color: _trendColor(trend),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _trendLabel(trend),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _trendColor(trend),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _categoryColor(
                                                    _categoryFor(percentage),
                                                  ).withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _categoryLabel(
                                                    _categoryFor(percentage),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _categoryColor(
                                                      _categoryFor(percentage),
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            'Not graded yet',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _editPercentage(
                                      subjectLevel,
                                      studentDoc.id,
                                      studentName,
                                      percentage,
                                    ),
                                    child: Text(
                                      percentage == null
                                          ? 'Grade'
                                          : '${percentage.round()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showWarningHistory(
                                        studentDoc.id,
                                        studentName,
                                      ),
                                      icon: const Icon(Icons.history, size: 16),
                                      label: const Text('History'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade600,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    if (isCritical)
                                      TextButton.icon(
                                        onPressed: () => _sendWarningLetter(
                                          studentDoc.id,
                                          studentName,
                                          subjectLevel,
                                          percentage,
                                        ),
                                        icon: const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Send Warning Letter',
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
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
        );
      },
    );
  }
}
