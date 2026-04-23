import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { pending, submitted, approved, rejected }

TaskStatus parseTaskStatus(String? raw) {
  switch (raw) {
    case 'submitted':
      return TaskStatus.submitted;
    case 'approved':
      return TaskStatus.approved;
    case 'rejected':
      return TaskStatus.rejected;
    case 'pending':
    default:
      return TaskStatus.pending;
  }
}

String taskStatusToString(TaskStatus s) => s.name;

enum ProofType { image, pdf }

ProofType? parseProofType(String? raw) {
  switch (raw) {
    case 'image':
      return ProofType.image;
    case 'pdf':
      return ProofType.pdf;
    default:
      return null;
  }
}

class AgaramTask {
  final String id;
  final String eventId;
  final String eventTitle;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedToName;
  final DateTime? dueDate;
  final TaskStatus status;
  final String? proofUrl;
  final ProofType? proofType;
  final String? memberNote;
  final String? reviewNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? submittedAt;
  final int starsAwarded;

  const AgaramTask({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedToName,
    required this.status,
    this.dueDate,
    this.proofUrl,
    this.proofType,
    this.memberNote,
    this.reviewNote,
    this.reviewedBy,
    this.reviewedAt,
    this.submittedAt,
    this.starsAwarded = 0,
  });

  factory AgaramTask.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AgaramTask(
      id: doc.id,
      eventId: data['eventId'] as String? ?? doc.reference.parent.parent?.id ?? '',
      eventTitle: data['eventTitle'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assignedTo: data['assignedTo'] as String? ?? '',
      assignedToName: data['assignedToName'] as String? ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      status: parseTaskStatus(data['status'] as String?),
      proofUrl: data['proofUrl'] as String?,
      proofType: parseProofType(data['proofType'] as String?),
      memberNote: data['memberNote'] as String?,
      reviewNote: data['reviewNote'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      starsAwarded: (data['starsAwarded'] as num?)?.toInt() ?? 0,
    );
  }
}
