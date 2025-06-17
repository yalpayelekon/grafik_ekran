import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'web_runtime_models.dart';

class WebRuntimeService {
  static const String _storagePrefix = 'webAppDesigner_';

  // Cache for loaded data
  static final Map<String, Project> _projectCache = {};
  static final Map<String, DesignPage> _pageCache = {};
  static final Map<String, String> _assetCache = {};

  // Load project data from multiple sources
  static Future<Project?> loadProject(String projectId) async {
    // Check cache first
    if (_projectCache.containsKey(projectId)) {
      return _projectCache[projectId];
    }

    try {
      // Try to load from localStorage (if data was uploaded)
      final projectData =
          html.window.localStorage['${_storagePrefix}project_$projectId'];
      if (projectData != null) {
        final project = Project.fromJson(json.decode(projectData));
        _projectCache[projectId] = project;
        return project;
      }

      // Try to load from assets (if bundled with web app)
      try {
        final assetData = await rootBundle.loadString(
          'assets/projects/$projectId/project.json',
        );
        final project = Project.fromJson(json.decode(assetData));
        _projectCache[projectId] = project;
        return project;
      } catch (e) {
        print('Could not load project from assets: $e');
      }

      return null;
    } catch (e) {
      print('Error loading project $projectId: $e');
      return null;
    }
  }

  // Load page data
  static Future<DesignPage?> loadPage(String projectId, String pageId) async {
    final cacheKey = '${projectId}_$pageId';

    // Check cache first
    if (_pageCache.containsKey(cacheKey)) {
      return _pageCache[cacheKey];
    }

    try {
      // Try localStorage first
      final pageData = html
          .window
          .localStorage['${_storagePrefix}page_${projectId}_$pageId'];
      if (pageData != null) {
        final page = DesignPage.fromJson(json.decode(pageData));
        _pageCache[cacheKey] = page;
        return page;
      }

      // Try assets
      try {
        final assetData = await rootBundle.loadString(
          'assets/projects/$projectId/pages/$pageId.json',
        );
        final page = DesignPage.fromJson(json.decode(assetData));
        _pageCache[cacheKey] = page;
        return page;
      } catch (e) {
        print('Could not load page from assets: $e');
      }

      return null;
    } catch (e) {
      print('Error loading page $pageId: $e');
      return null;
    }
  }

  // Load asset (image) data
  static Future<String?> loadAsset(String projectId, String assetPath) async {
    final cacheKey = '${projectId}_$assetPath';

    // Check cache first
    if (_assetCache.containsKey(cacheKey)) {
      return _assetCache[cacheKey];
    }

    try {
      // For web, we'll use base64 encoded images stored in localStorage
      final assetData =
          html.window.localStorage['${_storagePrefix}asset_$cacheKey'];
      if (assetData != null) {
        _assetCache[cacheKey] = assetData;
        return assetData;
      }

      // Try to load from assets folder if bundled
      try {
        final fileName = assetPath.split('/').last;
        final assetUrl = 'assets/projects/$projectId/assets/images/$fileName';
        _assetCache[cacheKey] = assetUrl;
        return assetUrl;
      } catch (e) {
        print('Could not load asset from assets: $e');
      }

      return null;
    } catch (e) {
      print('Error loading asset $assetPath: $e');
      return null;
    }
  }

  // Get list of available projects
  static List<String> getAvailableProjects() {
    final projects = <String>[];

    // Check localStorage for uploaded projects
    for (final key in html.window.localStorage.keys) {
      if (key.startsWith('${_storagePrefix}project_')) {
        final projectId = key.substring('${_storagePrefix}project_'.length);
        projects.add(projectId);
      }
    }

    return projects;
  }

  // Upload project data from desktop app (for testing/demo)
  static Future<void> uploadProjectData(
    Map<String, dynamic> projectData,
  ) async {
    try {
      final projectJson = projectData['project'] as Map<String, dynamic>;
      final pagesData = projectData['pages'] as Map<String, dynamic>;
      final assetsData = projectData['assets'] as Map<String, dynamic>?;

      final project = Project.fromJson(projectJson);

      // Store project
      html.window.localStorage['${_storagePrefix}project_${project.id}'] = json
          .encode(project.toJson());

      // Store pages
      for (final entry in pagesData.entries) {
        final pageId = entry.key;
        final pageJson = entry.value as Map<String, dynamic>;
        html
            .window
            .localStorage['${_storagePrefix}page_${project.id}_$pageId'] = json
            .encode(pageJson);
      }

      // Store assets (base64 encoded)
      if (assetsData != null) {
        for (final entry in assetsData.entries) {
          final assetPath = entry.key;
          final assetData = entry.value as String;
          html
                  .window
                  .localStorage['${_storagePrefix}asset_${project.id}_$assetPath'] =
              assetData;
        }
      }

      // Clear caches to force reload
      _projectCache.clear();
      _pageCache.clear();
      _assetCache.clear();
    } catch (e) {
      print('Error uploading project data: $e');
      rethrow;
    }
  }

  // Clear all data (for testing)
  static void clearAllData() {
    final keysToRemove = <String>[];
    for (final key in html.window.localStorage.keys) {
      if (key.startsWith(_storagePrefix)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      html.window.localStorage.remove(key);
    }

    _projectCache.clear();
    _pageCache.clear();
    _assetCache.clear();
  }

  // Create demo project data for testing
  static Future<void> createDemoProject() async {
    final demoProject = Project(
      id: 'demo-project-1',
      name: 'Demo Website',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pageIds: ['home-page', 'about-page'],
      defaultPageSize: const Size(1920, 1080),
      projectPath: '/demo',
    );

    final homePage = DesignPage(
      id: 'home-page',
      name: 'Home Page',
      projectId: 'demo-project-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pageSize: const Size(1920, 1080),
      backgroundColor: const Color(0xFFF5F5F5),
      canvasItems: [
        // Header container
        LayeredCanvasItem(
          id: 'header-container',
          type: WidgetType.container,
          position: const Offset(0, 0),
          size: const Size(1920, 80),
          zIndex: 0,
          properties: {
            'backgroundColor': const Color(0xFF2196F3),
            'text': '',
            'textColor': Colors.white,
          },
        ),
        // Logo/Title
        LayeredCanvasItem(
          id: 'logo-text',
          type: WidgetType.text,
          position: const Offset(50, 20),
          size: const Size(300, 40),
          zIndex: 1,
          properties: {
            'text': 'My Website',
            'fontSize': 24.0,
            'isBold': true,
            'color': Colors.white,
          },
        ),
        // Navigation button to About
        LayeredCanvasItem(
          id: 'nav-about-btn',
          type: WidgetType.button,
          position: const Offset(1720, 20),
          size: const Size(150, 40),
          zIndex: 1,
          linkedPageId: 'about-page',
          properties: {
            'text': 'About Us',
            'backgroundColor': Colors.white,
            'textColor': const Color(0xFF2196F3),
          },
        ),
        // Main content
        LayeredCanvasItem(
          id: 'main-title',
          type: WidgetType.text,
          position: const Offset(100, 200),
          size: const Size(1720, 100),
          zIndex: 0,
          properties: {
            'text': 'Welcome to Our Website!',
            'fontSize': 48.0,
            'isBold': true,
            'color': const Color(0xFF333333),
          },
        ),
        LayeredCanvasItem(
          id: 'main-description',
          type: WidgetType.text,
          position: const Offset(100, 320),
          size: const Size(1720, 60),
          zIndex: 0,
          properties: {
            'text':
                'This is a demo website created with our Flutter Web App Designer.',
            'fontSize': 18.0,
            'color': const Color(0xFF666666),
          },
        ),
        // CTA Button
        LayeredCanvasItem(
          id: 'cta-button',
          type: WidgetType.button,
          position: const Offset(100, 420),
          size: const Size(200, 50),
          zIndex: 0,
          linkedPageId: 'about-page',
          properties: {
            'text': 'Learn More',
            'backgroundColor': const Color(0xFF4CAF50),
            'textColor': Colors.white,
          },
        ),
      ],
    );

    final aboutPage = DesignPage(
      id: 'about-page',
      name: 'About Page',
      projectId: 'demo-project-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pageSize: const Size(1920, 1080),
      backgroundColor: const Color(0xFFF5F5F5),
      canvasItems: [
        // Header container
        LayeredCanvasItem(
          id: 'header-container-about',
          type: WidgetType.container,
          position: const Offset(0, 0),
          size: const Size(1920, 80),
          zIndex: 0,
          properties: {
            'backgroundColor': const Color(0xFF2196F3),
            'text': '',
            'textColor': Colors.white,
          },
        ),
        // Logo/Title
        LayeredCanvasItem(
          id: 'logo-text-about',
          type: WidgetType.text,
          position: const Offset(50, 20),
          size: const Size(300, 40),
          zIndex: 1,
          properties: {
            'text': 'My Website',
            'fontSize': 24.0,
            'isBold': true,
            'color': Colors.white,
          },
        ),
        // Back to Home button
        LayeredCanvasItem(
          id: 'nav-home-btn',
          type: WidgetType.button,
          position: const Offset(1720, 20),
          size: const Size(150, 40),
          zIndex: 1,
          linkedPageId: 'home-page',
          properties: {
            'text': 'Home',
            'backgroundColor': Colors.white,
            'textColor': const Color(0xFF2196F3),
          },
        ),
        // About content
        LayeredCanvasItem(
          id: 'about-title',
          type: WidgetType.text,
          position: const Offset(100, 200),
          size: const Size(1720, 100),
          zIndex: 0,
          properties: {
            'text': 'About Our Company',
            'fontSize': 48.0,
            'isBold': true,
            'color': const Color(0xFF333333),
          },
        ),
        LayeredCanvasItem(
          id: 'about-description',
          type: WidgetType.text,
          position: const Offset(100, 320),
          size: const Size(1720, 200),
          zIndex: 0,
          properties: {
            'text':
                'We are a innovative company that creates amazing web applications using Flutter. Our drag-and-drop designer allows anyone to create beautiful, functional websites without coding knowledge.',
            'fontSize': 18.0,
            'color': const Color(0xFF666666),
          },
        ),
        // Info card
        LayeredCanvasItem(
          id: 'info-card',
          type: WidgetType.card,
          position: const Offset(100, 550),
          size: const Size(400, 200),
          zIndex: 0,
          properties: {
            'text':
                'Founded in 2024\nServing customers worldwide\nBuilt with Flutter',
            'backgroundColor': Colors.white,
            'textColor': const Color(0xFF333333),
            'elevation': 4.0,
          },
        ),
      ],
    );

    // Upload the demo data
    await uploadProjectData({
      'project': demoProject.toJson(),
      'pages': {
        'home-page': homePage.toJson(),
        'about-page': aboutPage.toJson(),
      },
      'assets': <String, String>{}, // No assets in demo
    });
  }
}
