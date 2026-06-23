# New Features Documentation

## 🎉 Top 5 Features Implemented

### 1. ResponsiveGrid

Adaptive grid layout that automatically adjusts columns based on screen size.

#### Usage

```dart
ResponsiveGrid(
  children: [
    ItemCard(item1),
    ItemCard(item2),
    ItemCard(item3),
    // ... more items
  ],
  // Auto: 1 column on phone, 2 on tablet, 3 on desktop
  // Or customize:
  smallColumns: 1,
  mediumColumns: 2,
  largeColumns: 4,
  spacing: 12.0,
  runSpacing: 12.0,
  enableStaggerAnimation: true, // Optional stagger animations
)
```

#### Features
- ✅ Auto-adjusting columns based on breakpoints
- ✅ Stagger animations support
- ✅ Responsive spacing
- ✅ Customizable column counts per breakpoint

---

### 2. SwipeableCard

Swipe actions with smooth animations and haptic feedback.

#### Usage

```dart
SwipeableCard(
  onSwipeLeft: () => deleteItem(),
  onSwipeRight: () => archiveItem(),
  leftActionColor: Colors.red,
  rightActionColor: Colors.green,
  child: Card(
    child: ListTile(
      title: Text('Swipe me!'),
    ),
  ),
)
```

#### Features
- ✅ Left/right swipe actions
- ✅ Animated action reveals
- ✅ Haptic feedback
- ✅ Customizable thresholds
- ✅ Smooth snap-back animations

---

### 3. AdaptiveDialog

Automatically switches between dialog and bottom sheet based on screen size.

#### Usage

```dart
AdaptiveDialog.show(
  context: context,
  title: 'Settings',
  child: SettingsForm(),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: () => save(),
      child: Text('Save'),
    ),
  ],
)
```

#### Features
- ✅ Auto-adapts to screen size
- ✅ Dialog on tablet/desktop
- ✅ Bottom sheet on phone
- ✅ Smooth transitions
- ✅ Customizable max width/height

---

### 4. ResponsiveTypography

Complete typography system that adapts to screen sizes and accessibility.

#### Usage

```dart
// Simple usage
ResponsiveText(
  'Hello World',
  style: ResponsiveTextStyle.headlineLarge,
)

// With customization
ResponsiveText(
  'Custom Text',
  style: ResponsiveTextStyle.bodyLarge,
  color: Colors.blue,
  fontWeight: FontWeight.bold,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)

// Or use helper directly
Text(
  'Hello',
  style: ResponsiveTypography.getStyle(
    context,
    style: ResponsiveTextStyle.titleMedium,
  ),
)
```

#### Available Styles
- `displayLarge`, `displayMedium`, `displaySmall`
- `headlineLarge`, `headlineMedium`, `headlineSmall`
- `titleLarge`, `titleMedium`, `titleSmall`
- `bodyLarge`, `bodyMedium`, `bodySmall`
- `labelLarge`, `labelMedium`, `labelSmall`

#### Features
- ✅ Pre-defined text styles
- ✅ Respects accessibility font scaling
- ✅ Responsive line heights
- ✅ Adaptive letter spacing
- ✅ Material Design 3 compliant

---

### 5. BreakpointBuilder

Clean way to render different widgets based on screen size.

#### Usage

```dart
// Using builder
BreakpointBuilder(
  builder: (context, breakpoint) {
    if (breakpoint.isSmall) return MobileLayout();
    if (breakpoint.isMedium) return TabletLayout();
    return DesktopLayout();
  },
)

// Using specific widgets
BreakpointBuilder(
  small: MobileLayout(),
  medium: TabletLayout(),
  large: DesktopLayout(),
)

// Responsive value builder
ResponsiveValueBuilder<int>(
  small: 1,
  medium: 2,
  large: 3,
  builder: (context, columns) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
      ),
      itemBuilder: (context, index) => ItemCard(),
    );
  },
)
```

#### Breakpoint Information
```dart
class Breakpoint {
  final bool isSmall;      // Phone
  final bool isMedium;    // Tablet
  final bool isLarge;     // Desktop
  final double width;      // Screen width
  final double height;     // Screen height
  final Orientation orientation; // Portrait/Landscape
}
```

#### Features
- ✅ Clean conditional rendering
- ✅ Multiple breakpoint checks
- ✅ Responsive to orientation changes
- ✅ Performance optimized
- ✅ Access to screen dimensions

---

## Additional Features (6-15)

### 6. ParallaxScroll

Parallax scrolling effects with responsive calculations.

```dart
ParallaxScroll(
  backgroundImageUrl: 'https://example.com/bg.jpg',
  scrollSpeed: 0.5, // Responsive based on screen size
  child: ListView(
    children: [
      // Your scrollable content
    ],
  ),
)
```

### 7. StaggeredGrid

Pinterest-style masonry grid with responsive columns.

```dart
StaggeredGrid(
  children: items.map((item) => ItemCard(item)).toList(),
  smallColumns: 2,
  mediumColumns: 3,
  largeColumns: 4,
  enableStaggerAnimation: true,
)
```

### 8. ResponsiveImage

Automatically loads appropriate image sizes.

```dart
ResponsiveImage(
  imageUrl: 'https://example.com/image.jpg',
  smallImageUrl: 'https://example.com/image-small.jpg',
  mediumImageUrl: 'https://example.com/image-medium.jpg',
  largeImageUrl: 'https://example.com/image-large.jpg',
  placeholder: ShimmerContainer(),
)
```

### 9. AdaptiveNavigation

Smart navigation that adapts to screen size.

```dart
AdaptiveNavigation(
  items: [
    AdaptiveNavItem(
      label: 'Home',
      icon: Icons.home,
      onTap: () => navigateToHome(),
    ),
    // More items...
  ],
  currentIndex: 0,
  // Drawer on phone, Tabs on tablet, Rail on desktop
)
```

### 10. LoadingSkeleton

Pre-built skeleton screens for common patterns.

```dart
// Article layout
LoadingSkeleton.article(context)

// Card layout
LoadingSkeleton.card(context)

// Profile layout
LoadingSkeleton.profile(context)

// List layout
LoadingSkeleton.list(context, itemCount: 5)

// Grid layout
LoadingSkeleton.grid(context, columns: 2, rows: 3)
```

### 11. ResponsiveForm

Adaptive form widgets with responsive layouts.

```dart
ResponsiveForm(
  formKey: _formKey,
  fields: [
    ResponsiveTextField(
      label: 'Name',
      controller: nameController,
    ),
    ResponsiveTextField(
      label: 'Email',
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
    ),
    // Stacks on phone, side-by-side on tablet
  ],
  submitButton: AnimatedButton(
    onPressed: () => submit(),
    child: Text('Submit'),
  ),
)
```

### 12. DragAndDropList

Reorderable list with smooth animations.

```dart
DragAndDropList(
  items: todos.map((todo) => DragAndDropListItem(
    data: todo,
    id: todo.id,
    child: TodoCard(todo),
  )).toList(),
  onReorder: (oldIndex, newIndex) {
    final item = todos.removeAt(oldIndex);
    todos.insert(newIndex, item);
  },
)
```

### 13. ResponsiveSpacing

Adaptive spacing system with pre-defined scales.

```dart
Column(
  children: [
    Text('Item 1'),
    ResponsiveSpacing.sm(context), // 8px on phone, 12px on tablet
    Text('Item 2'),
    ResponsiveSpacing.md(context), // 16px on phone, 24px on tablet
    Text('Item 3'),
    ResponsiveSpacing.lg(context), // 24px on phone, 32px on tablet
  ],
)

// Or get values
final spacing = ResponsiveSpacing.mdValue(context);
```

### 14. AnimatedCounter

Number counter with smooth counting animations.

```dart
AnimatedCounter(
  value: 1234,
  duration: Duration(seconds: 2),
  prefix: '\$',
  suffix: '.00',
  enableThousandsSeparator: true,
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)
```

### 15. ResponsiveCharts

Adaptive chart helpers with responsive sizing and legends.

```dart
ResponsiveChartContainer(
  title: 'Sales Overview',
  subtitle: 'Last 30 days',
  chart: YourChartWidget(),
  legend: ResponsiveLegend(
    dataPoints: [
      ChartDataPoint(label: 'Product A', value: 100, color: Colors.blue),
      ChartDataPoint(label: 'Product B', value: 200, color: Colors.green),
    ],
    horizontal: true,
  ),
)
```

### 16. InfiniteScroll

Auto-loading lists with pagination handling.

```dart
InfiniteScroll(
  loadData: (page, pageSize) async {
    return await apiService.getItems(page, pageSize);
  },
  itemBuilder: (context, item, index) {
    return ListTile(title: Text(item.name));
  },
  pageSize: 20,
  loadingWidget: CircularProgressIndicator(),
)
```

### 17. ResponsiveCarousel

Adaptive carousel with responsive item counts and auto-play.

```dart
ResponsiveCarousel(
  children: [
    Image.network('image1.jpg'),
    Image.network('image2.jpg'),
    Image.network('image3.jpg'),
  ],
  autoPlay: true,
  showIndicators: true,
  showArrows: true,
)
```

### 18. AdaptiveBottomSheet

Smart bottom sheets with auto height calculation.

```dart
AdaptiveBottomSheet.show(
  context: context,
  title: 'Settings',
  child: SettingsForm(),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('Cancel'),
    ),
  ],
)
```

### 19. ResponsiveAppBar

Adaptive app bar with auto-collapsing on scroll.

```dart
ResponsiveAppBar(
  titleText: 'My App',
  actions: [
    IconButton(icon: Icon(Icons.search), onPressed: () {}),
  ],
  collapseOnScroll: true,
  scrollController: scrollController,
)
```

---

## Complete Example

```dart
import 'package:gems_responsive/gems_responsive.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ResponsiveText(
          'My App',
          style: ResponsiveTextStyle.headlineMedium,
        ),
      ),
      body: BreakpointBuilder(
        builder: (context, breakpoint) {
          if (breakpoint.isSmall) {
            return _MobileLayout();
          }
          return _DesktopLayout();
        },
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return SwipeableCard(
          onSwipeLeft: () => deleteItem(items[index]),
          child: Card(child: ItemWidget(items[index])),
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      children: items.map((item) => ItemCard(item)).toList(),
      mediumColumns: 3,
      largeColumns: 4,
      enableStaggerAnimation: true,
    );
  }
}
```

---

## Benefits

1. **ResponsiveGrid** - No more manual column calculations
2. **SwipeableCard** - Better UX with swipe actions
3. **AdaptiveDialog** - One widget, works everywhere
4. **ResponsiveTypography** - Consistent text across devices
5. **BreakpointBuilder** - Clean responsive code

All features are:
- ✅ Fully responsive
- ✅ Performance optimized
- ✅ Highly customizable
- ✅ Production ready
