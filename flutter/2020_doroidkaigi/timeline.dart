import 'package:whack_a_mole/domain/models/mole_event.dart';

/// MoleEventのListを管理
class Timeline {
  List<MoleEvent> events = [];

  bool canAdd(MoleEvent newEvent) {
    for (var anEvent in events) {
      if (anEvent.overlaps(newEvent)) {
        //既存のイベントとオーバーラップする場合追加不可
        return false;
      }
    }
    return true;
  }

  void addEvent(MoleEvent newEvent) {
    events.add(newEvent);
  }
}
