
// annotations.dart

import 'dart:async';
import 'dart:io';

class Controller{
  final String path;
  const Controller(this.path);
}

class Get {
  final String path;
  const Get(this.path);
}

class Post {
  final String path;
  const Post(this.path);
}

class Put {
  final String path;
  const Put(this.path);
}

class Patch {
  final String path;
  const Patch(this.path);
}
class Delete {
  final String path;
  const Delete(this.path);
}


class Middleware {
  const Middleware(this.handler);
  final FutureOr Function(HttpRequest, HttpResponse) handler;
}