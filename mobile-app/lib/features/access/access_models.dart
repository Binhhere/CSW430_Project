enum CompanyRole {
  owner('OWNER'),
  staff('STAFF');

  const CompanyRole(this.wireValue);
  final String wireValue;

  factory CompanyRole.fromWire(String value) => switch (value) {
    'OWNER' => CompanyRole.owner,
    'STAFF' => CompanyRole.staff,
    _ => throw FormatException('Unknown Company role: $value'),
  };
}

enum DeletionAction {
  deleteNow('DELETE_NOW'),
  requestManual('REQUEST_MANUAL'),
  blocked('BLOCKED'),
  blockedActiveAssignment('BLOCKED_ACTIVE_ASSIGNMENT'),
  deleted('DELETED');

  const DeletionAction(this.wireValue);
  final String wireValue;

  factory DeletionAction.fromWire(String value) => switch (value) {
    'DELETE_NOW' => DeletionAction.deleteNow,
    'REQUEST_MANUAL' => DeletionAction.requestManual,
    'BLOCKED' => DeletionAction.blocked,
    'BLOCKED_ACTIVE_ASSIGNMENT' => DeletionAction.blockedActiveAssignment,
    'DELETED' => DeletionAction.deleted,
    _ => throw FormatException('Unknown deletion action: $value'),
  };
}

enum DeletionReason {
  requestAlreadyPending('ACCOUNT_REQUEST_ALREADY_PENDING'),
  ownedCompanyHasMembers('ACCOUNT_OWNS_COMPANY_WITH_MEMBERS'),
  ownedCompanyHasActiveWork('ACCOUNT_COMPANY_HAS_ACTIVE_WORK'),
  activeAssignment('ACCOUNT_HAS_ACTIVE_ASSIGNMENT'),
  companyHasStaff('COMPANY_HAS_STAFF'),
  companyHasActiveTransfers('COMPANY_HAS_ACTIVE_TRANSFERS'),
  companyHasOpenDamage('COMPANY_HAS_OPEN_DAMAGE');

  const DeletionReason(this.wireValue);
  final String wireValue;

  String get messageKey => switch (this) {
    DeletionReason.requestAlreadyPending => 'deletionRequestAlreadyPending',
    DeletionReason.ownedCompanyHasMembers => 'deletionOwnedCompanyHasMembers',
    DeletionReason.ownedCompanyHasActiveWork =>
      'deletionOwnedCompanyHasActiveWork',
    DeletionReason.activeAssignment => 'completeOrReassignWork',
    DeletionReason.companyHasStaff => 'deletionCompanyHasStaff',
    DeletionReason.companyHasActiveTransfers =>
      'deletionCompanyHasActiveTransfers',
    DeletionReason.companyHasOpenDamage => 'deletionCompanyHasOpenDamage',
  };

  factory DeletionReason.fromWire(String value) => switch (value) {
    'ACCOUNT_REQUEST_ALREADY_PENDING' => DeletionReason.requestAlreadyPending,
    'ACCOUNT_OWNS_COMPANY_WITH_MEMBERS' =>
      DeletionReason.ownedCompanyHasMembers,
    'ACCOUNT_COMPANY_HAS_ACTIVE_WORK' =>
      DeletionReason.ownedCompanyHasActiveWork,
    'ACCOUNT_HAS_ACTIVE_ASSIGNMENT' => DeletionReason.activeAssignment,
    'COMPANY_HAS_STAFF' => DeletionReason.companyHasStaff,
    'COMPANY_HAS_ACTIVE_TRANSFERS' => DeletionReason.companyHasActiveTransfers,
    'COMPANY_HAS_OPEN_DAMAGE' => DeletionReason.companyHasOpenDamage,
    _ => throw FormatException('Unknown deletion reason: $value'),
  };
}

List<DeletionReason> deletionReasonsFromWire(Object? value) => [
  for (final reason in (value as List? ?? const []))
    DeletionReason.fromWire(reason as String),
];

class RelayCompany {
  const RelayCompany({
    required this.id,
    required this.name,
    required this.role,
  });
  final String id;
  final String name;
  final CompanyRole role;
  bool get isOwner => role == CompanyRole.owner;
}

class DeveloperAnnouncement {
  const DeveloperAnnouncement({
    required this.id,
    required this.announcementKey,
    required this.titleEn,
    required this.bodyEn,
    required this.titleEs,
    required this.bodyEs,
    required this.titleJa,
    required this.bodyJa,
    required this.publishedAt,
    required this.expiresAt,
    required this.seenAt,
    required this.isUnread,
  });

  final String id;
  final String announcementKey;
  final String titleEn;
  final String bodyEn;
  final String titleEs;
  final String bodyEs;
  final String titleJa;
  final String bodyJa;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final DateTime? seenAt;
  final bool isUnread;
  bool get isBundled => id.startsWith('bundled:');

  String titleFor(String languageCode) =>
      switch (languageCode.toLowerCase().split('-').first) {
        'es' => titleEs,
        'ja' => titleJa,
        _ => titleEn,
      };

  String bodyFor(String languageCode) =>
      switch (languageCode.toLowerCase().split('-').first) {
        'es' => bodyEs,
        'ja' => bodyJa,
        _ => bodyEn,
      };

  factory DeveloperAnnouncement.fromRow(Map<String, dynamic> row) =>
      DeveloperAnnouncement(
        id: row['id'] as String,
        announcementKey: row['announcement_key'] as String,
        titleEn: row['title_en'] as String,
        bodyEn: row['body_en'] as String,
        titleEs: row['title_es'] as String,
        bodyEs: row['body_es'] as String,
        titleJa: row['title_ja'] as String,
        bodyJa: row['body_ja'] as String,
        publishedAt: DateTime.parse(row['published_at'] as String),
        expiresAt: row['expires_at'] == null
            ? null
            : DateTime.parse(row['expires_at'] as String),
        seenAt: row['seen_at'] == null
            ? null
            : DateTime.parse(row['seen_at'] as String),
        isUnread: row['is_unread'] as bool? ?? true,
      );
}

class DeveloperAnnouncementStatus {
  const DeveloperAnnouncementStatus({
    required this.unreadCount,
    required this.totalCount,
  });

  final int unreadCount;
  final int totalCount;

  factory DeveloperAnnouncementStatus.fromRow(Map<String, dynamic> row) =>
      DeveloperAnnouncementStatus(
        unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
        totalCount: (row['total_count'] as num?)?.toInt() ?? 0,
      );
}

class RelayMember {
  const RelayMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });
  final String userId;
  final String displayName;
  final CompanyRole role;
  bool get isOwner => role == CompanyRole.owner;
}

enum CompanyOwnerTransferRequestState {
  pending('PENDING'),
  cancelled('CANCELLED'),
  accepted('ACCEPTED'),
  expired('EXPIRED');

  const CompanyOwnerTransferRequestState(this.wireValue);
  final String wireValue;

  factory CompanyOwnerTransferRequestState.fromWire(String value) =>
      switch (value) {
        'PENDING' => CompanyOwnerTransferRequestState.pending,
        'CANCELLED' => CompanyOwnerTransferRequestState.cancelled,
        'ACCEPTED' => CompanyOwnerTransferRequestState.accepted,
        'EXPIRED' => CompanyOwnerTransferRequestState.expired,
        _ => throw FormatException(
          'Unknown owner transfer request state: $value',
        ),
      };
}

class CompanyOwnerTransferRequest {
  const CompanyOwnerTransferRequest({
    required this.requestId,
    required this.requestedByUserId,
    required this.requestedByDisplayName,
    required this.targetUserId,
    required this.targetDisplayName,
    required this.requestedAt,
    required this.expiresAt,
    required this.state,
    required this.canCancel,
    required this.canAccept,
  });

  final String requestId;
  final String requestedByUserId;
  final String requestedByDisplayName;
  final String targetUserId;
  final String targetDisplayName;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final CompanyOwnerTransferRequestState state;
  final bool canCancel;
  final bool canAccept;

  bool get isPending => state == CompanyOwnerTransferRequestState.pending;

  factory CompanyOwnerTransferRequest.fromRow(Map<String, dynamic> row) =>
      CompanyOwnerTransferRequest(
        requestId: row['request_id'] as String,
        requestedByUserId: row['requested_by_user_id'] as String,
        requestedByDisplayName: row['requested_by_display_name'] as String,
        targetUserId: row['target_user_id'] as String,
        targetDisplayName: row['target_display_name'] as String,
        requestedAt: DateTime.parse(row['requested_at'] as String),
        expiresAt: DateTime.parse(row['expires_at'] as String),
        state: CompanyOwnerTransferRequestState.fromWire(
          row['state'] as String,
        ),
        canCancel: row['can_cancel'] as bool? ?? false,
        canAccept: row['can_accept'] as bool? ?? false,
      );
}

class InvitationPreview {
  const InvitationPreview({
    required this.workspaceId,
    required this.companyName,
    required this.expiresAt,
  });
  final String workspaceId;
  final String companyName;
  final DateTime expiresAt;
}

class InvitationCode {
  const InvitationCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

class InvitationStatus {
  const InvitationStatus({required this.active, this.expiresAt});

  final bool active;
  final DateTime? expiresAt;
}

class CompanyDeletionPreview {
  const CompanyDeletionPreview({
    required this.action,
    required this.reasons,
    required this.companyName,
    required this.staffCount,
    required this.activeTransferCount,
    required this.unresolvedDamageCount,
  });

  final DeletionAction action;
  final List<DeletionReason> reasons;
  final String companyName;
  final int staffCount;
  final int activeTransferCount;
  final int unresolvedDamageCount;

  bool get canDeleteNow => action == DeletionAction.deleteNow;

  factory CompanyDeletionPreview.fromRow(Map<String, dynamic> row) =>
      CompanyDeletionPreview(
        action: DeletionAction.fromWire(row['action'] as String),
        reasons: deletionReasonsFromWire(row['reasons']),
        companyName: row['company_name'] as String,
        staffCount: (row['staff_count'] as num?)?.toInt() ?? 0,
        activeTransferCount:
            (row['active_transfer_count'] as num?)?.toInt() ?? 0,
        unresolvedDamageCount:
            (row['unresolved_damage_count'] as num?)?.toInt() ?? 0,
      );
}

class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.action,
    required this.reasons,
    required this.companyCount,
  });

  final DeletionAction action;
  final List<DeletionReason> reasons;
  final int companyCount;

  bool get canDeleteNow => action == DeletionAction.deleteNow;
  bool get needsManualHandling => action == DeletionAction.requestManual;
  bool get isBlockedByActiveAssignment =>
      action == DeletionAction.blockedActiveAssignment;

  factory AccountDeletionPreview.fromRow(Map<String, dynamic> row) =>
      AccountDeletionPreview(
        action: DeletionAction.fromWire(row['action'] as String),
        reasons: deletionReasonsFromWire(row['reasons']),
        companyCount: (row['company_count'] as num?)?.toInt() ?? 0,
      );
}

class AccountDeletionResult {
  const AccountDeletionResult({required this.action, this.reasons = const []});

  final DeletionAction action;
  final List<DeletionReason> reasons;

  bool get deleted => action == DeletionAction.deleted;
  bool get requestReceived => action == DeletionAction.requestManual;
  bool get isBlockedByActiveAssignment =>
      action == DeletionAction.blockedActiveAssignment;
}

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure({this.code, this.stage});

  final String? code;
  final String? stage;

  String get userMessageKey => switch (stage) {
    'read_company_scope' => 'accountDeletionAccessFailed',
    'remove_storage' => 'accountDeletionStorageFailed',
    'mark_storage_cleaned' => 'accountDeletionSafetyFailed',
    'revoke_sessions' => 'accountDeletionSessionsFailed',
    'delete_auth_identity' => 'accountDeletionIdentityFailed',
    _ => 'accountDeletionFinishFailed',
  };

  @override
  String toString() => 'AccountDeletionFailure(code: $code, stage: $stage)';
}

class CompanyDeletionFailure implements Exception {
  const CompanyDeletionFailure({
    this.code,
    this.stage,
    this.reasons = const [],
  });

  final String? code;
  final String? stage;
  final List<DeletionReason> reasons;

  String get userMessageKey => switch (stage) {
    'remove_storage' => 'companyDeletionStorageFailed',
    'mark_storage_cleaned' => 'companyDeletionSafetyFailed',
    'delete_company' => 'companyDeletionFinishFailed',
    _ => 'companyDeletionUnavailable',
  };

  @override
  String toString() =>
      'CompanyDeletionFailure(code: $code, stage: $stage, reasons: $reasons)';
}
