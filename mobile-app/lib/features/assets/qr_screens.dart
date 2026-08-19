import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../l10n/relay_localizations.dart';
import '../../shared/ledger_widgets.dart';
import 'asset_domain.dart';
import 'asset_repository.dart';

class AssetQrScanPage extends ConsumerStatefulWidget {
  const AssetQrScanPage({required this.companyId, super.key});
  final String companyId;

  @override
  ConsumerState<AssetQrScanPage> createState() => _AssetQrScanPageState();
}

class _AssetQrScanPageState extends ConsumerState<AssetQrScanPage> {
  final _camera = MobileScannerController();
  var _handling = false;
  String? _message;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _resolve(String raw) async {
    if (_handling) return;
    final token = raw.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{16}$').hasMatch(token)) {
      setState(() => _message = context.l10n.text('invalidQr'));
      return;
    }
    setState(() {
      _handling = true;
      _message = context.l10n.text('resolvingQr');
    });
    try {
      final asset = await ref
          .read(assetCatalogRepositoryProvider)
          .resolveAssetQr(companyId: widget.companyId, rawToken: token);
      if (!mounted) return;
      if (asset == null) {
        setState(() {
          _handling = false;
          _message = context.l10n.text('qrNotFoundOrNoAccess');
        });
        return;
      }
      await _camera.stop();
      if (mounted) Navigator.pop(context, asset);
    } catch (_) {
      if (mounted) {
        setState(() {
          _handling = false;
          _message = context.l10n.text('qrNetworkFailure');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LedgerPage(
    title: context.l10n.text('scanAssetQr'),
    child: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _camera,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null) {
                _resolve(raw);
                return;
              }
            }
          },
          errorBuilder: (context, error) => _CameraFailure(
            permissionDenied:
                error.errorCode == MobileScannerErrorCode.permissionDenied,
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: context.relay.focusRing, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: context.relay.structuralLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _message ?? context.l10n.text('scanAssetQrBody'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class AssetQrLabelPage extends StatefulWidget {
  const AssetQrLabelPage({required this.asset, super.key});
  final AssetRecord asset;

  @override
  State<AssetQrLabelPage> createState() => _AssetQrLabelPageState();
}

class _AssetQrLabelPageState extends State<AssetQrLabelPage> {
  var _labelSize = _QrLabelSize.compact;
  var _copies = 1;
  var _busy = false;
  String? _error;

  AssetRecord get _asset => widget.asset;

  Future<Uint8List> _pdf() async {
    final document = pw.Document();
    for (var copy = 0; copy < _copies; copy++) {
      document.addPage(
        pw.Page(
          pageFormat: _labelSize.format,
          build: (_) => pw.Center(
            child: pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: _asset.qrToken!,
                    color: PdfColors.black,
                    backgroundColor: PdfColors.white,
                    padding: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
                    width: 48 * PdfPageFormat.mm,
                    height: 48 * PdfPageFormat.mm,
                  ),
                  pw.SizedBox(height: 4 * PdfPageFormat.mm),
                  pw.Text(
                    _asset.name,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
                  pw.Text(
                    _asset.serialNumber ?? '',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return document.save();
  }

  Future<void> _print() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Printing.layoutPdf(
        onLayout: (_) => _pdf(),
        format: _labelSize.format,
        name: 'relay-${_asset.serialNumber ?? _asset.id}-label.pdf',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('printQrFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Printing.sharePdf(
        bytes: await _pdf(),
        filename: 'relay-${_asset.serialNumber ?? _asset.id}-label.pdf',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.text('shareQrFailed'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: LedgerPage(
      title: context.l10n.text('printQrLabel'),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            RelayNotice(message: _error!, kind: RelayNoticeKind.danger),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: context.relay.structuralLine),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _asset.qrToken!,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  size: 220,
                ),
                const SizedBox(height: 12),
                Text(
                  _asset.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _asset.serialNumber ?? '',
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'RelayMono',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<_QrLabelSize>(
            initialValue: _labelSize,
            decoration: InputDecoration(
              labelText: context.l10n.text('labelSize'),
            ),
            items: [
              for (final size in _QrLabelSize.values)
                DropdownMenuItem(value: size, child: Text(size.label)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _labelSize = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _copies,
            decoration: InputDecoration(
              labelText: context.l10n.text('copyCount'),
            ),
            items: [
              for (var count = 1; count <= 10; count++)
                DropdownMenuItem(value: count, child: Text('$count')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _copies = value!),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _print,
            icon: const Icon(Icons.print_outlined),
            label: Text(context.l10n.text('printLabel')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share_outlined),
            label: Text(context.l10n.text('sharePdf')),
          ),
        ],
      ),
    ),
  );
}

enum _QrLabelSize {
  compact(
    '62 × 100 mm',
    PdfPageFormat(62 * PdfPageFormat.mm, 100 * PdfPageFormat.mm),
  ),
  a4('A4', PdfPageFormat.a4);

  const _QrLabelSize(this.label, this.format);
  final String label;
  final PdfPageFormat format;
}

class _CameraFailure extends StatelessWidget {
  const _CameraFailure({required this.permissionDenied});
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RelayNotice(
          kind: RelayNoticeKind.danger,
          message: permissionDenied
              ? context.l10n.text('cameraPermissionDenied')
              : context.l10n.text('cameraUnavailable'),
        ),
      ),
    ),
  );
}
