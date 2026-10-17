import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/features/payment/domain/payment.dart';

abstract class PaymentRepository {
  Future<ApiResult<PaymentSession>> createPaymentSession(String bookingId);
  Future<ApiResult<PaymentSession>> getPaymentStatus(String paymentId);
}
