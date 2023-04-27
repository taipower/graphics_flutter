import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class Utils{
  static bool initShaders(dynamic glProgram, gl, vsSource, fsSource) {
    // Compile shaders
    var vertexShader = makeShader(gl, vsSource, gl.VERTEX_SHADER);
    var fragmentShader = makeShader(gl, fsSource, gl.FRAGMENT_SHADER);

    // Attach and link shaders to the program
    gl.attachShader(glProgram, vertexShader);
    gl.attachShader(glProgram, fragmentShader);
    gl.linkProgram(glProgram);
    var res = gl.getProgramParameter(glProgram, gl.LINK_STATUS);
    print(" initShaders LINK_STATUS _res: $res ");
    if (res == false || res == 0) {
      print("Unable to initialize the shader program");
      return false;
    }

    // Use program
    gl.useProgram(glProgram);

    return true;
  }

  static makeShader(gl, src, type) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    var res = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (res == 0 || res == false) {
      print("Error compiling shader: ${gl.getShaderInfoLog(shader)}");
      return;
    }

    return shader;
  }

  static Future<Uint8List> loadImage(String imgPath) async{
    final ByteData imageData = await rootBundle.load(imgPath);
    final Uint8List bytes = imageData.buffer.asUint8List();

    // Decode the image
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.Image image = (await codec.getNextFrame()).image;

    // Flip the image vertically
    final Uint8List pixelData = await _flipImageVertically(image);

    return pixelData;
  }

  static Future<Uint8List> _flipImageVertically(ui.Image image) async {
    final int width = image.width;
    final int height = image.height;

    final ByteData? byteData = await image.toByteData();
    final Uint8List pixels = Uint8List.fromList(byteData?.buffer.asUint8List() ?? []);

    for (int y = 0; y < height ~/ 2; y++) {
      final int topOffset = y * width * 4;
      final int bottomOffset = (height - y - 1) * width * 4;
      for (int x = 0; x < width; x++) {
        final int topIndex = topOffset + x * 4;
        final int bottomIndex = bottomOffset + x * 4;
        final int r = pixels[topIndex];
        final int g = pixels[topIndex + 1];
        final int b = pixels[topIndex + 2];
        final int a = pixels[topIndex + 3];
        pixels[topIndex] = pixels[bottomIndex];
        pixels[topIndex + 1] = pixels[bottomIndex + 1];
        pixels[topIndex + 2] = pixels[bottomIndex + 2];
        pixels[topIndex + 3] = pixels[bottomIndex + 3];
        pixels[bottomIndex] = r;
        pixels[bottomIndex + 1] = g;
        pixels[bottomIndex + 2] = b;
        pixels[bottomIndex + 3] = a;
      }
    }

    return pixels;
  }
}