import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

// Project Model
class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> pageIds;
  final Size defaultPageSize;
  final String projectPath;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.pageIds,
    required this.defaultPageSize,
    required this.projectPath,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      pageIds: List<String>.from(json['pageIds'] ?? []),
      defaultPageSize: Size(
        json['defaultPageSize']['width'].toDouble(),
        json['defaultPageSize']['height'].toDouble(),
      ),
      projectPath: json['projectPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pageIds': pageIds,
      'defaultPageSize': {
        'width': defaultPageSize.width,
        'height': defaultPageSize.height,
      },
      'projectPath': projectPath,
    };
  }

  Project copyWith({
    String? name,
    DateTime? updatedAt,
    List<String>? pageIds,
    Size? defaultPageSize,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pageIds: pageIds ?? this.pageIds,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      projectPath: projectPath,
    );
  }
}

// Page Model with Layer Support
class DesignPage {
  final String id;
  final String name;
  final String projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Size pageSize;
  final List<LayeredCanvasItem> canvasItems;
  final Color backgroundColor;

  DesignPage({
    required this.id,
    required this.name,
    required this.projectId,
    required this.createdAt,
    required this.updatedAt,
    required this.pageSize,
    required this.canvasItems,
    this.backgroundColor = Colors.white,
  });

  factory DesignPage.fromJson(Map<String, dynamic> json) {
    return DesignPage(
      id: json['id'],
      name: json['name'],
      projectId: json['projectId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      pageSize: Size(
        json['pageSize']['width'].toDouble(),
        json['pageSize']['height'].toDouble(),
      ),
      canvasItems: (json['canvasItems'] as List)
          .map((item) => LayeredCanvasItem.fromJson(item))
          .toList(),
      backgroundColor: Color(json['backgroundColor'] ?? Colors.white.value),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectId': projectId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pageSize': {'width': pageSize.width, 'height': pageSize.height},
      'canvasItems': canvasItems.map((item) => item.toJson()).toList(),
      'backgroundColor': backgroundColor.value,
    };
  }

  DesignPage copyWith({
    String? name,
    DateTime? updatedAt,
    Size? pageSize,
    List<LayeredCanvasItem>? canvasItems,
    Color? backgroundColor,
  }) {
    return DesignPage(
      id: id,
      name: name ?? this.name,
      projectId: projectId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pageSize: pageSize ?? this.pageSize,
      canvasItems: canvasItems ?? this.canvasItems,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

// Enhanced Canvas Item with Layer Support
class LayeredCanvasItem {
  final String id;
  final WidgetType type;
  Offset position;
  Size size;
  Map<String, dynamic> properties;
  int zIndex; // Layer depth
  double opacity;
  String? linkedPageId; // For navigation

  LayeredCanvasItem({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    Map<String, dynamic>? properties,
    this.zIndex = 0,
    this.opacity = 1.0,
    this.linkedPageId,
  }) : properties = properties ?? {};

  factory LayeredCanvasItem.fromJson(Map<String, dynamic> json) {
    return LayeredCanvasItem(
      id: json['id'],
      type: WidgetType.values.firstWhere((e) => e.toString() == json['type']),
      position: Offset(
        json['position']['dx'].toDouble(),
        json['position']['dy'].toDouble(),
      ),
      size: Size(
        json['size']['width'].toDouble(),
        json['size']['height'].toDouble(),
      ),
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      zIndex: json['zIndex'] ?? 0,
      opacity: json['opacity']?.toDouble() ?? 1.0,
      linkedPageId: json['linkedPageId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'properties': properties,
      'zIndex': zIndex,
      'opacity': opacity,
      'linkedPageId': linkedPageId,
    };
  }

  LayeredCanvasItem copyWith({
    Offset? position,
    Size? size,
    Map<String, dynamic>? properties,
    int? zIndex,
    double? opacity,
    String? linkedPageId,
  }) {
    return LayeredCanvasItem(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      properties: properties ?? this.properties,
      zIndex: zIndex ?? this.zIndex,
      opacity: opacity ?? this.opacity,
      linkedPageId: linkedPageId ?? this.linkedPageId,
    );
  }
}

// Widget Types
enum WidgetType { text, button, image, container, card, input }

// File System Item for File Explorer
class FileSystemItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedDate;
  final String? extension;

  FileSystemItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedDate,
    this.extension,
  });

  factory FileSystemItem.fromFileSystemEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    final isDir = entity is Directory;

    return FileSystemItem(
      name: p.basename(entity.path),
      path: entity.path,
      isDirectory: isDir,
      size: isDir ? null : stat.size,
      modifiedDate: stat.modified,
      extension: isDir ? null : p.extension(entity.path).toLowerCase(),
    );
  }

  bool get isImageFile {
    if (extension == null) return false;
    return [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension!.toLowerCase());
  }
}
