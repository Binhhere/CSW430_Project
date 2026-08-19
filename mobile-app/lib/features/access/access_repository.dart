import 'dart:async';

import '../../shared/request_timeout.dart';
import '../../config/app_config.dart';
import '../../data/course_api_client.dart';
import '../../data/local_backend_compat.dart';
import 'access_models.dart';

class LocalUser {
  const LocalUser({
    required this.id,
    required this.email,
    required this.displayName,
  });
  final String id;
  final String email;
  final String displayName;
}

class LocalSession {
  const LocalSession({required this.accessToken, required this.user});
  final String accessToken;
  final LocalUser user;
}

enum LocalAuthEvent { initialSession, signedIn, signedOut }

class LocalAuthState {
  const LocalAuthState(this.event, this.session);
  final LocalAuthEvent event;
  final LocalSession? session;
}

class AccessRepository {
  AccessRepository(this.client, this.redirectUrl, [CourseApiClient? api])
    : api = api ?? CourseApiClient(AppConfig.current.apiBaseUrl);

  AccessRepository.local(this.api) : client = null, redirectUrl = '';

  // Kept only for legacy screens that are outside the local course demo.
  // The assessed authentication/profile/customer paths never read it.
  final dynamic client;
  final String redirectUrl;
  final CourseApiClient api;

  LocalSession? _session;
  final _authChanges = StreamController<LocalAuthState>.broadcast();

  LocalSession? get session => _session;
  Stream<LocalAuthState> get authChanges => _authChanges.stream;

  Future<void> restoreLocalSession() async {}

  void _setSession(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.from(data['user'] as Map);
    final session = Map<String, dynamic>.from(data['session'] as Map);
    _session = LocalSession(
      accessToken: session['accessToken'] as String,
      user: LocalUser(
        id: user['id'] as String,
        email: user['email'] as String,
        displayName: user['displayName'] as String? ?? user['email'] as String,
      ),
    );
    CourseApiClient.localAccessToken = _session!.accessToken;
    _authChanges.add(LocalAuthState(LocalAuthEvent.signedIn, _session));
  }

  Future<void> signIn(String email, String password) async {
    final data = await withRelayRequestTimeout(
      api.post('/api/v1/auth/login', {
        'email': email.trim(),
        'password': password,
      }),
    );
    _setSession(Map<String, dynamic>.from(data as Map));
  }

  Future<bool> hasCurrentLegalAcceptance() async {
    return true;
  }

  Future<void> recordCurrentLegalAcceptance(String method) async {}

  Future<bool> register(
    String displayName,
    String email,
    String password,
  ) async {
    final data = await withRelayRequestTimeout(
      api.post('/api/v1/auth/register', {
        'displayName': displayName.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );
    if (data is! Map || data['session'] is! Map) return false;
    _setSession(Map<String, dynamic>.from(data));
    return true;
  }

  Future<bool> signInWithGoogle() async {
    return false;
  }

  Future<void> sendPasswordReset(String email) async {}

  Future<void> updatePassword(String password) async {}

  Future<void> signOut() async {
    _session = null;
    CourseApiClient.localAccessToken = null;
    _authChanges.add(const LocalAuthState(LocalAuthEvent.signedOut, null));
  }

  Future<AccountDeletionPreview> previewAccountDeletion() async {
    final rows = await withRelayRequestTimeout(
      client.rpc('preview_current_account_deletion'),
    );
    if (rows is! List || rows.length != 1) {
      throw StateError('Account deletion preview is unavailable');
    }
    return AccountDeletionPreview.fromRow(
      Map<String, dynamic>.from(rows.single as Map),
    );
  }

  Future<AccountDeletionResult> deleteAccount() async {
    late final FunctionResponse response;
    try {
      response = await withRelayRequestTimeout(
        client.functions.invoke('delete-account'),
        timeout: const Duration(seconds: 30),
      );
    } on BackendFunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        throw AccountDeletionFailure(
          code: details['code'] as String?,
          stage: details['stage'] as String?,
        );
      }
      throw const AccountDeletionFailure();
    }
    final data = response.data;
    if (data is! Map) {
      throw const AccountDeletionFailure(code: 'INVALID_RESPONSE');
    }
    final row = Map<String, dynamic>.from(data);
    final action = row['action'] as String?;
    if (action == null) {
      throw AccountDeletionFailure(
        code: row['code'] as String?,
        stage: row['stage'] as String?,
      );
    }
    return AccountDeletionResult(
      action: DeletionAction.fromWire(action),
      reasons: deletionReasonsFromWire(row['reasons']),
    );
  }

  Future<List<RelayCompany>> companies() async {
    final rows = await withRelayRequestTimeout(api.get('/api/v1/companies'));
    return [
      for (final row in rows as List)
        RelayCompany(
          id: row['id'] as String,
          name: row['name'] as String,
          role: CompanyRole.fromWire(row['role'] as String),
        ),
    ];
  }

  Future<List<DeveloperAnnouncement>> developerAnnouncements({
    DateTime? afterPublishedAt,
    String? afterId,
    int pageSize = 20,
  }) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'list_developer_announcements',
        params: {
          'after_published_at': afterPublishedAt?.toUtc().toIso8601String(),
          'after_id': afterId,
          'page_size': pageSize,
        },
      ),
    );
    return [
      for (final row in rows as List)
        DeveloperAnnouncement.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<DeveloperAnnouncementStatus> developerAnnouncementStatus() async {
    final rows = await withRelayRequestTimeout(
      client.rpc('get_developer_announcement_status'),
    );
    if (rows is! List || rows.length != 1) {
      throw StateError('Developer announcement status is unavailable');
    }
    return DeveloperAnnouncementStatus.fromRow(
      Map<String, dynamic>.from(rows.single as Map),
    );
  }

  Future<void> markDeveloperAnnouncementSeen(String announcementId) =>
      withRelayRequestTimeout(
        client.rpc(
          'mark_developer_announcement_seen',
          params: {'target_announcement_id': announcementId},
        ),
      );

  Future<int> markAllDeveloperAnnouncementsSeen() async {
    final result = await withRelayRequestTimeout(
      client.rpc('mark_all_developer_announcements_seen'),
    );
    return (result as num?)?.toInt() ?? 0;
  }

  Future<String> createCompany(String name) async =>
      await withRelayRequestTimeout(
            client.rpc('create_company', params: {'company_name': name.trim()}),
          )
          as String;

  Future<InvitationPreview?> previewInvitation(String code) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'preview_company_invitation',
        params: {'raw_code': _normalizeCode(code)},
      ),
    );
    if (rows is! List || rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.single as Map);
    return InvitationPreview(
      workspaceId: row['workspace_id'] as String,
      companyName: row['company_name'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<String?> acceptInvitation(String code) async =>
      await withRelayRequestTimeout(
            client.rpc(
              'accept_company_invitation',
              params: {'raw_code': _normalizeCode(code)},
            ),
          )
          as String?;

  Future<List<RelayMember>> members(String companyId) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'list_company_members',
        params: {'target_workspace_id': companyId},
      ),
    );
    return [
      for (final row in rows as List)
        RelayMember(
          userId: row['user_id'] as String,
          displayName: row['display_name'] as String,
          role: CompanyRole.fromWire(row['role'] as String),
        ),
    ];
  }

  Future<List<CompanyOwnerTransferRequest>> ownerTransferRequests(
    String companyId,
  ) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'list_company_owner_transfer_requests',
        params: {'target_workspace_id': companyId},
      ),
    );
    return [
      for (final row in rows as List)
        CompanyOwnerTransferRequest.fromRow(
          Map<String, dynamic>.from(row as Map),
        ),
    ];
  }

  Future<void> requestCompanyOwnerTransfer(String companyId, String userId) =>
      withRelayRequestTimeout(
        client.rpc(
          'request_company_owner_transfer',
          params: {'target_workspace_id': companyId, 'target_user_id': userId},
        ),
      );

  Future<void> cancelCompanyOwnerTransferRequest(String requestId) =>
      withRelayRequestTimeout(
        client.rpc(
          'cancel_company_owner_transfer_request',
          params: {'target_request_id': requestId},
        ),
      );

  Future<void> acceptCompanyOwnerTransferRequest(String requestId) =>
      withRelayRequestTimeout(
        client.rpc(
          'accept_company_owner_transfer_request',
          params: {'target_request_id': requestId},
        ),
      );

  Future<InvitationCode> rotateInvitation(String companyId) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'rotate_company_invitation',
        params: {'target_workspace_id': companyId},
      ),
    );
    final row = Map<String, dynamic>.from((rows as List).single as Map);
    return InvitationCode(
      code: row['code'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<void> revokeInvitation(String companyId) => withRelayRequestTimeout(
    client.rpc(
      'revoke_company_invitation',
      params: {'target_workspace_id': companyId},
    ),
  );

  Future<InvitationStatus> invitationStatus(String companyId) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'get_company_invitation_status',
        params: {'target_workspace_id': companyId},
      ),
    );
    if (rows is! List || rows.isEmpty) {
      return const InvitationStatus(active: false);
    }
    final row = Map<String, dynamic>.from(rows.single as Map);
    return InvitationStatus(
      active: row['active'] as bool? ?? false,
      expiresAt: row['expires_at'] == null
          ? null
          : DateTime.parse(row['expires_at'] as String),
    );
  }

  Future<CompanyDeletionPreview> previewCompanyDeletion(
    String companyId,
  ) async {
    final rows = await withRelayRequestTimeout(
      client.rpc(
        'preview_company_deletion',
        params: {'target_workspace_id': companyId},
      ),
    );
    if (rows is! List || rows.length != 1) {
      throw StateError('Company deletion preview is unavailable');
    }
    return CompanyDeletionPreview.fromRow(
      Map<String, dynamic>.from(rows.single as Map),
    );
  }

  Future<void> deleteCompany(String companyId) async {
    late final FunctionResponse response;
    try {
      response = await withRelayRequestTimeout(
        client.functions.invoke(
          'delete-company',
          headers: {'x-relay-workspace-id': companyId},
        ),
      );
    } on BackendFunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        throw CompanyDeletionFailure(
          code: details['code'] as String?,
          stage: details['stage'] as String?,
          reasons: deletionReasonsFromWire(details['reasons']),
        );
      }
      throw const CompanyDeletionFailure();
    }
    final data = response.data;
    if (data is! Map) {
      throw const CompanyDeletionFailure(code: 'INVALID_RESPONSE');
    }
    final row = Map<String, dynamic>.from(data);
    final action = row['action'] as String?;
    if (action != null &&
        DeletionAction.fromWire(action) == DeletionAction.deleted) {
      return;
    }
    throw CompanyDeletionFailure(
      code: row['code'] as String?,
      stage: row['stage'] as String?,
      reasons: deletionReasonsFromWire(row['reasons']),
    );
  }

  Future<void> removeStaffMember(String companyId, String userId) =>
      withRelayRequestTimeout(
        client.rpc(
          'remove_company_staff_member',
          params: {'target_workspace_id': companyId, 'target_user_id': userId},
        ),
      );

  Future<void> renameCompany(String companyId, String name) =>
      withRelayRequestTimeout(
        client
            .from('workspaces')
            .update({'name': name.trim()})
            .eq('id', companyId),
      );

  Future<String?> profileName() async {
    final data = await withRelayRequestTimeout(api.get('/api/v1/profile'));
    return data['display_name'] as String?;
  }

  Future<void> updateProfileName(String value) async {
    await withRelayRequestTimeout(
      api.put('/api/v1/profile', {'displayName': value.trim()}),
    );
  }

  String _normalizeCode(String value) {
    final compact = value.toUpperCase().replaceAll(
      RegExp(r'[^0-9A-HJKMNP-TV-Z]'),
      '',
    );
    if (compact.length != 16) return value.trim().toUpperCase();
    return '${compact.substring(0, 4)}-${compact.substring(4, 8)}-'
        '${compact.substring(8, 12)}-${compact.substring(12, 16)}';
  }
}
