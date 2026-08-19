import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/assets/asset_domain.dart';
import 'package:relay_av_demo/features/assets/asset_screens.dart';

void main() {
  final asset = AssetRecord(
    id: 'asset-1',
    mode: AssetMode.serialized,
    name: 'Camera Kit',
    locationId: 'warehouse-1',
    locationName: 'Main Warehouse',
    workingState: AssetWorkingState.atWarehouse,
    stateRank: 0,
    createdAt: DateTime(2026, 8, 1),
  );

  const companyId = 'company-1';
  final coverBytes = Uint8List.fromList([1, 2, 3]);

  AssetSaveResult saved(AssetSaveAction action) =>
      AssetSaveResult(assetId: asset.id, action: action);

  test('asset save failure does not run a cover operation', () async {
    var saveCalls = 0;
    var uploadCalls = 0;
    var removeCalls = 0;
    var loadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        throw StateError('save failed');
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async => uploadCalls++,
      removeCover: () async => removeCalls++,
      loadAsset: (_) async {
        loadCalls++;
        return asset;
      },
    );

    expect(result.assetSaved, isFalse);
    expect(result.assetId, isNull);
    expect(result.coverOperation, AssetCoverOperation.upload);
    expect(result.coverOperationSucceeded, isNull);
    expect(result.refreshSucceeded, isNull);
    expect(result.failureStage, AssetSaveFailureStage.saveAsset);
    expect(result.failure?.errorType, 'StateError');
    expect(result.failure?.stackTrace, isNotNull);
    expect(result.coverRetryRequest, isNull);
    expect(saveCalls, 1);
    expect(uploadCalls, 0);
    expect(removeCalls, 0);
    expect(loadCalls, 0);
  });

  test('created asset keeps its id when cover upload fails', () async {
    var saveCalls = 0;
    var uploadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.created);
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async {
        uploadCalls++;
        throw StateError('upload failed');
      },
      removeCover: () async {},
      loadAsset: (assetId) async {
        expect(assetId, asset.id);
        return asset;
      },
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.asset, same(asset));
    expect(result.saveAction, AssetSaveAction.created);
    expect(result.coverOperation, AssetCoverOperation.upload);
    expect(result.coverOperationSucceeded, isFalse);
    expect(result.failureStage, AssetSaveFailureStage.uploadCover);
    expect(result.failure?.errorType, 'StateError');
    expect(result.coverRetryRequest, isNotNull);
    expect(result.coverRetryRequest!.assetId, asset.id);
    expect(result.coverRetryRequest!.companyId, companyId);
    expect(saveCalls, 1);
    expect(uploadCalls, 1);
  });

  test('updated asset keeps its id when cover upload fails', () async {
    var saveCalls = 0;
    var uploadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.updated);
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async {
        uploadCalls++;
        throw StateError('upload failed');
      },
      removeCover: () async {},
      loadAsset: (_) async => asset,
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.saveAction, AssetSaveAction.updated);
    expect(result.failureStage, AssetSaveFailureStage.uploadCover);
    expect(saveCalls, 1);
    expect(uploadCalls, 1);
  });

  test('remove cover failure keeps the saved asset data', () async {
    var saveCalls = 0;
    var removeCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.updated);
      },
      coverOperation: AssetCoverOperation.remove,
      coverBytes: null,
      uploadCover: () async {},
      removeCover: () async {
        removeCalls++;
        throw StateError('remove failed');
      },
      loadAsset: (_) async => asset,
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.asset, same(asset));
    expect(result.coverOperation, AssetCoverOperation.remove);
    expect(result.coverOperationSucceeded, isFalse);
    expect(result.failureStage, AssetSaveFailureStage.removeCover);
    expect(result.coverRetryRequest, isNotNull);
    expect(result.coverRetryRequest!.operation, AssetCoverOperation.remove);
    expect(saveCalls, 1);
    expect(removeCalls, 1);
  });

  test('cover failure and refresh failure preserve both results', () async {
    var saveCalls = 0;
    var uploadCalls = 0;
    var loadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.created);
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async {
        uploadCalls++;
        throw StateError('upload failed');
      },
      removeCover: () async {},
      loadAsset: (_) async {
        loadCalls++;
        throw StateError('refresh failed');
      },
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.failureStage, AssetSaveFailureStage.uploadCover);
    expect(result.failure?.errorType, 'StateError');
    expect(result.refreshFailure?.stage, AssetSaveFailureStage.refreshAsset);
    expect(result.refreshFailure?.errorType, 'StateError');
    expect(result.hasCoverFailure, isTrue);
    expect(result.hasRefreshFailure, isTrue);
    expect(result.coverRetryRequest, isNotNull);
    expect(saveCalls, 1);
    expect(uploadCalls, 1);
    expect(loadCalls, 1);
  });

  test('cover success and refresh failure do not offer cover retry', () async {
    var saveCalls = 0;
    var uploadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.updated);
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async => uploadCalls++,
      removeCover: () async {},
      loadAsset: (_) async => throw StateError('refresh failed'),
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.coverOperationSucceeded, isTrue);
    expect(result.failure, isNull);
    expect(result.failureStage, AssetSaveFailureStage.refreshAsset);
    expect(result.refreshFailure, isNotNull);
    expect(result.hasCoverFailure, isFalse);
    expect(result.hasRefreshFailure, isTrue);
    expect(result.coverRetryRequest, isNull);
    expect(saveCalls, 1);
    expect(uploadCalls, 1);
  });

  test(
    'upload retry succeeds but refresh failure disables cover retry',
    () async {
      var saveCalls = 0;
      var uploadCalls = 0;
      var loadCalls = 0;
      var failFirstUpload = true;

      final partial = await runAssetSaveWorkflow(
        companyId: companyId,
        saveAsset: () async {
          saveCalls++;
          return saved(AssetSaveAction.created);
        },
        coverOperation: AssetCoverOperation.upload,
        coverBytes: coverBytes,
        uploadCover: () async {
          uploadCalls++;
          if (failFirstUpload) {
            failFirstUpload = false;
            throw StateError('upload failed');
          }
        },
        removeCover: () async {},
        loadAsset: (_) async {
          loadCalls++;
          return asset;
        },
      );
      final controller = AssetCoverRetryController(
        current: partial,
        uploadCover: (_) async => uploadCalls++,
        removeCover: (_) async {},
        loadAsset: (_) async {
          loadCalls++;
          throw StateError('refresh failed');
        },
      );

      final retried = await controller.retry();
      await controller.retry();

      expect(retried.coverOperationSucceeded, isTrue);
      expect(retried.failure, isNull);
      expect(retried.refreshFailure?.stage, AssetSaveFailureStage.refreshAsset);
      expect(retried.coverRetryRequest, isNull);
      expect(retried.hasCoverFailure, isFalse);
      expect(saveCalls, 1);
      expect(uploadCalls, 2);
      expect(loadCalls, 2);
    },
  );

  test(
    'retry failure keeps the data-only retry request and diagnostics',
    () async {
      var saveCalls = 0;
      var uploadCalls = 0;

      final partial = await runAssetSaveWorkflow(
        companyId: companyId,
        saveAsset: () async {
          saveCalls++;
          return saved(AssetSaveAction.updated);
        },
        coverOperation: AssetCoverOperation.upload,
        coverBytes: coverBytes,
        uploadCover: () async => throw StateError('initial upload failed'),
        removeCover: () async {},
        loadAsset: (_) async => asset,
      );
      final controller = AssetCoverRetryController(
        current: partial,
        uploadCover: (_) async {
          uploadCalls++;
          throw StateError('retry upload failed');
        },
        removeCover: (_) async {},
        loadAsset: (_) async => asset,
      );

      final retried = await controller.retry();
      final retriedAgain = await controller.retry();

      expect(retried.assetSaved, isTrue);
      expect(retried.assetId, asset.id);
      expect(retried.failureStage, AssetSaveFailureStage.uploadCover);
      expect(retried.failure?.errorType, 'StateError');
      expect(retried.failure?.stackTrace, isNotNull);
      expect(retried.coverRetryRequest, isNotNull);
      expect(retriedAgain.coverRetryRequest, isNotNull);
      expect(
        retried.failure.toString(),
        isNot(contains('retry upload failed')),
      );
      expect(saveCalls, 1);
      expect(uploadCalls, 2);
    },
  );

  test(
    'upload retry only operates on the existing asset and refreshes it',
    () async {
      var saveCalls = 0;
      var uploadCalls = 0;
      var loadedIds = <String>[];
      var failFirstUpload = true;

      final partial = await runAssetSaveWorkflow(
        companyId: companyId,
        saveAsset: () async {
          saveCalls++;
          return saved(AssetSaveAction.created);
        },
        coverOperation: AssetCoverOperation.upload,
        coverBytes: coverBytes,
        uploadCover: () async {
          uploadCalls++;
          if (failFirstUpload) {
            failFirstUpload = false;
            throw StateError('upload failed');
          }
        },
        removeCover: () async {},
        loadAsset: (assetId) async {
          loadedIds.add(assetId);
          return asset;
        },
      );
      final controller = AssetCoverRetryController(
        current: partial,
        uploadCover: (_) async => uploadCalls++,
        removeCover: (_) async {},
        loadAsset: (assetId) async {
          loadedIds.add(assetId);
          return asset;
        },
      );

      final retried = await controller.retry();

      expect(retried.assetSaved, isTrue);
      expect(retried.assetId, asset.id);
      expect(retried.coverOperationSucceeded, isTrue);
      expect(retried.failureStage, isNull);
      expect(saveCalls, 1);
      expect(uploadCalls, 2);
      expect(loadedIds, [asset.id, asset.id]);
    },
  );

  test('remove retry only operates on the existing asset', () async {
    var saveCalls = 0;
    var removeCalls = 0;

    final partial = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.updated);
      },
      coverOperation: AssetCoverOperation.remove,
      coverBytes: null,
      uploadCover: () async {},
      removeCover: () async {
        removeCalls++;
        throw StateError('remove failed');
      },
      loadAsset: (_) async => asset,
    );
    final controller = AssetCoverRetryController(
      current: partial,
      uploadCover: (_) async {},
      removeCover: (_) async => removeCalls++,
      loadAsset: (_) async => asset,
    );

    final retried = await controller.retry();

    expect(retried.assetId, asset.id);
    expect(retried.coverOperation, AssetCoverOperation.remove);
    expect(retried.coverOperationSucceeded, isTrue);
    expect(saveCalls, 1);
    expect(removeCalls, 2);
  });

  test(
    'retry controller coalesces repeated taps into one cover request',
    () async {
      var saveCalls = 0;
      var uploadCalls = 0;
      final releaseUpload = Completer<void>();

      final partial = await runAssetSaveWorkflow(
        companyId: companyId,
        saveAsset: () async {
          saveCalls++;
          return saved(AssetSaveAction.created);
        },
        coverOperation: AssetCoverOperation.upload,
        coverBytes: coverBytes,
        uploadCover: () async => throw StateError('upload failed'),
        removeCover: () async {},
        loadAsset: (_) async => asset,
      );
      final controller = AssetCoverRetryController(
        current: partial,
        uploadCover: (_) async {
          uploadCalls++;
          await releaseUpload.future;
        },
        removeCover: (_) async {},
        loadAsset: (_) async => asset,
      );

      final first = controller.retry();
      final second = controller.retry();
      releaseUpload.complete();
      await Future.wait([first, second]);

      expect(saveCalls, 1);
      expect(uploadCalls, 1);
    },
  );

  test('workflow result contains only data needed for a retry', () async {
    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async => saved(AssetSaveAction.created),
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async => throw StateError('upload failed'),
      removeCover: () async {},
      loadAsset: (_) async => asset,
    );

    final retry = result.coverRetryRequest!;
    expect(retry, isA<AssetCoverRetryRequest>());
    expect(retry.companyId, companyId);
    expect(retry.assetId, asset.id);
    expect(retry.operation, AssetCoverOperation.upload);
    expect(retry.bytes, coverBytes);
  });

  test('successful save and cover update preserves the success path', () async {
    var saveCalls = 0;
    var uploadCalls = 0;

    final result = await runAssetSaveWorkflow(
      companyId: companyId,
      saveAsset: () async {
        saveCalls++;
        return saved(AssetSaveAction.updated);
      },
      coverOperation: AssetCoverOperation.upload,
      coverBytes: coverBytes,
      uploadCover: () async => uploadCalls++,
      removeCover: () async {},
      loadAsset: (_) async => asset,
    );

    expect(result.assetSaved, isTrue);
    expect(result.assetId, asset.id);
    expect(result.asset, same(asset));
    expect(result.coverOperationSucceeded, isTrue);
    expect(result.failureStage, isNull);
    expect(result.failure, isNull);
    expect(result.refreshFailure, isNull);
    expect(result.coverRetryRequest, isNull);
    expect(saveCalls, 1);
    expect(uploadCalls, 1);
  });
}
