import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../crystal.dart';
import '../state.dart';
import '../theme.dart';

/// "My 2026 in sugar": a card rendered to an image and handed to the share sheet
/// (which also offers Save Image).
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/nosugar-${widget.state.today.year}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final year = s.today.year;
    final eaten = s.gramsEaten(year: year);
    final skipped = s.gramsSkipped(year: year);
    return Scaffold(
      backgroundColor: const Color(0xFF070A16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        title: Text('Share your year', style: T.body(16, color: C.text, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _key,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1430),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFF2C3458)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MY $year IN SUGAR', style: T.body(12, color: C.muted, weight: FontWeight.w600).copyWith(letterSpacing: 1.4)),
                          Cluster(grams: eaten, height: 190),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(formatGrams(eaten), style: T.display(30)),
                                  Text(eaten == 0 ? 'eaten' : 'eaten · ${packets(eaten)}', style: T.body(13, color: C.muted)),
                                ]),
                              ),
                              if (skipped != null)
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(formatGrams(skipped), style: T.display(30, color: C.gold)),
                                  Text('skipped', style: T.body(13, color: C.muted)),
                                ]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(height: 1, color: C.line),
                          const SizedBox(height: 12),
                          Text('${s.cleanNights(year: year)} sugar-free nights · ${s.cravingsBeaten} cravings outlasted', style: T.body(14)),
                          const SizedBox(height: 28),
                          Text.rich(TextSpan(children: [
                            TextSpan(text: 'nosugar', style: T.display(18)),
                            TextSpan(text: '.', style: T.display(18, color: C.gold)),
                          ])),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Pill(label: _busy ? 'Preparing…' : 'Share', onPressed: _busy ? null : _share),
            ],
          ),
        ),
      ),
    );
  }
}
