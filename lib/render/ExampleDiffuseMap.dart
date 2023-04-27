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

class ExampleDiffuseMap extends StatefulWidget {
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<ExampleDiffuseMap> {
  late FlutterGlPlugin flutterGlPlugin;

  int? fboId;
  num dpr = 1.0;
  late double width;
  late double height;

  ui.Size? screenSize;

  dynamic glProgram;
  dynamic _vao;
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
    gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
    
    gl.uniform3f(gl.getUniformLocation(glProgram,'lightPos'),3.0, 5.0, -3.0);
    gl.uniform3f(gl.getUniformLocation(glProgram,'viewPos'),3.0,3.0,3.0);

    // light properties
    gl.uniform3f(gl.getUniformLocation(glProgram,'light.ambient'),0.2,0.2,0.2);
    gl.uniform3f(gl.getUniformLocation(glProgram,'light.diffuse'),0.5,0.5,0.5);
    gl.uniform3f(gl.getUniformLocation(glProgram,'light.specular'),1.0,1.0,1.0);

    // material properties
    gl.uniform3f(gl.getUniformLocation(glProgram,'material.specular'),0.5,0.5,0.5);
    gl.uniform1f(gl.getUniformLocation(glProgram,'material.shininess'), 64.0);

    _texture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(GL_TEXTURE_2D, _texture);
    // set the texture wrapping parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    // set texture filtering parameters
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    gl.uniform1i(gl.getUniformLocation(glProgram,'material.diffuse'),0);

    double radius = 45.0;

    final model = math.Matrix4.identity()..translate(2.0,0.0,-6.0)..rotateX(radius)..rotateY(radius/2);
    final view = math.Matrix4.identity()..translate(math.Vector3(-1.0,-1.0,-1.0));
    math.Matrix4 projection = math.makePerspectiveMatrix(45.0,1.0, 0.1, 100.0);
    math.Matrix4 MVP = projection * view * model;

    var mvpPosition = gl.getUniformLocation(glProgram, 'mvp');
    if(mvpPosition < 0){
      print('Failed to get the storage location of MVP');
      return -1;
    }
    gl.uniformMatrix4fv(mvpPosition, false, MVP.storage);

    // load image, create texture and generate mipmaps
    Utils.loadImage('assets/images/flutter540.jpg').then((bytes) {
      gl.texImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 540, 540, 0, GL_RGBA, GL_UNSIGNED_BYTE, Uint8Array.from(bytes.toList()));
      gl.generateMipmap(GL_TEXTURE_2D);

      gl.drawArrays(gl.TRIANGLES, 0, 36);

      gl.finish();

      if (!kIsWeb) {
        flutterGlPlugin.updateTexture(sourceTexture);
      }
    });
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

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoords;

out vec3 FragPos;
out vec3 Normal;
out vec2 TexCoords;

uniform mat4 mvp;

void main() {
    FragPos = vec3(vec4(aPos,1.0));
    Normal = aNormal;
    TexCoords = aTexCoords;
    
    gl_Position = mvp * vec4(aPos, 1.0);
}
    """;

    var fs = """#version $version
precision mediump float;

out vec4 pc_fragColor;
#define gl_FragColor pc_fragColor

struct Material{
  sampler2D diffuse;
  vec3 specular;
  float shininess;
};

struct Light{
  vec3 position;
  
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
};

in vec3 Normal;
in vec3 FragPos;
in vec2 TexCoords;

uniform vec3 viewPos;
uniform Material material;
uniform Light light;

void main() {
  // ambient
  vec3 ambient = light.ambient * texture(material.diffuse,TexCoords).rgb;
  
  // diffuse
  vec3 norm = normalize(Normal);
  vec3 lightDir = normalize(light.position - FragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = light.diffuse * diff * texture(material.diffuse,TexCoords).rgb;
  
  // specular
  vec3 viewDir = normalize(viewPos - FragPos);
  vec3 reflectDir = reflect(-lightDir,norm);
  float spec = exp2(max(dot(viewDir,reflectDir),0.0) * 10.0);
  vec3 specular = light.specular * (spec * material.specular);
  
  vec3 result = ambient + diffuse + specular;
  gl_FragColor = vec4(result,1.0);
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
      -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0,
      1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 0.0,
      1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0,
      1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0,
      -1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 1.0,
      -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0,

      -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0,
      1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 0.0,
      1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0,
      1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0,
      -1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 1.0,
      -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0,

      -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0,
      -1.0,  1.0, -1.0, -1.0,  0.0,  0.0, 1.0, 1.0,
      -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0,
      -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0,
      -1.0, -1.0,  1.0, -1.0,  0.0,  0.0, 0.0, 0.0,
      -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0,

      1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0,
      1.0,  1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 1.0,
      1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0,
      1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0,
      1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 0.0,
      1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0,

      -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0,
      1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 1.0, 1.0,
      1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0,
      1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0,
      -1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 0.0, 0.0,
      -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0,

      -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0,
      1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 1.0, 1.0,
      1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 1.0, 0.0,
      1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 1.0, 0.0,
      -1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 0.0, 0.0,
      -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0,
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
    var aPosition = gl.getAttribLocation(glProgram, 'aPos');
    if (aPosition < 0) {
      print('Failed to get the storage location of aPos');
      return -1;
    }
    gl.vertexAttribPointer(
        aPosition, dim, gl.FLOAT, false, Float32List.bytesPerElement * 8, 0);
    gl.enableVertexAttribArray(aPosition);

    // Assign the vertices in buffer object to a_Position variable
    var aNormal = gl.getAttribLocation(glProgram, 'aNormal');
    if (aNormal < 0) {
      print('Failed to get the storage location of aNormal');
      return -1;
    }
    gl.vertexAttribPointer(
        aNormal, dim, gl.FLOAT, false, Float32List.bytesPerElement * 8, Float32List.bytesPerElement * 3);
    gl.enableVertexAttribArray(aNormal);

    var aTexture = gl.getAttribLocation(glProgram, 'aTexCoords');
    if (aTexture < 0) {
      print('Failed to get the storage location of aTexCoords');
      return -1;
    }
    gl.vertexAttribPointer(
        aTexture, 2, gl.FLOAT, false, Float32List.bytesPerElement * 8, Float32List.bytesPerElement * 6);
    gl.enableVertexAttribArray(aTexture);

    // Return number of vertices
    return (vertices.length ~/ dim);
  }
}