import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class TestServer {
  final Uri baseUrl;
  final HttpServer _server;

  TestServer._(this._server, this.baseUrl);

  Future<void> close() => _server.close();

  static Future<TestServer> start(Directory directory) async {
    final handler = createStaticHandler(directory.path);
    final server = await io.serve(handler, 'localhost', 0);
    final baseUrl = Uri.parse('http://localhost:${server.port}');
    return TestServer._(server, baseUrl);
  }

}
