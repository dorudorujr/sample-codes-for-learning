import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:whack_a_mole/domain/bloc/sequence_bloc.dart';
import 'package:whack_a_mole/domain/models/mole_game_sequence.dart';
import 'package:whack_a_mole/domain/models/mole_game_sequence_type.dart';
import 'package:whack_a_mole/domain/models/mole_type.dart';
import 'package:whack_a_mole/domain/repository/game_repository.dart';
import 'package:whack_a_mole/infra/game_dao.dart';
import 'package:whack_a_mole/infra/global_dao.dart';

class GameScreen extends StatelessWidget {
  final int deviceId;

  const GameScreen(this.deviceId);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: MoleWidget(deviceId: deviceId),
      );
}

class MoleWidget extends StatefulWidget {
  final int deviceId;

  const MoleWidget({Key key, this.deviceId}) : super(key: key);

  @override
  _MoleState createState() => _MoleState();
}

class _MoleState extends State<MoleWidget> with SingleTickerProviderStateMixin {
  SequenceBloc _sequenceBloc;
  Animation<Offset> _animation;
  AnimationController _controller;

  @override
  void initState() {
    super.initState();

    final globalDao = GlobalDao(Firestore.instance);
    final gameDao = GameDao(Firestore.instance);
    final repository = GameRepository(globalDao, gameDao);    /// firestoreに登録してあるもぐら情報をリストにして返す関数を保持している
    _sequenceBloc =
        SequenceBloc(repository: repository, deviceId: widget.deviceId);

    _controller = AnimationController(      /// duration: 間隔, vsync: 伝える相手
        duration: const Duration(milliseconds: 300), vsync: this);

    /// Tween: アニメーションで制御する数値の間隔を定義
    /// y座標2.0から0.0に移動
    _animation =
        Tween<Offset>(begin: const Offset(0.0, 2.0), end: const Offset(0.0, 0))
            .animate(_controller);
    // streamに合わせてアニメーション表示
    _sequenceBloc.sequenceStream.listen((sequence) {
      switch (sequence.sequenceType) {
        case MoleGameSequenceType.ENTRY:
          _controller.forward();
          break;
        case MoleGameSequenceType.EXIT:
          _controller.reverse();
          break;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sequenceBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MoleGameSequence>(
      stream: _sequenceBloc.sequenceStream,
      builder: (context, snapshot) {
        return SlideTransition(       ///通常の位置を基準にしてウィジェットの位置をアニメーション化します。
            position: _animation,
            child: Padding(
                padding: EdgeInsets.all(24.0),
                child: snapshot.hasData
                    ? GestureDetector(
                        onTap: () => _whackMole(context, snapshot.data),
                        child: Image.asset(snapshot.data.moleType.iconPath))
                    : CircularProgressIndicator()));        /// インジケータ
      });

  /// もぐらを叩く
  void _whackMole(BuildContext context, MoleGameSequence sequence) {
    // FIXME: たたいたもぐらを表示
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(sequence.moleType.toString()),
    ));

    // もぐらを下がらせる
    _controller.reverse();
  }
}
