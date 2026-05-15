import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network_client.dart';
import '../network/dio_network_client.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final networkClientProvider = Provider<NetworkClient>((ref) {
  final dio = ref.watch(dioProvider);
  return DioNetworkClient(dio);
});
