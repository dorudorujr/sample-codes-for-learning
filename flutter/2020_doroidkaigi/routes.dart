import 'package:flutter/widgets.dart';
import 'package:whack_a_mole/ui/screens/client/game_screen.dart';
import 'package:whack_a_mole/ui/screens/client/position_selection_screen.dart';
import 'package:whack_a_mole/ui/screens/host/host_screen.dart';

class Routes {
  /// ホスト画面
  static const host = "/host";

  /// クライアントの位置選択画面
  static const positionSelection = "/client/positionSelection";

  /// クライアント画面
  static const game = "/client/game";

  static Map<String, WidgetBuilder> get() {
    return <String, WidgetBuilder>{
      host: (BuildContext context) => HostScreen(),
      positionSelection: (BuildContext context) => PositionSelectionScreen(),
      game: (BuildContext context) {
        ///PositionSelectionScreenからのpush時にGameArguments値を渡しそれを取得している
        final GameArguments args = ModalRoute.of(context).settings.arguments;
        return GameScreen(args.deviceId);
      },
    };
  }
}

@immutable
class GameArguments {
  final int deviceId;

  const GameArguments(this.deviceId);
}
