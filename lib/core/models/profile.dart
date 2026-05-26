import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Profile {
  final String id;
  final String name;
  final int colorValue;
  final String? iconName;
  final int sortOrder;
  final DateTime createdAt;

  Profile({
    String? id,
    required this.name,
    required this.colorValue,
    this.iconName,
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  Profile copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    int? sortOrder,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconName': iconName,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['colorValue'] as int,
      iconName: map['iconName'] as String?,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class TokenGroup {
  final String id;
  final String profileId;
  final String name;
  final int sortOrder;

  TokenGroup({
    String? id,
    required this.profileId,
    required this.name,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  TokenGroup copyWith({String? name, int? sortOrder}) {
    return TokenGroup(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'sortOrder': sortOrder,
    };
  }

  factory TokenGroup.fromMap(Map<String, dynamic> map) {
    return TokenGroup(
      id: map['id'] as String,
      profileId: map['profileId'] as String,
      name: map['name'] as String,
      sortOrder: map['sortOrder'] as int,
    );
  }
}
