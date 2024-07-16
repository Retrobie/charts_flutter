import 'dart:ui' show TextDirection;
import 'package:flutter/material.dart'
    show
        AnimationController,
        BuildContext,
        State,
        TickerProviderStateMixin,
        Widget;
import 'package:charts_common/common.dart' as common;
import 'package:flutter/widgets.dart'
    show Directionality, LayoutId, CustomMultiChildLayout;
import 'behaviors/chart_behavior.dart'
    show BuildableBehavior, ChartBehavior, ChartStateBehavior;
import 'base_chart.dart' show BaseChart;
import 'chart_container.dart' show ChartContainer;
import 'chart_state.dart' show ChartState;
import 'chart_gesture_detector.dart' show ChartGestureDetector;
import 'widget_layout_delegate.dart';

class BaseChartState<D> extends State<BaseChart<D>>
    with TickerProviderStateMixin
    implements ChartState {
  late AnimationController _animationController;
  double _animationValue = 0.0;

  BaseChart<D>? _oldWidget;
  ChartGestureDetector? _chartGestureDetector;
  bool _configurationChanged = false;

  final autoBehaviorWidgets = <ChartBehavior<D>>[];
  final addedBehaviorWidgets = <ChartBehavior<D>>[];
  final addedCommonBehaviorsByRole = <String, common.ChartBehavior>{};

  final addedSelectionChangedListenersByType =
      <common.SelectionModelType, common.SelectionModelListener<D>>{};
  final addedSelectionUpdatedListenersByType =
      <common.SelectionModelType, common.SelectionModelListener<D>>{};

  final _behaviorAnimationControllers =
      <ChartStateBehavior, AnimationController>{};

  static const chartContainerLayoutID = 'chartContainer';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this)
      ..addListener(_animationTick);
  }

  @override
  void requestRebuild() {
    setState(() {});
  }

  @override
  void markChartDirty() {
    _configurationChanged = true;
  }

  @override
  void resetChartDirtyFlag() {
    _configurationChanged = false;
  }

  @override
  bool get chartIsDirty => _configurationChanged;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Widget _buildChartContainer() {
    final chartContainer = ChartContainer<D>(
      oldChartWidget: _oldWidget,
      chartWidget: widget,
      chartState: this,
      animationValue: _animationValue,
      rtl: Directionality.of(context) == TextDirection.rtl,
      rtlSpec: widget.rtlSpec,
      userManagedState: widget.userManagedState,
    );
    _oldWidget = widget;

    final desiredGestures = widget.getDesiredGestures(this);
    if (desiredGestures.isNotEmpty) {
      _chartGestureDetector ??= ChartGestureDetector();
      return _chartGestureDetector!
          .makeWidget(context, chartContainer, desiredGestures);
    } else {
      return chartContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartWidgets = <LayoutId>[];
    final idAndBehaviorMap = <String, BuildableBehavior>{};

    chartWidgets.add(
        LayoutId(id: chartContainerLayoutID, child: _buildChartContainer()));

    addedCommonBehaviorsByRole.forEach((id, behavior) {
      if (behavior is BuildableBehavior) {
        assert(id != chartContainerLayoutID);

        final buildableBehavior = behavior as BuildableBehavior;
        idAndBehaviorMap[id] = buildableBehavior;

        final widget = buildableBehavior.build(context);
        chartWidgets.add(LayoutId(id: id, child: widget));
      }
    });

    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return CustomMultiChildLayout(
        delegate: WidgetLayoutDelegate(
            chartContainerLayoutID, idAndBehaviorMap, isRTL),
        children: chartWidgets);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _behaviorAnimationControllers
        .forEach((_, controller) => controller.dispose());
    _behaviorAnimationControllers.clear();
    super.dispose();
  }

  @override
  void setAnimation(Duration transition) {
    _playAnimation(transition);
  }

  void _playAnimation(Duration duration) {
    _animationController.duration = duration;
    _animationController.forward(from: (duration == Duration.zero) ? 1.0 : 0.0);
    _animationValue = _animationController.value;
  }

  void _animationTick() {
    setState(() {
      _animationValue = _animationController.value;
    });
  }

  /// Get animation controller to be used by [behavior].
  AnimationController getAnimationController(ChartStateBehavior behavior) {
    _behaviorAnimationControllers[behavior] ??=
        AnimationController(vsync: this);

    return _behaviorAnimationControllers[behavior]!;
  }

  /// Dispose of animation controller used by [behavior].
  void disposeAnimationController(ChartStateBehavior behavior) {
    final controller = _behaviorAnimationControllers.remove(behavior);
    controller?.dispose();
  }
}
