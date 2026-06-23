# Flutter Gems

#Usage guide
r## Option 1

```bash
Just command this line in your project terminal
git submodule add https://github.com/md-adnan-ullah/flutter_gems.git flutter_gems 
git submodule update --init --recursive

reuse:
git submodule add -f -b develop https://github.com/md-adnan-ullah/flutter_gems.git flutter_gems
git submodule update --init --recursive
git submodule update --remote --merge


r## Option 2

```bash
rm -rf flutter_gems
git clone -b develop --single-branch https://github.com/md-adnan-ullah/flutter_gems.git flutter_gems
rm -rf flutter_gems/.git
git add flutter_gems
git commit -m "chore: update flutter_gems to latest develop"


A comprehensive Flutter package collection providing responsive UI widgets, core utilities, and data layer functionality.

## 📦 Packages

This repository contains 3 main packages:

1. **[gems_responsive](packages/gems_responsive/)** - 25+ responsive UI widgets and helpers
2. **[gems_core](packages/gems_core/)** - Core utilities (Result types, error handling, validation)
3. **[gems_data_layer](packages/gems_data_layer/)** - Data layer (REST API, CRUD, Auth, Cache, Offline sync)

## 🚀 Quick Start

See **[USAGE_GUIDE.md](USAGE_GUIDE.md)** for complete instructions on using these packages in a new project.

### Using in a New Project

**Method 1: Local Path (Development)**
```yaml
dependencies:
  gems_responsive:
    path: ../flutter_gems/packages/gems_responsive
  gems_core:
    path: ../flutter_gems/packages/gems_core
  gems_data_layer:
    path: ../flutter_gems/packages/gems_data_layer
```

**Method 2: Git Repository**
```yaml
dependencies:
  gems_responsive:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_responsive
      ref: main
  gems_core:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_core
      ref: main
  gems_data_layer:
    git:
      url: https://github.com/yourusername/flutter_gems.git
      path: packages/gems_data_layer
      ref: main
```

For detailed instructions, see **[USAGE_GUIDE.md](USAGE_GUIDE.md)**.

## 📚 Documentation

- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Complete guide on using all packages
- **[packages/gems_responsive/README.md](packages/gems_responsive/README.md)** - Responsive widgets documentation
- **[packages/gems_core/README.md](packages/gems_core/README.md)** - Core utilities documentation
- **[packages/gems_data_layer/README.md](packages/gems_data_layer/README.md)** - Data layer documentation

## 🎯 Features

### gems_responsive
- 25+ responsive widgets
- Animated components
- Adaptive layouts
- Responsive typography
- Breakpoint builders

### gems_core
- Result type for error handling
- Input validation
- Environment configuration
- Dependency injection helpers

### gems_data_layer
- REST API service
- CRUD operations
- Authentication
- Offline sync
- Hive database integration

## 📝 License

MIT License - see LICENSE files in each package directory.

## 👤 Author

**Md. Adnan Ullah**
- Email: saadnanullah@gmail.com
- GitHub: [md-adnan-ullah](https://github.com/md-adnan-ullah)

---

## Original Project

This was originally a Flutter project demonstrating the packages.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
