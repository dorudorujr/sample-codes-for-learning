import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:whack_a_mole/domain/models/mole_event.dart';
import 'package:whack_a_mole/domain/models/mole_game_sequence.dart';
import 'package:whack_a_mole/domain/models/mole_game_sequence_type.dart';
import 'package:whack_a_mole/domain/models/mole_type.dart';
import 'package:whack_a_mole/domain/repository/game_repository.dart';

///
/// ゲームシーケンスのBLoC.
class SequenceBloc {
  final GameRepository repository;

  // 端末ID
  final int deviceId;

  // ObserverとStreamを継承したSubjectを定義
  final _subject = PublishSubject<MoleGameSequence>();    /// MoleGameSewuence: もぐらの出現状態(in or out)、もぐらのtype(画像)
  final _gameIdController = StreamController<String>();

  StreamSubscription _subscription;

  SequenceBloc({this.repository, this.deviceId}) {
    _fetchSequences();
  }

  // Streamは連続したObserverの配列みたいなものを定義
  Stream<MoleGameSequence> get sequenceStream => _subject.stream;

  // StreamにObserverをaddするためのアクセッサを定義
  Sink<MoleGameSequence> get sequenceSink => _subject.sink;

  /// Firestoreからゲームシーケンスを取得
  void _fetchSequences() async {
    // _subscription = repository.currentGameId
    //     .asyncMap((gameId) => repository.getEvents(gameId, deviceId))   /// Futureを返す可能性があり、その場合、このストリームは結果を続行する前にそのfutureが完了するのを待ちます。
    //     .listen(_handleMoleEvents);

    // GameId取得
    _subscription = repository.currentGameId.listen((gameId) {
      // GameId追加
      _gameIdController.sink.add(gameId);
      // イベント取得
      repository.getEvents(gameId, deviceId).then(_handleMoleEvents);   /// then:非同期処理が完了したときに、完了した値Tと共にコールバック関数が呼び出されます。
    });
  }

  /// [MoleEvent]から[MoleGameSequence]を設定されたタイミングで発信
  ///
  /// [events] [Firestore]から取得したもぐらイベント
  void _handleMoleEvents(List<MoleEvent> events) {
    events.forEach((event) {
      log(event.toString());

      // もぐらの種類
      final moleType = MoleTypeExtension.valueOf(event.type);

      // 現在のtimestamp
      final now = Timestamp.now();
      final startDelay = event.timeInMilliseconds - now.millisecondsSinceEpoch;
      final animationTime =
          (event.duration.inMilliseconds * _moleAnimationRatio).toInt();
      final delay = event.duration.inMilliseconds - animationTime;

      log(startDelay.toString());

      if (startDelay > 0) {
        /// 表示時間まで待ってからsequenceSink.add(entryEvent);を行っている
        Future.delayed(Duration(milliseconds: startDelay), () {   /// startDelay待ってから実行
          // 指定したtimestampのタイミングで追加
          final entryEvent = MoleGameSequence(
              sequenceType: MoleGameSequenceType.ENTRY,
              moleType: moleType,
              duration: Duration(milliseconds: animationTime));
          _subject.sink.add(entryEvent);

          /// 消える時間まで待ってからsequenceSink.add(exitEvent);している
          Future.delayed(Duration(milliseconds: delay), () {
            // 指定したtimestamp+durationのタイミングで追加
            final exitEvent = MoleGameSequence(
                sequenceType: MoleGameSequenceType.EXIT,
                moleType: moleType,
                duration: Duration(milliseconds: animationTime));
            _subject.sink.add(exitEvent);
          });
        });
      }
    });
  }

  void dispose() {
    _subject.close();
    _subscription.cancel();
  }
}
