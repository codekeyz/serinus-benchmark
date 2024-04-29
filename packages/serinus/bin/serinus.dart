import 'package:serinus/serinus.dart';
import 'package:serinus/src/commons/versioning.dart';

class TestMiddleware extends Middleware {
  int counter = 0;

  TestMiddleware() : super(routes: ['*']);

  @override
  Future<void> use(RequestContext context, InternalResponse response,
      NextFunction next) async {
    print('Middleware executed ${++counter}');
    return next();
  }
}

class TestProvider extends Provider {
  final List<String> testList = [];

  TestProvider({super.isGlobal});

  String testMethod() {
    testList.add('Hello world');
    return 'Hello world';
  }
}

class TestProviderTwo extends Provider
    with OnApplicationInit, OnApplicationShutdown {
  final TestProvider testProvider;

  TestProviderTwo(this.testProvider);

  String testMethod() {
    testProvider.testMethod();
    return '${testProvider.testList} from provider two';
  }

  @override
  Future<void> onApplicationInit() async {
    print('Provider two initialized');
  }

  @override
  Future<void> onApplicationShutdown() async {
    print('Provider two shutdown');
  }
}

class TestGuard extends Guard {
  @override
  Future<bool> canActivate(ExecutionContext context) async {
    context.addDataToRequest('test', 'Hello world');
    return true;
  }
}

class GetRoute extends Route {
  const GetRoute({
    required super.path,
    super.method = HttpMethod.get,
  });

  @override
  // TODO: implement version
  int? get version => 2;

  @override
  List<Guard> get guards => [TestGuard()];
}

class PostRoute extends Route {
  const PostRoute({
    required super.path,
    super.method = HttpMethod.post,
    super.queryParameters = const {
      'hello': String,
    },
  });

  @override
  List<Guard> get guards => [TestGuard()];
}

class HomeController extends Controller {
  HomeController({super.path = '/'}) {
    on(GetRoute(path: '/'), (context) async {
      context.use<TestProviderTwo>().testMethod();
      return Response.text(context.use<TestProviderTwo>().testMethod());
    });
    on(PostRoute(path: '/*'), (context) async {
      return Response.text(
          '${context.request.getData('test')} ${context.pathParameters}');
    });
  }
}

class HomeAController extends Controller {
  HomeAController() : super(path: '/a') {
    on(GetRoute(path: '/'), (context) async {
      return Response.redirect('/');
    });
    on(PostRoute(path: '/<id>'), _handlePostRequest);
  }

  Future<Response> _handlePostRequest(RequestContext context) async {
    print(context.body.formData?.fields);
    return Response.text('Hello world from a ${context.pathParameters}');
  }
}

class AppModule extends Module {
  AppModule()
      : super(
            imports: [ReAppModule()],
            controllers: [HomeController()],
            providers: [TestProvider(isGlobal: true)],
            middlewares: [TestMiddleware()]);
}

class ReAppModule extends Module {
  ReAppModule()
      : super(imports: [], controllers: [
          HomeAController()
        ], providers: [
          DeferredProvider(inject: [TestProvider, TestProvider],
              (context) async {
            final prov = context.use<TestProvider>();
            return TestProviderTwo(prov);
          })
        ], middlewares: [
          TestMiddleware()
        ], exports: [
          TestProviderTwo
        ]);
}

void main(List<String> arguments) async {
  SerinusApplication application =
      await serinus.createApplication(entrypoint: AppModule());
  application.enableShutdownHooks();
  // application.enableVersioning(
  //   type: VersioningType.uri,
  //   version: 1
  // );
  await application.serve();
}
