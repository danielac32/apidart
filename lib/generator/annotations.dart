library annotations;

import 'package:meta/meta.dart';

@immutable
class Route {
  final String method;
  final String path;

  const Route(this.method, this.path);
}