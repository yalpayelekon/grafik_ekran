import 'package:flutter/material.dart';
import 'package:graphics/grid_painter.dart';
import 'package:uuid/uuid.dart';
import 'project_models.dart';
import 'project_manager.dart';

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
  static const Uuid _uuid = Uuid();

  int? creatingPolygonIndex;
  Offset? mousePosition;
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

  void _handleCanvasTap(Offset localCanvasPosition) {
    if (creatingPolygonIndex == null) return;

    final item = currentPage.canvasItems[creatingPolygonIndex!];
    if (item.type != WidgetType.polygon || !item.properties['isCreating'])
      return;

    debugPolygonState();
    final relativePosition = Offset(
      localCanvasPosition.dx - item.position.dx,
      localCanvasPosition.dy - item.position.dy,
    );

    // Check if click is within the polygon's bounds
    if (relativePosition.dx < 0 ||
        relativePosition.dx > item.size.width ||
        relativePosition.dy < 0 ||
        relativePosition.dy > item.size.height) {
      // Show a message that click should be within polygon bounds
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Click within the polygon area (blue container)'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Add point relative to polygon container
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );

    points.add({'dx': relativePosition.dx, 'dy': relativePosition.dy});

    print('Added point: $relativePosition to polygon at ${item.position}');
    _updateItemProperty(item, 'points', points);
  }

  // 2. Fix the finish polygon method with proper state management
  void _finishPolygon(LayeredCanvasItem item) {
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );

    if (points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygon needs at least 3 points')),
      );
      return;
    }

    // Update the item to mark it as finished
    setState(() {
      final itemIndex = currentPage.canvasItems.indexWhere(
        (i) => i.id == item.id,
      );
      if (itemIndex != -1) {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );
        final updatedProperties = Map<String, dynamic>.from(item.properties);
        updatedProperties['isCreating'] = false;

        updatedItems[itemIndex] = item.copyWith(properties: updatedProperties);
        currentPage = currentPage.copyWith(canvasItems: updatedItems);

        // Clear creation state
        creatingPolygonIndex = null;

        print('Polygon finished with ${points.length} points');
      }
    });
  }

  // 3. Fix the _updateItemProperty method to ensure proper updates
  void _updateItemProperty(LayeredCanvasItem item, String key, dynamic value) {
    setState(() {
      final itemIndex = currentPage.canvasItems.indexWhere(
        (i) => i.id == item.id,
      );
      if (itemIndex != -1) {
        final updatedItems = List<LayeredCanvasItem>.from(
          currentPage.canvasItems,
        );

        if (key == 'zIndex') {
          updatedItems[itemIndex] = item.copyWith(zIndex: value);
        } else if (key == 'opacity') {
          updatedItems[itemIndex] = item.copyWith(opacity: value);
        } else if (key == 'linkedPageId') {
          updatedItems[itemIndex] = item.copyWith(linkedPageId: value);
        } else {
          final updatedProperties = Map<String, dynamic>.from(item.properties);
          updatedProperties[key] = value;
          updatedItems[itemIndex] = item.copyWith(
            properties: updatedProperties,
          );
        }

        currentPage = currentPage.copyWith(canvasItems: updatedItems);

        print('Updated $key to $value for item ${item.id}');
      }
    });
  }

  // 4. Update the canvas build method
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
          child: GestureDetector(
            onTapDown: (details) {
              if (creatingPolygonIndex != null) {
                _handleCanvasTap(details.localPosition);
              }
            },
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
                  CustomPaint(
                    painter: GridPainter(),
                    size: currentPage.pageSize,
                  ),

                  // Show polygon creation area when creating
                  if (creatingPolygonIndex != null)
                    _buildPolygonCreationHelper(),

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
      ),
    );
  }

  // 5. Add helper to show polygon creation area
  Widget _buildPolygonCreationHelper() {
    if (creatingPolygonIndex == null) return Container();

    final item = currentPage.canvasItems[creatingPolygonIndex!];

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: Container(
        width: item.size.width,
        height: item.size.height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          color: Colors.blue.withOpacity(0.1),
        ),
        child: const Center(
          child: Text(
            'Click here to add points',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // 6. Update polygon widget builder to show container bounds when creating
  Widget _buildPolygonWidget(LayeredCanvasItem item) {
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );
    final isCreating = item.properties['isCreating'] as bool? ?? false;
    final strokeColor =
        _parseColor(item.properties['strokeColor']) ?? Colors.blue;
    final fillColor =
        _parseColor(item.properties['fillColor']) ??
        Colors.blue.withOpacity(0.3);
    final strokeWidth = item.properties['strokeWidth'] as double? ?? 2.0;

    return Stack(
      children: [
        // Show container bounds when creating
        if (isCreating)
          Container(
            width: item.size.width,
            height: item.size.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
              color: Colors.blue.withOpacity(0.05),
            ),
          ),

        // The actual polygon
        CustomPaint(
          painter: PolygonPainter(
            points: points,
            strokeColor: strokeColor,
            fillColor: fillColor,
            strokeWidth: strokeWidth,
            isCreating: isCreating,
          ),
          size: item.size,
        ),
      ],
    );
  }

  void _updatePolygonPoint(
    LayeredCanvasItem item,
    int pointIndex,
    Offset newPosition,
  ) {
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );
    if (pointIndex >= 0 && pointIndex < points.length) {
      points[pointIndex] = {'dx': newPosition.dx, 'dy': newPosition.dy};
      _updateItemProperty(item, 'points', points);
    }
  }

  Future<void> _savePage() async {
    try {
      final updatedPage = currentPage.copyWith(updatedAt: DateTime.now());
      await ProjectManager.savePage(updatedPage);
      setState(() => currentPage = updatedPage);
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
      case WidgetType.polygon:
        return 'Polygon';
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
      case WidgetType.polygon:
        return {
          'points': <Map<String, double>>[], // List of points as {dx: x, dy: y}
          'isCreating': true, // Whether we're still in creation mode
          'strokeColor': Colors.blue,
          'fillColor': Colors.blue.withOpacity(0.3),
          'strokeWidth': 2.0,
        };
      case WidgetType.button:
        return {
          'text': 'Button',
          'backgroundColor': Colors.blue,
          'textColor': Colors.white,
        };
    }
  }

  void _addCanvasItem(WidgetType type) {
    final newItem = LayeredCanvasItem(
      id: _uuid.v4(),
      type: type,
      position: const Offset(300, 200),
      size: const Size(150, 100),
      properties: _getDefaultPropertiesForType(type),
      zIndex: currentPage.canvasItems.length,
    );

    setState(() {
      currentPage = currentPage.copyWith(
        canvasItems: [...currentPage.canvasItems, newItem],
      );
      selectedItemIndex = currentPage.canvasItems.length - 1;
      isPanelExpanded = true;

      if (type == WidgetType.polygon) {
        creatingPolygonIndex = selectedItemIndex;
      }

      if (type == WidgetType.text) {
        textController.text = newItem.properties['text'] as String;
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
            icon: const Icon(Icons.save),
            onPressed: _savePage,
            tooltip: 'Save Page',
          ),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                _buildCanvas(),
                if (selectedItemIndex != null && isPanelExpanded)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 300,
                    child: _buildPropertiesPanel(),
                  ),

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
          _buildDraggable('Polygon', Icons.polyline, WidgetType.polygon),
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

  Color? _parseColor(dynamic colorValue) {
    if (colorValue == null) return null;
    if (colorValue is Color) return colorValue;
    if (colorValue is int) return Color(colorValue);
    return null;
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
      case WidgetType.polygon:
        return _buildPolygonWidget(item);
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
    }
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
      case WidgetType.polygon:
        return _buildPolygonProperties(item);
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

  void debugPolygonState() {
    if (creatingPolygonIndex != null) {
      final item = currentPage.canvasItems[creatingPolygonIndex!];
      print('=== Polygon Debug ===');
      print('Item position: ${item.position}');
      print('Item size: ${item.size}');
      print('Is creating: ${item.properties['isCreating']}');
      print('Points: ${item.properties['points']}');
      print('Selected index: $selectedItemIndex');
      print('Creating index: $creatingPolygonIndex');
    }
  }

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

  List<Widget> _buildPolygonProperties(LayeredCanvasItem item) {
    final isCreating = item.properties['isCreating'] as bool? ?? false;
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );

    return [
      if (isCreating) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              const Text(
                'Creating Polygon',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Points: ${points.length}'),
              const SizedBox(height: 8),
              const Text(
                'Click on canvas to add points',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: points.length >= 3
                    ? () => _finishPolygon(item)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Finish Polygon'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              const Text(
                'Polygon Complete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Points: ${points.length}'),
              const SizedBox(height: 8),
              const Text(
                'Drag points to edit shape',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],

      // Style properties
      const Text(
        'Stroke Properties',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _buildColorPicker('Stroke Color', 'strokeColor', item),
      const SizedBox(height: 16),
      _buildStrokeWidthSlider(item),
      const SizedBox(height: 16),

      const Text(
        'Fill Properties',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _buildColorPicker('Fill Color', 'fillColor', item),
    ];
  }

  // Add this method for stroke width control
  Widget _buildStrokeWidthSlider(LayeredCanvasItem item) {
    final strokeWidth = item.properties['strokeWidth'] as double? ?? 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Stroke Width'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: strokeWidth,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                label: strokeWidth.toString(),
                onChanged: (value) =>
                    _updateItemProperty(item, 'strokeWidth', value),
              ),
            ),
            Text(strokeWidth.toInt().toString()),
          ],
        ),
      ],
    );
  }

  // Update _buildResizableWidget method to handle polygons specially
  Widget _buildResizableWidget(int index, LayeredCanvasItem item) {
    final isSelected = selectedItemIndex == index;

    // Special handling for polygons
    if (item.type == WidgetType.polygon) {
      return _buildPolygonResizableWidget(index, item, isSelected);
    }

    // Existing logic for other widget types...
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

              // Resize handle (only when selected and not polygon)
              if (isSelected && item.type != WidgetType.polygon)
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

  // Add this new method for polygon-specific resizable widget
  Widget _buildPolygonResizableWidget(
    int index,
    LayeredCanvasItem item,
    bool isSelected,
  ) {
    final points = List<Map<String, double>>.from(
      item.properties['points'] ?? [],
    );
    final isCreating = item.properties['isCreating'] as bool? ?? false;

    return Opacity(
      opacity: item.opacity,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedItemIndex = index;
            isPanelExpanded = true;
          });
        },
        child: Stack(
          children: [
            // Polygon widget
            SizedBox(
              width: item.size.width,
              height: item.size.height,
              child: _buildWidgetForType(item),
            ),

            // Point editing handles (when selected and not creating)
            if (isSelected && !isCreating)
              ...points.asMap().entries.map((entry) {
                final pointIndex = entry.key;
                final point = entry.value;

                return Positioned(
                  left: point['dx']! - 6,
                  top: point['dy']! - 6,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      final newPosition = Offset(
                        point['dx']! + details.delta.dx,
                        point['dy']! + details.delta.dy,
                      );
                      _updatePolygonPoint(item, pointIndex, newPosition);
                    },
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                );
              }).toList(),

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
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<Map<String, double>> points;
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;
  final bool isCreating;

  PolygonPainter({
    required this.points,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.isCreating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Convert points to Offset list
    final offsetPoints = points.map((p) => Offset(p['dx']!, p['dy']!)).toList();

    if (offsetPoints.length >= 2) {
      final path = Path();
      path.moveTo(offsetPoints.first.dx, offsetPoints.first.dy);

      for (int i = 1; i < offsetPoints.length; i++) {
        path.lineTo(offsetPoints[i].dx, offsetPoints[i].dy);
      }

      // Close the path if not creating (completed polygon)
      if (!isCreating && offsetPoints.length >= 3) {
        path.close();
        // Fill the polygon
        canvas.drawPath(path, fillPaint);
      }

      // Draw the stroke
      canvas.drawPath(path, paint);
    }

    // Draw points as small circles
    final pointPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    for (final point in offsetPoints) {
      canvas.drawCircle(point, 4.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
