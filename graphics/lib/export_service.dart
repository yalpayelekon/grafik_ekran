import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'project_models.dart';
import 'project_manager.dart';

class ExportService {
  // Export project as JSON for web runtime
  static Future<void> exportProjectToJson(String projectId) async {
    try {
      // Let user choose export location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Project',
        fileName: 'project_$projectId.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return; // User cancelled

      // Load project data
      final projects = await ProjectManager.loadProjects();
      final project = projects.firstWhere((p) => p.id == projectId);

      // Load all pages
      final pages = await ProjectManager.loadProjectPages(projectId);
      final pagesMap = <String, Map<String, dynamic>>{};
      for (final page in pages) {
        pagesMap[page.id] = page.toJson();
      }

      // Load and encode assets as base64
      final assetsMap = <String, String>{};
      final projectAssets = await ProjectManager.getProjectAssets(projectId);

      for (final asset in projectAssets) {
        try {
          final file = File(asset.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String =
                'data:image/${asset.extension?.substring(1) ?? 'png'};base64,${base64Encode(bytes)}';
            assetsMap[asset.path] = base64String;
          }
        } catch (e) {
          print('Failed to encode asset ${asset.path}: $e');
        }
      }

      // Create export data
      final exportData = {
        'project': project.toJson(),
        'pages': pagesMap,
        'assets': assetsMap,
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      // Write to file
      final file = File(result);
      await file.writeAsString(json.encode(exportData));

      print('Project exported successfully to: $result');
    } catch (e) {
      print('Export failed: $e');
      rethrow;
    }
  }

  // Export project as HTML package (complete web app)
  static Future<void> exportProjectAsWebApp(String projectId) async {
    try {
      // Let user choose export directory
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Export Web App To Folder',
      );

      if (result == null) return;

      final exportDir = Directory(result);

      // Create project export data (same as JSON export)
      final projects = await ProjectManager.loadProjects();
      final project = projects.firstWhere((p) => p.id == projectId);

      final pages = await ProjectManager.loadProjectPages(projectId);
      final pagesMap = <String, Map<String, dynamic>>{};
      for (final page in pages) {
        pagesMap[page.id] = page.toJson();
      }

      final assetsMap = <String, String>{};
      final projectAssets = await ProjectManager.getProjectAssets(projectId);

      for (final asset in projectAssets) {
        try {
          final file = File(asset.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String =
                'data:image/${asset.extension?.substring(1) ?? 'png'};base64,${base64Encode(bytes)}';
            assetsMap[asset.path] = base64String;
          }
        } catch (e) {
          print('Failed to encode asset ${asset.path}: $e');
        }
      }

      final exportData = {
        'project': project.toJson(),
        'pages': pagesMap,
        'assets': assetsMap,
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      // Create the web app structure
      await _createWebAppFiles(exportDir, exportData, project);

      print('Web app exported successfully to: $result');
    } catch (e) {
      print('Web app export failed: $e');
      rethrow;
    }
  }

  // Create complete web app files
  static Future<void> _createWebAppFiles(
    Directory exportDir,
    Map<String, dynamic> exportData,
    Project project,
  ) async {
    // Create index.html
    final indexHtml = _generateIndexHtml(project);
    await File(
      path.join(exportDir.path, 'index.html'),
    ).writeAsString(indexHtml);

    // Create data.js with embedded project data
    final dataJs = _generateDataJs(exportData);
    await File(path.join(exportDir.path, 'data.js')).writeAsString(dataJs);

    // Copy web runtime files (you would need to build the web runtime first)
    // For now, we'll create a simplified runtime
    final runtimeJs = _generateRuntimeJs();
    await File(
      path.join(exportDir.path, 'runtime.js'),
    ).writeAsString(runtimeJs);

    // Create CSS
    final css = _generateCss();
    await File(path.join(exportDir.path, 'styles.css')).writeAsString(css);

    // Create README
    final readme = _generateReadme(project);
    await File(path.join(exportDir.path, 'README.md')).writeAsString(readme);
  }

  // Generate index.html
  static String _generateIndexHtml(Project project) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${project.name}</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div id="app">
        <div id="loading">
            <div class="spinner"></div>
            <p>Loading ${project.name}...</p>
        </div>
    </div>
    
    <script src="data.js"></script>
    <script src="runtime.js"></script>
</body>
</html>
''';
  }

  // Generate data.js with embedded project data
  static String _generateDataJs(Map<String, dynamic> exportData) {
    return '''
// Generated project data
window.PROJECT_DATA = ${json.encode(exportData)};
''';
  }

  // Generate a simplified JavaScript runtime
  static String _generateRuntimeJs() {
    return '''
// Simple Web App Runtime
class WebAppRuntime {
    constructor() {
        this.currentPageId = null;
        this.project = null;
        this.pages = {};
        this.history = [];
    }

    async init() {
        try {
            const data = window.PROJECT_DATA;
            this.project = data.project;
            this.pages = data.pages;
            
            // Hide loading screen
            document.getElementById('loading').style.display = 'none';
            
            // Load first page
            if (this.project.pageIds.length > 0) {
                this.navigateToPage(this.project.pageIds[0]);
            }
        } catch (error) {
            console.error('Failed to initialize:', error);
            this.showError('Failed to load the application');
        }
    }

    navigateToPage(pageId) {
        const page = this.pages[pageId];
        if (!page) {
            console.error('Page not found:', pageId);
            return;
        }

        if (this.currentPageId) {
            this.history.push(this.currentPageId);
        }
        this.currentPageId = pageId;
        
        this.renderPage(page);
        this.updateUrl(pageId);
    }

    renderPage(page) {
        const appContainer = document.getElementById('app');
        
        // Create page container
        const pageContainer = document.createElement('div');
        pageContainer.id = 'page-container';
        pageContainer.style.cssText = `
            width: \${page.pageSize.width}px;
            height: \${page.pageSize.height}px;
            background-color: \${this.colorToHex(page.backgroundColor)};
            position: relative;
            margin: 0 auto;
            overflow: hidden;
        `;

        // Sort items by zIndex
        const sortedItems = page.canvasItems.sort((a, b) => a.zIndex - b.zIndex);

        // Render each canvas item
        sortedItems.forEach(item => {
            const element = this.createElementForItem(item);
            if (element) {
                pageContainer.appendChild(element);
            }
        });

        // Replace content
        appContainer.innerHTML = '';
        
        // Add navigation if there's history
        if (this.history.length > 0) {
            const backBtn = document.createElement('button');
            backBtn.textContent = '← Back';
            backBtn.style.cssText = `
                position: fixed;
                top: 10px;
                left: 10px;
                z-index: 1000;
                padding: 8px 16px;
                background: #2196F3;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
            `;
            backBtn.onclick = () => this.goBack();
            appContainer.appendChild(backBtn);
        }

        appContainer.appendChild(pageContainer);
    }

    createElementForItem(item) {
        const element = document.createElement('div');
        element.style.cssText = `
            position: absolute;
            left: \${item.position.dx}px;
            top: \${item.position.dy}px;
            width: \${item.size.width}px;
            height: \${item.size.height}px;
            opacity: \${item.opacity};
        `;

        switch (item.type) {
            case 'WidgetType.text':
                return this.createTextElement(item, element);
            case 'WidgetType.button':
                return this.createButtonElement(item, element);
            case 'WidgetType.container':
                return this.createContainerElement(item, element);
            case 'WidgetType.card':
                return this.createCardElement(item, element);
            case 'WidgetType.image':
                return this.createImageElement(item, element);
            case 'WidgetType.input':
                return this.createInputElement(item, element);
            default:
                return null;
        }
    }

    createTextElement(item, element) {
        element.style.cssText += `
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: \${item.properties.fontSize || 16}px;
            font-weight: \${item.properties.isBold ? 'bold' : 'normal'};
            font-style: \${item.properties.isItalic ? 'italic' : 'normal'};
            color: \${this.colorToHex(item.properties.color)};
            text-align: center;
        `;
        element.textContent = item.properties.text || 'Sample Text';
        return element;
    }

    createButtonElement(item, element) {
        const button = document.createElement('button');
        button.style.cssText = `
            width: 100%;
            height: 100%;
            background-color: \${this.colorToHex(item.properties.backgroundColor)};
            color: \${this.colorToHex(item.properties.textColor)};
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        `;
        button.textContent = item.properties.text || 'Button';
        
        if (item.linkedPageId) {
            button.onclick = () => this.navigateToPage(item.linkedPageId);
        }
        
        element.appendChild(button);
        return element;
    }

    createContainerElement(item, element) {
        element.style.cssText += `
            background-color: \${this.colorToHex(item.properties.backgroundColor)};
            display: flex;
            align-items: center;
            justify-content: center;
            color: \${this.colorToHex(item.properties.textColor)};
        `;
        element.textContent = item.properties.text || 'Container';
        return element;
    }

    createCardElement(item, element) {
        element.style.cssText += `
            background-color: \${this.colorToHex(item.properties.backgroundColor)};
            border-radius: 4px;
            box-shadow: 0 \${item.properties.elevation || 2}px \${(item.properties.elevation || 2) * 2}px rgba(0,0,0,0.2);
            display: flex;
            align-items: center;
            justify-content: center;
            color: \${this.colorToHex(item.properties.textColor)};
            padding: 8px;
        `;
        element.textContent = item.properties.text || 'Card Widget';
        return element;
    }

    createImageElement(item, element) {
        if (item.properties.imagePath && window.PROJECT_DATA.assets[item.properties.imagePath]) {
            const img = document.createElement('img');
            img.src = window.PROJECT_DATA.assets[item.properties.imagePath];
            img.style.cssText = 'width: 100%; height: 100%; object-fit: cover;';
            element.appendChild(img);
        } else {
            element.style.cssText += `
                background-color: #f0f0f0;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #999;
            `;
            element.textContent = 'No Image';
        }
        return element;
    }

    createInputElement(item, element) {
        const input = document.createElement('input');
        input.type = 'text';
        input.placeholder = item.properties.placeholder || 'Enter text...';
        input.style.cssText = `
            width: 100%;
            height: 100%;
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 14px;
        `;
        element.appendChild(input);
        return element;
    }

    colorToHex(color) {
        if (!color) return '#000000';
        if (typeof color === 'string') return color;
        if (typeof color === 'number') {
            return '#' + (color & 0xFFFFFF).toString(16).padStart(6, '0');
        }
        return '#000000';
    }

    goBack() {
        if (this.history.length > 0) {
            const previousPageId = this.history.pop();
            this.currentPageId = previousPageId;
            const page = this.pages[previousPageId];
            if (page) {
                this.renderPage(page);
                this.updateUrl(previousPageId);
            }
        }
    }

    updateUrl(pageId) {
        if (history.pushState) {
            history.pushState({ pageId }, '', `#\${pageId}`);
        }
    }

    showError(message) {
        const appContainer = document.getElementById('app');
        appContainer.innerHTML = `
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh;">
                <h1 style="color: red;">Error</h1>
                <p>\${message}</p>
            </div>
        `;
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    const runtime = new WebAppRuntime();
    runtime.init();
});
''';
  }

  // Generate CSS
  static String _generateCss() {
    return '''
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background-color: #f5f5f5;
    overflow-x: auto;
    overflow-y: auto;
}

#app {
    min-height: 100vh;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 20px;
}

#loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 50vh;
}

.spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #2196F3;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 16px;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

button:hover {
    opacity: 0.8;
    transform: translateY(-1px);
}

button:active {
    transform: translateY(0);
}

/* Responsive design */
@media (max-width: 768px) {
    #app {
        padding: 10px;
    }
}
''';
  }

  // Generate README
  static String _generateReadme(Project project) {
    return '''
# ${project.name}

This web application was created using Flutter Web App Designer.

## Project Information
- **Created:** ${project.createdAt}
- **Last Updated:** ${project.updatedAt}
- **Pages:** ${project.pageIds.length}
- **Default Size:** ${project.defaultPageSize.width.toInt()} × ${project.defaultPageSize.height.toInt()}

## How to Run
1. Open `index.html` in a web browser
2. Or serve from a web server for best results

## File Structure
- `index.html` - Main HTML file
- `data.js` - Embedded project data
- `runtime.js` - JavaScript runtime engine
- `styles.css` - Styling
- `README.md` - This file

## Features
- Responsive design
- Page navigation
- Interactive buttons
- Image support
- Form inputs

---
Generated by Flutter Web App Designer
''';
  }
}
