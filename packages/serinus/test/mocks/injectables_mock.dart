import 'package:serinus/serinus.dart';

class TestProvider extends Provider {
  TestProvider();

  String testMethod() {
    return 'Hello world';
  }
}

class TestProviderTwo extends Provider {
  TestProviderTwo();

  String testMethod() {
    return 'Hello world';
  }
}

class TestProviderThree extends Provider {
  TestProviderThree();

  String testMethod() {
    return 'Hello world';
  }
}

class TestGuard extends Guard {
  TestGuard();

  @override
  Future<bool> canActivate(ExecutionContext context) async {
    return true;
  }
}

class TestMiddleware extends Middleware {
  TestMiddleware() : super(routes: ['*']);

  @override
  Future<void> use(RequestContext context, InternalResponse response,
      NextFunction next) async {
    return next();
  }
}

class TestPipe extends Pipe {
  TestPipe();

  @override
  Future<void> transform(ExecutionContext context) async {}
}
