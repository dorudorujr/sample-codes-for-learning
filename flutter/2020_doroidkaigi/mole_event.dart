class MoleEvent {
  int type;
  int timeInMilliseconds;   ///絶対時間
  Duration duration;    ///Duration: 指定期間? , /// 出現時間

  MoleEvent({this.type, this.timeInMilliseconds, this.duration});

  int get endTimeInMilliseconds => timeInMilliseconds + duration.inMilliseconds;

  /// 出現時間が被るかどうか？
  bool overlaps(MoleEvent evt) {
    int lower = evt.timeInMilliseconds > timeInMilliseconds
        ? evt.timeInMilliseconds
        : timeInMilliseconds;           /// lower: 大きい方の値を使う
    int upper = evt.endTimeInMilliseconds < endTimeInMilliseconds
        ? evt.endTimeInMilliseconds
        : endTimeInMilliseconds;        /// upper: 小さい方の値を使う
    return upper > lower;
  }
}
