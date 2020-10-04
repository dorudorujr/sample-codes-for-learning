import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:whack_a_mole/config/field_configuration.dart';
import 'package:whack_a_mole/providers.dart';
import 'package:whack_a_mole/ui/routes.dart';
import 'package:whack_a_mole/ui/screens/mode_selection_screen.dart';

class App extends StatelessWidget {
  final FieldConfiguration fieldConfiguration;

  const App({Key key, this.fieldConfiguration}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ///結局childでdeviceIdServiceで生成したDeviceIdService()を下位Widgetに渡しているだけ
          Provider<FieldConfiguration>.value(value: fieldConfiguration),
          deviceIdService,
        ],
        child: MaterialApp(
          title: 'Flutter Demo',
          theme: ThemeData(
            // This is the theme of your application.
            //
            // Try running your application with "flutter run". You'll see the
            // application has a blue toolbar. Then, without quitting the app, try
            // changing the primarySwatch below to Colors.green and then invoke
            // "hot reload" (press "r" in the console where you ran "flutter run",
            // or simply save your changes to "hot reload" in a Flutter IDE).
            // Notice that the counter didn't reset back to zero; the application
            // is not restarted.
            primarySwatch: Colors.blue,
          ),
          home: ModeSelectionScreen(),
          routes: Routes.get(),
        ),
      );
}
