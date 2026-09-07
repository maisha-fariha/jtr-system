import 'package:flutter/material.dart';

class JtrFamilyArticle {
  const JtrFamilyArticle({
    required this.name,
    required this.quantity,
    required this.amount,
  });

  final String name;
  final int quantity;
  final double amount;
}

class JtrProductFamily {
  const JtrProductFamily({
    required this.name,
    required this.totalQuantity,
    required this.totalAmount,
    required this.articles,
  });

  final String name;
  final int totalQuantity;
  final double totalAmount;
  final List<JtrFamilyArticle> articles;
}

class JtrGapTransaction {
  const JtrGapTransaction({
    required this.meta,
    required this.label,
    this.quantity,
    this.tag,
    this.discountPercent,
    required this.amount,
  });

  final String meta;
  final String label;
  final int? quantity;
  final String? tag;
  final int? discountPercent;
  final double amount;
}

class JtrGapCategoryDetail {
  const JtrGapCategoryDetail({
    required this.label,
    required this.color,
    required this.totalAmount,
    required this.transactions,
  });

  final String label;
  final Color color;
  final double totalAmount;
  final List<JtrGapTransaction> transactions;
}
