import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whack_a_mole/domain/models/mole_event.dart';

///
/// Game情報にアクセスを統一するData Access Object
///
class GameDao {
  final Firestore _firestore;

  const GameDao(this._firestore);

  /// [Firestore]からゲームイベントを取得.
  ///
  ///[gameId] 取得するゲームイベントのゲームID
  ///[deviceId] 取得するゲームイベントのデバイスID
  /// ゲームイベントの取得(各もぐらの情報)
  Future<QuerySnapshot> getEvents(String gameId, int deviceId) => _firestore
      .collection(_rootCollection)
      .document(gameId)
      .collection(_sequenceCollection)
      .document(deviceId.toString())
      .collection(_eventCollection)
      .getDocuments();

  /// Globalのコレクション
  static const _rootCollection = 'games';

  /// Sequenceのコレクション
  static const _sequenceCollection = 'sequences';

  /// Eventのコレクション
  static const _eventCollection = 'events';

  /// EventのDocument内のもぐらタイプフィールド
  static const eventTypeField = 'type';

  /// EventのDocument内のTimestampフィールド
  static const eventTimestampField = 'time';

  /// EventのDocument内のDurationフィールド
  static const eventDurationField = 'duration';
}
