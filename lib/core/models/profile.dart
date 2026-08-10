import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Profile {
  final String id;
  final String name;
  final int colorValue;
  final String? iconName;
  final int sortOrder;
  // Position of the synthetic "General" (ungrouped) section among this
  // profile's groups on the Home screen. -1 sorts before any real group's
  // default sortOrder of 0, so existing profiles keep General first until
  // the user actually drags it elsewhere.
  final int generalSortOrder;
  final DateTime createdAt;

  Profile({
    String? id,
    required this.name,
    required this.colorValue,
    this.iconName,
    this.sortOrder = 0,
    this.generalSortOrder = -1,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);

  Profile copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    int? sortOrder,
    int? generalSortOrder,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      generalSortOrder: generalSortOrder ?? this.generalSortOrder,
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
      'generalSortOrder': generalSortOrder,
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
      generalSortOrder: map['generalSortOrder'] as int? ?? -1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class TokenGroup {
  final String id;
  final String profileId;
  final String name;
  final int sortOrder;
  // User-picked emoji for this group's icon; null falls back to the
  // default folder icon wherever the group is rendered.
  final String? iconName;

  TokenGroup({
    String? id,
    required this.profileId,
    required this.name,
    this.sortOrder = 0,
    this.iconName,
  }) : id = id ?? const Uuid().v4();

  TokenGroup copyWith({String? name, int? sortOrder, String? iconName}) {
    return TokenGroup(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'sortOrder': sortOrder,
      'iconName': iconName,
    };
  }

  factory TokenGroup.fromMap(Map<String, dynamic> map) {
    return TokenGroup(
      id: map['id'] as String,
      profileId: map['profileId'] as String,
      name: map['name'] as String,
      sortOrder: map['sortOrder'] as int,
      iconName: map['iconName'] as String?,
    );
  }
}
