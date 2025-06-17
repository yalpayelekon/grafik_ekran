import 'package:flutter/material.dart';
import 'package:graphics/export_service.dart';
import 'package:graphics/page_editor.dart';
import 'project_models.dart';
import 'project_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Project> projects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => isLoading = true);
    try {
      final loadedProjects = await ProjectManager.loadProjects();
      setState(() {
        projects = loadedProjects;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load projects: $e');
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateProjectDialog(),
    );

    if (result != null) {
      try {
        final project = await ProjectManager.createProject(
          name: result['name'],
          defaultPageSize: result['size'],
        );
        setState(() {
          projects.add(project);
        });

        // Navigate to project detail
        _openProject(project);
      } catch (e) {
        _showErrorDialog('Failed to create project: $e');
      }
    }
  }

  void _openProject(Project project) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        )
        .then((_) => _loadProjects()); // Refresh when returning
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ProjectManager.deleteProject(project.id);
        setState(() {
          projects.removeWhere((p) => p.id == project.id);
        });
      } catch (e) {
        _showErrorDialog('Failed to delete project: $e');
      }
    }
  }

  Future<void> _exportProject(Project project) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Project'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'json'),
            child: const Text('JSON Data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'web'),
            child: const Text('Web App'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        setState(() => isLoading = true);

        if (result == 'json') {
          await ExportService.exportProjectToJson(project.id);
          _showSuccessDialog('Project exported as JSON successfully!');
        } else if (result == 'web') {
          await ExportService.exportProjectAsWebApp(project.id);
          _showSuccessDialog('Web app exported successfully!');
        }
      } catch (e) {
        _showErrorDialog('Export failed: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web App Designer'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProjectList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProjectList() {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Click the + button to create your first project',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.web_asset, color: Colors.blue[600], size: 32),
                  const Spacer(),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteProject(project);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                project.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${project.pageIds.length} pages',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(),
              Text(
                'Modified: ${_formatDate(project.updatedAt)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  CreateProjectDialogState createState() => CreateProjectDialogState();
}

class CreateProjectDialogState extends State<CreateProjectDialog> {
  final nameController = TextEditingController();
  Size selectedSize = const Size(1920, 1080);

  final List<Size> predefinedSizes = [
    const Size(1920, 1080), // Full HD
    const Size(1366, 768), // Laptop
    const Size(1280, 720), // HD
    const Size(768, 1024), // Tablet Portrait
    const Size(1024, 768), // Tablet Landscape
    const Size(375, 667), // Mobile Portrait
    const Size(667, 375), // Mobile Landscape
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Default Page Size:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Size>(
              value: selectedSize,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: predefinedSizes.map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text('${size.width.toInt()} × ${size.height.toInt()}'),
                );
              }).toList(),
              onChanged: (size) {
                if (size != null) {
                  setState(() => selectedSize = size);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'size': selectedSize,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// Project Detail Screen - Shows pages in a project
class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ProjectDetailScreenState createState() => ProjectDetailScreenState();
}

class ProjectDetailScreenState extends State<ProjectDetailScreen> {
  List<DesignPage> pages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    setState(() => isLoading = true);
    try {
      final loadedPages = await ProjectManager.loadProjectPages(
        widget.project.id,
      );
      setState(() {
        pages = loadedPages;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to load pages: $e');
    }
  }

  Future<void> _createPage() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreatePageDialog(project: widget.project),
    );

    if (result != null) {
      try {
        final page = await ProjectManager.createPage(
          projectId: widget.project.id,
          name: result['name'],
          pageSize: result['size'],
        );
        setState(() {
          pages.add(page);
        });

        // Navigate to page editor
        _openPageEditor(page);
      } catch (e) {
        _showErrorDialog('Failed to create page: $e');
      }
    }
  }

  void _openPageEditor(DesignPage page) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                PageEditorScreen(project: widget.project, page: page),
          ),
        )
        .then((_) => _loadPages()); // Refresh when returning
  }

  Future<void> _deletePage(DesignPage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Are you sure you want to delete "${page.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ProjectManager.deletePage(widget.project.id, page.id);
        setState(() {
          pages.removeWhere((p) => p.id == page.id);
        });
      } catch (e) {
        _showErrorDialog('Failed to delete page: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPageList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPage,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPageList() {
    if (pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pages yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Click the + button to create your first page',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          return _buildPageCard(page);
        },
      ),
    );
  }

  Widget _buildPageCard(DesignPage page) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _openPageEditor(page),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Colors.blue[600], size: 24),
                  const Spacer(),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePage(page);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Page preview (simplified)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: page.backgroundColor,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${page.canvasItems.length} items',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                page.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${page.pageSize.width.toInt()} × ${page.pageSize.height.toInt()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePageDialog extends StatefulWidget {
  final Project project;

  const CreatePageDialog({super.key, required this.project});

  @override
  CreatePageDialogState createState() => CreatePageDialogState();
}

class CreatePageDialogState extends State<CreatePageDialog> {
  final nameController = TextEditingController();
  late Size selectedSize;

  final List<Size> predefinedSizes = [
    const Size(1920, 1080), // Full HD
    const Size(1366, 768), // Laptop
    const Size(1280, 720), // HD
    const Size(768, 1024), // Tablet Portrait
    const Size(1024, 768), // Tablet Landscape
    const Size(375, 667), // Mobile Portrait
    const Size(667, 375), // Mobile Landscape
  ];

  @override
  void initState() {
    super.initState();
    selectedSize = widget.project.defaultPageSize;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Page'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Page Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Page Size:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Size>(
              value: selectedSize,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: predefinedSizes.map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text('${size.width.toInt()} × ${size.height.toInt()}'),
                );
              }).toList(),
              onChanged: (size) {
                if (size != null) {
                  setState(() => selectedSize = size);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'size': selectedSize,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
