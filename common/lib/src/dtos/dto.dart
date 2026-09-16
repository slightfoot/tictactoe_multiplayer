part of '../dtos.dart';

sealed class DataTransferObject {
  const DataTransferObject();

  DtoType get type;

  factory DataTransferObject.fromJson(Map<String, Object?> json) {
    final type = DtoType.fromValue(json['type'] as String);
    return type.fromJson(json);
  }

  Map<String, Object?> toJson() {
    return {'type': type.toJson()};
  }
}
