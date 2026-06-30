import '../../models/session_order.dart';

class CreateTableOrderResult {
  const CreateTableOrderResult({
    required this.order,
    required this.apiLog,
  });

  final SessionOrder order;
  final String apiLog;
}
