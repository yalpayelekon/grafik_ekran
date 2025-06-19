import 'dart:convert';
import 'package:universal_html/html.dart' as html;
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
}
