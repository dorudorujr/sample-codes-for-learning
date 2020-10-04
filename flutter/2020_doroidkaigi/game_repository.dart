import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whack_a_mole/domain/models/mole_event.dart';
import 'package:whack_a_mole/infra/game_dao.dart';
import 'package:whack_a_mole/infra/global_dao.dart';

class GameRepository {
  final GlobalDao _globalDao;
  final GameDao _gameDao;

  const GameRepository(this._globalDao, this._gameDao);

  Stream<String> get currentGameId => _globalDao.currentGameId;   ///最新のゲームIDを取得

  /// - async/awaitを使っている関数で
  /// - 戻り値がある（T型）
  /// firesoreに登録してあるもぐら情報を取得し、リストにして返す
  Future<List<MoleEvent>> getEvents(String gameId, int deviceId) async {
    final documents = await _gameDao.getEvents(gameId, deviceId);   ///ゲームイベントを取得(もぐらの情報(出現時間、type))

    // QuerySnapshotを変換
    /// documents.documents: snapshotから値を取得している
    final events = documents.documents.map((document) {
      final int type = document.data[GameDao.eventTypeField];
      final Timestamp timestamp = document.data[GameDao.eventTimestampField];
      final duration =
          Duration(milliseconds: document.data[GameDao.eventDurationField]);
      return MoleEvent(
          type: type,
          timeInMilliseconds: timestamp.millisecondsSinceEpoch,
          duration: duration);
    }).toList();    /// MoleEventのリストに変換?
    return Future.value(events);    /// Future<List<MoleEvent>>の型の値を生成?、非同期処理を扱える型
  }
}
