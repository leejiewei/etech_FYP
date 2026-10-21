import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// eTech's motion in the app, the same as the website's (web/js/reveal.js
/// and the motion rules in web/css/style.css): pages and product cards
/// fade up while rising a few pixels, and a card gives a little under the
/// finger. Quiet and quick; nothing bounces. Every timing is one of the
/// AppTheme.dur* values with AppTheme.easeOut.
///
/// With the phone's "Remove animations" setting on, each of these simply
/// shows its child.

bool _reduced(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Widget _rise(Animation<double> t, Widget child) => AnimatedBuilder(
      animation: t,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, AppTheme.rise * (1 - t.value)),
        child: child,
      ),
      child: child,
    );

/// Every MaterialPageRoute in the app (set in AppTheme.theme): the new
/// page fades up over the old one and rises into place.
class RisePageTransitionsBuilder extends PageTransitionsBuilder {
  const RisePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppTheme.durSlow;

  @override
  Duration get reverseTransitionDuration => AppTheme.durBase;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduced(context)) return child;
    final t = CurvedAnimation(
      parent: animation,
      curve: AppTheme.easeOut,
      reverseCurve: AppTheme.easeOut.flipped,
    );
    return FadeTransition(opacity: t, child: _rise(t, child));
  }
}

/// A product card coming in. The first screenful arrives one after
/// another; anything further down the list, built as it scrolls in, comes
/// straight in, so a long list never waits. It plays once per card: a
/// rebuild (ticking the heart, a cart update) keeps the state and does
/// not replay it.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, required this.index, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppTheme.durSlow);
  late final Animation<double> _t =
      CurvedAnimation(parent: _controller, curve: AppTheme.easeOut);
  Timer? _wait;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduced(context)) {
      _controller.value = 1;
      return;
    }
    final place = widget.index < 8 ? widget.index : 0;
    if (place == 0) {
      _controller.forward();
    } else {
      // The website's gap between cards: a quarter of durFast.
      _wait = Timer(AppTheme.durFast * (place / 4), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _t, child: _rise(_t, widget.child));
}

/// Gives a little under the finger, the way the website's buttons press
/// in. Listens to the raw pointer, so taps, the heart and Add to cart all
/// work as before; dragging the list lets go at once.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  Offset? _down;

  void _release() {
    if (_down != null) setState(() => _down = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (e) => setState(() => _down = e.position),
      onPointerMove: (e) {
        if (_down != null && (e.position - _down!).distance > kTouchSlop) _release();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _down == null ? 1 : AppTheme.pressScale,
        duration: AppTheme.durFast,
        curve: AppTheme.easeOut,
        child: widget.child,
      ),
    );
  }
}
