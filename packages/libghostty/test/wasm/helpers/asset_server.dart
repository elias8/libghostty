import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:stream_channel/stream_channel.dart';

const _corsHeaders = {'Access-Control-Allow-Origin': '*'};

Future<void> hybridMain(StreamChannel<Object?> channel) async {
  final handler = const Pipeline()
      .addMiddleware(_cors())
      .addHandler(createStaticHandler('.'));

  final server = await io.serve(handler, 'localhost', 0);
  channel.sink.add(server.port);

  await channel.stream.listen(null).asFuture<void>();
  await server.close();
}

Middleware _cors() {
  return (handler) => (request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: _corsHeaders);
    }
    final response = await handler(request);
    return response.change(headers: _corsHeaders);
  };
}
