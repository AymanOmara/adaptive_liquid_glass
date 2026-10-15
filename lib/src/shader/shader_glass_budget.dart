import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Caps how many shader glass groups draw at once in one view on Android.
///
/// Under Impeller every `ImageFilter.shader` backdrop renders into
/// full-screen offscreen textures whatever the glass's size (about
/// 110-200 MB of GPU memory each at 1080x2340), so a screen of shader glass
/// can exceed what Android's low-memory killer allows. Each glass group
/// that would draw the shader takes a [ShaderGlassTicket]; groups past the
/// budget draw the frosted-blur fallback instead.
///
/// The rule: tickets rank by priority (the tab bar's own glass first),
/// then by registration order, and the first `budget` rank in. A group
/// that registers late waits; when a group ahead of it leaves, it is
/// promoted on the next frame (never mid-frame, so a scroll that mounts
/// and unmounts rows does not make glass flicker). Groups in routes hidden
/// under an opaque route ([TickerMode] off) keep their place but do not
/// count, so a pushed page gets the slots, and the page below takes them
/// back when it shows again.
class ShaderGlassBudget {
  ShaderGlassBudget._();

  static final Map<Object, ShaderGlassBudget> _byView = {};

  /// The budget of the view [context] is drawn into.
  static ShaderGlassBudget of(BuildContext context) => _byView.putIfAbsent(
    View.maybeOf(context) ?? _noView,
    ShaderGlassBudget._,
  );

  static const Object _noView = Object();

  /// Whether the over-budget warning was printed; reset it in tests.
  @visibleForTesting
  static bool debugWarned = false;

  /// Live tickets in this budget.
  @visibleForTesting
  int get debugTicketCount => _tickets.length;

  final List<ShaderGlassTicket> _tickets = [];
  int _next = 0;
  bool _notifyScheduled = false;

  /// Takes a place in the queue; [onChanged] runs (after a frame) when the
  /// ticket's grant changes because other tickets came or went.
  ShaderGlassTicket register(VoidCallback onChanged) {
    final ticket = ShaderGlassTicket._(this, _next++, onChanged);
    _tickets.add(ticket);
    return ticket;
  }

  int _rank(ShaderGlassTicket me) {
    var rank = 0;
    for (final t in _tickets) {
      if (identical(t, me) || !t._active) continue;
      if (t._priority != me._priority ? t._priority : t._order < me._order) {
        rank++;
      }
    }
    return rank;
  }

  /// Tells the tickets whose grant changed, after this frame.
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _notifyScheduled = false;
        for (final t in List.of(_tickets)) {
          if (t._active && t._built != null && t._granted != t._built) {
            t._onChanged();
          }
        }
      })
      ..ensureVisualUpdate();
  }
}

/// One glass group's place in a [ShaderGlassBudget].
class ShaderGlassTicket {
  ShaderGlassTicket._(this._budget, this._order, this._onChanged);

  final ShaderGlassBudget _budget;
  final int _order;
  final VoidCallback _onChanged;
  bool _priority = false;
  bool _active = true;
  int? _limit;
  bool _released = false;

  /// The grant the owner last built with.
  bool? _built;

  /// The owner's view: a different one needs a new ticket.
  ShaderGlassBudget get budget => _budget;

  bool get _granted {
    final limit = _limit;
    return limit == null || _budget._rank(this) < limit;
  }

  /// Updates the ticket from the owner's build and returns whether the
  /// owner may draw the shader.
  ///
  /// [limit] is the budget (null: unlimited), [priority] puts the ticket
  /// ahead of non-priority ones, and [active] is false while the owner is
  /// not shown (a route under an opaque route).
  bool resolve({
    required int? limit,
    required bool priority,
    required bool active,
  }) {
    assert(!_released);
    // Others' ranks change with a priority or visibility change.
    if (priority != _priority || active != _active) {
      _priority = priority;
      _active = active;
      _budget._scheduleNotify();
    }
    _limit = limit;
    // Hidden: keep what is built, nothing is drawn anyway.
    if (!active && _built != null) return _built!;
    final granted = _granted;
    _built = granted;
    if (!granted) {
      assert(() {
        if (!ShaderGlassBudget.debugWarned) {
          ShaderGlassBudget.debugWarned = true;
          debugPrint(
            'adaptive_liquid_glass: more than $limit shader glass groups '
            'are on screen; the rest draw a frosted blur instead. On '
            'Android every shader glass group costs about 110-200 MB of '
            'GPU memory whatever its size (full-screen offscreen textures '
            'under Impeller), and too many get the app killed. Put '
            'neighbouring glass in one GlassGroup (one group = one '
            'surface), or change LiquidGlassThemeData.androidShaderBudget.',
          );
        }
        return true;
      }());
    }
    return granted;
  }

  /// Gives the place up; waiting tickets are promoted after this frame.
  void release() {
    if (_released) return;
    _released = true;
    _budget._tickets.remove(this);
    _budget._scheduleNotify();
  }
}

/// Puts the glass groups below ahead in the [ShaderGlassBudget] queue.
///
/// The tab bar's own glass uses it: it is permanent chrome, and frosting it
/// while content glass keeps the shader would look wrong.
class ShaderBudgetPriority extends InheritedWidget {
  /// Marks [child]'s glass groups as priority.
  const ShaderBudgetPriority({super.key, required super.child});

  /// Whether [context] is under a [ShaderBudgetPriority].
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShaderBudgetPriority>() != null;

  @override
  bool updateShouldNotify(ShaderBudgetPriority oldWidget) => false;
}
