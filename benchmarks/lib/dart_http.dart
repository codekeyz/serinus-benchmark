import 'shared/serinus_benchmark.dart';
import 'dart:io';

class DartHttpBenchmark extends SerinusBenchmark {
  DartHttpBenchmark() : super(name: 'Dart HTTP Server');

  late HttpServer _server;

  @override
  Future<void> setup() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv6, 3000);
    _server.listen((req) => req.response
      ..write('echo!')
      ..close());
  }

  @override
  Future<void> teardown() async {
    await _server.close();
  }
}
