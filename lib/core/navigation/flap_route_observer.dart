import 'package:flutter/widgets.dart';

/// Root [NavigatorObserver] so widgets can use [RouteAware] (e.g. pause video when a route covers the shell).
final RouteObserver<ModalRoute<dynamic>> flapRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
