import 'package:flutter/foundation.dart';

import '../../shared/relay_failure.dart';
import 'asset_domain.dart';
import 'asset_repository.dart';

enum AssetCoverOperation { none, upload, remove }

enum AssetSaveFailureStage { saveAsset, uploadCover, removeCover, refreshAsset }

class AssetWorkflowFailure {
  const AssetWorkflowFailure({
    required this.stage,
    required this.errorType,
    required this.stackTrace,
    this.safeCode,
  });

  final AssetSaveFailureStage stage;
  final String errorType;
  final String? safeCode;
  final StackTrace stackTrace;
}

class AssetCoverRetryRequest {
  const AssetCoverRetryRequest({
    required this.companyId,
    required this.assetId,
    required this.operation,
    this.bytes,
  });

  final String companyId;
  final String assetId;
  final AssetCoverOperation operation;
  final Uint8List? bytes;
}

class AssetSaveWorkflowResult {
  const AssetSaveWorkflowResult({
    required this.assetSaved,
    required this.assetId,
    required this.asset,
    required this.saveAction,
    required this.coverOperation,
    required this.coverOperationSucceeded,
    required this.refreshSucceeded,
    this.failure,
    this.refreshFailure,
    this.coverRetryRequest,
    this.mergedKeepingExistingCover = false,
  });

  final bool assetSaved;
  final String? assetId;
  final AssetRecord? asset;
  final AssetSaveAction? saveAction;
  final AssetCoverOperation coverOperation;
  final bool? coverOperationSucceeded;
  final bool? refreshSucceeded;
  final AssetWorkflowFailure? failure;
  final AssetWorkflowFailure? refreshFailure;
  final AssetCoverRetryRequest? coverRetryRequest;
  final bool mergedKeepingExistingCover;

  AssetSaveFailureStage? get failureStage =>
      failure?.stage ?? refreshFailure?.stage;

  bool get hasCoverFailure =>
      failure?.stage == AssetSaveFailureStage.uploadCover ||
      failure?.stage == AssetSaveFailureStage.removeCover;

  bool get hasRefreshFailure => refreshFailure != null;
}

Future<AssetSaveWorkflowResult> runAssetSaveWorkflow({
  required String companyId,
  required Future<AssetSaveResult> Function() saveAsset,
  required AssetCoverOperation coverOperation,
  required Uint8List? coverBytes,
  required Future<void> Function() uploadCover,
  required Future<void> Function() removeCover,
  required Future<AssetRecord?> Function(String assetId) loadAsset,
}) async {
  AssetSaveResult saved;
  try {
    saved = await saveAsset();
  } catch (error, stackTrace) {
    _logAssetWorkflowFailure(
      stage: AssetSaveFailureStage.saveAsset,
      assetId: null,
      saveAction: null,
      error: error,
      stackTrace: stackTrace,
    );
    return AssetSaveWorkflowResult(
      assetSaved: false,
      assetId: null,
      asset: null,
      saveAction: null,
      coverOperation: coverOperation,
      coverOperationSucceeded: null,
      refreshSucceeded: null,
      failure: _failure(
        stage: AssetSaveFailureStage.saveAsset,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  return runAssetCoverWorkflow(
    companyId: companyId,
    saved: saved,
    coverOperation: coverOperation,
    coverBytes: coverBytes,
    uploadCover: uploadCover,
    removeCover: removeCover,
    loadAsset: loadAsset,
  );
}

Future<AssetSaveWorkflowResult> runAssetCoverWorkflow({
  required String companyId,
  required AssetSaveResult saved,
  required AssetCoverOperation coverOperation,
  required Uint8List? coverBytes,
  required Future<void> Function() uploadCover,
  required Future<void> Function() removeCover,
  required Future<AssetRecord?> Function(String assetId) loadAsset,
}) async {
  AssetWorkflowFailure? coverFailure;

  if (!saved.isMerged) {
    try {
      switch (coverOperation) {
        case AssetCoverOperation.none:
          break;
        case AssetCoverOperation.upload:
          await uploadCover();
        case AssetCoverOperation.remove:
          await removeCover();
      }
    } catch (error, stackTrace) {
      final stage = switch (coverOperation) {
        AssetCoverOperation.none => AssetSaveFailureStage.saveAsset,
        AssetCoverOperation.upload => AssetSaveFailureStage.uploadCover,
        AssetCoverOperation.remove => AssetSaveFailureStage.removeCover,
      };
      coverFailure = _failure(
        stage: stage,
        error: error,
        stackTrace: stackTrace,
      );
      _logAssetWorkflowFailure(
        stage: stage,
        assetId: saved.assetId,
        saveAction: saved.action,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AssetRecord? asset;
  AssetWorkflowFailure? refreshFailure;
  try {
    asset = await loadAsset(saved.assetId);
    if (asset == null) throw StateError('Saved Asset is not readable');
  } catch (error, stackTrace) {
    refreshFailure = _failure(
      stage: AssetSaveFailureStage.refreshAsset,
      error: error,
      stackTrace: stackTrace,
    );
    _logAssetWorkflowFailure(
      stage: AssetSaveFailureStage.refreshAsset,
      assetId: saved.assetId,
      saveAction: saved.action,
      error: error,
      stackTrace: stackTrace,
    );
  }

  return AssetSaveWorkflowResult(
    assetSaved: true,
    assetId: saved.assetId,
    asset: asset,
    saveAction: saved.action,
    coverOperation: coverOperation,
    coverOperationSucceeded: coverFailure == null,
    refreshSucceeded: refreshFailure == null,
    failure: coverFailure,
    refreshFailure: refreshFailure,
    coverRetryRequest: coverFailure == null
        ? null
        : AssetCoverRetryRequest(
            companyId: companyId,
            assetId: saved.assetId,
            operation: coverOperation,
            bytes: coverBytes,
          ),
    mergedKeepingExistingCover:
        saved.isMerged && coverOperation != AssetCoverOperation.none,
  );
}

Future<AssetSaveWorkflowResult> retryAssetCoverWorkflow({
  required AssetSaveWorkflowResult current,
  required Future<void> Function(AssetCoverRetryRequest request) uploadCover,
  required Future<void> Function(AssetCoverRetryRequest request) removeCover,
  required Future<AssetRecord?> Function(String assetId) loadAsset,
}) async {
  final request = current.coverRetryRequest;
  if (!current.assetSaved || !current.hasCoverFailure || request == null) {
    return current;
  }

  try {
    switch (request.operation) {
      case AssetCoverOperation.none:
        return current;
      case AssetCoverOperation.upload:
        await uploadCover(request);
      case AssetCoverOperation.remove:
        await removeCover(request);
    }
  } catch (error, stackTrace) {
    final stage = switch (request.operation) {
      AssetCoverOperation.none => AssetSaveFailureStage.saveAsset,
      AssetCoverOperation.upload => AssetSaveFailureStage.uploadCover,
      AssetCoverOperation.remove => AssetSaveFailureStage.removeCover,
    };
    _logAssetWorkflowFailure(
      stage: stage,
      assetId: request.assetId,
      saveAction: current.saveAction,
      error: error,
      stackTrace: stackTrace,
    );
    return AssetSaveWorkflowResult(
      assetSaved: true,
      assetId: current.assetId,
      asset: current.asset,
      saveAction: current.saveAction,
      coverOperation: current.coverOperation,
      coverOperationSucceeded: false,
      refreshSucceeded: current.refreshSucceeded,
      failure: _failure(stage: stage, error: error, stackTrace: stackTrace),
      refreshFailure: current.refreshFailure,
      coverRetryRequest: request,
      mergedKeepingExistingCover: current.mergedKeepingExistingCover,
    );
  }

  AssetRecord? asset;
  AssetWorkflowFailure? refreshFailure;
  try {
    asset = await loadAsset(request.assetId);
    if (asset == null) throw StateError('Retried Asset is not readable');
  } catch (error, stackTrace) {
    refreshFailure = _failure(
      stage: AssetSaveFailureStage.refreshAsset,
      error: error,
      stackTrace: stackTrace,
    );
    _logAssetWorkflowFailure(
      stage: AssetSaveFailureStage.refreshAsset,
      assetId: request.assetId,
      saveAction: current.saveAction,
      error: error,
      stackTrace: stackTrace,
    );
  }

  return AssetSaveWorkflowResult(
    assetSaved: true,
    assetId: current.assetId,
    asset: asset ?? current.asset,
    saveAction: current.saveAction,
    coverOperation: current.coverOperation,
    coverOperationSucceeded: true,
    refreshSucceeded: refreshFailure == null,
    refreshFailure: refreshFailure,
    mergedKeepingExistingCover: current.mergedKeepingExistingCover,
  );
}

class AssetCoverRetryController {
  AssetCoverRetryController({
    required this._current,
    required this._uploadCover,
    required this._removeCover,
    required this._loadAsset,
  });

  AssetSaveWorkflowResult _current;
  final Future<void> Function(AssetCoverRetryRequest request) _uploadCover;
  final Future<void> Function(AssetCoverRetryRequest request) _removeCover;
  final Future<AssetRecord?> Function(String assetId) _loadAsset;
  Future<AssetSaveWorkflowResult>? _inFlight;

  Future<AssetSaveWorkflowResult> retry() {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!_current.hasCoverFailure || _current.coverRetryRequest == null) {
      return Future.value(_current);
    }
    final future = _run();
    _inFlight = future;
    return future;
  }

  Future<AssetSaveWorkflowResult> _run() async {
    try {
      final result = await retryAssetCoverWorkflow(
        current: _current,
        uploadCover: _uploadCover,
        removeCover: _removeCover,
        loadAsset: _loadAsset,
      );
      _current = result;
      return result;
    } finally {
      _inFlight = null;
    }
  }
}

AssetCoverRetryController? createAssetCoverRetryController({
  required AssetSaveWorkflowResult result,
  required AssetCatalogRepository repository,
}) {
  final request = result.coverRetryRequest;
  if (!result.hasCoverFailure || request == null) return null;
  return AssetCoverRetryController(
    current: result,
    uploadCover: (request) async {
      final bytes = request.bytes;
      if (bytes == null) throw StateError('Cover retry payload is missing');
      await repository.uploadCover(
        companyId: request.companyId,
        assetId: request.assetId,
        bytes: bytes,
      );
    },
    removeCover: (request) => repository.removeCover(
      companyId: request.companyId,
      assetId: request.assetId,
    ),
    loadAsset: (assetId) => repository.asset(request.companyId, assetId),
  );
}

AssetWorkflowFailure _failure({
  required AssetSaveFailureStage stage,
  required Object error,
  required StackTrace stackTrace,
}) {
  final classified = RelayFailure.from(error);
  return AssetWorkflowFailure(
    stage: stage,
    errorType: error.runtimeType.toString(),
    safeCode: classified.code,
    stackTrace: stackTrace,
  );
}

void _logAssetWorkflowFailure({
  required AssetSaveFailureStage stage,
  required String? assetId,
  required AssetSaveAction? saveAction,
  required Object error,
  required StackTrace stackTrace,
}) {
  final classified = RelayFailure.from(error);
  debugPrint(
    'Asset workflow failed at ${stage.name}; '
    'assetId=${assetId ?? 'none'}; '
    'saveAction=${saveAction?.name ?? 'unknown'}; '
    'errorType=${error.runtimeType}; '
    'errorCode=${classified.code ?? 'none'}',
  );
  debugPrintStack(stackTrace: stackTrace);
}
