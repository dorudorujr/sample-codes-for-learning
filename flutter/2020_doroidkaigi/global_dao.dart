import 'package:cloud_firestore/cloud_firestore.dart';

///
/// Global情報にアクセスを統一するData Access Object
///
class GlobalDao {
  final Firestore _firestore;

  const GlobalDao(this._firestore);

  /// 最新のゲームIDのStream
  /// globalのgameIdのcurrentを取得？
  Stream<String> get currentGameId => _firestore
      .collection(_rootCollection)
      .document(_gameIdDocument)
      .snapshots()  /// snapshots: そのdocumentの参照(子要素とかも含むデータ?)
      .map((document) => document.data[_currentGameField]);

  /// globalのstatesのisPlayingを取得
  Stream<bool> get isPlaying => _firestore
      .collection(_rootCollection)
      .document(_stateDocument)
      .snapshots()
      .map((document) => document.data[_isPlayingField] == 1);

  /// 最新のゲームIDを更新する
  Future<void> updateCurrentGameId(String newGameId) => _firestore
      .collection(_rootCollection)
      .document(_gameIdDocument)
      .setData({_currentGameField: newGameId});

  /// プレイ中の値をセットする
  Future<void> updateIsPlaying(bool isPlaying) => _firestore
      .collection(_rootCollection)
      .document(_stateDocument)
      .setData({_isPlayingField: (isPlaying) ? 1 : 0});

  /// Globalのコレクション
  static const _rootCollection = 'global';

  /// gameId管理用のDocument
  static const _gameIdDocument = 'gameId';

  /// gameIdのDocument内の最新のゲームID持つフィールド
  static const _currentGameField = 'current';

  /// ステート管理用のDocument
  static const _stateDocument = 'states';

  /// ステートのDocument内のプレイ中フィールド
  static const _isPlayingField = 'isPlaying';
}
