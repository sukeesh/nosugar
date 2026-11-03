import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../sky.dart';
import '../sugar_names.dart';
import '../theme.dart';

/// Photograph an ingredient list; on-device OCR finds sugar under other names.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Stage { idle, reading, result }

/// On-device OCR: Apple Vision on iOS, ML Kit on Android (see the native entry points).
const _ocr = MethodChannel('nosugar/ocr');

class _ScanScreenState extends State<ScanScreen> {
  _Stage _stage = _Stage.idle;
  String _text = '';
  List<SugarHit> _hits = [];
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 90);
    } catch (e) {
      setState(() => _error = 'Couldn\'t open the ${source == ImageSource.camera ? 'camera' : 'photo library'}. Check permissions in Settings.');
      return;
    }
    if (file == null) return;
    setState(() => _stage = _Stage.reading);
    try {
      final text = await _ocr.invokeMethod<String>('recognize', file.path);
      _show(text ?? '');
    } catch (e) {
      setState(() {
        _stage = _Stage.idle;
        _error = 'Couldn\'t read that photo. Try again with the label flat and well lit.';
      });
    }
  }

  void _show(String text) {
    setState(() {
      _text = text.trim();
      _hits = findSugars(text);
      _stage = _Stage.result;
    });
  }

  Future<void> _type() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paste or type the ingredients', style: T.display(22)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              style: T.body(16, color: C.text),
              decoration: InputDecoration(
                labelText: 'Ingredients',
                hintText: 'Rolled oats, brown rice syrup, almonds…',
                filled: true,
                fillColor: C.night,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            Pill(label: 'Check', onPressed: () => Navigator.of(context).pop(controller.text)),
          ],
        ),
      ),
    );
    if (text != null && text.trim().isNotEmpty) _show(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: C.soft),
        title: Text('Check a label', style: T.body(16, color: C.text, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: switch (_stage) {
            _Stage.idle => _idle(),
            _Stage.reading => const Center(child: CircularProgressIndicator(color: C.gold)),
            _Stage.result => _result(),
          },
        ),
      ),
    );
  }

  Widget _idle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const CrystalIcon(size: 64),
        const SizedBox(height: 24),
        Text('Find the crystals\nhiding in food.', style: T.display(38, height: 1.05)),
        const SizedBox(height: 12),
        Text('Photograph the ingredients list. We\'ll spot sugar under its other names: dextrose, rice syrup, jaggery and dozens more.', style: T.body(16)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: T.body(14, color: const Color(0xFFFFB199)))),
        const Spacer(),
        Pill(label: 'Take a photo', icon: const Icon(Icons.photo_camera_outlined, size: 20, color: C.ink), onPressed: () => _pick(ImageSource.camera)),
        const SizedBox(height: 10),
        Pill(label: 'Choose from photos', outlined: true, onPressed: () => _pick(ImageSource.gallery)),
        const SizedBox(height: 4),
        Center(child: TextButton(onPressed: _type, child: Text('Type it instead', style: T.body(15)))),
      ],
    );
  }

  Widget _result() {
    final sugars = _hits.where((h) => !h.watch).toList();
    final watch = _hits.where((h) => h.watch).toList();
    final clean = sugars.isEmpty;
    final empty = _text.length < 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  if (clean && !empty)
                    const Icon(Icons.star_rounded, color: C.gold, size: 40)
                  else
                    const CrystalIcon(size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empty
                              ? 'Couldn\'t read much'
                              : clean
                                  ? 'No added sugar found'
                                  : sugars.length == 1
                                      ? '1 crystal hiding here'
                                      : '${sugars.length} crystals hiding here',
                          style: T.display(26),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          empty ? 'Try again closer, with the label flat.' : clean ? 'Double-check anything the camera missed.' : 'Added sugar under other names',
                          style: T.body(14, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final h in sugars) _row(h),
              if (watch.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Not sugar, but close', style: T.body(14, color: C.muted)),
                const SizedBox(height: 8),
                for (final h in watch) _row(h),
              ],
              if (!empty) ...[
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('What we read', style: T.body(14, color: C.muted)),
                    iconColor: C.muted,
                    collapsedIconColor: C.muted,
                    children: [Text(_text, style: T.body(13, color: C.muted))],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Pill(label: 'Scan another', onPressed: () => setState(() => _stage = _Stage.idle)),
      ],
    );
  }

  Widget _row(SugarHit h) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(child: Text(h.name, style: T.body(16, color: C.text, weight: FontWeight.w600))),
            Text(h.kind, style: T.body(13, color: C.muted)),
          ],
        ),
      );
}
