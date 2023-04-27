import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:flutter_gl/openGL/opengl/opengl_es_bindings/opengl_es_bindings.dart';
import 'package:vector_math/vector_math.dart' as math;

import '../Utils/utils.dart';

class ExampleCubeMultiple extends StatefulWidget {
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<ExampleCubeMultiple> {
  late FlutterGlPlugin flutterGlPlugin;

  int? fboId;
  num dpr = 1.0;
  late double width;
  late double height;

  ui.Size? screenSize;

  dynamic glProgram;
  dynamic _vao;
  dynamic _texture1;
  dynamic _texture2;

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

    // web need wait dom ok!!!
    Future.delayed(const Duration(milliseconds: 100), () {
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

    setState(() {});

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
          child: Text("Render"),
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
    gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);

    List<math.Vector3> cubePosition =[
      math.Vector3(2.0,10.0,-15.0),
      math.Vector3(-1.5,-2.2,-2.5),
      math.Vector3(-5.8,-2.0,-2.5),
      math.Vector3(1.3,-2.0,-2.5),
      math.Vector3(-0.5,2.0,-1.5),
    ];

    final view = math.Matrix4.identity()..translate(math.Vector3(1.0,3.0,-3.0));
    math.Matrix4 projection = math.makePerspectiveMatrix(45.0,1.0, 0.1, 100.0);

    for(int i=0;i<5;i++){
      math.Matrix4 model = math.Matrix4.identity();
      model.translate(cubePosition[i]);
      math.Vector3 axis = math.Vector3(1.0, 0.3, 0.5);
      double angle = 20.0 * i;
      model.rotate(axis, angle);
      math.Matrix4 MVP = projection * view * model;

      var mvpPosition = gl.getUniformLocation(glProgram, 'mvp');
      if(mvpPosition < 0){
        print('Failed to get the storage location of MVP');
        return -1;
      }
      gl.uniformMatrix4fv(mvpPosition, true, MVP.storage);

      gl.drawArrays(gl.TRIANGLES, 0, 36);
    }

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
layout (location = 1) in vec2 a_TexCoord;

out vec2 TexCoord;

uniform mat4 mvp;

void main() {
    gl_Position = mvp * vec4(a_Position, 1.0);
    TexCoord = vec2(a_TexCoord.x,1.0 - a_TexCoord.y);
}
    """;

    var fs = """#version $version
precision mediump float;

out vec4 pc_fragColor;
#define gl_FragColor pc_fragColor

in vec2 TexCoord;

uniform sampler2D texture1;
uniform sampler2D texture2;

void main() {
  gl_FragColor = mix(texture(texture1, TexCoord), texture(texture2, TexCoord), 0.2);
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

    gl.enable(GL_DEPTH_TEST);

    var vertices = Float32Array.fromList([
      // position          // texture coords
      -0.25, -0.25, -0.25,  0.0, 0.0,
      0.25, -0.25, -0.25,  1.0, 0.0,
      0.25,  0.25, -0.25,  1.0, 1.0,
      0.25,  0.25, -0.25,  1.0, 1.0,
      -0.25,  0.25, -0.25,  0.0, 1.0,
      -0.25, -0.25, -0.25,  0.0, 0.0,

      -0.25, -0.25,  0.25,  0.0, 0.0,
      0.25, -0.25,  0.25,  1.0, 0.0,
      0.25,  0.25,  0.25,  1.0, 1.0,
      0.25,  0.25,  0.25,  1.0, 1.0,
      -0.25,  0.25,  0.25,  0.0, 1.0,
      -0.25, -0.25,  0.25,  0.0, 0.0,

      -0.25,  0.25,  0.25,  1.0, 0.0,
      -0.25,  0.25, -0.25,  1.0, 1.0,
      -0.25, -0.25, -0.25,  0.0, 1.0,
      -0.25, -0.25, -0.25,  0.0, 1.0,
      -0.25, -0.25,  0.25,  0.0, 0.0,
      -0.25,  0.25,  0.25,  1.0, 0.0,

      0.25,  0.25,  0.25,  1.0, 0.0,
      0.25,  0.25, -0.25,  1.0, 1.0,
      0.25, -0.25, -0.25,  0.0, 1.0,
      0.25, -0.25, -0.25,  0.0, 1.0,
      0.25, -0.25,  0.25,  0.0, 0.0,
      0.25,  0.25,  0.25,  1.0, 0.0,

      -0.25, -0.25, -0.25,  0.0, 1.0,
      0.25, -0.25, -0.25,  1.0, 1.0,
      0.25, -0.25,  0.25,  1.0, 0.0,
      0.25, -0.25,  0.25,  1.0, 0.0,
      -0.25, -0.25,  0.25,  0.0, 0.0,
      -0.25, -0.25, -0.25,  0.0, 1.0,

      -0.25,  0.25, -0.25,  0.0, 1.0,
      0.25,  0.25, -0.25,  1.0, 1.0,
      0.25,  0.25,  0.25,  1.0, 0.0,
      0.25,  0.25,  0.25,  1.0, 0.0,
      -0.25,  0.25,  0.25,  0.0, 0.0,
      -0.25,  0.25, -0.25,  0.0, 1.0,
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

    if(kIsWeb) {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.length, vertices, gl.STATIC_DRAW);
    } else {
      gl.bufferData(gl.ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.STATIC_DRAW);
    }

    // Assign the vertices in buffer object to a_Position variable
    var aPosition = gl.getAttribLocation(glProgram, 'a_Position');
    if (aPosition < 0) {
      print('Failed to get the storage location of a_Position');
      return -1;
    }

    var cPosition = gl.getAttribLocation(glProgram, 'a_TexCoord');
    if(cPosition < 0){
      print('Failed to get the storage location of a_TexCoord');
      return -1;
    }

    gl.vertexAttribPointer(
        aPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 5, 0);
    gl.enableVertexAttribArray(aPosition);

    gl.vertexAttribPointer(
        cPosition, 2, gl.FLOAT, false, Float32List.bytesPerElement * 5, Float32List.bytesPerElement * 3);
    gl.enableVertexAttribArray(cPosition);

    _texture1 = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(GL_TEXTURE_2D, _texture1);
    // set the texture wrapping parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    gl.uniform1i(gl.getUniformLocation(glProgram,'texture1'),0);

    // load image, create texture and generate mipmaps
    Utils.loadImage('assets/images/flutter540.jpg').then((bytes) {
      gl.texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 540, 540, 0, GL_RGBA, GL_UNSIGNED_BYTE, Uint8Array.from(bytes.toList()));
      gl.generateMipmap(GL_TEXTURE_2D);

      _texture2 = gl.createTexture();
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(GL_TEXTURE_2D, _texture2);
      // set the texture wrapping parameters
      gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
      gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
      // set texture filtering parameters
      gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
      gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      gl.uniform1i(gl.getUniformLocation(glProgram,'texture2'),1);

      // load image, create texture and generate mipmaps
      Utils.loadImage('assets/images/awesomeface.png').then((bytes) {
        gl.texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 476, 476, 0, GL_RGBA, GL_UNSIGNED_BYTE, Uint8Array.from(bytes.toList()));
        gl.generateMipmap(GL_TEXTURE_2D);
      });
    });

    // Return number of vertices
    return (vertices.length ~/ dim);
  }
}