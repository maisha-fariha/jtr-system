import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'transitions.dart';

/// Infinite Scroll - Auto-loading lists with pagination
class InfiniteScroll<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) loadData;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final VoidCallback? onRefresh;

  const InfiniteScroll({
    super.key,
    required this.loadData,
    required this.itemBuilder,
    this.pageSize = 20,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.onRefresh,
  });

  @override
  State<InfiniteScroll<T>> createState() => _InfiniteScrollState<T>();
}

class _InfiniteScrollState<T> extends State<InfiniteScroll<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    (widget.controller ?? _scrollController).addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final controller = widget.controller ?? _scrollController;
    if (!controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;
    final currentScroll = controller.position.pixels;
    final delta = ResponsiveHelper.getResponsiveHeight(context, 200);

    if (currentScroll >= (maxScroll - delta) && !_isLoading && _hasMore) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final newItems = await widget.loadData(_currentPage, widget.pageSize);

      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.length >= widget.pageSize;
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _currentPage = 1;
      _hasMore = true;
      _hasError = false;
    });
    await _loadData();
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.getResponsiveSize(context, 64),
                  color: Colors.red,
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 16),
                Text(
                  _errorMessage ?? 'Failed to load data',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                    color: Colors.red,
                  ),
                ),
                ResponsiveHelper.getResponsiveSpacing(context, 16),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    if (_items.isEmpty && !_isLoading) {
      return widget.emptyWidget ??
          Center(
            child: Text(
              'No items found',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                color: Colors.grey,
              ),
            ),
          );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: widget.controller ?? _scrollController,
        padding: widget.padding ??
            ResponsiveHelper.getResponsivePadding(context, all: 8),
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            // Loading indicator
            return widget.loadingWidget ??
                Padding(
                  padding: ResponsiveHelper.getResponsivePadding(
                    context,
                    all: 16,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                );
          }

          return FadeSlideTransition(
            slideDirection: SlideDirection.fromBottom,
            duration: const Duration(milliseconds: 300),
            child: widget.itemBuilder(context, _items[index], index),
          );
        },
      ),
    );
  }
}
