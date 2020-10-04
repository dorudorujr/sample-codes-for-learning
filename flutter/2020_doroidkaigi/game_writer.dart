import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whack_a_mole/domain/models/timeline.dart';

// TODO: 配信を待つ時間を定数化
// TODO: ゲームのスタート時刻を遅らせる

class GameWriter {
  final db = Firestore.instance;

  void write(
      {List<Timeline> timelines,
      DateTime startTime,
      String playerName = "admin",
      String twitterId = ""}) {
    final batch = db.batch();   ///firestoreのbatch処理を行うために必要な処理

    /// バッチ: データの一括書き込み(fireBaseに)

    //
    // Game Contents
    //
    final gameRoot = db.collection("games").document();
    final sequenceRoot = gameRoot.collection("sequences");

    /// asMap: ListをMapに変換(keyはindex)
    timelines.asMap().forEach((deviceId, timeline) {
      final timelineDocument = sequenceRoot.document(deviceId.toString());
      final eventsCollection = timelineDocument.collection("events");

      timeline.events.asMap().forEach((index, element) {
        final date =
            startTime.add(Duration(milliseconds: element.timeInMilliseconds));    ///出現時間をここで作成
        final obj = {
          "time": date,
          "duration": element.duration.inMilliseconds,
          "type": element.type
        };

        batch.setData(
          eventsCollection.document(index.toString()),
          obj,
          merge: true,
        );
      });
    });

    //
    // Player info
    //
    batch.setData(gameRoot, {"nickname": playerName}, merge: true);
    batch.setData(gameRoot, {"twitterId": twitterId}, merge: true);

    //
    // Game ID
    //
    final gameIdDoc = db.collection("global").document("gameId");
    batch.setData(gameIdDoc, {"current": gameRoot.documentID});

    batch.commit();
  }
}
