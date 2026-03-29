import 'package:flutter/material.dart';

/// [RouteAware] 用の共有オブザーバ（検索画面の戻りリフレッシュ等）。
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
