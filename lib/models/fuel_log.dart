import 'fuel_type.dart';

/// "기름 먹은 날" 기록. 특정 운행 기록(drives)과는 연결되지 않는 독립적인 주유/충전 기록이다.
class FuelLog {
  final int? id;
  final String date; // yyyy-MM-dd
  final FuelType fuelType;
  final double? amount;
  final double cost;
  final String? memo;
  final DateTime createdAt;

  FuelLog({
    this.id,
    required this.date,
    required this.fuelType,
    this.amount,
    required this.cost,
    this.memo,
    required this.createdAt,
  });

  factory FuelLog.create({
    required String date,
    required FuelType fuelType,
    double? amount,
    required double cost,
    String? memo,
  }) {
    return FuelLog(
      date: date,
      fuelType: fuelType,
      amount: amount,
      cost: cost,
      memo: memo,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'fuel_type': fuelType.dbValue,
      'amount': amount,
      'cost': cost,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'] as int?,
      date: map['date'] as String,
      fuelType: FuelType.fromDbValue(map['fuel_type'] as String),
      amount: map['amount'] as double?,
      cost: map['cost'] as double,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
