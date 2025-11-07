import 'package:flutter/material.dart';
import '../models/submission.dart';
import '../services/submission_service.dart';
import '../widgets/submission_card.dart';
import '../widgets/unread_badge.dart';
import 'submission_chat_screen.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({Key? key}) : super(key: key);

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  final SubmissionService _submissionService = SubmissionService();

  List<SubmissionListItem> _submissions = [];
  UnreadCounts? _unreadCounts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final submissions = await _submissionService.listSubmissions(limit: 100);
      final unreadCounts = await _submissionService.getUnreadCount();

      setState(() {
        _submissions = submissions;
        _unreadCounts = unreadCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'All Submissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_unreadCounts != null && _unreadCounts!.total > 0) ...[
              const SizedBox(width: 12),
              UnreadBadge(count: _unreadCounts!.total, size: 22),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No submissions yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Submissions from students will appear here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final submission = _submissions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SubmissionCard(
                          submission: submission,
                          showStudentInfo: true, // Show student and program info for admins
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SubmissionChatScreen(
                                  submissionId: submission.id,
                                ),
                              ),
                            );
                            // Reload submissions if messages were added
                            if (result == true && mounted) {
                              _loadData();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
