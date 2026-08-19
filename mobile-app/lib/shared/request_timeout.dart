import 'dart:async';

/// Shared deadline for network-backed work so a busy screen can recover when
/// the backend or connection never completes a request.
const relayRequestTimeout = Duration(seconds: 20);

Future<T> withRelayRequestTimeout<T>(
  Future<T> request, {
  Duration timeout = relayRequestTimeout,
}) => request.timeout(timeout);
