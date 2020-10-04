import 'package:flutter/foundation.dart';
import 'package:whack_a_mole/config/field_configuration.dart';

class DeviceIdService {
  final FieldConfiguration fieldConfiguration;

  DeviceIdService({@required this.fieldConfiguration});

  /// total devices
  /// もぐらたたきに使用するデバイス総数
  int get deviceCount => fieldConfiguration.columns * fieldConfiguration.rows;

  /// list of all device ids for the current fieldConfiguration
  /// List.generate: リスト作成
  /// [0,1,2,....11]
  List<int> get deviceIds => List.generate(deviceCount, (index) => index);

  /// resolve device Id from column & row
  /// @param [columnIndex] 0 based index of column
  /// @param [rowIndex] 0 based index of row
  /// @returns a device id between 0 and ([rows] * [columns] - 1)
  /// 列と行からデバイスのIDを返す
  int resolveDeviceId(int columnIndex, int rowIndex) {
    if (columnIndex >= fieldConfiguration.columns ||
        columnIndex < 0 ||
        rowIndex >= fieldConfiguration.rows ||
        rowIndex < 0) {
      throw RangeError(
        'out of range: rows: $fieldConfiguration.rows | '
        'columns: $fieldConfiguration.columns',
      );
    }

    return rowIndex * fieldConfiguration.columns + columnIndex;
  }
}
