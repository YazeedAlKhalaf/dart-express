import 'package:dart_express/src/engines/engine.dart';
import 'package:code_buffer/code_buffer.dart';
import 'package:file/local.dart';
import 'package:jael/jael.dart' as jael;
import 'package:jael_preprocessor/jael_preprocessor.dart' as jael;
import 'package:symbol_table/symbol_table.dart';

class JaelEngine {
  static String ext = '.jael';

  static handler(
      String filePath, Map<String, dynamic> options, HandlerCallback callback) {
    var fs = LocalFileSystem();
    var file = fs.file(filePath);

    file.readAsString().then((str) async {
      // Store any parsing/resolution/rendering errors
      var errors = <jael.JaelError>[];

      // Parse the document, of course.
      var buffer = CodeBuffer();
      var document =
          jael.parseDocument(str, sourceUrl: filePath, onError: errors.add);

      // Resolve template includes, etc.
      document = await jael.resolve(document, fs.directory('views'),
          onError: errors.add);

      // Render an error page if anything went wrong.
      if (errors.isNotEmpty) {
        jael.Renderer.errorDocument(errors, buffer);
        return callback(null, buffer.toString());
      }

      // Everything went okay - now render.
      // In case the rendering throws an error, be prepared to catch and
      // render it.
      try {
        var scope = SymbolTable(values: options);
        jael.Renderer()
            .render(document, buffer, scope, strictResolution: false);
      } on jael.JaelError catch (e) {
        jael.Renderer.errorDocument([e], buffer..clear());
        return callback(null, buffer.toString());
      }
      return callback(null, buffer.toString());
    }).catchError((e) => callback(e, null));
  }

  static Engine use() {
    return Engine(JaelEngine.ext, JaelEngine.handler);
  }
}
