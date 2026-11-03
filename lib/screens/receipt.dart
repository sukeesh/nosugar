import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state.dart';
import '../sugar.dart';
import '../theme.dart';

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

const _paper = Color(0xFFF4F1EA);
const _ink = Color(0xFF1A1A1A);

/// A month of sugar as a till receipt, rendered to an image and shared.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.state, required this.year, required this.month});
  final AppState state;
  final int year;
  final int month;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/nosugar-receipt-${widget.year}-${widget.month}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        title: Text(
          'Share your receipt',
          style: T.body(16, color: C.text, weight: FontWeight.w600),
        ),
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
                  child: SingleChildScrollView(
                    child: Transform.rotate(
                      angle: -0.025,
                      child: RepaintBoundary(
                        key: _key,
                        // Padding keeps the paper's shadow inside the shared image.
                        child: Container(
                          color: const Color(0xFF070A16),
                          padding: const EdgeInsets.all(18),
                          child: Receipt(state: widget.state, year: widget.year, month: widget.month),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Pill(
                label: _busy ? 'Preparing…' : 'Share',
                icon: const Icon(Icons.ios_share_rounded, size: 18, color: C.ink),
                onPressed: _busy ? null : _share,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.state, required this.year, required this.month});
  final AppState state;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final logs = s.logsIn(year: year, month: month)..sort((a, b) => a.day.compareTo(b.day));
    final eaten = s.gramsEaten(year: year, month: month);
    final skipped = s.gramsSkipped(year: year, month: month);
    final isNow = s.today.year == year && s.today.month == month;
    final days = isNow ? s.today.day : DateTime(year, month + 1, 0).day;
    final clean = s.cleanNights(year: year, month: month);
    final mono = GoogleFonts.jetBrainsMono(fontSize: 12, height: 1.7, color: _ink);
    final bold = mono.copyWith(fontWeight: FontWeight.w700);
    String up(String t) => t.toUpperCase();

    Widget row(String a, String b, {TextStyle? style}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(a, style: style ?? mono)),
        const SizedBox(width: 12),
        Text(b, style: style ?? mono),
      ],
    );
    Widget rule() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter()),
    );

    return SizedBox(
      width: 300,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 16))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: _paper,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Column(
                children: [
                  Text('nosugar.', style: T.display(24, color: _ink)),
                  Text('SUGAR RECEIPT · ${up(monthNames[month - 1])} $year', style: mono, textAlign: TextAlign.center),
                  Text('HONEST LOGS: ${logs.length}', style: mono.copyWith(color: const Color(0xFF6B6B6B))),
                  rule(),
                  if (logs.isEmpty)
                    Text('NOTHING. NOT A SINGLE GRAIN.', style: bold)
                  else
                    for (final l in logs.take(12))
                      row(
                        '${l.day.day.toString().padLeft(2, '0')} ${up(monthNames[l.day.month - 1].substring(0, 3))}  ${up(l.label ?? _itemName(s.sugarCategory(l)))}',
                        '${l.grams} G',
                      ),
                  if (logs.length > 12) row('+${logs.length - 12} MORE', ''),
                  rule(),
                  row('TOTAL EATEN', up(formatGrams(eaten)), style: bold.copyWith(fontSize: 14)),
                  if (skipped != null) ...[
                    row('AT YOUR OLD HABIT (EST.)', up(formatGrams(eaten + skipped))),
                    row('SUGAR SKIPPED', '−${up(formatGrams(skipped))}', style: bold),
                  ],
                  rule(),
                  row('CLEAN NIGHTS', '$clean / $days'),
                  const SizedBox(height: 14),
                  Text('THANK YOU FOR BEING HONEST', style: bold, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  CustomPaint(size: const Size(180, 38), painter: _BarcodePainter(year * 100 + month)),
                ],
              ),
            ),
            CustomPaint(size: const Size(300, 8), painter: _ZigzagPainter()),
          ],
        ),
      ),
    );
  }
}

String _itemName(String category) => category == 'Other' ? 'Sugar' : category;

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _ink;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + 3, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => false;
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final p = Paint()..color = _ink;
    var x = 0.0;
    while (x < size.width) {
      final w = [1.0, 1.0, 2.0, 3.0][r.nextInt(4)];
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + [1.0, 2.0, 2.0, 3.0][r.nextInt(4)];
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter o) => o.seed != seed;
}

/// The torn edge at the bottom of the paper.
class _ZigzagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0);
    const step = 10.0;
    for (var i = 0; i * step <= size.width; i++) {
      path.lineTo(i * step, i.isEven ? 0 : size.height);
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = _paper);
  }

  @override
  bool shouldRepaint(_ZigzagPainter o) => false;
}
