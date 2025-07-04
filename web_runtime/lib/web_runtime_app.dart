import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;

void main() {
  runApp(const WebRuntimeApp());
}

class WebRuntimeApp extends StatelessWidget {
  const WebRuntimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web App Runtime',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WebRuntimeHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebRuntimeHome extends StatefulWidget {
  const WebRuntimeHome({super.key});

  @override
  WebRuntimeHomeState createState() => WebRuntimeHomeState();
}

class WebRuntimeHomeState extends State<WebRuntimeHome> {
  NavigationState navigationState = NavigationState();
  Project? currentProject;
  DesignPage? currentPage;
  bool isLoading = false;
  String? errorMessage;
  List<String> availableProjects = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => isLoading = true);

    try {
      // Get available projects
      availableProjects = WebRuntimeService.getAvailableProjects();

      if (availableProjects.isEmpty) {
        return;
      }

      await _loadProject(availableProjects.first);
    } catch (e) {
      setState(() => errorMessage = 'Failed to initialize app: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadProject(String projectId) async {
    setState(() => isLoading = true);

    try {
      final project = await WebRuntimeService.loadProject(projectId);
      if (project != null) {
        final projects = WebRuntimeService.getAvailableProjects();
        setState(() {
          availableProjects = projects;
          currentProject = project;
          navigationState = NavigationState(currentProjectId: projectId);
        });

        // Load first page
        if (project.pageIds.isNotEmpty) {
          await _navigateToPage(project.pageIds.first);
        }
      } else {
        setState(() => errorMessage = 'Project not found: $projectId');
      }
    } catch (e) {
      setState(() => errorMessage = 'Failed to load project: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _navigateToPage(String pageId) async {
    if (currentProject == null) return;

    setState(() => isLoading = true);

    try {
      final page = await WebRuntimeService.loadPage(currentProject!.id, pageId);
      if (page != null) {
        setState(() {
          currentPage = page;
          navigationState = navigationState.navigateToPage(pageId);
          errorMessage = null;
        });
      } else {
        setState(() => errorMessage = 'Page not found: $pageId');
      }
    } catch (e) {
      setState(() => errorMessage = 'Failed to load page: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _goBack() {
    if (navigationState.canGoBack) {
      final newState = navigationState.goBack();
      if (newState.currentPageId != null) {
        setState(() => navigationState = newState);
        _navigateToPage(newState.currentPageId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 60,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Project selector
          if (availableProjects.isNotEmpty) ...[
            const Text('Project: '),
            DropdownButton<String>(
              value: currentProject?.id,
              hint: const Text('Select Project'),
              items: availableProjects.map((projectId) {
                return DropdownMenuItem(
                  value: projectId,
                  child: Text(projectId),
                );
              }).toList(),
              onChanged: (projectId) {
                if (projectId != null) {
                  _loadProject(projectId);
                }
              },
            ),
            const SizedBox(width: 20),
          ],

          // Page info
          if (currentPage != null) ...[
            Text('Page: ${currentPage!.name}'),
            const SizedBox(width: 20),
          ],

          const Spacer(),

          // Navigation controls
          IconButton(
            onPressed: navigationState.canGoBack ? _goBack : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Go Back',
          ),

          IconButton(
            onPressed: () => _showDevTools(),
            icon: const Icon(Icons.developer_mode),
            tooltip: 'Developer Tools',
          ),

          // Reload button
          IconButton(
            onPressed: () => _initializeApp(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => errorMessage = null);
                _initializeApp();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (currentPage == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No page loaded'),
            SizedBox(height: 8),
            Text(
              'Select a project and page to view',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return PageRenderer(page: currentPage!, onNavigate: _navigateToPage);
  }

  void _showDevTools() {
    showDialog(
      context: context,
      builder: (context) => DevToolsDialog(
        currentProject: currentProject,
        currentPage: currentPage,
        onNavigate: _navigateToPage,
        onProjectChanged: _loadProject,
      ),
    );
  }
}

class PageRenderer extends StatefulWidget {
  final DesignPage page;
  final Function(String) onNavigate;

  const PageRenderer({super.key, required this.page, required this.onNavigate});

  @override
  PageRendererState createState() => PageRendererState();
}

class PageRendererState extends State<PageRenderer> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          width: widget.page.pageSize.width,
          height: widget.page.pageSize.height,
          color: widget.page.backgroundColor,
          child: Stack(
            children:
                (widget.page.canvasItems
                        .where((item) => item.opacity > 0)
                        .toList()
                      ..sort((a, b) => a.zIndex.compareTo(b.zIndex)))
                    .map((item) => _buildCanvasItem(item))
                    .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasItem(LayeredCanvasItem item) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: Opacity(
        opacity: item.opacity,
        child: SizedBox(
          width: item.size.width,
          height: item.size.height,
          child: _buildWidget(item),
        ),
      ),
    );
  }

  Widget _buildWidget(LayeredCanvasItem item) {
    final properties = item.properties;

    switch (item.type) {
      case WidgetType.text:
        return Container(
          width: item.size.width,
          height: item.size.height,
          alignment: Alignment.center,
          child: Text(
            properties['text'] as String? ?? 'Sample Text',
            style: TextStyle(
              fontSize: properties['fontSize'] as double? ?? 16.0,
              fontWeight: properties['isBold'] as bool? ?? false
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontStyle: properties['isItalic'] as bool? ?? false
                  ? FontStyle.italic
                  : FontStyle.normal,
              color: _parseColor(properties['color']) ?? Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        );

      case WidgetType.button:
        return SizedBox(
          width: item.size.width,
          height: item.size.height,
          child: ElevatedButton(
            onPressed: () {
              if (item.linkedPageId != null) {
                widget.onNavigate(item.linkedPageId!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _parseColor(properties['backgroundColor']) ?? Colors.blue,
              foregroundColor:
                  _parseColor(properties['textColor']) ?? Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              properties['text'] as String? ?? 'Button',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );

      case WidgetType.image:
        return _buildImageWidget(item);

      case WidgetType.card:
        return Card(
          elevation: properties['elevation'] as double? ?? 2.0,
          color: _parseColor(properties['backgroundColor']) ?? Colors.white,
          child: Container(
            width: item.size.width,
            height: item.size.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              properties['text'] as String? ?? 'Card Widget',
              style: TextStyle(
                color: _parseColor(properties['textColor']) ?? Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Widget _buildImageWidget(LayeredCanvasItem item) {
    final imagePath = item.properties['imagePath'] as String?;

    if (imagePath == null) {
      return Container(
        width: item.size.width,
        height: item.size.height,
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 32, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No Image',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // For web runtime, we need to handle image loading differently
    return FutureBuilder<String?>(
      future: WebRuntimeService.loadAsset(widget.page.projectId, imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: item.size.width,
            height: item.size.height,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            width: item.size.width,
            height: item.size.height,
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Image Error',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final assetUrl = snapshot.data!;

        // Check if it's a base64 encoded image or URL
        if (assetUrl.startsWith('data:image')) {
          // Base64 encoded image
          return Image.network(
            assetUrl,
            width: item.size.width,
            height: item.size.height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: item.size.width,
              height: item.size.height,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image),
            ),
          );
        } else {
          // Asset URL
          return Image.asset(
            assetUrl,
            width: item.size.width,
            height: item.size.height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: item.size.width,
              height: item.size.height,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image),
            ),
          );
        }
      },
    );
  }

  Color? _parseColor(dynamic colorValue) {
    if (colorValue == null) return null;
    if (colorValue is Color) return colorValue;
    if (colorValue is int) return Color(colorValue);
    return null;
  }
}

class DevToolsDialog extends StatefulWidget {
  final Project? currentProject;
  final DesignPage? currentPage;
  final Function(String) onNavigate;
  final Function(String) onProjectChanged;

  const DevToolsDialog({
    super.key,
    required this.currentProject,
    required this.currentPage,
    required this.onNavigate,
    required this.onProjectChanged,
  });

  @override
  DevToolsDialogState createState() => DevToolsDialogState();
}

class DevToolsDialogState extends State<DevToolsDialog> {
  String selectedTab = 'project';
  List<DesignPage> projectPages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentProject != null) {
      _loadProjectPages();
    }
  }

  Future<void> _loadProjectPages() async {
    if (widget.currentProject == null) return;

    setState(() => isLoading = true);

    try {
      final pages = <DesignPage>[];
      for (final pageId in widget.currentProject!.pageIds) {
        final page = await WebRuntimeService.loadPage(
          widget.currentProject!.id,
          pageId,
        );
        if (page != null) {
          pages.add(page);
        }
      }
      setState(() => projectPages = pages);
    } catch (e) {
      print('Error loading project pages: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        child: Column(
          children: [
            AppBar(
              title: const Text('Developer Tools'),
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          _buildTab('project', 'Project Info'),
          _buildTab('pages', 'Pages'),
          _buildTab('upload', 'Upload Data'),
          _buildTab('debug', 'Debug'),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String label) {
    final isSelected = selectedTab == tabId;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = tabId),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[600] : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 'project':
        return _buildProjectInfo();
      case 'pages':
        return _buildPagesInfo();
      case 'upload':
        return _buildUploadInterface();
      case 'debug':
        return _buildDebugInfo();
      default:
        return Container();
    }
  }

  Widget _buildProjectInfo() {
    if (widget.currentProject == null) {
      return const Center(child: Text('No project loaded'));
    }

    final project = widget.currentProject!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Project ID', project.id),
          _buildInfoRow('Name', project.name),
          _buildInfoRow('Created', project.createdAt.toString()),
          _buildInfoRow('Updated', project.updatedAt.toString()),
          _buildInfoRow('Page Count', project.pageIds.length.toString()),
          _buildInfoRow(
            'Default Size',
            '${project.defaultPageSize.width.toInt()} × ${project.defaultPageSize.height.toInt()}',
          ),
          const SizedBox(height: 20),
          const Text(
            'Page IDs:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...project.pageIds.map(
            (pageId) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  Text('• $pageId'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNavigate(pageId);
                    },
                    child: const Text('Navigate'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesInfo() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (projectPages.isEmpty) {
      return const Center(child: Text('No pages found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projectPages.length,
      itemBuilder: (context, index) {
        final page = projectPages[index];
        final isCurrentPage = widget.currentPage?.id == page.id;

        return Card(
          color: isCurrentPage ? Colors.blue[50] : null,
          child: ListTile(
            title: Text(
              page.name,
              style: TextStyle(
                fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${page.id}'),
                Text(
                  'Size: ${page.pageSize.width.toInt()} × ${page.pageSize.height.toInt()}',
                ),
                Text('Items: ${page.canvasItems.length}'),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: isCurrentPage
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onNavigate(page.id);
                    },
              child: Text(isCurrentPage ? 'Current' : 'Navigate'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadInterface() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Project Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload JSON data exported from the desktop designer app:',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadProjectData,
            icon: const Icon(Icons.upload_file),
            label: const Text('Select JSON File'),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'Demo Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _clearAllData,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Clear All Data'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Available Projects',
            WebRuntimeService.getAvailableProjects().length.toString(),
          ),
          _buildInfoRow('Current URL', html.window.location.href),
          _buildInfoRow('User Agent', html.window.navigator.userAgent),
          const SizedBox(height: 20),
          const Text(
            'LocalStorage Keys:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: html.window.localStorage.keys
                  .where((key) => key.startsWith('webAppDesigner_'))
                  .map(
                    (key) =>
                        Text('• $key', style: const TextStyle(fontSize: 12)),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _uploadProjectData() {
    // For web, we'll use a file input
    final input = html.FileUploadInputElement()..accept = '.json';
    input.click();

    input.onChange.listen((e) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) {
          try {
            final jsonData = reader.result as String;
            final data = Map<String, dynamic>.from(
              Map<String, dynamic>.from(jsonDecode(jsonData)),
            );

            WebRuntimeService.uploadProjectData(data)
                .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Project data uploaded successfully!'),
                    ),
                  );
                  Navigator.pop(context);
                  // Refresh the main app
                  if (data['project'] != null) {
                    final project = Project.fromJson(data['project']);
                    widget.onProjectChanged(project.id);
                  }
                })
                .catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Upload failed: $error')),
                  );
                });
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Invalid JSON file: $e')));
          }
        });

        reader.readAsText(file);
      }
    });
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure? This will delete all projects and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              WebRuntimeService.clearAllData();
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('All data cleared')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

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
    final properties = Map<String, dynamic>.from(json['properties'] ?? {});

    // Deserialize Color objects
    _deserializeColors(properties);

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
      properties: properties,
      zIndex: json['zIndex'] ?? 0,
      opacity: json['opacity']?.toDouble() ?? 1.0,
      linkedPageId: json['linkedPageId'],
    );
  }

  Map<String, dynamic> toJson() {
    // Create a copy of properties and serialize colors
    final serializedProperties = Map<String, dynamic>.from(properties);
    _serializeColors(serializedProperties);

    return {
      'id': id,
      'type': type.toString(),
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'properties': serializedProperties,
      'zIndex': zIndex,
      'opacity': opacity,
      'linkedPageId': linkedPageId,
    };
  }

  // Helper method to serialize Color objects to int values
  static void _serializeColors(Map<String, dynamic> properties) {
    final colorKeys = [
      'color',
      'backgroundColor',
      'textColor',
      'borderColor',
      'strokeColor',
      'fillColor',
      // Add more color property keys as needed
    ];

    for (final key in colorKeys) {
      if (properties.containsKey(key)) {
        final value = properties[key];
        if (value is Color) {
          properties[key] = value.value; // Convert Color to int
        } else if (value is MaterialColor) {
          properties[key] = value.value; // Convert MaterialColor to int
        }
      }
    }
  }

  // Helper method to deserialize int values back to Color objects
  static void _deserializeColors(Map<String, dynamic> properties) {
    final colorKeys = [
      'color',
      'backgroundColor',
      'textColor',
      'borderColor',
      'strokeColor',
      'fillColor',
      // Add more color property keys as needed
    ];

    for (final key in colorKeys) {
      if (properties.containsKey(key)) {
        final value = properties[key];
        if (value is int) {
          properties[key] = Color(value); // Convert int back to Color
        }
      }
    }
  }
}

enum WidgetType { text, button, image, card }

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
