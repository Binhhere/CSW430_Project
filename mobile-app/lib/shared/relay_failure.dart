import 'dart:async';

import '../data/local_backend_compat.dart';
import '../l10n/relay_localizations.dart';

enum RelayFailureKind {
  timeout,
  authentication,
  authorization,
  conflict,
  validation,
  service,
  unknown,
}

class RelayFailure {
  const RelayFailure(this.kind, {this.code});

  factory RelayFailure.from(Object error) {
    if (error is TimeoutException) {
      return const RelayFailure(RelayFailureKind.timeout);
    }
    if (error is BackendAuthException) {
      return RelayFailure(RelayFailureKind.authentication, code: error.code);
    }
    if (error is PostgrestException) {
      return RelayFailure(switch (error.code) {
        '42501' => RelayFailureKind.authorization,
        '23503' || '23505' => RelayFailureKind.conflict,
        '22000' ||
        '22003' ||
        '22007' ||
        '22P02' ||
        '22023' ||
        '23502' ||
        'P0002' => RelayFailureKind.validation,
        '23514' => RelayFailureKind.conflict,
        _ => RelayFailureKind.service,
      }, code: error.code);
    }
    if (error is BackendFunctionException) {
      final status = error.status;
      return RelayFailure(switch (status) {
        401 => RelayFailureKind.authentication,
        403 => RelayFailureKind.authorization,
        409 => RelayFailureKind.conflict,
        int status when status >= 400 && status < 500 =>
          RelayFailureKind.validation,
        _ => RelayFailureKind.service,
      }, code: status?.toString());
    }
    if (error is StorageException) {
      final status = int.tryParse(error.statusCode ?? '');
      return RelayFailure(switch (status) {
        401 => RelayFailureKind.authentication,
        403 => RelayFailureKind.authorization,
        409 => RelayFailureKind.conflict,
        _ => RelayFailureKind.service,
      }, code: error.statusCode);
    }
    return const RelayFailure(RelayFailureKind.unknown);
  }

  final RelayFailureKind kind;
  final String? code;

  String message({
    required RelayLocalizations l10n,
    required String fallback,
  }) => switch (kind) {
    RelayFailureKind.timeout => l10n.text('failureTimeout'),
    RelayFailureKind.authentication => l10n.text('failureAuthentication'),
    RelayFailureKind.authorization => l10n.text('failureAuthorization'),
    RelayFailureKind.conflict => l10n.text('failureConflict'),
    RelayFailureKind.validation => l10n.text('failureValidation'),
    RelayFailureKind.service => l10n.text('failureService'),
    RelayFailureKind.unknown => fallback,
  };
}
