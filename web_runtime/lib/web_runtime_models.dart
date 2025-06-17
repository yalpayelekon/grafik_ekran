import 'dart:convert';
import 'package:flutter/material.dart';

// Shared models for the web runtime (identical to desktop app models)
// These need to be exactly the same as the desktop app models for compatibility

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
}

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
}

class LayeredCanvasItem {
  final String id;
  final WidgetType type;
  final Offset position;
  final Size size;
  final Map<String, dynamic> properties;
  final int zIndex;
  final double opacity;
  final String? linkedPageId;

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
}

enum WidgetType { text, button, image, container, card, input }

// Navigation state management
class NavigationState {
  final String? currentProjectId;
  final String? currentPageId;
  final List<String> navigationHistory;

  NavigationState({
    this.currentProjectId,
    this.currentPageId,
    this.navigationHistory = const [],
  });

  NavigationState copyWith({
    String? currentProjectId,
    String? currentPageId,
    List<String>? navigationHistory,
  }) {
    return NavigationState(
      currentProjectId: currentProjectId ?? this.currentProjectId,
      currentPageId: currentPageId ?? this.currentPageId,
      navigationHistory: navigationHistory ?? this.navigationHistory,
    );
  }

  NavigationState navigateToPage(String pageId) {
    final newHistory = List<String>.from(navigationHistory);
    if (currentPageId != null) {
      newHistory.add(currentPageId!);
    }

    return NavigationState(
      currentProjectId: currentProjectId,
      currentPageId: pageId,
      navigationHistory: newHistory,
    );
  }

  NavigationState goBack() {
    if (navigationHistory.isNotEmpty) {
      final newHistory = List<String>.from(navigationHistory);
      final previousPageId = newHistory.removeLast();

      return NavigationState(
        currentProjectId: currentProjectId,
        currentPageId: previousPageId,
        navigationHistory: newHistory,
      );
    }
    return this;
  }

  bool get canGoBack => navigationHistory.isNotEmpty;
}
