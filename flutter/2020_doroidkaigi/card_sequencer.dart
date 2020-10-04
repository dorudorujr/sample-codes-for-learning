import 'dart:math';

//
// カードを「このカード何枚、あのカード何枚」という形式で受け取って
// それを１枚ずつ繰り出していくクラス。
//
class CardSequencer<T> {
  List<T> flattenedSequence;

  CardSequencer.randomFromMap(Map<T, int> countMap) {
    List<T> unshuffled = [];
    flattenedSequence = [];

    // Flatten the Map to List first
    for (T key in countMap.keys) {    ///keyを取得({0: x, 1: y})
      final arrayToAdd = List.filled(countMap[key], key);   /// List.filled(数,値): List.filled(2, 0) = [0,0]
      unshuffled.addAll(arrayToAdd);
    }

    final rng = Random();
    while (unshuffled.length > 0) {     ///lengthが0以下になるまで続ける
      final int num = rng.nextInt(unshuffled.length);   ///0~lengthまでの値を生成
      final card = unshuffled.removeAt(num);    ///listから値を削除し、削除した値を返す
      flattenedSequence.add(card);
    }
  }

  CardSequencer.rawSequence(this.flattenedSequence);

  bool hasNext() {
    return flattenedSequence.length > 0;
  }

  T next() {
    assert(flattenedSequence.length > 0);   ///デバック時のみ実行される
    return flattenedSequence.removeAt(0);
  }

  int length() {
    return flattenedSequence.length;
  }
}
