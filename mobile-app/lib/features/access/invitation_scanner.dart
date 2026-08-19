part of 'access_flow.dart';

class _InvitationScannerPage extends StatefulWidget {
  const _InvitationScannerPage();
  @override
  State<_InvitationScannerPage> createState() => _InvitationScannerPageState();
}

class _InvitationScannerPageState extends State<_InvitationScannerPage> {
  var _handled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('scanInvitationQr'))),
    body: MobileScanner(
      onDetect: (capture) {
        if (_handled) return;
        final code = capture.barcodes.firstOrNull?.rawValue;
        if (code == null || code.isEmpty) return;
        _handled = true;
        Navigator.pop(context, code);
      },
    ),
  );
}
