import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'project_models.dart'; // Import the models we just created

class ProjectManager {
  static const String _projectsFolder = 'WebAppDesigner';
  static const String _projectsFile = 'projects.json';
  static const Uuid _uuid = Uuid();

  // Get base directory for projects
  static Future<String> get _baseDir async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory(
      path.join(documentsDir.path, _projectsFolder),
    );

    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }

    return projectsDir.path;
  }

  // Get projects list file
  static Future<File> get _projectsListFile async {
    final baseDir = await _baseDir;
    return File(path.join(baseDir, _projectsFile));
  }

  // Load all projects
  static Future<List<Project>> loadProjects() async {
    try {
      final file = await _projectsListFile;

      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);

      return jsonList.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Error loading projects: $e');
      return [];
    }
  }

  // Save projects list
  static Future<void> _saveProjectsList(List<Project> projects) async {
    try {
      final file = await _projectsListFile;
      final jsonString = json.encode(projects.map((p) => p.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving projects list: $e');
      rethrow;
    }
  }

  // Create new project
  static Future<Project> createProject({
    required String name,
    Size defaultPageSize = const Size(1920, 1080),
  }) async {
    final projectId = _uuid.v4();
    final baseDir = await _baseDir;
    final projectPath = path.join(baseDir, projectId);

    // Create project directory structure
    final projectDir = Directory(projectPath);
    await projectDir.create(recursive: true);

    final pagesDir = Directory(path.join(projectPath, 'pages'));
    await pagesDir.create();

    final assetsDir = Directory(path.join(projectPath, 'assets'));
    await assetsDir.create();

    final imagesDir = Directory(path.join(assetsDir.path, 'images'));
    await imagesDir.create();

    final now = DateTime.now();
    final project = Project(
      id: projectId,
      name: name,
      createdAt: now,
      updatedAt: now,
      pageIds: [],
      defaultPageSize: defaultPageSize,
      projectPath: projectPath,
    );

    // Save project metadata
    await _saveProjectMetadata(project);

    // Update projects list
    final projects = await loadProjects();
    projects.add(project);
    await _saveProjectsList(projects);

    return project;
  }

  // Save project metadata
  static Future<void> _saveProjectMetadata(Project project) async {
    final projectFile = File(path.join(project.projectPath, 'project.json'));
    await projectFile.writeAsString(json.encode(project.toJson()));
  }

  // Update project
  static Future<Project> updateProject(Project project) async {
    final updatedProject = project.copyWith(updatedAt: DateTime.now());
    await _saveProjectMetadata(updatedProject);

    // Update in projects list
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      projects[index] = updatedProject;
      await _saveProjectsList(projects);
    }

    return updatedProject;
  }

  // Delete project
  static Future<void> deleteProject(String projectId) async {
    final projects = await loadProjects();
    final project = projects.firstWhere((p) => p.id == projectId);

    // Delete project directory
    final projectDir = Directory(project.projectPath);
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }

    // Remove from projects list
    projects.removeWhere((p) => p.id == projectId);
    await _saveProjectsList(projects);
  }

  // Load project pages
  static Future<List<DesignPage>> loadProjectPages(String projectId) async {
    try {
      final projects = await loadProjects();
      final project = projects.firstWhere((p) => p.id == projectId);

      final pagesDir = Directory(path.join(project.projectPath, 'pages'));
      final pages = <DesignPage>[];

      for (final pageId in project.pageIds) {
        final pageFile = File(path.join(pagesDir.path, '$pageId.json'));
        if (await pageFile.exists()) {
          final jsonString = await pageFile.readAsString();
          final pageJson = json.decode(jsonString);
          pages.add(DesignPage.fromJson(pageJson));
        }
      }

      return pages;
    } catch (e) {
      print('Error loading project pages: $e');
      return [];
    }
  }

  // Create new page
  static Future<DesignPage> createPage({
    required String projectId,
    required String name,
    Size? pageSize,
  }) async {
    final pageId = _uuid.v4();
    final projects = await loadProjects();
    final project = projects.firstWhere((p) => p.id == projectId);

    final now = DateTime.now();
    final page = DesignPage(
      id: pageId,
      name: name,
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
      pageSize: pageSize ?? project.defaultPageSize,
      canvasItems: [],
    );

    // Save page
    await savePage(page);

    // Update project's page list
    final updatedProject = project.copyWith(
      pageIds: [...project.pageIds, pageId],
      updatedAt: now,
    );
    await updateProject(updatedProject);

    return page;
  }

  // Save page
  static Future<void> savePage(DesignPage page) async {
    try {
      final projects = await loadProjects();
      final project = projects.firstWhere((p) => p.id == page.projectId);

      final pageFile = File(
        path.join(project.projectPath, 'pages', '${page.id}.json'),
      );
      await pageFile.writeAsString(json.encode(page.toJson()));
    } catch (e) {
      print('Error saving page: $e');
      rethrow;
    }
  }

  // Delete page
  static Future<void> deletePage(String projectId, String pageId) async {
    final projects = await loadProjects();
    final project = projects.firstWhere((p) => p.id == projectId);

    // Delete page file
    final pageFile = File(
      path.join(project.projectPath, 'pages', '$pageId.json'),
    );
    if (await pageFile.exists()) {
      await pageFile.delete();
    }

    // Update project's page list
    final updatedPageIds = project.pageIds.where((id) => id != pageId).toList();
    final updatedProject = project.copyWith(
      pageIds: updatedPageIds,
      updatedAt: DateTime.now(),
    );
    await updateProject(updatedProject);
  }

  // Copy file to project assets
  static Future<String> copyAssetToProject(
    String projectId,
    String sourceFilePath,
  ) async {
    try {
      final projects = await loadProjects();
      final project = projects.firstWhere((p) => p.id == projectId);

      final sourceFile = File(sourceFilePath);
      final fileName = path.basename(sourceFilePath);
      final targetPath = path.join(
        project.projectPath,
        'assets',
        'images',
        fileName,
      );

      // Create unique filename if file already exists
      var finalTargetPath = targetPath;
      var counter = 1;
      while (await File(finalTargetPath).exists()) {
        final nameWithoutExt = path.basenameWithoutExtension(fileName);
        final extension = path.extension(fileName);
        finalTargetPath = path.join(
          project.projectPath,
          'assets',
          'images',
          '${nameWithoutExt}_$counter$extension',
        );
        counter++;
      }

      await sourceFile.copy(finalTargetPath);
      return finalTargetPath;
    } catch (e) {
      print('Error copying asset: $e');
      rethrow;
    }
  }

  // Get project assets
  static Future<List<FileSystemItem>> getProjectAssets(String projectId) async {
    try {
      final projects = await loadProjects();
      final project = projects.firstWhere((p) => p.id == projectId);

      final imagesDir = Directory(
        path.join(project.projectPath, 'assets', 'images'),
      );

      if (!await imagesDir.exists()) {
        return [];
      }

      final entities = await imagesDir.list().toList();
      return entities
          .where((entity) => entity is File)
          .map((entity) => FileSystemItem.fromFileSystemEntity(entity))
          .where((item) => item.isImageFile)
          .toList();
    } catch (e) {
      print('Error getting project assets: $e');
      return [];
    }
  }

  // Get file system drives (Windows)
  static Future<List<String>> getAvailableDrives() async {
    try {
      if (!Platform.isWindows) {
        return ['/'];
      }

      final drives = <String>[];
      for (int i = 65; i <= 90; i++) {
        final drive = '${String.fromCharCode(i)}:\\';
        final dir = Directory(drive);
        if (await dir.exists()) {
          drives.add(drive);
        }
      }
      return drives;
    } catch (e) {
      print('Error getting drives: $e');
      return [];
    }
  }

  // Browse file system
  static Future<List<FileSystemItem>> browseFileSystem(
    String directoryPath,
  ) async {
    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        return [];
      }

      final entities = await directory.list().toList();
      final items = entities
          .map((entity) => FileSystemItem.fromFileSystemEntity(entity))
          .toList();

      // Sort: directories first, then files, both alphabetically
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return items;
    } catch (e) {
      print('Error browsing file system: $e');
      return [];
    }
  }
}
