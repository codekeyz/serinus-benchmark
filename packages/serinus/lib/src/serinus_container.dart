import 'dart:mirrors';

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart' as logging;
import 'package:serinus/serinus.dart';
import 'package:serinus/src/commons/form_data.dart';
import 'package:serinus/src/utils/body_decoder.dart';

import 'models/models.dart';
import 'utils/activator.dart';

class SerinusContainer {
  logging.Logger routesLoader = logging.Logger("SerinusContainer");
  GetIt _getIt = GetIt.instance;
  final List<RouteContext> _routes = [];
  final Map<SerinusModule, List<Type>> _controllers = {};
  final Map<SerinusModule, List<MiddlewareConsumer>> _moduleMiddlewares = {};
  static final SerinusContainer instance = SerinusContainer._internal();

  factory SerinusContainer() {
    return instance;
  }

  SerinusContainer._internal(){
    _routes.clear();
  }

  List<RouteContext> discoverRoutes(dynamic module){
    _getIt.reset();
    _routes.clear();
    _controllers.clear();
    _moduleMiddlewares.clear();
    _loadModuleDependencies(module, []);
    _loadRoutes();
    return _routes;
  }

  void _loadModuleDependencies(dynamic m, List<MiddlewareConsumer> middlewares){
    final module = _getModule(m);
    List<MiddlewareConsumer> _middlewares = [];
    routesLoader.info("Injecting dependencies for ${m.runtimeType}");
    if(module == null){
      return;
    }
    Symbol configure = this._getMiddlewareConfigurer(m);
    if(configure != Symbol.empty){
      MiddlewareConsumer consumer = MiddlewareConsumer();
      reflect(m).invoke(configure, [consumer]);
      _middlewares.add(consumer);
      _middlewares.addAll(middlewares);
    }
    for(dynamic import in module.imports){
      _loadModuleDependencies(import, _middlewares);
    }
    if(!_getIt.isRegistered<SerinusModule>(instanceName: m.runtimeType.toString())){
      _getIt.registerSingleton<SerinusModule>(m, instanceName: m.runtimeType.toString());
    }
    _istantiateInjectable<SerinusService>(module.providers);
    if(!_controllers.containsKey(m)){
      _istantiateInjectable<SerinusController>(module.controllers);
      _checkControllerPath([...module.controllers, ..._controllers.values.expand((element) => element).toList()]);
      _controllers[m] = module.controllers;
    }
    _moduleMiddlewares[m] = _middlewares;
  }

  void _istantiateInjectable<T extends Object>(List<Type> injectable){
    for(Type t in injectable){
      MethodMirror constructor = (reflectClass(t).declarations[Symbol(t.toString())] as MethodMirror);
      List<dynamic> parameters = [];
      for(ParameterMirror p in constructor.parameters){
        if(_getIt.isRegistered<SerinusService>(instanceName: p.type.reflectedType.toString())){
          parameters.add(_getIt.call<SerinusService>(instanceName: p.type.reflectedType.toString()));
        }
      }
      _getIt.registerSingleton<T>(reflectClass(t).newInstance(Symbol.empty, parameters).reflectee, instanceName: t.toString());
    }
  }

  void _loadRoutes(){
    for(SerinusModule module in _controllers.keys){
      for(Type c in _controllers[module]!){
        var controller = _getIt.call<SerinusController>(instanceName: c.toString());
        var ref = reflect(controller);
        _isController(ref);
        routesLoader.info("Loading routes from ${ref.type.reflectedType} (${ref.type.metadata[0].reflectee.path.isNotEmpty ? ref.type.metadata[0].reflectee.path : '/'})");
        final routes = _getDecoratedRoutes(ref.type.instanceMembers);
        routes.entries.forEach((e) { 
          InstanceMirror? controllerRoute;
          try{
            controllerRoute = e.value.metadata.firstWhere((element) => element.reflectee is Route);
          }catch(_){}
          if(controllerRoute != null){
            String path = Uri(path: "${ref.type.metadata[0].reflectee.path}${controllerRoute.reflectee.path}").normalizePath().path;
            if(_routes.indexWhere((element) => element.path == path && element.method == controllerRoute!.reflectee.method) == -1){
              if(e.value.parameters.where((element) => element.metadata.isNotEmpty && element.metadata.first.reflectee is Body).length > 1){
                throw Exception("A route can't have two body parameters.");
              }
              _routes.add(
                RouteContext(
                  path: path, 
                  controller: ref, 
                  handler: e.value, 
                  symbol: e.key, 
                  method: controllerRoute.reflectee.method,
                  statusCode: controllerRoute.reflectee.statusCode,
                  parameters: e.value.parameters,
                  module: module
                )
              );
              routesLoader.info("Added route: ${controllerRoute.reflectee.method} - $path");
            }
          }
        });
      }
    }
  }

  Map<String, dynamic> _getParametersValues(RouteContext context, Map<String, dynamic> routeParas){
    if(context.parameters.isNotEmpty){
      List<ParameterMirror> dataToPass = context.parameters;
      Map<String, dynamic> sorted = {};
      for(int i = 0; i < dataToPass.length; i++){
        ParameterMirror d = dataToPass[i];
        if(d.metadata.isNotEmpty){
          for(InstanceMirror meta in d.metadata){
            String type = meta.reflectee.runtimeType.toString().toLowerCase();
            String name = '';
            if(meta.reflectee is Body || meta.reflectee is RequestInfo){
              name = MirrorSystem.getName(d.simpleName);
            }else{
              name = meta.reflectee.name;
            }
            if(meta.reflectee is Param || meta.reflectee is Query){
              if(d.type.reflectedType is! String){
                switch(d.type.reflectedType){
                  case int:
                    routeParas['$type-$name'] = int.tryParse(routeParas['$type-$name']);
                    break;
                  case double:
                    routeParas['$type-$name'] = int.tryParse(routeParas['$type-$name']);
                    break;
                  default:
                    break;
                }
              }
              if(!meta.reflectee.nullable && routeParas['$type-$name'] == null){
                throw BadRequestException(message: "The $type parameter $name doesn't accept null as value");
              }
            }
            sorted['$type-$name'] = routeParas['$type-$name'];
          }
        }
        
      }
      routeParas.clear();
      routeParas.addAll(sorted);
    }
    return routeParas;
  }

  Module? _getModule(dynamic module){
    final moduleRef = reflect(module);
    if(moduleRef.type.metadata.isEmpty){
      throw StateError("It seems ${moduleRef.type.reflectedType} doesn't have the @Module decorator");
    }
    int index = moduleRef.type.metadata.indexWhere((element) => element.reflectee is Module);
    if(index == -1){
      return null;
    }
    return moduleRef.type.metadata[index].reflectee;
  }

  Symbol _getMiddlewareConfigurer(SerinusModule module){
    final moduleRef = reflect(module);
    final configure = moduleRef.type.instanceMembers[Symbol("configure")];
    if(configure != null){
      return configure.simpleName;
    }
    return Symbol.empty;
  }

  List<MiddlewareConsumer> getMiddlewareConsumers(SerinusModule module){
    return _moduleMiddlewares[module] ?? [];
  }

  Future<Map<String, dynamic>> addParameters(Map<String, dynamic> routeParas, Request request, RouteContext context) async {
    dynamic jsonBody, body;
    if(isMultipartFormData(request.contentType)){
      body = await FormData.parseMultipart(
        request: request.httpRequest
      );
    }else if(isUrlEncodedFormData(request.contentType)){
      body = FormData.parseUrlEncoded(await request.body());
    }else{
      jsonBody = await request.json();
      body = await request.body();
    }
    routeParas.remove(routeParas.keys.first);
    routeParas.addAll(
      Map<String, dynamic>.fromEntries(
        request.queryParameters.entries.map(
          (e) => MapEntry("query-${e.key}", e.value)
        )
      )
    );
    routeParas.addAll(
      Map<String, dynamic>.fromEntries(
        context.parameters.where(
          (element) => element.metadata.isNotEmpty && element.metadata.first.reflectee is Body || element.metadata.first.reflectee is RequestInfo
        ).map((e){
          if(e.metadata.first.reflectee is Body){
            if(!isMultipartFormData(request.contentType) && !isUrlEncodedFormData(request.contentType)){
              if (e.type.reflectedType is! BodyParsable){
                return MapEntry(
                  "body-${MirrorSystem.getName(e.simpleName)}",
                  body
                );
              }
              return MapEntry(
                "body-${MirrorSystem.getName(e.simpleName)}",
                Activator.createInstance(e.type.reflectedType, jsonBody)
              );
            }
            return MapEntry(
              "body-${MirrorSystem.getName(e.simpleName)}",
              body
            );
          }
          return MapEntry(
            "requestinfo-${MirrorSystem.getName(e.simpleName)}", 
            request
          );
        })
      )
    );
    routeParas = _getParametersValues(context, routeParas);
    return routeParas;
  }
  
  Controller _isController(InstanceMirror controller) {
    int index = controller.type.metadata.indexWhere((element) => element.reflectee is Controller);
    if(index == -1) throw StateError("${controller.type.reflectedType} is in the controllers list of the module but doesn't have the @Controller decorator");
    return controller.type.metadata[index].reflectee;
  }

  Map<Symbol, MethodMirror> _getDecoratedRoutes(Map<Symbol, MethodMirror> instanceMembers){
    Map<Symbol, MethodMirror> map = Map<Symbol, MethodMirror>.from(instanceMembers);
    map.removeWhere((key, value) => value.metadata.indexWhere((element) => element.reflectee is Route) == -1);
    return map; 
  }

  void dispose() {
    _routes.clear();
    _controllers.clear();
  }

  Map<String, dynamic> _checkIfRequestedRoute(String element, Request request) {
    String reqUriNoAddress = request.path;
    if(element == reqUriNoAddress || element.substring(0, element.length - 1) == reqUriNoAddress){
      return {element: true};
    }
    List<String> pathSegments = Uri(path: reqUriNoAddress).pathSegments.where((element) => element.isNotEmpty).toList();
    List<String> elementSegments = Uri(path: element).pathSegments.where((element) => element.isNotEmpty).toList();
    if(pathSegments.length != elementSegments.length){
      return {};
    }
    Map<String, dynamic> toReturn = {};
    for(int i = 0; i < pathSegments.length; i++){
      if(elementSegments[i].contains(r':') && pathSegments[i].isNotEmpty){
        toReturn["param-${elementSegments[i].replaceFirst(':', '')}"] = pathSegments[i];
      }
    }
    return toReturn.isEmpty ? {} : {
      element: true, 
      ...toReturn
    };
  }
  
  RequestedRoute getRoute(Request request) {
    Map<String, dynamic> routeParas = {};
    try{
      final possibileRoutes = _routes.where(
        (element) {
          routeParas.clear();
          routeParas.addAll(_checkIfRequestedRoute(element.path, request));
          return (routeParas.isNotEmpty);
        }
      );
      if(possibileRoutes.isEmpty){
        throw NotFoundException(uri: request.uri);
      }
      if(possibileRoutes.every((element) => element.method != request.method.toMethod())){
        throw MethodNotAllowedException(message: "Can't ${request.method} ${request.path}", uri: request.uri);
      } 
      return RequestedRoute(
        data: possibileRoutes.firstWhere((element) => element.method == request.method.toMethod()),
        params: routeParas
      );
    }catch(e){
      rethrow;
    }
  }
  
  void _checkControllerPath(List<Type> controllers) {
    List<String> controllersPaths = [];
    for(Type c in controllers){
      SerinusController controller = _getIt.call<SerinusController>(instanceName: c.toString());
      Controller controllerMetadata = _isController(reflect(controller));
      controllersPaths.add(controllerMetadata.path);
    }
    if(controllersPaths.toSet().length != controllersPaths.length){
      throw new StateError("There can't be two controllers with the same path");
    }
  }
}