import '../core/core.dart';
import '../http/http.dart';
import 'request_context.dart';

sealed class ExecutionContext {
  final Map<Type, Provider> providers;
  final Request request;

  ExecutionContext(this.providers, this.request);

  T use<T>() {
    if (!providers.containsKey(T)) {
      throw StateError('Provider not found in request context');
    }
    return providers[T] as T;
  }

  void addDataToRequest(String key, dynamic value) {
    request.addData(key, value);
  }
}

class _ExecutionContextImpl extends ExecutionContext {
  _ExecutionContextImpl(super.providers, super.request);

  @override
  T use<T>() {
    if (!providers.containsKey(T)) {
      throw StateError('Provider not found in request context');
    }
    return providers[T] as T;
  }
}

class ExecutionContextBuilder {
  Map<Type, Provider> providers = {};

  ExecutionContextBuilder addProviders(Iterable<Provider> providers) {
    this.providers.addAll({
      for (var provider in providers) provider.runtimeType: provider,
    });
    return this;
  }

  ExecutionContext fromRequestContext(RequestContext context) {
    return _ExecutionContextImpl(context.providers, context.request);
  }

  ExecutionContext build(Request request) {
    return _ExecutionContextImpl(providers, request);
  }
}
