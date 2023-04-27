import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:graphics_flutter/render/ExampleCameraCircle.dart';
import 'package:graphics_flutter/render/ExampleCanvas.dart';
import 'package:graphics_flutter/render/ExampleColorAtVertex.dart';
import 'package:graphics_flutter/render/ExampleCoordinateSystem.dart';
import 'package:graphics_flutter/render/ExampleCube.dart';
import 'package:graphics_flutter/render/ExampleCubeMultiple.dart';
import 'package:graphics_flutter/render/ExampleDiffuseMap.dart';
import 'package:graphics_flutter/render/ExampleLightDiffuse.dart';
import 'package:graphics_flutter/render/ExampleMaterials.dart';
import 'package:graphics_flutter/render/ExampleRectagle.dart';
import 'package:graphics_flutter/render/ExampleShaderUniform.dart';
import 'package:graphics_flutter/render/ExampleShaders.dart';
import 'package:graphics_flutter/render/ExampleTexture.dart';
import 'package:graphics_flutter/render/ExampleTextureColor.dart';
import 'package:graphics_flutter/render/ExampleTextureUnit.dart';
import 'package:graphics_flutter/render/ExampleTransformation.dart';
import 'package:graphics_flutter/render/ExampleTriangle.dart';
import 'render/Example3D.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleCanvas();
    //return ExampleTriangle();
    //return ExampleRectagle();
    //return ExampleShaders();
    //return ExampleShaderUniform();
    //return ExampleColorAtVertex();
    //return ExampleTexture();
    //return ExampleTextureColor();
    //return ExampleTextureUnit();
    //return ExampleTransformation();
    //return ExampleCoordinateSystem();
    //return Example3D();
    //return ExampleCube();
    //return ExampleCubeMultiple();
    //return ExampleCameraCircle();
    //return ExampleLightDiffuse();
    //return ExampleMaterials();
    //return ExampleDiffuseMap();
  }
}