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

enum ExtensionStatus { pending, approved, denied }

ExtensionStatus? parseExtensionStatus(String? raw) {
  switch (raw) {
    case 'pending':
      return ExtensionStatus.pending;
    case 'approved':
      return ExtensionStatus.approved;
    case 'denied':
      return ExtensionStatus.denied;
    default:
      return null;
  }
}

String extensionStatusToString(ExtensionStatus s) => s.name;

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

  final int extensionCount;
  final ExtensionStatus? extensionStatus;
  final DateTime? extensionRequestedAt;
  final String? extensionReason;
  final int? extensionRequestedDays;
  final DateTime? extensionGrantedUntil;
  final int? extensionGrantedDays;
  final String? extensionReviewedBy;
  final DateTime? extensionReviewedAt;
  final String? extensionReviewNote;
  final bool extensionAdminInitiated;
  final int extensionStarCost;

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
    this.extensionCount = 0,
    this.extensionStatus,
    this.extensionRequestedAt,
    this.extensionReason,
    this.extensionRequestedDays,
    this.extensionGrantedUntil,
    this.extensionGrantedDays,
    this.extensionReviewedBy,
    this.extensionReviewedAt,
    this.extensionReviewNote,
    this.extensionAdminInitiated = false,
    this.extensionStarCost = 0,
  });

  /// The date the member must upload by, accounting for an approved extension.
  /// Old tasks without [dueDate] return null (can always upload).
  DateTime? get effectiveDueDate => extensionGrantedUntil ?? dueDate;

  bool get isPastDue {
    final d = effectiveDueDate;
    return d != null && DateTime.now().isAfter(d);
  }

  /// What the next member-initiated extension request will cost in stars.
  int get nextExtensionCost => extensionCount + 1;

  bool get hasPendingExtension =>
      extensionStatus == ExtensionStatus.pending;

  bool get hasActiveExtension =>
      extensionStatus == ExtensionStatus.approved &&
      extensionGrantedUntil != null &&
      DateTime.now().isBefore(extensionGrantedUntil!);

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
      extensionCount: (data['extensionCount'] as num?)?.toInt() ?? 0,
      extensionStatus: parseExtensionStatus(data['extensionStatus'] as String?),
      extensionRequestedAt:
          (data['extensionRequestedAt'] as Timestamp?)?.toDate(),
      extensionReason: data['extensionReason'] as String?,
      extensionRequestedDays:
          (data['extensionRequestedDays'] as num?)?.toInt(),
      extensionGrantedUntil:
          (data['extensionGrantedUntil'] as Timestamp?)?.toDate(),
      extensionGrantedDays: (data['extensionGrantedDays'] as num?)?.toInt(),
      extensionReviewedBy: data['extensionReviewedBy'] as String?,
      extensionReviewedAt:
          (data['extensionReviewedAt'] as Timestamp?)?.toDate(),
      extensionReviewNote: data['extensionReviewNote'] as String?,
      extensionAdminInitiated:
          data['extensionAdminInitiated'] as bool? ?? false,
      extensionStarCost: (data['extensionStarCost'] as num?)?.toInt() ?? 0,
    );
  }
}
