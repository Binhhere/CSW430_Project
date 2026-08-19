import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:relay_av_demo/shared/relay_failure.dart';
import 'package:relay_av_demo/data/local_backend_compat.dart';

void main() {
  test('request failures preserve actionable categories', () {
    expect(
      RelayFailure.from(TimeoutException('late')).kind,
      RelayFailureKind.timeout,
    );
    expect(
      RelayFailure.from(
        const PostgrestException(message: 'denied', code: '42501'),
      ).kind,
      RelayFailureKind.authorization,
    );
    expect(
      RelayFailure.from(
        const PostgrestException(message: 'duplicate', code: '23505'),
      ).kind,
      RelayFailureKind.conflict,
    );
    expect(
      RelayFailure.from(
        const PostgrestException(message: 'invalid', code: '22023'),
      ).kind,
      RelayFailureKind.validation,
    );
    expect(
      RelayFailure.from(
        const PostgrestException(message: 'blocked', code: '23514'),
      ).kind,
      RelayFailureKind.conflict,
    );
    expect(
      RelayFailure.from(
        const PostgrestException(message: 'missing', code: 'P0002'),
      ).kind,
      RelayFailureKind.validation,
    );
  });

  test('request failures use the active language', () {
    final failure = RelayFailure.from(TimeoutException('late'));

    expect(
      failure.message(
        l10n: RelayLocalizations(const Locale('es')),
        fallback: 'fallback',
      ),
      contains('agotó el tiempo'),
    );
  });
}
