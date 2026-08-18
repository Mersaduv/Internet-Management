import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/clients_provider.dart';

/// Reports when a connected-list row intersects the scroll viewport so live
/// traffic polling can start/stop per device (including pending approval rows).
class TrafficListItemVisibility extends StatefulWidget {
  const TrafficListItemVisibility({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<TrafficListItemVisibility> createState() =>
      _TrafficListItemVisibilityState();
}

class _TrafficListItemVisibilityState extends State<TrafficListItemVisibility> {
  ClientsProvider? _provider;
  ScrollPosition? _scrollPosition;
  bool? _lastVisible;
  bool _reportScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= context.read<ClientsProvider>();
    _attachScrollPosition();
    _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant TrafficListItemVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (_lastVisible == true) {
        _provider?.reportTrafficListItemVisibility(oldWidget.index, false);
        _lastVisible = null;
      }
      _scheduleReport();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    if (_lastVisible == true) {
      _provider?.reportTrafficListItemVisibility(widget.index, false);
    }
    super.dispose();
  }

  void _attachScrollPosition() {
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (identical(_scrollPosition, position)) {
      return;
    }
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_onScroll);
  }

  void _onScroll() {
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled) {
      return;
    }
    _reportScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _reportScheduled = false;
      _reportVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _reportVisibility() {
    if (!mounted) {
      return;
    }
    _attachScrollPosition();
    final provider = _provider ?? context.read<ClientsProvider>();
    final visible = _intersectsScrollViewport(context);
    if (_lastVisible == visible) {
      return;
    }
    _lastVisible = visible;
    provider.reportTrafficListItemVisibility(widget.index, visible);
  }

  bool _intersectsScrollViewport(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return false;
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      return false;
    }

    final position = scrollable.position;
    if (!position.hasPixels) {
      return false;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final reveal = viewport.getOffsetToReveal(renderObject, 0.0);
    final itemStart = reveal.offset;
    final itemEnd = itemStart + renderObject.size.height;
    final viewStart = position.pixels;
    final viewEnd = position.pixels + position.viewportDimension;

    return itemEnd > viewStart && itemStart < viewEnd;
  }
}

/// Wraps the connected [ListView] and nudges visibility reporters after scroll.
class TrafficListScrollScope extends StatefulWidget {
  const TrafficListScrollScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<TrafficListScrollScope> createState() => _TrafficListScrollScopeState();
}

class _TrafficListScrollScopeState extends State<TrafficListScrollScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant TrafficListScrollScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) {
      return;
    }
    context.read<ClientsProvider>().notifyTrafficListScrolled();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
