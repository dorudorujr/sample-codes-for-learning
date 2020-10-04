import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whack_a_mole/domain/game_generator.dart';
import 'package:whack_a_mole/domain/models/game_control_events.dart';
import 'package:whack_a_mole/domain/models/game_control_state.dart';
import 'package:whack_a_mole/domain/repository/state_repository.dart';
import 'package:whack_a_mole/infra/game_writer.dart';

class GameControlBloc extends Bloc<GameControlEvent, GameControlState> {
  static const gameStartDelay = Duration(seconds: 3);

  final StateRepository stateRepository;    ///ゲームのisPlayingを更新(変化させる)するリポジトリ
  final GameGenerator gameGenerator;
  final GameWriter gameWriter;

  GameControlBloc({
    @required this.stateRepository,
    @required this.gameGenerator,
    @required this.gameWriter,
  }) {
    // forward stateRepository updated as events to this bloc
    _stateSubscription = stateRepository.isPlaying      /// firestoreのisPlayingが1かどうかのbool
        .map((isPlaying) => _FirebaseUpdate(isPlaying))
        .listen(add);     /// 自身のmapEventToStateを呼ぶ
  }

  StreamSubscription _stateSubscription;

  /// Firebaseにゲーム開始を送信するタイマー
  Timer _gameStartTimer;

  /// Firebaseにゲーム中止を送信するタイマー
  Timer _gameStopTimer;

  @override
  GameControlState get initialState => GameControlState.idle;   /// initialState: イベントが処理される前の状態

  @override
  Stream<GameControlState> mapEventToState(GameControlEvent event) async* {
    final currentState = state;

    if (event is _FirebaseUpdate) {
      /// isPlayingがfalseならゲームの時間(_gameStartTimer,_gameStopTimer)を止める
      if (!event.isPlaying) {
        _stopFirebaseUpdateTimers();
      }

      yield (event.isPlaying)
          ? GameControlState.playing
          : GameControlState.idle;
    }

    if (event is StartGame) {
      _startGame(event.playerName, event.twitterHandle);

      if (currentState != GameControlState.playing) {
        yield GameControlState.waiting;
      }
    }

    if (event is StopGame) {
      _stopFirebaseUpdateTimers();
      stateRepository.updateIsPlaying(false);

      if (currentState != GameControlState.idle) {
        yield GameControlState.waiting;
      }
    }
  }

  /// 新しいゲームを生成し、Firebaseに送信
  /// ゲーム開始のタイマー・ゲーム中止タイマーをセットする
  void _startGame(String playerName, String twitterId) {
    ///timelinesを生成している
    ///timelines: もぐらの情報(ローカルな情報)
    final timelines = gameGenerator.generateGame();

    final startTime = DateTime.now().add(gameStartDelay);

    /// firestormにデータを書き込む
    /// もぐらの情報
    /// type,出現時間など
    gameWriter.write(
      timelines: timelines,
      startTime: startTime,
      playerName: playerName,
      twitterId: twitterId,
    );

    final lastMoleEvent = timelines
        .expand(      /// expand: 各要素を0個以上の要素に展開します。
          (timeline) => timeline.events,
        )             /// [[event1_1,event1_2], [event2_1, event2_2]] => [event1_1, event1_2, event2_1, event2_2]
        .reduce(      /// reduce: 与えられた関数を使って、要素を単一の値にする
          (tempMaximum, current) => (tempMaximum.endTimeInMilliseconds >=
                  current.endTimeInMilliseconds)
              ? tempMaximum
              : current,
        );            /// 一番最後のeventを取得

    /// 終わる時間を算出
    final endTime = startTime
        .add(Duration(milliseconds: lastMoleEvent.endTimeInMilliseconds));

    _startFirebaseUpdateTimers(
      // ゲーム開始のタイムスタンプより少し前
      gameStartDelay - Duration(seconds: 1),
      // ゲーム終了時
      DateTime.now().difference(endTime).abs(),
    );
  }

  /// Firebase上にゲーム開始・中止のステートをアップデートするタイマーをセット
  void _startFirebaseUpdateTimers(Duration startAfter, Duration stopAfter) {
    _gameStartTimer = Timer(
      startAfter,
      () {
        stateRepository.updateIsPlaying(true);
      },
    );

    // ゲーム終わってからFirestoreのステートを変更する
    _gameStopTimer = Timer(
      stopAfter,
      () {
        stateRepository.updateIsPlaying(false);
      },
    );
  }

  /// ゲーム開始・中止タイマーをキャンセル
  void _stopFirebaseUpdateTimers() {
    if (_gameStartTimer?.isActive == true) {
      _gameStartTimer.cancel();
    }

    if (_gameStopTimer?.isActive == true) {
      _gameStopTimer.cancel();
    }
  }

  @override
  Future<void> close() async {
    _stopFirebaseUpdateTimers();
    _stateSubscription?.cancel();
    super.close();
  }
}

/// [StateRepository]の状態が更新されたら発行するイベント
@immutable
class _FirebaseUpdate extends GameControlEvent {
  final bool isPlaying;

  const _FirebaseUpdate(this.isPlaying) : super();
}
