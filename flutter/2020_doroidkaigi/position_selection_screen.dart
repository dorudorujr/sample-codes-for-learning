import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:whack_a_mole/config/field_configuration.dart';
import 'package:whack_a_mole/ui/routes.dart';

class PositionSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fieldConfiguration = Provider.of<FieldConfiguration>(context); ///providerによってFieldConfigurationを取得 

    return Scaffold(
      body: GridView.builder(
        itemCount: fieldConfiguration.rows * fieldConfiguration.columns,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(    ///行間などの設定
          crossAxisCount: fieldConfiguration.columns,
          crossAxisSpacing: 3.0,
          mainAxisSpacing: 3.0,
        ),
        itemBuilder: (context, int index) {
          final deviceId = index;
          return AspectRatio(   ///アスペクト比を指定するwidget
            aspectRatio: 1.0,
            child: MaterialButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  Routes.game,
                  arguments: GameArguments(deviceId),     ///routesファイルで指定した子viewに値を渡す方法
                );
              },
              child: Center(
                child: Text("$deviceId"),
              ),
            ),
          );
        },
      ),
    );
  }
}
