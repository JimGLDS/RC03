import 'package:flutter/material.dart';

enum GloveKeypadMode { alpha, num }

Future<String?> showGloveKeypad({
  required BuildContext context,
  required GloveKeypadMode mode,
  String initialText = '',
  String title = 'Keypad',
}) {
  return Navigator.of(context).push<String?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GloveKeypadScreen(
        mode: mode,
        initialText: initialText,
        title: title,
      ),
    ),
  );
}

class GloveKeypadScreen extends StatefulWidget {
  final GloveKeypadMode mode;
  final String initialText;
  final String title;

  const GloveKeypadScreen({
    super.key,
    required this.mode,
    this.initialText = '',
    this.title = 'Keypad',
  });

  @override
  State<GloveKeypadScreen> createState() => _GloveKeypadScreenState();
}

class _GloveKeypadScreenState extends State<GloveKeypadScreen> {
  late GloveKeypadMode _mode;
  late String _buf;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _buf = widget.initialText;
  }

  void _append(String s) {
    setState(() {
      if (_mode == GloveKeypadMode.alpha) {
        _buf = (_buf + s).toUpperCase();
      } else {
        _buf = _buf + s;
      }
    });
  }

  void _backspace() {
    if (_buf.isEmpty) return;
    setState(() => _buf = _buf.substring(0, _buf.length - 1));
  }

  void _clear() {
    setState(() => _buf = '');
  }

  void _switchMode(GloveKeypadMode m) {
    setState(() => _mode = m);
  }

  void _cancel() => Navigator.pop(context, null);
  void _enter() => Navigator.pop(context, _buf);

  Widget _squareButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _displayBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _buf,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Backspace',
            onPressed: _backspace,
            icon: const Icon(Icons.backspace_outlined),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }  Widget _alphaGrid() {
    // 4-across glove-friendly alpha keypad (bigger targets)
    return Column(
      children: [
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'A', onTap: () => _append('A'))),
          Expanded(child: _squareButton(label: 'B', onTap: () => _append('B'))),
          Expanded(child: _squareButton(label: 'C', onTap: () => _append('C'))),
          Expanded(child: _squareButton(label: 'D', onTap: () => _append('D'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'E', onTap: () => _append('E'))),
          Expanded(child: _squareButton(label: 'F', onTap: () => _append('F'))),
          Expanded(child: _squareButton(label: 'G', onTap: () => _append('G'))),
          Expanded(child: _squareButton(label: 'H', onTap: () => _append('H'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'I', onTap: () => _append('I'))),
          Expanded(child: _squareButton(label: 'J', onTap: () => _append('J'))),
          Expanded(child: _squareButton(label: 'K', onTap: () => _append('K'))),
          Expanded(child: _squareButton(label: 'L', onTap: () => _append('L'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'M', onTap: () => _append('M'))),
          Expanded(child: _squareButton(label: 'N', onTap: () => _append('N'))),
          Expanded(child: _squareButton(label: 'O', onTap: () => _append('O'))),
          Expanded(child: _squareButton(label: 'P', onTap: () => _append('P'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'Q', onTap: () => _append('Q'))),
          Expanded(child: _squareButton(label: 'R', onTap: () => _append('R'))),
          Expanded(child: _squareButton(label: 'S', onTap: () => _append('S'))),
          Expanded(child: _squareButton(label: 'T', onTap: () => _append('T'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'U', onTap: () => _append('U'))),
          Expanded(child: _squareButton(label: 'V', onTap: () => _append('V'))),
          Expanded(child: _squareButton(label: 'X', onTap: () => _append('X'))),
          Expanded(child: _squareButton(label: 'Y', onTap: () => _append('Y'))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'Z', onTap: () => _append('Z'))),
          Expanded(child: _squareButton(label: '!', onTap: () => _append('!'))),
          Expanded(child: _squareButton(label: 'SP', onTap: () => _append(' '))),
          Expanded(child: _squareButton(label: '⌫', onTap: _backspace)),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: _squareButton(label: 'CANCEL', onTap: _cancel)),
          Expanded(child: _squareButton(label: '#', onTap: () => _switchMode(GloveKeypadMode.num))),
          Expanded(child: _squareButton(label: 'ENTER', onTap: _enter)),
        ])),
      ],
    );
  }
Widget _numGrid() {
    const rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['-', '0', '⌫'],
    ];

    return Column(
      children: [
        for (final r in rows)
          Expanded(
            child: Row(
              children: [
                for (final k in r)
                  Expanded(
                    child: _squareButton(
                      label: k,
                      onTap: () {
                        if (k == '⌫') return _backspace();
                        _append(k);
                      },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _squareButton(label: 'CANCEL', onTap: _cancel)),
              Expanded(
                child: _squareButton(
                  label: 'A',
                  onTap: () => _switchMode(GloveKeypadMode.alpha),
                ),
              ),
              Expanded(child: _squareButton(label: 'ENTER', onTap: _enter)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: _cancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _displayBar(),
              const SizedBox(height: 4),
              Expanded(
                child: _mode == GloveKeypadMode.alpha ? _alphaGrid() : _numGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
