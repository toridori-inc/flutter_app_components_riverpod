import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:state_notifier/state_notifier.dart';

import '../refresh_config.dart';
import '../refresh_state.dart';

part 'simple_refresh_controller.dart';
part 'page_refresh_controller.dart';

abstract class RefreshController<V, E> extends StateNotifier<RefreshState<V, E>> {
  static Function(dynamic e, StackTrace st) errorCallback;

  Duration lifetime;

  DateTime _lastLoadTime;

  // ignore: close_sinks
  Sink<Stream<void>> requestLifetimeRefreshSink;

  // ignore: close_sinks
  Sink<Stream<RefreshConfig>> requestConfigRefreshSink;

  final CompositeSubscription _compositeSubscription = CompositeSubscription();

  final PublishSubject<Stream<void>> _requestLifetimeRefreshSub = PublishSubject();
  final PublishSubject<Stream<RefreshConfig>> _requestConfigRefreshSub = PublishSubject();

  RefreshController._({
    this.lifetime,
    RefreshState<V, E> initialState,
  }) : super(initialState ?? RefreshState<V, E>()) {
    requestLifetimeRefreshSink = _requestLifetimeRefreshSub.sink;
    requestConfigRefreshSink = _requestConfigRefreshSub.sink;

    Rx.merge([
      _requestLifetimeRefreshSub.flatMap((x) => x).map((x) => RefreshConfig()),
      _requestConfigRefreshSub.flatMap((x) => x),
    ]).listen((x) => requestLifetimeRefresh(config: x))
      ..addTo(_compositeSubscription);
  }

  @override
  void dispose() {
    _requestConfigRefreshSub.close();
    _requestLifetimeRefreshSub.close();
    _compositeSubscription.dispose();
    super.dispose();
  }

  Future requestLifetimeRefresh({RefreshConfig config}) async {
    final conf = config ?? RefreshConfig();

    if (!_checkNeedLoad(conf)) {
      return;
    }

    try {
      await _mayRefresh(conf);
      _lastLoadTime = DateTime.now();
    } catch (e) {
      //ignore
    }
  }

  Future<V> requestSilentRefresh() => requestCleanRefresh(silent: true);

  Future<V> requestCleanRefresh({silent = false}) async {
    final config = RefreshConfig(silent: silent);

    return await _mayRefresh(config);
  }

  Future<V> requestMoreRefresh() async {
    final config = RefreshConfig(silent: true, stack: true);

    return await _mayRefresh(config);
  }

  Future _mayRefresh(RefreshConfig config) async {
    await for (final newState in _doRefresh(config, state)) {
      if (!mounted) {
        break;
      }

      state = newState;
    }
  }

  /// ???????????????????????????
  ///
  /// dispose?????????StateNotifier???state???????????????????????????????????????????????????????????????????????????????????????????????????
  /// ????????????state??????????????????????????????????????????????????????????????????????????????yield????????????????????????
  Stream<RefreshState<V, E>> _doRefresh(RefreshConfig config, RefreshState<V, E> currentState);

  bool _checkNeedLoad(RefreshConfig config) {
    if (state.isRefreshing) {
      // ????????????????????????????????????????????????????????????
      return false;
    }
    
    if (config.resetLifetime) {
      // ???????????????????????????????????????????????????
      return true;
    }
    if (_lastLoadTime == null) {
      // ??????????????????????????????????????????????????????????????????
      return true;
    }
    if (lifetime == null) {
      // ???????????????????????????????????????????????????????????????
      return true;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastLoadTime);
    final needLoad = diff.compareTo(lifetime) == 1;

    if (!needLoad) {
      print("Skip refresh. lifetime will be over after ${(lifetime - diff).inSeconds} seconds.");
    }
    return needLoad;
  }
}
