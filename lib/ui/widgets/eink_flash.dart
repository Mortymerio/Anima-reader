import 'package:flutter/material.dart';

/// Full-screen flash for E-ink ghosting cleanup.
///
/// Performs a black→white→black cycle to force a full display refresh.
/// Duration is configurable; defaults to 400ms which works well on
/// most E-ink displays (Bigme, Boox, Kobo).
class EinkFlash extends StatefulWidget {
  final bool visible;
  final Duration duration;

  const EinkFlash({
    super.key,
    required this.visible,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<EinkFlash> createState() => _EinkFlashState();
}

class _EinkFlashState extends State<EinkFlash> {
  bool _showWhite = false;

  @override
  void didUpdateWidget(EinkFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _runDoubleFlash();
    }
  }

  /// Double flash: black → white → complete
  /// This forces a deeper refresh on E-ink panels.
  void _runDoubleFlash() async {
    if (!mounted) return;
    setState(() => _showWhite = false); // Start with black

    await Future.delayed(Duration(milliseconds: widget.duration.inMilliseconds ~/ 2));
    if (!mounted) return;
    setState(() => _showWhite = true); // Flash to white

    await Future.delayed(Duration(milliseconds: widget.duration.inMilliseconds ~/ 2));
    // The parent widget will set visible=false after the duration completes
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Container(
      color: _showWhite ? Colors.white : Colors.black,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
