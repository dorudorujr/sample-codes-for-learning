import 'dart:math';

import 'package:whack_a_mole/domain/card_sequencer.dart';
import 'package:whack_a_mole/domain/models/mole_event.dart';
import 'package:whack_a_mole/domain/models/timeline.dart';

const numMoleTypes = 4;

class GameGenerator {
  List<Timeline> timelines;
  int numDevices;   ///デバイスの総数

  GameGenerator({this.numDevices}) {

    ///numDevices分、空のTimeLineを生成
    timelines = List<Timeline>.generate(numDevices, (int index) {
      return Timeline();
    });
  }

  ///関数generateを2回呼んでtimelinesを返している
  ///timelinesにMoleEventを追加している
  ///MoleEvent = 出てくる時間、もぐらのタイプなどのローカルなもぐら情報
  List<Timeline> generateGame() {
    generate(
        startTimeInMilliseconds: 0,
        endTimeInMilliseconds: 5000,
        appearanceDuration: Duration(seconds: 1),   ///1秒
        sequence: CardSequencer<int>.randomFromMap({0: 2, 1: 3}));  /// [0,0,1,1,1]の配列をまぶしている
    generate(
        startTimeInMilliseconds: 5000,
        endTimeInMilliseconds: 10000,
        appearanceDuration: Duration(seconds: 1),
        sequence: CardSequencer<int>.randomFromMap({0: 5, 1: 5}));

    return timelines;
  }

  void generate(
      {int startTimeInMilliseconds,
      int endTimeInMilliseconds,
      Duration appearanceDuration,
      CardSequencer<int> sequence,
      Random randomizer}) {
    // ※interval < appearanceDuration となるようにすると同時に出るようになる
    /// 等間隔でもぐらが出るシステムでその間隔値
    final interval =
        (endTimeInMilliseconds - startTimeInMilliseconds) ~/ sequence.length();   /// ~/: 切り捨て除算
    int currentTime = startTimeInMilliseconds;

    final rng = randomizer ?? Random();

    ///sequenceの長さが0以下になるまで回す
    while (sequence.hasNext()) {
      // moleCountsに指定されているカードから１つ選定。
      final type = sequence.next();   ///sequenceから値を取得し、取得した値をListから削除する, 0か1の値(もぐらのtype?)

      // MoleEventを生成
      final event = MoleEvent(
        type: type,
        timeInMilliseconds: currentTime,
        duration: appearanceDuration,
      );

      // event.time時に空いている端末リスト
      /// canAddでTimelineから空いている端末のindexを確認している
      final freeDeviceIds = List.generate(numDevices, (index) => index)
          .where((id) => timelines[id].canAdd(event))   ///rxswiftのfilterみたいな感じ
          .toList(growable: false);
      // deviceNoをランダムで決定
      /// 空いている端末Noをランダムで取得
      final deviceNo = freeDeviceIds[rng.nextInt(freeDeviceIds.length)];

      timelines[deviceNo].addEvent(event);
      print(
          "Event of type ${event.type} added on device $deviceNo at time: $currentTime");

      currentTime += interval;
    }
  }
}
