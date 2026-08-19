import 'asset_import_decoder.dart';
import 'asset_import_models.dart';
import 'asset_import_preview.dart';
import 'asset_import_repository.dart';
import 'asset_import_template_service.dart';
import '../../../data/local_backend_compat.dart';

class AssetImportService {
  AssetImportService({
    AssetImportDecoder? decoder,
    AssetImportTemplateService? templates,
    this._batchRepository,
  }) : _decoder = decoder ?? AssetImportDecoder(),
       _templates = templates ?? AssetImportTemplateService();

  final AssetImportDecoder _decoder;
  final AssetImportTemplateService _templates;
  final AssetImportBatchRepository? _batchRepository;

  AssetImportTemplateFile generateTemplate({required String locale}) =>
      _templates.generate(locale: locale);

  AssetImportDecodedFile decode(AssetImportRequest request) =>
      _decoder.decode(request);

  AssetImportPreviewResult preview(AssetImportPreviewRequest request) =>
      AssetImportPreviewer().preview(request);

  Future<List<AssetImportBatchRowResult>> commit(
    AssetImportBatchCommitRequest request,
  ) =>
      (_batchRepository ?? AssetImportBatchRepository(LocalBackendClient()))
          .commit(request);
}
