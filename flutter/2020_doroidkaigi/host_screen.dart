import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:whack_a_mole/config/field_configuration.dart';
import 'package:whack_a_mole/domain/bloc/game_control_bloc.dart';
import 'package:whack_a_mole/domain/game_generator.dart';
import 'package:whack_a_mole/domain/models/game_control_events.dart';
import 'package:whack_a_mole/domain/models/game_control_state.dart';
import 'package:whack_a_mole/domain/repository/state_repository.dart';
import 'package:whack_a_mole/infra/game_writer.dart';
import 'package:whack_a_mole/infra/global_dao.dart';
import 'package:whack_a_mole/localization/whack_a_mole_localizations.dart';

class HostScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(   /// BlocProvider:blocを生成してchildに渡す
        create: (context) {
          /// app.dartのfieldConfigurationを取得
          final fieldConfiguration = Provider.of<FieldConfiguration>(
            context,
            listen: false,
          );

          final globalDao = GlobalDao(Firestore.instance);
          return GameControlBloc(
            stateRepository: StateRepository(globalDao),
            gameGenerator: GameGenerator(
              numDevices: fieldConfiguration.columns * fieldConfiguration.rows,
            ),
            gameWriter: GameWriter(),
          );
        },
        child: Scaffold(
          appBar: AppBar(title: Text('Host Screen')),
          body: _HostControlsScreen(),
        ),
      );
}

class _HostControlsScreen extends StatefulWidget {
  @override
  __HostControlsScreenState createState() => __HostControlsScreenState();
}

class __HostControlsScreenState extends State<_HostControlsScreen> {
  GameControlBloc _gameControlBloc;

  final _playerNameController = TextEditingController();
  final _twitterHandleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gameControlBloc = BlocProvider.of<GameControlBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = WhackAMoleLocalizations.of(context);

    return Center(
      child: BlocBuilder<GameControlBloc, GameControlState>(
        builder: (BuildContext context, GameControlState state) {
          switch (state) {
            case GameControlState.idle:
              return Column(
                children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration(
                      icon: Icon(Icons.account_circle),
                      labelText: localizations.playerNameLabel,
                    ),
                    controller: _playerNameController,
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      icon: Icon(Icons.nature),
                      labelText: localizations.twitterIdLabel,
                    ),
                    controller: _twitterHandleController,
                  ),
                  IconButton(
                    icon: Icon(Icons.play_arrow),
                    onPressed: _startGame,
                  ),
                ],
              );
            case GameControlState.playing:
              return IconButton(
                icon: Icon(Icons.stop),
                onPressed: _stopGame,
              );
            case GameControlState.waiting:
              return CircularProgressIndicator();
          }

          // should not happen?
          return SizedBox.shrink();
        },
      ),
    );
  }

  void _startGame() {
    final event = StartGame(
      playerName: _playerNameController.text,
      twitterHandle: _twitterHandleController.text,
    );
    _gameControlBloc.add(event);    /// flutter_blocライブラリーのBloc<GameControlEvent, GameControlState>を継承している
    _playerNameController.clear();
    _twitterHandleController.clear();
  }

  void _stopGame() {
    _gameControlBloc.add(StopGame());
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _twitterHandleController.dispose();
    super.dispose();
  }
}
