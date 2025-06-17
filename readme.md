# Flutter Web App Designer

A comprehensive visual web application designer built with Flutter. Create stunning web applications using an intuitive drag-and-drop interface, then deploy them as standalone web apps or run them in a Flutter web runtime.

## 🚀 Overview

Flutter Web App Designer is a complete visual development environment that allows you to:
- **Design** web applications visually using drag-and-drop
- **Preview** your designs with real-time editing
- **Export** as standalone web apps or Flutter web projects
- **Deploy** anywhere without dependencies

### Two-App Architecture
1. **Desktop Designer** (`graphics/`) - Visual design environment
2. **Web Runtime** (`web_runtime/`) - Displays designed apps in browser

## ✨ Key Features

### 🎨 Visual Design Studio
- **Drag & Drop Interface** - Intuitive component placement
- **Layer Management** - Control depth and overlapping with z-index
- **Real-time Preview** - See changes instantly as you design
- **Component Library** - Text, Buttons, Images, Containers, Cards, Inputs
- **Property Panels** - Fine-tune colors, fonts, sizes, and positioning
- **Grid Snapping** - Precise alignment and positioning

### 🔗 Navigation System
- **Page Linking** - Connect pages with button navigation
- **Navigation History** - Built-in back button functionality
- **Deep Linking** - URL-based page routing (web runtime)
- **Visual Flow** - See navigation connections in designer

### 📁 Asset Management
- **File Explorer** - Windows-style file browser
- **Multi-Drive Support** - Access all drives (C:, D:, etc.)
- **Image Import** - Copy images to project assets
- **Format Support** - PNG, JPG, GIF, BMP, WebP
- **Preview Mode** - View images before importing

### 📤 Export Options
- **JSON Export** - For Flutter web runtime deployment
- **Standalone Web App** - Complete HTML/CSS/JS package
- **Asset Optimization** - Base64 embedded images
- **Cross-Platform** - Works on any web server

### 🌐 Web Runtime
- **Perfect Rendering** - 1:1 reproduction of designs
- **Responsive Design** - Scrollable for larger page sizes
- **Fast Loading** - Optimized for performance
- **Browser Compatible** - Works in all modern browsers

## 🏗️ Project Structure

```
flutter-web-app-designer/
├── graphics/                    # Desktop Designer Application
│   ├── lib/
│   │   ├── main.dart           # Application entry point
│   │   ├── project_models.dart  # Data models and structures
│   │   ├── project_manager.dart # File system operations
│   │   ├── home_screen.dart    # Project management UI
│   │   ├── page_editor.dart    # Visual design editor
│   │   ├── file_explorer.dart  # Asset management system
│   │   └── export_service.dart # Export functionality
│   ├── pubspec.yaml            # Dependencies
│   └── windows/                # Windows-specific configuration
└── web_runtime/                # Web Runtime Application
    ├── lib/
    │   ├── main.dart           # Runtime entry point
    │   ├── web_runtime_models.dart     # Shared data models
    │   ├── web_runtime_service.dart    # Data loading service
    │   └── web_runtime_app.dart       # Runtime engine
    ├── pubspec.yaml            # Web-specific dependencies
    └── web/                    # Flutter web configuration
```

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Windows 10/11 (for desktop app)
- Chrome/Edge browser (for web runtime)

### 1. Clone Repository
```bash
git clone https://github.com/yalpayelekon/grafik_ekran.git
cd grafik_ekran
```

### 2. Setup Desktop Designer
```bash
cd graphics
flutter pub get
flutter run -d windows
```

### 3. Setup Web Runtime
```bash
cd web_runtime
flutter pub get
flutter run -d chrome
```

## 📋 Usage Guide

### Creating Your First Web App

#### 1. **Project Creation**
1. Launch the desktop designer
2. Click the **+** button to create a new project
3. Enter project name and select default page size
4. Choose from preset sizes (Full HD, Laptop, Mobile, etc.)

#### 2. **Page Design**
1. Click **+** in the project to create a new page
2. Use the component sidebar to add elements:
   - **Text** - Headlines, paragraphs, labels
   - **Button** - Navigation and action buttons
   - **Image** - Photos, logos, graphics
   - **Container** - Colored backgrounds and sections
   - **Card** - Elevated content blocks
   - **Input** - Form fields and text inputs

#### 3. **Component Customization**
1. Select any component to open the properties panel
2. Customize appearance:
   - **Colors** - Background, text, border colors
   - **Typography** - Font size, bold, italic
   - **Layout** - Position, size, padding
   - **Layer** - Z-index, opacity for overlapping

#### 4. **Navigation Setup**
1. Select a button component
2. Open the **Navigation** section in properties
3. Choose target page from dropdown or enter page ID
4. Test navigation in preview mode

#### 5. **Asset Management**
1. Click **Image** component to open file explorer
2. Browse your computer's drives and folders
3. Select image files to import
4. Images are automatically copied to project assets

### Export & Deployment

#### JSON Export (for Flutter Web Runtime)
```bash
# In designer app:
1. Right-click project → Export → JSON Data
2. Save the .json file
3. Upload to web runtime via developer tools
```

#### Standalone Web App Export
```bash
# In designer app:
1. Right-click project → Export → Web App
2. Select destination folder
3. Upload folder contents to any web server
```

#### Web Runtime Deployment
```bash
# Build and deploy web runtime:
cd web_runtime
flutter build web
# Upload build/web/ folder to hosting provider
```

## 🎯 Component Reference

### Text Component
- **Properties**: Text content, font size, bold, italic, color
- **Use Cases**: Headlines, paragraphs, labels, captions
- **Best Practices**: Use appropriate font sizes for hierarchy

### Button Component
- **Properties**: Text, background color, text color, navigation link
- **Use Cases**: Navigation, form submission, call-to-action
- **Navigation**: Link to other pages by ID

### Image Component
- **Properties**: Image source, fit mode
- **Supported Formats**: PNG, JPG, GIF, BMP, WebP
- **Import**: Use file explorer to add images to project

### Container Component
- **Properties**: Background color, text content, text color
- **Use Cases**: Headers, sections, colored backgrounds
- **Layout**: Perfect for creating page structure

### Card Component
- **Properties**: Text, background color, text color, elevation
- **Use Cases**: Content blocks, feature highlights, information panels
- **Styling**: Configurable shadow elevation

### Input Component
- **Properties**: Placeholder text
- **Use Cases**: Contact forms, search boxes, user input
- **Note**: Functional in runtime, display-only in designer

## 🔧 Advanced Features

### Layer Management
- **Z-Index Control** - Precise layering of overlapping elements
- **Visual Indicators** - See layer numbers on selected items
- **Layer Panel** - Drag to reorder layers
- **Opacity Settings** - Create transparent overlays

### Responsive Design
- **Fixed Layouts** - Pages maintain designed dimensions
- **Scrollable Viewport** - Larger pages scroll in smaller browsers
- **Multi-Device Testing** - Preview on different screen sizes

### Performance Optimization
- **Asset Compression** - Images optimized for web delivery
- **Lazy Loading** - Components load as needed
- **Minimal Runtime** - Lightweight JavaScript engine
- **Fast Exports** - Optimized build process

## 🌐 Deployment Options

### 1. Flutter Web Runtime
```bash
# Best for: Dynamic content, multiple projects
cd web_runtime
flutter build web --release
# Deploy build/web/ to hosting
```

### 2. Standalone Web Apps
```bash
# Best for: Single projects, simple hosting
# Export from designer → Upload to any web server
# No build process required
```

## 🧪 Testing & Quality Assurance

### Built-in Testing Tools
- **Project Validation** - Verify data integrity
- **Navigation Testing** - Check all page links
- **Export Verification** - Validate exported data
- **Performance Monitoring** - Load time analysis

### Manual Testing Checklist
- [ ] All components render correctly
- [ ] Navigation flows work as intended
- [ ] Images display properly
- [ ] Export process completes successfully
- [ ] Web runtime loads without errors
- [ ] Cross-browser compatibility verified

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:
* will be added later

---

*Made with ❤️ using Flutter*