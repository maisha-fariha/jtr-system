import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gems_responsive/gems_responsive.dart';
import '../controllers/todo_controller.dart';
import '../models/todo/todo_model.dart';
import '../utils/app_theme.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Controller is injected via GetX binding in routes
    final controller = Get.find<TodoController>();

    return Scaffold(
      appBar: ResponsiveAppBar(
        title: Obx(() {
          final totalTodos = controller.items.length;
          final completedTodos = controller.items.where((t) => t.isCompleted).length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Todo App',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldPrimary,
                ),
              ),
              if (totalTodos > 0) ...[
                SizedBox(width: ResponsiveHelper.getResponsiveWidth(context, 12)),
                Container(
                  padding: ResponsiveHelper.getResponsivePadding(
                    context,
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.getResponsiveRadius(context, 12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: completedTodos,
                        duration: const Duration(milliseconds: 500),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldPrimary,
                        ),
                      ),
                      Text(
                        '/',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      AnimatedCounter(
                        value: totalTodos,
                        duration: const Duration(milliseconds: 500),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }),
        actions: [
          Padding(
            padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
            child: GemsAnimatedIcon(
              icon: Icons.refresh,
              animationType: AnimationType.rotation,
              onTap: () => controller.refresh(),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            ),
          ),
        ],
        collapseOnScroll: true,
        scrollController: _scrollController,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: ResponsiveHelper.getResponsiveMargin(
                    context,
                    vertical: 8,
                  ),
                  child: ShimmerListItem(
                    hasAvatar: false,
                    hasSubtitle: true,
                    lines: 2,
                  ),
                ),
              ),
            ),
          );
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.items.isEmpty) {
          return Center(
            child: FadeSlideTransition(
              slideDirection: SlideDirection.fromBottom,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemsAnimatedIcon(
                    icon: Icons.error_outline,
                    animationType: AnimationType.pulse,
                    repeat: true,
                    color: AppTheme.error,
                    size: ResponsiveHelper.getResponsiveSize(context, 64),
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 16),
                  Padding(
                    padding: ResponsiveHelper.getResponsivePadding(
                      context,
                      horizontal: 32,
                    ),
                    child: Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 24),
                  AnimatedButton(
                    onPressed: () => controller.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.items.isEmpty) {
          return Center(
            child: FadeSlideTransition(
              slideDirection: SlideDirection.fromBottom,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemsAnimatedIcon(
                    icon: Icons.check_circle_outline,
                    animationType: AnimationType.pulse,
                    repeat: true,
                    size: ResponsiveHelper.getResponsiveSize(context, 80),
                    color: AppTheme.goldPrimary,
                  ),
                  ResponsiveHelper.getResponsiveSpacing(context, 24),
                  Builder(
                    builder: (context) => Text(
                      'No todos yet.\nTap + to add one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          16,
                        ),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView.builder(
            controller: _scrollController,
            padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
            itemCount: controller.items.length,
            itemBuilder: (context, index) {
              final todo = controller.items[index];
              return AnimatedListItem(
                key: ValueKey(todo.id),
                index: index,
                animationType: ListAnimationType.fadeSlide,
                slideDirection: ListSlideDirection.fromBottom,
                delay: const Duration(milliseconds: 50),
                child: _TodoItem(
                  key: ValueKey(todo.id),
                  todo: todo,
                  onToggle: () => controller.toggleTodo(todo),
                  onDelete: () => controller.deleteTodo(todo.id),
                ),
              );
            },
          ),
        );
      }),
      floatingActionButton: PulseAnimation(
        repeat: false,
        child: FloatingActionButton(
          onPressed: () => _showAddTodoDialog(context, controller),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context, TodoController controller) {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    AdaptiveBottomSheet.show(
      context: context,
      title: 'Add Todo',
      child: ResponsiveForm(
        formKey: formKey,
        padding: EdgeInsets.zero,
        fields: [
          ResponsiveTextField(
            label: 'Title',
            hint: 'Enter todo title',
            controller: titleController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a todo title';
              }
              if (value.trim().length > 200) {
                return 'Title must be less than 200 characters';
              }
              return null;
            },
            autofocus: true,
            maxLength: 200,
          ),
        ],
        submitButton: AnimatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              controller.createTodo(
                titleController.text.trim(),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add Todo'),
          padding: ResponsiveHelper.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: ResponsiveHelper.getResponsiveMargin(
        context,
        vertical: 4,
        horizontal: 8,
      ),
      elevation: todo.isCompleted ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.getResponsiveRadius(context, 12),
        ),
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: onToggle,
          child: GemsAnimatedIcon(
            icon: todo.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            animationType: AnimationType.scale,
            color: todo.isCompleted
                ? AppTheme.success
                : AppTheme.goldPrimary,
            duration: const Duration(milliseconds: 200),
          ),
        ),
        title: FadeTransitionWidget(
          duration: const Duration(milliseconds: 300),
          child: Text(
            todo.title,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              decoration: todo.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: todo.isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary,
              fontWeight: todo.isCompleted ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
        subtitle: Text(
          'User ID: ${todo.userId}',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: GemsAnimatedIcon(
          icon: Icons.delete_outline,
          animationType: AnimationType.pulse,
          color: AppTheme.error,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => ScaleTransitionWidget(
                beginScale: 0.8,
                endScale: 1.0,
                duration: const Duration(milliseconds: 300),
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.getResponsiveRadius(context, 16),
                    ),
                  ),
                  title: const Text('Delete Todo'),
                  content: Text('Are you sure you want to delete "${todo.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    AnimatedButton(
                      onPressed: () {
                        onDelete();
                        Navigator.pop(context);
                      },
                      backgroundColor: AppTheme.error,
                      foregroundColor: AppTheme.textPrimary,
                      child: const Text('Delete'),
                      padding: ResponsiveHelper.getResponsivePadding(
                        context,
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

