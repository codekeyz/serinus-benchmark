import 'package:serinus/serinus.dart';
import 'package:test/test.dart';

class TestProvider extends Provider {
  TestProvider();
}

class TestModule extends Module {
  TestModule({super.imports, super.providers = const [], super.exports});
}

class TestSubModule extends Module {
  TestSubModule({super.providers = const [], super.exports});
}

class TestProviderExported extends Provider {
  TestProviderExported();
}

final config = ApplicationConfig(
    host: 'localhost',
    port: 3000,
    poweredByHeader: 'Powered by Serinus',
    securityContext: null,
    serverAdapter: SerinusHttpAdapter(
      host: 'localhost',
      port: 3000,
      poweredByHeader: 'Powered by Serinus',
    ));

void main() async {
  group('$Module', () {
    test('''when a $Module is registered in the application, 
          then all the submodules should be registered as well
        ''', () async {
      final container = ModulesContainer(config);
      final module = TestModule(imports: [TestSubModule()]);
      await container.registerModules(module, Type);

      await container.finalize(module);

      expect(container.modules.length, 2);
    });

    test('''when a $Module is registered in the application, 
          and is the entrypoint, 
          and has exports, 
          then it should throw a $InitializationError
        ''', () async {
      final container = ModulesContainer(config);

      container
          .registerModules(
              TestModule(
                  imports: [TestSubModule()],
                  providers: [TestProviderExported()],
                  exports: [TestProviderExported]),
              TestModule)
          .catchError(
              (value) => expect(value.runtimeType, InitializationError));
    });

    test('''when a $Module is registered in the application, 
          and it imports itself,
          then it should throw a $InitializationError
        ''', () async {
      final container = ModulesContainer(config);

      container
          .registerModules(
              TestModule(
                imports: [TestModule()],
              ),
              TestModule)
          .catchError(
              (value) => expect(value.runtimeType, InitializationError));
    });

    test('''when a $Module is registered in the application, 
          and it exports a provider that is not registered in the module,
          then it should throw a $InitializationError
        ''', () async {
      final container = ModulesContainer(config);
      final entrypoint = TestModule(
        imports: [
          TestSubModule(exports: [TestProviderExported])
        ],
      );
      await container.registerModules(entrypoint, TestModule);

      container.finalize(entrypoint).catchError(
          (value) => expect(value.runtimeType, InitializationError));
    });

    test(
        '''when the function 'getModuleByToken' is called with a token that does not exist,
          then it should throw an $ArgumentError
        ''', () async {
      final container = ModulesContainer(config);

      expect(() => container.getModuleByToken('test'),
          throwsA(isA<ArgumentError>()));
    });

    test(
        '''when the function 'getParents' is called with a module that has no parents,
          then it should return an empty list
        ''', () async {
      final container = ModulesContainer(config);

      final module = TestModule();
      final parents = container.getParents(module);

      expect(parents, []);
    });

    test(
        '''when the function 'getParents' is called with a module that has parents,
          then it should return a list with the parents
        ''', () async {
      final container = ModulesContainer(config);
      final subModule = TestSubModule();
      final module = TestModule(imports: [subModule]);

      await container.registerModules(module, TestModule);

      await container.finalize(module);

      final parents = container.getParents(subModule);

      expect(parents, [module]);
    });

    test(
        '''when a $DeferredModule is registered in the application through a $Module,
          then it should be initialized after the 'eager' modules
        ''', () async {
      final container = ModulesContainer(config);
      final subModule = TestSubModule();
      final module = TestModule(
          imports: [DeferredModule((context) async => subModule, inject: [])]);

      await container.registerModules(module, TestModule);

      await container.finalize(module);

      final parents = container.getParents(subModule);

      expect(parents, [module]);
    });
  });
}
