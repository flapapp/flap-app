// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Badge _$BadgeFromJson(Map<String, dynamic> json) => Badge(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toInt(),
      category: json['category'] as String,
      isAvailable: json['isAvailable'] as bool? ?? true,
      releaseDate: json['releaseDate'] == null
          ? null
          : DateTime.parse(json['releaseDate'] as String),
    );

Map<String, dynamic> _$BadgeToJson(Badge instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'emoji': instance.emoji,
      'description': instance.description,
      'price': instance.price,
      'category': instance.category,
      'isAvailable': instance.isAvailable,
      'releaseDate': instance.releaseDate?.toIso8601String(),
    };
