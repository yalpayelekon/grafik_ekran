import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'project_models.dart';
import 'project_manager.dart';

class FileExplorer extends StatefulWidget {
  final String projectId;
  final Function(String)? onFileSelected;
  final bool showOnlyImages;

  const FileExplorer({
    super.key,
    required this.projectId,
    this.onFileSelected,
    this.showOnlyImages = true,
  });

  @override
  FileExplorerState createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer> {
  String? currentPath;
  List<FileSystemItem> currentItems = [];
  List<String> availableDrives = [];
  bool isLoading = true;
  List<FileSystemItem> projectAssets = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => isLoading = true);

    try {
      // Load available drives
      availableDrives = await ProjectManager.getAvailableDrives();

      // Load project assets
      projectAssets = await ProjectManager.getProjectAssets(widget.projectId);

      // Start with Documents directory
      final documentsDir = Platform.environment['USERPROFILE'] ?? '/';
      await _navigateToPath(path.join(documentsDir, 'Documents'));
    } catch (e) {
      print('Error initializing file explorer: $e');
      if (availableDrives.isNotEmpty) {
        await _navigateToPath(availableDrives.first);
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> _navigateToPath(String newPath) async {
    setState(() => isLoading = true);

    try {
      final items = await ProjectManager.browseFileSystem(newPath);
      setState(() {
        currentPath = newPath;
        currentItems = widget.showOnlyImages
            ? items
                  .where((item) => item.isDirectory || item.isImageFile)
                  .toList()
            : items;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Cannot access this location: $e');
    }
  }

  Future<void> _navigateUp() async {
    if (currentPath != null) {
      final parentPath = path.dirname(currentPath!);
      if (parentPath != currentPath) {
        await _navigateToPath(parentPath);
      }
    }
  }

  Future<void> _copyFileToProject(FileSystemItem item) async {
    try {
      setState(() => isLoading = true);

      final assetPath = await ProjectManager.copyAssetToProject(
        widget.projectId,
        item.path,
      );

      // Refresh project assets
      projectAssets = await ProjectManager.getProjectAssets(widget.projectId);

      setState(() => isLoading = false);

      if (widget.onFileSelected != null) {
        widget.onFileSelected!(assetPath);
      }

      _showSuccessDialog('File copied to project assets successfully!');
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Failed to copy file: $e');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildTabBar(),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildCurrentView(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[100],
      child: Row(
        children: [
          // Drive selector
          if (availableDrives.isNotEmpty)
            DropdownButton<String>(
              value:
                  currentPath != null &&
                      availableDrives.any(
                        (drive) => currentPath!.toLowerCase().startsWith(
                          drive.toLowerCase(),
                        ),
                      )
                  ? availableDrives.firstWhere(
                      (drive) => currentPath!.toLowerCase().startsWith(
                        drive.toLowerCase(),
                      ),
                    )
                  : null,
              hint: const Text('Select Drive'),
              items: availableDrives.map((drive) {
                return DropdownMenuItem(value: drive, child: Text(drive));
              }).toList(),
              onChanged: (drive) {
                if (drive != null) {
                  _navigateToPath(drive);
                }
              },
            ),

          const SizedBox(width: 8),

          // Up button
          IconButton(
            onPressed: currentPath != null ? _navigateUp : null,
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Go up',
          ),

          const SizedBox(width: 8),

          // Current path
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentPath ?? 'Select a location',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: Colors.grey[50],
        child: const TabBar(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(text: 'Browse Files'),
            Tab(text: 'Project Assets'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    return DefaultTabController(
      length: 2,
      child: TabBarView(
        children: [_buildFileList(currentItems), _buildProjectAssetsList()],
      ),
    );
  }

  Widget _buildFileList(List<FileSystemItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No files found in this location'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildFileListItem(item);
      },
    );
  }

  Widget _buildProjectAssetsList() {
    if (projectAssets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No assets in this project'),
            SizedBox(height: 8),
            Text(
              'Copy images from the Browse Files tab',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: projectAssets.length,
      itemBuilder: (context, index) {
        final asset = projectAssets[index];
        return _buildAssetTile(asset);
      },
    );
  }

  Widget _buildFileListItem(FileSystemItem item) {
    return ListTile(
      leading: Icon(
        item.isDirectory
            ? Icons.folder
            : item.isImageFile
            ? Icons.image
            : Icons.insert_drive_file,
        color: item.isDirectory
            ? Colors.blue[600]
            : item.isImageFile
            ? Colors.green[600]
            : Colors.grey[600],
      ),
      title: Text(item.name),
      subtitle: item.isDirectory
          ? null
          : Text(
              '${_formatFileSize(item.size ?? 0)} • ${_formatDate(item.modifiedDate)}',
              style: const TextStyle(fontSize: 12),
            ),
      onTap: () {
        if (item.isDirectory) {
          _navigateToPath(item.path);
        }
      },
      trailing: item.isImageFile
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () => _previewImage(item),
                  tooltip: 'Preview',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyFileToProject(item),
                  tooltip: 'Copy to Project',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildAssetTile(FileSystemItem asset) {
    return Card(
      child: InkWell(
        onTap: () {
          if (widget.onFileSelected != null) {
            widget.onFileSelected!(asset.path);
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: asset.isImageFile
                      ? Image.file(
                          File(asset.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.image),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                asset.name,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewImage(FileSystemItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(item.name),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Navigator.pop(context);
                      _copyFileToProject(item);
                    },
                    tooltip: 'Copy to Project',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'Cannot preview this image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Standalone File Explorer Dialog
class FileExplorerDialog extends StatelessWidget {
  final String projectId;
  final Function(String)? onFileSelected;

  const FileExplorerDialog({
    super.key,
    required this.projectId,
    this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Image'),
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
            Expanded(
              child: FileExplorer(
                projectId: projectId,
                onFileSelected: (filePath) {
                  Navigator.pop(context);
                  if (onFileSelected != null) {
                    onFileSelected!(filePath);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
