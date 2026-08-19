import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../app/relay_ui.dart';
import '../l10n/relay_localizations.dart';

typedef RelayImageEdit =
    Future<Uint8List?> Function(BuildContext context, Uint8List bytes);

Future<Uint8List?> editRelayImage(BuildContext context, Uint8List bytes) =>
    Navigator.of(context).push<Uint8List>(
      RelayPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => RelayImageEditorPage(bytes: bytes),
      ),
    );

class RelayImageEditorPage extends StatefulWidget {
  const RelayImageEditorPage({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  State<RelayImageEditorPage> createState() => _RelayImageEditorPageState();
}

class _RelayImageEditorPageState extends State<RelayImageEditorPage> {
  final _controller = CropController();
  var _saving = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('photoEditFailed'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.text('editPhoto')),
      leading: IconButton(
        tooltip: context.l10n.text('cancel'),
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  setState(() => _saving = true);
                  _controller.crop();
                },
          child: Text(context.l10n.text('savePhoto')),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Crop(
                image: widget.bytes,
                controller: _controller,
                onCropped: _onCropped,
                interactive: true,
                fixCropRect: true,
                aspectRatio: 1,
                cornerDotBuilder: (_, index) => const SizedBox.shrink(),
                radius: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              context.l10n.text('moveAndZoomPhoto'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}
