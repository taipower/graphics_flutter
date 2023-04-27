import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:flutter_gl/openGL/opengl/opengl_es_bindings/opengl_es_bindings.dart';

import '../Utils/utils.dart';

class ExampleTextureColor extends StatefulWidget {
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<ExampleTextureColor> {
  late FlutterGlPlugin flutterGlPlugin;

  int? fboId;
  num dpr = 1.0;
  late double width;
  late double height;

  ui.Size? screenSize;

  dynamic glProgram;
  dynamic _vao;
  dynamic _ebo;
  dynamic _texture;

  dynamic sourceTexture;

  dynamic defaultFramebuffer;
  dynamic defaultFramebufferTexture;

  int n = 0;

  int t = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();

    print(" init state..... ");
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = width;

    flutterGlPlugin = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await flutterGlPlugin.initialize(options: options);

    print(" flutterGlPlugin: textureid: ${flutterGlPlugin.textureId} ");

    // web need wait dom ok!!!
    Future.delayed(Duration(milliseconds: 100), () {
      setup();
    });
  }

  setup() async {
    // web no need use fbo
    if (!kIsWeb) {
      await flutterGlPlugin.prepareContext();

      setupDefaultFBO();
      sourceTexture = defaultFramebufferTexture;
    }

    setState(() {

    });

    prepare();
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mq = MediaQuery.of(context);

    screenSize = mq.size;
    dpr = mq.devicePixelRatio;

    print(" screenSize: $screenSize dpr: $dpr ");

    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Example app'),
        ),
        body: Builder(
          builder: (BuildContext context) {
            initSize(context);
            return SingleChildScrollView(child: _build(context));
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            clickRender();
          },
          child: const Text("Render"),
        ),
      ),
    );
  }

  Widget _build(BuildContext context) {
    return Column(
      children: [
        Container(
            width: width,
            height: width,
            color: Colors.black,
            child: Builder(builder: (BuildContext context) {
              if (kIsWeb) {
                return flutterGlPlugin.isInitialized
                    ? HtmlElementView(
                    viewType: flutterGlPlugin.textureId!.toString())
                    : Container();
              } else {
                return flutterGlPlugin.isInitialized
                    ? Texture(textureId: flutterGlPlugin.textureId!)
                    : Container();
              }
            })),
      ],
    );
  }

  setupDefaultFBO() {
    final gl = flutterGlPlugin.gl;
    int glWidth = (width * dpr).toInt();
    int glHeight = (height * dpr).toInt();

    print("glWidth: $glWidth glHeight: $glHeight ");

    defaultFramebuffer = gl.createFramebuffer();
    defaultFramebufferTexture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);

    gl.bindTexture(gl.TEXTURE_2D, defaultFramebufferTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, glWidth, glHeight, 0, gl.RGBA,
        gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.bindFramebuffer(gl.FRAMEBUFFER, defaultFramebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0,
        gl.TEXTURE_2D, defaultFramebufferTexture, 0);
  }

  clickRender() {
    print(" click render ... ");
    render();
  }

  render() {
    final gl = flutterGlPlugin.gl;

    gl.viewport(0, 0, (width * dpr).toInt(), (height * dpr).toInt());

    // Clear canvas
    gl.clearColor(0.2, 0.3, 0.3, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.drawElements(gl.TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    gl.finish();

    if (!kIsWeb) {
      flutterGlPlugin.updateTexture(sourceTexture);
    }
  }

  prepare() {
    final gl = flutterGlPlugin.gl;

    String version = "300 es";

    if(!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows) {
        version = "150";
      }
    }

    var vs = """#version $version
precision mediump float; // add a precision qualifier

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec3 a_Color;
layout (location = 2) in vec2 a_TexCoord;

out vec3 ourColor;
out vec2 TexCoord;

void main() {
    gl_Position = vec4(a_Position, 1.0);
    ourColor = a_Color;
    TexCoord = vec2(a_TexCoord.x,a_TexCoord.y);
}
    """;

    var fs = """#version $version
precision mediump float;

out vec4 pc_fragColor;
#define gl_FragColor pc_fragColor

in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D ourTexture;

void main() {
  gl_FragColor = texture(ourTexture, TexCoord) * vec4(ourColor, 1.0);
}
    """;

    // Create program
    glProgram = gl.createProgram();

    if (!Utils.initShaders(glProgram, gl, vs, fs)) {
      print('Failed to intialize shaders.');
      return;
    }

    // Write the positions of vertices to a vertex shader
    n = initVertexBuffers(gl);
    if (n < 0) {
      print('Failed to set the positions of the vertices');
      return;
    }
  }

  initVertexBuffers(gl) {
    // Vertices
    var dim = 3;

    var vertices = Float32Array.fromList([
      // position    // colors    // texture coords
      0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, // top right
      0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, // bottom right
      -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, // bottom left
      -0.5, 0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, // top left
    ]);

    var indices = Int32Array.fromList([
      0,1,3, // first triangle
      1,2,3, // second triangle
    ]);

    _vao = gl.createVertexArray();
    gl.bindVertexArray(_vao);

    // Create a buffer object
    var vertexBuffer = gl.createBuffer();
    if (vertexBuffer == null) {
      print('Failed to create the buffer object');
      return -1;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);

    _ebo = gl.createVertexArray();
    gl.bindVertexArray(_ebo);

    // Create a buffer object
    var indicesBuffer = gl.createBuffer();
    if (indicesBuffer == null) {
      print('Failed to create the buffer object');
      return -1;
    }
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indicesBuffer);

    if(kIsWeb) {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.length, vertices, gl.STATIC_DRAW);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.length, indices, gl.STATIC_DRAW);
    } else {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.lengthInBytes, indices, gl.STATIC_DRAW);
    }

    // Assign the vertices in buffer object to a_Position variable
    var aPosition = gl.getAttribLocation(glProgram, 'a_Position');
    if (aPosition < 0) {
      print('Failed to get the storage location of a_Position');
      return -1;
    }

    var bPosition = gl.getAttribLocation(glProgram, 'a_Color');
    if (bPosition < 0) {
      print('Failed to get the storage location of a_Position');
      return -1;
    }

    var cPosition = gl.getAttribLocation(glProgram, 'a_TexCoord');
    if(cPosition < 0){
      print('Failed to get the storage location of a_TexCoord');
      return -1;
    }

    gl.vertexAttribPointer(
        aPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 8, 0);
    gl.enableVertexAttribArray(aPosition);

    gl.vertexAttribPointer(
      bPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 8, Float32List.bytesPerElement * 3);
    gl.enableVertexAttribArray(bPosition);

    gl.vertexAttribPointer(
        cPosition, 2, gl.FLOAT, false, Float32List.bytesPerElement * 8, Float32List.bytesPerElement * 6);
    gl.enableVertexAttribArray(cPosition);

    _texture = gl.createTexture();
    gl.bindTexture(GL_TEXTURE_2D, _texture);
    // set the texture wrapping parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // load image, create texture and generate mipmaps
    Utils.loadImage('assets/images/flutter540.jpg').then((bytes) {
      gl.texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 540, 540, 0, GL_RGBA, GL_UNSIGNED_BYTE, Uint8Array.from(bytes.toList()));
      gl.generateMipmap(GL_TEXTURE_2D);
    });

    // Return number of vertices
    return (vertices.length ~/ dim);
  }
}