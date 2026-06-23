# Animated Widgets Guide

This document provides a comprehensive guide to all animated widgets in the `gems_responsive` package.

## Table of Contents

1. [AnimatedIcon](#animatedicon)
2. [ExpandableCard](#expandablecard)
3. [AnimatedButton](#animatedbutton)
4. [Transitions](#transitions)
5. [ShimmerLoading](#shimmerloading)
6. [AnimatedListItem](#animatedlistitem)
7. [PulseAnimation & BounceAnimation](#pulseanimation--bounceanimation)

---

## AnimatedIcon

A customizable icon widget with various animation types.

### Features
- Multiple animation types: scale, rotation, bounce, pulse, fade
- Customizable duration and curves
- Repeat animations
- Tap interactions

### Usage

```dart
import 'package:gems_responsive/gems_responsive.dart';

// Scale animation
AnimatedIcon(
  icon: Icons.favorite,
  animationType: AnimationType.scale,
  size: 24,
  color: Colors.red,
  repeat: true,
)

// Rotation animation
AnimatedIcon(
  icon: Icons.refresh,
  animationType: AnimationType.rotation,
  rotationAngle: 360,
  duration: Duration(seconds: 2),
  onTap: () => print('Tapped'),
)

// Pulse animation
AnimatedIcon(
  icon: Icons.notifications,
  animationType: AnimationType.pulse,
  repeat: true,
  minScale: 0.9,
  maxScale: 1.1,
)
```

### Parameters
- `icon` (required): The icon to display
- `size`: Icon size (defaults to responsive 24)
- `color`: Icon color
- `animationType`: Type of animation (scale, rotation, bounce, pulse, fade)
- `duration`: Animation duration
- `curve`: Animation curve
- `onTap`: Callback when tapped
- `repeat`: Whether to repeat animation
- `minScale` / `maxScale`: Scale bounds for scale animations
- `rotationAngle`: Rotation angle for rotation animations

---

## ExpandableCard

A card widget with smooth expand/collapse animations, perfect for accordions and collapsible sections.

### Features
- Smooth expand/collapse animations
- Customizable header with title, subtitle, leading, and trailing widgets
- Maintain state option
- Customizable styling

### Usage

```dart
ExpandableCard(
  title: Text('Click to expand'),
  subtitle: Text('Additional information'),
  initiallyExpanded: false,
  child: Column(
    children: [
      Text('Expanded content here'),
      // More widgets...
    ],
  ),
  onExpansionChanged: () => print('Expansion changed'),
)

// With custom styling
ExpandableCard(
  title: Text('Custom Card'),
  child: Text('Content'),
  backgroundColor: Colors.blue.shade50,
  borderRadius: BorderRadius.circular(16),
  elevation: 4,
  padding: EdgeInsets.all(20),
)
```

### Parameters
- `title` (required): Header title widget
- `subtitle`: Optional subtitle widget
- `child` (required): Content to show when expanded
- `initiallyExpanded`: Whether card starts expanded
- `duration`: Animation duration
- `curve`: Animation curve
- `padding` / `margin`: Spacing
- `backgroundColor`: Card background color
- `elevation`: Card elevation
- `borderRadius`: Border radius
- `expandIcon` / `collapseIcon`: Custom icons
- `onExpansionChanged`: Callback when expansion changes
- `maintainState`: Keep widget state when collapsed
- `leading` / `trailing`: Additional header widgets

---

## AnimatedButton

A button widget with micro-interactions and loading states.

### Features
- Scale animation on press
- Ripple effects
- Loading state support
- Fully customizable styling
- Responsive sizing

### Usage

```dart
AnimatedButton(
  onPressed: () => print('Button pressed'),
  child: Text('Click Me'),
)

// With loading state
AnimatedButton(
  onPressed: () async {
    // Do async work
  },
  isLoading: true,
  child: Text('Loading...'),
)

// Custom styling
AnimatedButton(
  onPressed: () {},
  child: Text('Custom Button'),
  backgroundColor: Colors.blue,
  foregroundColor: Colors.white,
  borderRadius: 12,
  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  minScale: 0.95,
  maxScale: 1.0,
)
```

### Parameters
- `child` (required): Button content
- `onPressed`: Callback when pressed
- `style`: Button style
- `animationDuration`: Animation duration
- `animationCurve`: Animation curve
- `minScale` / `maxScale`: Scale bounds
- `showRipple`: Show ripple effect
- `isLoading`: Show loading indicator
- `loadingWidget`: Custom loading widget
- `padding`: Button padding
- `borderRadius`: Border radius
- `backgroundColor` / `foregroundColor`: Colors
- `elevation`: Button elevation
- `minimumSize` / `maximumSize`: Size constraints
- `enabled`: Enable/disable button

---

## Transitions

A collection of transition widgets for smooth animations.

### FadeTransitionWidget

```dart
FadeTransitionWidget(
  duration: Duration(milliseconds: 500),
  child: Text('Fading in...'),
)
```

### SlideTransitionWidget

```dart
SlideTransitionWidget(
  direction: SlideDirection.fromBottom,
  distance: 100,
  child: Text('Sliding in...'),
)
```

### FadeSlideTransition

```dart
FadeSlideTransition(
  slideDirection: SlideDirection.fromRight,
  child: Container(
    child: Text('Fade and slide'),
  ),
)
```

### ScaleTransitionWidget

```dart
ScaleTransitionWidget(
  beginScale: 0.0,
  endScale: 1.0,
  child: Text('Scaling in...'),
)
```

---

## ShimmerLoading

Shimmer effect for skeleton screens and loading states.

### Features
- Custom shimmer colors
- Multiple directions
- Pre-built components (container, list item)

### Usage

```dart
// Basic shimmer
ShimmerLoading(
  child: Container(
    width: 200,
    height: 100,
    color: Colors.white,
  ),
)

// Pre-built container
ShimmerContainer(
  width: 200,
  height: 100,
  borderRadius: 8,
)

// Pre-built list item
ShimmerListItem(
  hasAvatar: true,
  hasSubtitle: true,
  lines: 3,
)
```

### Parameters
- `child`: Widget to apply shimmer to
- `baseColor`: Base shimmer color
- `highlightColor`: Highlight shimmer color
- `period`: Animation period
- `direction`: Shimmer direction (ltr, rtl, ttb, btt)

---

## AnimatedListItem

List items with stagger animations for smooth list appearances.

### Features
- Stagger animations based on index
- Multiple animation types
- Customizable delay and duration

### Usage

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return AnimatedListItem(
      index: index,
      animationType: AnimationType.fadeSlide,
      slideDirection: SlideDirection.fromBottom,
      child: ListTile(
        title: Text('Item $index'),
      ),
    );
  },
)
```

### Parameters
- `child` (required): List item widget
- `index` (required): Item index for stagger
- `delay`: Delay between items
- `duration`: Animation duration
- `curve`: Animation curve
- `animationType`: Type of animation
- `slideDirection`: Slide direction
- `slideDistance`: Slide distance

---

## PulseAnimation & BounceAnimation

Special effect animations for attention-grabbing elements.

### PulseAnimation

```dart
PulseAnimation(
  child: Icon(Icons.notifications, size: 48),
  minScale: 0.9,
  maxScale: 1.1,
  repeat: true,
  pulseColor: Colors.red,
)
```

### BounceAnimation

```dart
BounceAnimation(
  child: Icon(Icons.arrow_upward, size: 48),
  bounceHeight: 20,
  repeat: true,
  onBounceComplete: () => print('Bounce complete'),
)
```

---

## Best Practices

1. **Performance**: Use `maintainState: false` in ExpandableCard when content is heavy
2. **Responsiveness**: All widgets automatically use ResponsiveHelper for sizing
3. **Animations**: Keep durations between 200-500ms for most interactions
4. **Loading States**: Use ShimmerLoading for better UX than spinners
5. **Stagger Animations**: Use delays of 50-100ms between list items

---

## Examples

See the example app in the `example/` directory for complete usage examples.
