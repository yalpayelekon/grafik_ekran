import 'package:flutter/material.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'project_models.dart';
import 'project_manager.dart';
import 'file_explorer.dart';

class PageEditorScreen extends StatefulWidget {
  final Project project;
  final DesignPage page;

  const PageEditorScreen({
    super.key,
    required this.project,
    required this.page,
  });

  @override
  PageEditorScreenState createState() => PageEditorScreenState();
}

class PageEditorScreenState extends State<PageEditorScreen> {
  late DesignPage currentPage;
  int? selectedItemIndex;
  final TextEditingController textController = TextEditingController();
  bool isPanelExpanded = true;
  bool isLayersPanelExpanded = false;
  static const Uuid _uuid = Uuid();

  // Canvas transform for zoom and pan
  late TransformationController transformationController;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    currentPage = widget.page;
    transformationController = TransformationController();
  }

  @override
  void dispose() {
    textController.dispose();
    transformationController.dispose();
    super.dispose();
  }

  Future<void> _savePage() async {
    try {
      final updatedPage = currentPage.copyWith(updatedAt: DateTime.now());
      await ProjectManager.savePage(updatedPage);
      setState(() => currentPage = updatedPage);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Page saved successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save page: $e')));
    }
  }

  String _getNameForType(WidgetType type) {
    switch (type) {
      case WidgetType.text:
        return 'Text';
      case WidgetType.button:
        return 'Button';
      case WidgetType.image:
        return 'Image';
      case WidgetType.container:
        return 'Container';
      case WidgetType.card:
        return 'Card';
      case WidgetType.input:
        return 'Input';
    }
  }

  Map<String, dynamic> _getDefaultPropertiesForType(WidgetType type) {
    switch (type) {
      case WidgetType.text:
        return {
          'text': 'Sample Text',
          'fontSize': 16.0,
          'isBold': false,
          'isItalic': false,
          'color': Colors.black,
        };

      case WidgetType.button:
        return {
          'text': 'Button',
          'backgroundColor': Colors.blue,
          'textColor': Colors.white,
        };

      case WidgetType.container:
        return {
          'text': 'Container',
          'backgroundColor': Colors.blue[100],
          'textColor': Colors.black,
        };

      case WidgetType.card:
        return {
          'text': 'Card Widget',
          'elevation': 2.0,
          'backgroundColor': Colors.white,
          'textColor': Colors.black,
        };

      case WidgetType.input:
        return {'placeholder': 'Enter text...'};

      case WidgetType.image:
        return {};
    }
  }

  void _addCanvasItem(WidgetType type) {
    final newItem = LayeredCanvasItem(
      id: _uuid.v4(),
      type: type,
      position: const Offset(300, 200),
      size: const Size(150, 100),
      properties: _getDefaultPropertiesForType(type),
      zIndex: currentPage.canvasItems.length, // New items on top
    );

    setState(() {
      currentPage = currentPage.copyWith(
        canvasItems: [...currentPage.canvasItems, newItem],
      );
      selectedItemIndex = currentPage.canvasItems.length - 1;
      isPanelExpanded = true;

      if (type == WidgetType.text) {
        textController.text = newItem.properties['text'] as String;
      }
    });
  }

  void _deleteSelectedItem() {
    if (selectedItemIndex != null) {
      setState(() {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        updatedItems.removeAt(selectedItemIndex!);

        currentPage = currentPage.copyWith(canvasItems: updatedItems);
        selectedItemIndex = null;
      });
    }
  }

  void _duplicateItem(int itemIndex) {
    final originalItem = currentPage.canvasItems[itemIndex];
    final duplicatedItem = LayeredCanvasItem(
      id: _uuid.v4(),
      type: originalItem.type,
      position: originalItem.position + const Offset(20, 20),
      size: originalItem.size,
      properties: Map<String, dynamic>.from(originalItem.properties),
      zIndex: originalItem.zIndex + 1,
      opacity: originalItem.opacity,
    );
    setState(() {
      currentPage = currentPage.copyWith(
        canvasItems: [...currentPage.canvasItems, duplicatedItem],
      );
      selectedItemIndex = currentPage.canvasItems.length - 1;
      isPanelExpanded = true;
      if (duplicatedItem.type == WidgetType.text) {
        textController.text = duplicatedItem.properties['text'] as String;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${currentPage.name}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              setState(() {
                isLayersPanelExpanded = !isLayersPanelExpanded;
              });
            },
            tooltip: 'Toggle Layers Panel',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePage,
            tooltip: 'Save Page',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: selectedItemIndex != null ? _deleteSelectedItem : null,
            tooltip: 'Delete Selected',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _scale = (_scale * 1.2).clamp(0.1, 3.0);
                transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              });
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _scale = (_scale / 1.2).clamp(0.1, 3.0);
                transformationController.value = Matrix4.identity()
                  ..scale(_scale);
              });
            },
            tooltip: 'Zoom Out',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar with draggable components
          _buildSidebar(),

          // Main canvas area
          Expanded(
            child: Stack(
              children: [
                _buildCanvas(),

                // Properties panel
                if (selectedItemIndex != null && isPanelExpanded)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 300,
                    child: _buildPropertiesPanel(),
                  ),

                // Layers panel
                if (isLayersPanelExpanded)
                  Positioned(
                    left: 200,
                    top: 0,
                    bottom: 0,
                    width: 250,
                    child: _buildLayersPanel(),
                  ),

                // Properties panel toggle
                if (selectedItemIndex != null)
                  Positioned(
                    right: isPanelExpanded ? 300 : 0,
                    top: 10,
                    child: _buildPanelToggle(),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStatusBar(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: Colors.grey[200],
      child: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildSidebarHeader('Components'),
          _buildDraggable('Text', Icons.text_fields, WidgetType.text),
          _buildDraggable('Button', Icons.smart_button, WidgetType.button),
          _buildDraggable('Image', Icons.image, WidgetType.image),
          _buildDraggable('Container', Icons.crop_square, WidgetType.container),
          _buildDraggable('Card', Icons.credit_card, WidgetType.card),
          _buildDraggable('Input', Icons.input, WidgetType.input),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
      ),
    );
  }

  Widget _buildDraggable(String label, IconData icon, WidgetType type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        elevation: 2,
        child: InkWell(
          onTap: () => _addCanvasItem(type),
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue[600]),
                const SizedBox(width: 8.0),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return InteractiveViewer(
      transformationController: transformationController,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 3.0,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100],
        child: Center(
          child: Container(
            width: currentPage.pageSize.width,
            height: currentPage.pageSize.height,
            decoration: BoxDecoration(
              color: currentPage.backgroundColor,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Grid pattern
                CustomPaint(painter: GridPainter(), size: currentPage.pageSize),

                ...(() {
                  final entries = currentPage.canvasItems
                      .asMap()
                      .entries
                      .toList();
                  entries.sort(
                    (a, b) => a.value.zIndex.compareTo(b.value.zIndex),
                  );
                  return entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Positioned(
                      left: item.position.dx,
                      top: item.position.dy,
                      child: _buildResizableWidget(index, item),
                    );
                  }).toList();
                })(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page: ${currentPage.pageSize.width.toInt()} × ${currentPage.pageSize.height.toInt()}',
            ),
            if (selectedItemIndex != null) ...[
              Text(
                'Selected: ${_getNameForType(currentPage.canvasItems[selectedItemIndex!].type)}',
              ),
              Text(
                'Layer: ${currentPage.canvasItems[selectedItemIndex!].zIndex}',
              ),
            ],
            Text('Zoom: ${(_scale * 100).toInt()}%'),
          ],
        ),
      ),
    );
  }

  void _moveItemToLayer(int itemIndex, int newZIndex) {
    if (itemIndex < currentPage.canvasItems.length) {
      setState(() {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
          zIndex: newZIndex,
        );

        currentPage = currentPage.copyWith(canvasItems: updatedItems);
      });
    }
  }

  Widget _buildWidgetForType(LayeredCanvasItem item) {
    final properties = item.properties;

    switch (item.type) {
      case WidgetType.text:
        return Center(
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
              color: properties['color'] as Color? ?? Colors.black,
            ),
          ),
        );

      case WidgetType.button:
        return Center(
          child: ElevatedButton(
            onPressed: () {
              // Handle navigation if linked
              if (item.linkedPageId != null) {
                _showNavigationPreview(item.linkedPageId!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  properties['backgroundColor'] as Color? ?? Colors.blue,
              foregroundColor:
                  properties['textColor'] as Color? ?? Colors.white,
            ),
            child: Text(properties['text'] as String? ?? 'Button'),
          ),
        );

      case WidgetType.image:
        final imagePath = properties['imagePath'] as String?;
        if (imagePath != null && File(imagePath).existsSync()) {
          return Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildImagePlaceholder(),
          );
        }
        return _buildImagePlaceholder();

      case WidgetType.container:
        return Container(
          color: properties['backgroundColor'] as Color? ?? Colors.blue[100],
          child: Center(
            child: Text(
              properties['text'] as String? ?? 'Container',
              style: TextStyle(
                color: properties['textColor'] as Color? ?? Colors.black,
              ),
            ),
          ),
        );

      case WidgetType.card:
        return Card(
          elevation: properties['elevation'] as double? ?? 2.0,
          color: properties['backgroundColor'] as Color? ?? Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                properties['text'] as String? ?? 'Card Widget',
                style: TextStyle(
                  color: properties['textColor'] as Color? ?? Colors.black,
                ),
              ),
            ),
          ),
        );

      case WidgetType.input:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              enabled: false, // Disabled in editor
              decoration: InputDecoration(
                hintText:
                    properties['placeholder'] as String? ?? 'Enter text...',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 50.0, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Click to select image',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayersPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Layers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isLayersPanelExpanded = false;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: currentPage.canvasItems.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final items = List<LayeredCanvasItem>.from(
                    currentPage.canvasItems,
                  );
                  if (newIndex > oldIndex) newIndex--;
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);

                  // Update z-indices
                  for (int i = 0; i < items.length; i++) {
                    items[i] = items[i].copyWith(zIndex: items.length - 1 - i);
                  }

                  currentPage = currentPage.copyWith(canvasItems: items);
                });
              },
              itemBuilder: (context, index) {
                final item = currentPage
                    .canvasItems[currentPage.canvasItems.length - 1 - index];
                final actualIndex = currentPage.canvasItems.indexOf(item);
                final isSelected = selectedItemIndex == actualIndex;

                return _buildLayerItem(item, actualIndex, isSelected, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerItem(
    LayeredCanvasItem item,
    int actualIndex,
    bool isSelected,
    int listIndex,
  ) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Card(
        color: isSelected ? Colors.blue[50] : null,
        child: ListTile(
          dense: true,
          leading: Icon(_getIconForType(item.type), color: Colors.blue[600]),
          title: Text(
            _getNameForType(item.type),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text('Layer ${item.zIndex}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opacity control
              SizedBox(
                width: 60,
                child: Slider(
                  value: item.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() {
                      final updatedItems = List<LayeredCanvasItem>.from(
                        currentPage.canvasItems,
                      );
                      updatedItems[actualIndex] = item.copyWith(opacity: value);
                      currentPage = currentPage.copyWith(
                        canvasItems: updatedItems,
                      );
                    });
                  },
                ),
              ),
              // Duplicate button
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => _duplicateItem(actualIndex),
              ),
            ],
          ),
          onTap: () {
            setState(() {
              selectedItemIndex = actualIndex;
              isPanelExpanded = true;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    if (selectedItemIndex == null) return Container();

    final item = currentPage.canvasItems[selectedItemIndex!];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Properties',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      isPanelExpanded = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._buildPropertiesForType(item),
                const SizedBox(height: 16),
                _buildLayerControls(item),
                const SizedBox(height: 16),
                _buildPositionControls(item),
                const SizedBox(height: 16),
                _buildSizeControls(item),
                if (item.type == WidgetType.button) ...[
                  const SizedBox(height: 16),
                  _buildNavigationControls(item),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPropertiesForType(LayeredCanvasItem item) {
    switch (item.type) {
      case WidgetType.text:
        return [
          TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _updateItemProperty(item, 'text', value);
            },
          ),
          const SizedBox(height: 12),
          _buildFontSizeSlider(item),
          _buildTextStyleControls(item),
          _buildColorPicker('Text Color', 'color', item),
        ];

      case WidgetType.button:
        return [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Button Text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateItemProperty(item, 'text', value),
          ),
          const SizedBox(height: 16),
          _buildColorPicker('Background Color', 'backgroundColor', item),
          const SizedBox(height: 8),
          _buildColorPicker('Text Color', 'textColor', item),
        ];

      case WidgetType.image:
        return [
          ElevatedButton.icon(
            onPressed: () => _selectImage(item),
            icon: const Icon(Icons.image),
            label: const Text('Select Image'),
          ),
          if (item.properties['imagePath'] != null) ...[
            const SizedBox(height: 8),
            Text('Current: ${item.properties['imagePath'].split('/').last}'),
          ],
        ];

      case WidgetType.container:
        return [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Container Text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateItemProperty(item, 'text', value),
          ),
          const SizedBox(height: 16),
          _buildColorPicker('Background Color', 'backgroundColor', item),
          const SizedBox(height: 8),
          _buildColorPicker('Text Color', 'textColor', item),
        ];

      case WidgetType.card:
        return [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Card Text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateItemProperty(item, 'text', value),
          ),
          const SizedBox(height: 16),
          _buildElevationSlider(item),
          _buildColorPicker('Background Color', 'backgroundColor', item),
          const SizedBox(height: 8),
          _buildColorPicker('Text Color', 'textColor', item),
        ];

      case WidgetType.input:
        return [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Placeholder Text',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                _updateItemProperty(item, 'placeholder', value),
          ),
        ];
    }
  }

  Widget _buildPanelToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isPanelExpanded = !isPanelExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: const BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8.0),
            bottomLeft: Radius.circular(8.0),
          ),
        ),
        child: Icon(
          isPanelExpanded ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLayerControls(LayeredCanvasItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Layer Controls',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Z-Index: '),
            Expanded(
              child: Slider(
                value: item.zIndex.toDouble(),
                min: 0,
                max: currentPage.canvasItems.length.toDouble(),
                divisions: currentPage.canvasItems.length,
                label: item.zIndex.toString(),
                onChanged: (value) {
                  _updateItemProperty(item, 'zIndex', value.toInt());
                },
              ),
            ),
            Text(item.zIndex.toString()),
          ],
        ),
        Row(
          children: [
            const Text('Opacity: '),
            Expanded(
              child: Slider(
                value: item.opacity,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: (item.opacity * 100).toInt().toString() + '%',
                onChanged: (value) {
                  _updateItemProperty(item, 'opacity', value);
                },
              ),
            ),
            Text('${(item.opacity * 100).toInt()}%'),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationControls(LayeredCanvasItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Link to Page ID',
                  border: OutlineInputBorder(),
                  hintText: 'Enter page ID or leave empty',
                ),
                controller: TextEditingController(
                  text: item.linkedPageId ?? '',
                ),
                onChanged: (value) {
                  _updateItemProperty(
                    item,
                    'linkedPageId',
                    value.isEmpty ? null : value,
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => _showPageSelector(item),
              tooltip: 'Select from pages',
            ),
          ],
        ),
      ],
    );
  }

  void _selectImage(LayeredCanvasItem item) {
    showDialog(
      context: context,
      builder: (context) => FileExplorerDialog(
        projectId: widget.project.id,
        onFileSelected: (filePath) {
          _updateItemProperty(item, 'imagePath', filePath);
        },
      ),
    );
  }

  void _updateItemProperty(LayeredCanvasItem item, String key, dynamic value) {
    setState(() {
      final itemIndex = currentPage.canvasItems.indexOf(item);
      if (itemIndex != -1) {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        final updatedProperties = Map<String, dynamic>.from(item.properties);

        if (key == 'zIndex') {
          updatedItems[itemIndex] = item.copyWith(zIndex: value);
        } else if (key == 'opacity') {
          updatedItems[itemIndex] = item.copyWith(opacity: value);
        } else if (key == 'linkedPageId') {
          updatedItems[itemIndex] = item.copyWith(linkedPageId: value);
        } else {
          updatedProperties[key] = value;
          updatedItems[itemIndex] = item.copyWith(
            properties: updatedProperties,
          );
        }

        currentPage = currentPage.copyWith(canvasItems: updatedItems);
      }
    });
  }

  // Utility methods for UI components
  Widget _buildFontSizeSlider(LayeredCanvasItem item) {
    final fontSize = item.properties['fontSize'] as double? ?? 16.0;
    return Row(
      children: [
        const Text('Font Size:'),
        Expanded(
          child: Slider(
            value: fontSize,
            min: 8.0,
            max: 48.0,
            divisions: 40,
            label: fontSize.toInt().toString(),
            onChanged: (value) => _updateItemProperty(item, 'fontSize', value),
          ),
        ),
        Text(fontSize.toInt().toString()),
      ],
    );
  }

  Widget _buildTextStyleControls(LayeredCanvasItem item) {
    return Row(
      children: [
        Checkbox(
          value: item.properties['isBold'] as bool? ?? false,
          onChanged: (value) =>
              _updateItemProperty(item, 'isBold', value ?? false),
        ),
        const Text('Bold'),
        const SizedBox(width: 12),
        Checkbox(
          value: item.properties['isItalic'] as bool? ?? false,
          onChanged: (value) =>
              _updateItemProperty(item, 'isItalic', value ?? false),
        ),
        const Text('Italic'),
      ],
    );
  }

  Widget _buildElevationSlider(LayeredCanvasItem item) {
    final elevation = item.properties['elevation'] as double? ?? 2.0;
    return Row(
      children: [
        const Text('Elevation:'),
        Expanded(
          child: Slider(
            value: elevation,
            min: 0.0,
            max: 24.0,
            divisions: 24,
            label: elevation.toString(),
            onChanged: (value) => _updateItemProperty(item, 'elevation', value),
          ),
        ),
        Text(elevation.toString()),
      ],
    );
  }

  Widget _buildPositionControls(LayeredCanvasItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Position', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'X',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: item.position.dx.toInt().toString(),
                ),
                onChanged: (value) {
                  final x = double.tryParse(value) ?? item.position.dx;
                  _updateItemPosition(item, Offset(x, item.position.dy));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Y',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: item.position.dy.toInt().toString(),
                ),
                onChanged: (value) {
                  final y = double.tryParse(value) ?? item.position.dy;
                  _updateItemPosition(item, Offset(item.position.dx, y));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSizeControls(LayeredCanvasItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Width',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: item.size.width.toInt().toString(),
                ),
                onChanged: (value) {
                  final width = double.tryParse(value);
                  if (width != null && width >= 50) {
                    _updateItemSize(item, Size(width, item.size.height));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Height',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: item.size.height.toInt().toString(),
                ),
                onChanged: (value) {
                  final height = double.tryParse(value);
                  if (height != null && height >= 50) {
                    _updateItemSize(item, Size(item.size.width, height));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPicker(
    String label,
    String propertyKey,
    LayeredCanvasItem item,
  ) {
    final currentColor = item.properties[propertyKey] as Color? ?? Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _colorOption(Colors.blue, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.red, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.green, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.orange, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.purple, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.teal, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.pink, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.black, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
            _colorOption(Colors.white, currentColor, (color) {
              _updateItemProperty(item, propertyKey, color);
            }),
          ],
        ),
      ],
    );
  }

  Widget _colorOption(
    Color color,
    Color selectedColor,
    Function(Color) onSelect,
  ) {
    final isSelected = color.value == selectedColor.value;

    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  void _updateItemPosition(LayeredCanvasItem item, Offset newPosition) {
    setState(() {
      final itemIndex = currentPage.canvasItems.indexOf(item);
      if (itemIndex != -1) {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        updatedItems[itemIndex] = item.copyWith(position: newPosition);
        currentPage = currentPage.copyWith(canvasItems: updatedItems);
      }
    });
  }

  void _updateItemSize(LayeredCanvasItem item, Size newSize) {
    setState(() {
      final itemIndex = currentPage.canvasItems.indexOf(item);
      if (itemIndex != -1) {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        updatedItems[itemIndex] = item.copyWith(size: newSize);
        currentPage = currentPage.copyWith(canvasItems: updatedItems);
      }
    });
  }

  void _showPageSelector(LayeredCanvasItem item) async {
    try {
      final pages = await ProjectManager.loadProjectPages(widget.project.id);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Page to Link'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                if (pages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No other pages available'),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        if (page.id == currentPage.id)
                          return Container(); // Skip current page

                        return ListTile(
                          title: Text(page.name),
                          subtitle: Text('ID: ${page.id}'),
                          onTap: () {
                            Navigator.pop(context);
                            _updateItemProperty(item, 'linkedPageId', page.id);
                          },
                        );
                      },
                    ),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('Remove Link'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateItemProperty(item, 'linkedPageId', null);
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
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load pages: $e')));
    }
  }

  void _showNavigationPreview(String pageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigation Preview'),
        content: Text('This button would navigate to page: $pageId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Utility methods
  IconData _getIconForType(WidgetType type) {
    switch (type) {
      case WidgetType.text:
        return Icons.text_fields;
      case WidgetType.button:
        return Icons.smart_button;
      case WidgetType.image:
        return Icons.image;
      case WidgetType.container:
        return Icons.crop_square;
      case WidgetType.card:
        return Icons.credit_card;
      case WidgetType.input:
        return Icons.input;
    }
  }

  Widget _buildResizableWidget(int index, LayeredCanvasItem item) {
    final isSelected = selectedItemIndex == index;

    return Opacity(
      opacity: item.opacity,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedItemIndex = index;
            isPanelExpanded = true;

            if (item.type == WidgetType.text) {
              textController.text = item.properties['text'] as String;
            }
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final updatedItems = List<LayeredCanvasItem>.from(
              currentPage.canvasItems,
            );
            updatedItems[index] = item.copyWith(
              position: Offset(
                (item.position.dx + details.delta.dx).clamp(
                  0.0,
                  currentPage.pageSize.width - item.size.width,
                ),
                (item.position.dy + details.delta.dy).clamp(
                  0.0,
                  currentPage.pageSize.height - item.size.height,
                ),
              ),
            );

            currentPage = currentPage.copyWith(canvasItems: updatedItems);
            selectedItemIndex = index;
          });
        },
        child: Container(
          width: item.size.width,
          height: item.size.height,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Actual widget
              SizedBox(
                width: item.size.width,
                height: item.size.height,
                child: _buildWidgetForType(item),
              ),

              // Resize handle (only when selected)
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final newWidth = (item.size.width + details.delta.dx)
                            .clamp(50.0, 500.0);
                        final newHeight = (item.size.height + details.delta.dy)
                            .clamp(50.0, 500.0);

                        final updatedItems = List<LayeredCanvasItem>.from(
                          currentPage.canvasItems,
                        );
                        updatedItems[index] = item.copyWith(
                          size: Size(newWidth, newHeight),
                        );

                        currentPage = currentPage.copyWith(
                          canvasItems: updatedItems,
                        );
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.open_with,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // Z-index indicator
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Layer ${item.zIndex}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    // Draw grid lines
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
