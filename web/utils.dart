library utils;

import 'dart:math';
import 'dart:svg';

import 'package:vector_math/vector_math.dart';

double degToRad(double deg) => deg * PI / 180.0;

double radToDeg(double rad) => rad * 180.0 / PI;

bool isIdentityMatrix(Matrix m) => m.a == 1 && m.b == 0 && m.c == 0 && m.d == 1 && m.e == 0 && m.f == 0;

Matrix3 matrixToMatrix3(Matrix m) => new Matrix3(m.a, m.c, m.e, m.b, m.d, m.f, 0.0, 0.0, 1.0);

SvgSvgElement getNearestParentSvg(SvgElement e) {
  if (e is SvgSvgElement) return e;
  SvgElement parent = e.parent;
  while (parent is SvgElement && parent is! SvgSvgElement) {
    parent = parent.parent;
  }
  if (parent is SvgSvgElement) return parent;
  return null;
}