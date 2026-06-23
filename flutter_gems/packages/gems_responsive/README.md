# gems_responsive

A professional responsive helper class for Flutter apps. Provides consistent sizing across devices with smart tablet support using `flutter_screenutil`.

## Features

### Responsive Utilities
- ✅ **Smart Device Detection** - Automatically detects small, medium, and large devices
- ✅ **Responsive Sizing** - Width, height, font size, padding, margin, and more
- ✅ **Tablet Optimization** - Intelligent scaling limits for tablets to prevent oversized UI
- ✅ **ScreenUtil Integration** - Works seamlessly with `flutter_screenutil` when available
- ✅ **Fallback Support** - Works even without ScreenUtil initialization
- ✅ **Safe Area Support** - Built-in safe area and viewport helpers

### Animated Widgets
- ✅ **AnimatedIcon** - Icons with scale, rotation, bounce, pulse, and fade animations
- ✅ **ExpandableCard** - Smooth expand/collapse cards for accordions and collapsible sections
- ✅ **AnimatedButton** - Buttons with micro-interactions, loading states, and press animations
- ✅ **Transitions** - Fade, slide, scale, and combined transition widgets
- ✅ **ShimmerLoading** - Shimmer effects for skeleton screens and loading states
- ✅ **AnimatedListItem** - List items with stagger animations for smooth appearances
- ✅ **PulseAnimation & BounceAnimation** - Attention-grabbing pulse and bounce effects

### Responsive Layout Widgets
- ✅ **ResponsiveGrid** - Adaptive grid layout that auto-adjusts columns based on screen size
- ✅ **SwipeableCard** - Swipe actions with smooth animations and haptic feedback
- ✅ **AdaptiveDialog** - Automatically shows as dialog or bottom sheet based on device
- ✅ **ResponsiveTypography** - Complete typography system with pre-defined responsive styles
- ✅ **BreakpointBuilder** - Clean conditional rendering based on screen size and breakpoints
- ✅ **ParallaxScroll** - Parallax scrolling effects with responsive calculations
- ✅ **StaggeredGrid** - Pinterest-style masonry grid with responsive columns
- ✅ **ResponsiveImage** - Automatically loads appropriate image sizes
- ✅ **AdaptiveNavigation** - Smart navigation (drawer/tabs/rail) based on screen size
- ✅ **LoadingSkeleton** - Pre-built skeleton screens for common UI patterns
- ✅ **ResponsiveForm** - Adaptive form widgets with responsive layouts
- ✅ **DragAndDropList** - Reorderable list with smooth animations
- ✅ **ResponsiveSpacing** - Adaptive spacing system with pre-defined scales
- ✅ **AnimatedCounter** - Number counter with smooth counting animations
- ✅ **ResponsiveCharts** - Adaptive chart helpers with responsive sizing
- ✅ **InfiniteScroll** - Auto-loading lists with pagination handling
- ✅ **ResponsiveCarousel** - Adaptive carousel with responsive item counts
- ✅ **AdaptiveBottomSheet** - Smart bottom sheets with auto height calculation
- ✅ **ResponsiveAppBar** - Adaptive app bar with auto-collapsing on scroll

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  gems_responsive: ^0.1.0
  flutter_screenutil: ^5.9.0  # Required dependency
```

Then run:

```bash
flutter pub get
```

## Usage

### Initialize ScreenUtil (Recommended)

In your `main.dart`, initialize `ScreenUtil`:

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Base design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          home: HomePage(),
        );
      },
    );
  }
}
```

### Basic Usage

```dart
import 'package:gems_responsive/gems_responsive.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: ResponsiveHelper.getResponsiveWidth(context, 100),
      height: ResponsiveHelper.getResponsiveHeight(context, 50),
      padding: ResponsiveHelper.getResponsivePadding(context, all: 16),
      child: Text(
        'Hello',
        style: TextStyle(
          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
        ),
      ),
    );
  }
}
```

### Device Detection

```dart
if (ResponsiveHelper.isSmallDevice(context)) {
  // Phone layout
} else if (ResponsiveHelper.isMediumDevice(context)) {
  // Tablet layout
} else if (ResponsiveHelper.isLargeDevice(context)) {
  // Desktop/large tablet layout
}
```

### Responsive Values

```dart
final columns = ResponsiveHelper.getResponsiveValue<int>(
  context,
  small: 1,   // 1 column on phone
  medium: 2,  // 2 columns on tablet
  large: 3,   // 3 columns on desktop
);
```

### Shorthand Methods

```dart
// Quick responsive sizing
Container(
  width: ResponsiveHelper.w(100),
  height: ResponsiveHelper.h(50),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(ResponsiveHelper.r(8)),
  ),
  child: Text(
    'Text',
    style: TextStyle(fontSize: ResponsiveHelper.sp(16)),
  ),
)
```

### Bottom Navigation with Get Router

```dart
// In a GetMaterialApp.router setup
class RootShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveBottomNavShell(
      initialRoute: '/home',
      items: const [
        ResponsiveNavItem(route: '/home', label: 'Home', icon: Icons.home),
        ResponsiveNavItem(route: '/todos', label: 'Todos', icon: Icons.check_circle),
        ResponsiveNavItem(route: '/settings', label: 'Settings', icon: Icons.settings),
      ],
    );
  }
}
```

## API Reference

### Screen Dimensions
- `getScreenSize(BuildContext)` - Get screen size
- `getScreenWidth(BuildContext)` - Get screen width
- `getScreenHeight(BuildContext)` - Get screen height
- `getViewportWidth(BuildContext)` - Get viewport width (excluding safe areas)
- `getViewportHeight(BuildContext)` - Get viewport height (excluding safe areas)

### Responsive Sizing
- `getResponsiveWidth(BuildContext, double)` - Responsive width
- `getResponsiveHeight(BuildContext, double)` - Responsive height
- `getResponsiveSize(BuildContext, double)` - Responsive size (square)
- `getResponsiveFontSize(BuildContext, double)` - Responsive font size
- `getResponsiveRadius(BuildContext, double)` - Responsive border radius

### Padding & Margins
- `getResponsivePadding(BuildContext, {...})` - Responsive padding
- `getResponsivePaddingDirectional(BuildContext, {...})` - Directional padding
- `getResponsiveMargin(BuildContext, {...})` - Responsive margin
- `getSafeAreaPadding(BuildContext)` - Safe area padding

### Spacing
- `getResponsiveSpacing(BuildContext, double)` - Vertical spacing
- `getResponsiveHorizontalSpacing(BuildContext, double)` - Horizontal spacing

### Device Detection
- `isSmallDevice(BuildContext)` - Check if phone
- `isMediumDevice(BuildContext)` - Check if tablet
- `isLargeDevice(BuildContext)` - Check if desktop/large tablet
- `getResponsiveValue<T>(BuildContext, {small, medium?, large?})` - Get value based on device

### Constraints
- `getResponsiveConstraints(BuildContext, {...})` - Responsive box constraints
- `clampResponsive(BuildContext, double, {min?, max?})` - Clamp responsive value

### Shorthand Methods
- `w(double)` - Responsive width
- `h(double)` - Responsive height
- `sp(double)` - Responsive font size
- `r(double)` - Responsive radius

## Animated Widgets

The package includes a comprehensive set of animated widgets for creating engaging user interfaces.

### Quick Examples

#### AnimatedIcon
```dart
AnimatedIcon(
  icon: Icons.favorite,
  animationType: AnimationType.pulse,
  repeat: true,
  color: Colors.red,
)
```

#### ExpandableCard
```dart
ExpandableCard(
  title: Text('Click to expand'),
  child: Text('Expanded content'),
  initiallyExpanded: false,
)
```

#### AnimatedButton
```dart
AnimatedButton(
  onPressed: () => print('Pressed'),
  child: Text('Click Me'),
  isLoading: false,
)
```

#### ShimmerLoading
```dart
ShimmerLoading(
  child: Container(
    width: 200,
    height: 100,
    color: Colors.white,
  ),
)
```

#### AnimatedListItem
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return AnimatedListItem(
      index: index,
      animationType: AnimationType.fadeSlide,
      child: ListTile(title: Text('Item $index')),
    );
  },
)
```

For detailed documentation on all animated widgets, see [ANIMATED_WIDGETS.md](ANIMATED_WIDGETS.md).

### Responsive Layout Widgets

#### ResponsiveGrid
```dart
ResponsiveGrid(
  children: items.map((item) => ItemCard(item)).toList(),
  smallColumns: 1,   // 1 column on phone
  mediumColumns: 2,   // 2 columns on tablet
  largeColumns: 3,    // 3 columns on desktop
  enableStaggerAnimation: true,
)
```

#### SwipeableCard
```dart
SwipeableCard(
  onSwipeLeft: () => deleteItem(),
  onSwipeRight: () => archiveItem(),
  child: Card(child: ListTile(title: Text('Swipe me'))),
)
```

#### AdaptiveDialog
```dart
AdaptiveDialog.show(
  context: context,
  title: 'Settings',
  child: SettingsForm(),
  // Auto: Dialog on tablet, Bottom sheet on phone
)
```

#### ResponsiveTypography
```dart
ResponsiveText(
  'Hello World',
  style: ResponsiveTextStyle.headlineLarge,
)
```

#### BreakpointBuilder
```dart
BreakpointBuilder(
  builder: (context, breakpoint) {
    if (breakpoint.isSmall) return MobileLayout();
    return DesktopLayout();
  },
)
```

For detailed documentation on new features, see [NEW_FEATURES.md](NEW_FEATURES.md).

## Author

**Md. Adnan Ullah**
- Email: saadnanullah@gmail.com
- GitHub: [md-adnan-ullah](https://github.com/md-adnan-ullah)

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
