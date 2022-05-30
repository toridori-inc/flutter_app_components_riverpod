import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ViewModelStateWatcher<T> = T Function(T currentState);

/// EntityデータとUIの仲介役となるViewModelを生成します
///
/// [ViewModel]の動作は、基本的には、StateNotifierを拡張して得られる動作と同じです。一点だけ違うのは、
/// 「Entityデータのデータソースを一意に決めることができない」という状態において、そのデータソースの定義を外部から指定することができるので、
/// 通常のStateNotifierよりも少しだけ便利です。
///
/// UIからの入力を[ViewModel]で受け取りたい場合は、継承して使用してください
class ViewModel<T> extends StateNotifier<T> {
  final ViewModelStateWatcher<T>? stateWatcher;

  ViewModel({
    required T initialState,
    this.stateWatcher,
    required ProviderReference ref,
  }) : super(initialState) {
    _tryUpdateState();
  }

  void _tryUpdateState() {
    if (stateWatcher == null) {
      return;
    }

    final T? oldState = state;

    final newState = stateWatcher!(state);

    if (oldState != newState) {
      state = newState;
    }
  }
}
