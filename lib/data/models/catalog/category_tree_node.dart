import 'leaf_category_model.dart';

class CategoryTreeNode {
  const CategoryTreeNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  final int id;
  final String name;
  final List<CategoryTreeNode> children;

  bool get hasChildren => children.isNotEmpty;

  static CategoryTreeNode fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    final children = rawChildren is List
        ? rawChildren
            .whereType<Map<String, dynamic>>()
            .map(CategoryTreeNode.fromJson)
            .where((node) => node.id > 0)
            .toList()
        : <CategoryTreeNode>[];

    return CategoryTreeNode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      children: children,
    );
  }

  /// Builds a hierarchy from flat leaf categories when the tree API is unavailable.
  static List<CategoryTreeNode> fromLeafCategories(
    List<LeafCategoryModel> categories,
  ) {
    final active = categories.where((c) => c.isActive && c.id > 0).toList();
    if (active.isEmpty) return const [];

    final withParent = active.where((c) => c.parent != null).toList();
    if (withParent.isEmpty) {
      return active
          .map((c) => CategoryTreeNode(id: c.id, name: c.name))
          .toList();
    }

    final parentNodes = <int, CategoryTreeNode>{};
    for (final category in withParent) {
      final parent = category.parent!;
      parentNodes.putIfAbsent(
        parent.id,
        () => CategoryTreeNode(id: parent.id, name: parent.name),
      );
    }

    final childrenByParent = <int, List<CategoryTreeNode>>{};
    for (final category in withParent) {
      final parentId = category.parent!.id;
      childrenByParent.putIfAbsent(parentId, () => []).add(
            CategoryTreeNode(id: category.id, name: category.name),
          );
    }

    final roots = <CategoryTreeNode>[];
    for (final entry in parentNodes.entries) {
      final children = childrenByParent[entry.key] ?? const [];
      roots.add(
        CategoryTreeNode(
          id: entry.value.id,
          name: entry.value.name,
          children: children,
        ),
      );
    }

    for (final category in active.where((c) => c.parent == null)) {
      if (!roots.any((root) => root.id == category.id)) {
        roots.add(CategoryTreeNode(id: category.id, name: category.name));
      }
    }

    roots.sort((a, b) => a.name.compareTo(b.name));
    return roots;
  }
}

List<CategoryTreeNode> parseCategoryTreeResponse(Object? data) {
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(CategoryTreeNode.fromJson)
        .where((node) => node.id > 0 && node.name.isNotEmpty)
        .toList();
  }

  if (data is Map<String, dynamic>) {
    final nested = data['categories'] ?? data['tree'] ?? data['data'];
    if (nested != null) {
      return parseCategoryTreeResponse(nested);
    }
    if (data['id'] != null) {
      final node = CategoryTreeNode.fromJson(data);
      if (node.id > 0) return [node];
    }
  }

  return const [];
}
