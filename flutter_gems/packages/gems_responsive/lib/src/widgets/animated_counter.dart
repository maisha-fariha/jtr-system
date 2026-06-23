import 'package:flutter/material.dart';
import '../responsive_helper.dart';

/// Animated Counter - Number counter with smooth animations
class AnimatedCounter extends StatefulWidget {
  final num value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final int? fractionDigits;
  final bool enableThousandsSeparator;
  final String Function(double)? customFormatter;
  final VoidCallback? onComplete;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(seconds: 2),
    this.curve = Curves.easeOut,
    this.style,
    this.prefix,
    this.suffix,
    this.fractionDigits,
    this.enableThousandsSeparator = true,
    this.customFormatter,
    this.onComplete,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  num _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: _previousValue.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _animation = Tween<double>(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller.reset();
      _controller.forward().then((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (widget.customFormatter != null) {
      return widget.customFormatter!(value);
    }

    // Format with fraction digits
    String formatted;
    if (widget.fractionDigits != null) {
      formatted = value.toStringAsFixed(widget.fractionDigits!);
    } else {
      formatted = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    }

    // Add thousands separator
    if (widget.enableThousandsSeparator) {
      final parts = formatted.split('.');
      final integerPart = parts[0];
      final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
      
      String result = '';
      for (int i = integerPart.length - 1; i >= 0; i--) {
        result = integerPart[i] + result;
        if ((integerPart.length - i) % 3 == 0 && i > 0) {
          result = ',' + result;
        }
      }
      formatted = result + decimalPart;
    }

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
      fontWeight: FontWeight.bold,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue = _formatNumber(_animation.value);
        return Text(
          '${widget.prefix ?? ''}$displayValue${widget.suffix ?? ''}',
          style: widget.style ?? defaultStyle,
        );
      },
    );
  }
}
