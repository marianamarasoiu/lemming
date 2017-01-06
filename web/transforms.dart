library transforms;

import 'dart:math';
import 'dart:svg';

import 'package:vector_math/vector_math.dart';

class SvgTransformList {
  List<SvgTransform> _transformList;
  SvgElement _element;

  SvgTransformList(SvgElement element) {
    _transformList = [];
    _element = element;
  }

  void clear() {
    _transformList.clear();
    _updateTransformsOnElement();
  }

  SvgTransform initialize(SvgTransform newItem) {
    _transformList.clear();
    _transformList.add(newItem);
    _updateTransformsOnElement();
    return newItem;
  }

  SvgTransform getItem(int index) {
    return _transformList[index];
  }

  SvgTransform insertItemBefore(SvgTransform newItem, int index) {
    _transformList.insert(index, newItem);
    _updateTransformsOnElement();
    return newItem;
  }
  SvgTransform replaceItem(SvgTransform newItem, int index) {
    _transformList[index] = newItem;
    _updateTransformsOnElement();
    return newItem;
  }
  SvgTransform removeItem(int index) {
    SvgTransform removed = _transformList.removeAt(index);
    _updateTransformsOnElement();
    return removed;
  }

  SvgTransform appendItem(SvgTransform newItem) {
    _transformList.add(newItem);
    _updateTransformsOnElement();
    return newItem;
  }

  SvgTransform consolidate() {
    Matrix3 matrix = new Matrix3.identity();
    _transformList.forEach((SvgTransform transform) {
      matrix.multiply(transform.matrix);
    });
    SvgTransform transform = new SvgTransformMatrix.fromMatrix(matrix);
    _transformList.clear();
    _transformList.add(transform);
    _updateTransformsOnElement();
    return transform;
  }

  _updateTransformsOnElement() {
    _element.attributes['transform'] = toString();
  }

  // Some helper methods to work on lists.

  /// Returns [true] if there are no elements in this list.
  bool get isEmpty => _transformList.isEmpty;

  /// Returns [true] if there is at least one element in this list.
  bool get isNotEmpty => _transformList.isNotEmpty;

  /// Returns the length of this list.
  int get length => _transformList.length;

  String toString() {
    return _transformList.join(' ');
  }
}

abstract class SvgTransform {
  Matrix3 get matrix;
}


class SvgTransformMatrix extends SvgTransform {
  double a, b, c, d, e, f;

  SvgTransformMatrix(double a, double b, double c, double d, double e, double f) {
    this.a = a;
    this.b = b;
    this.c = c;
    this.d = d;
    this.e = e;
    this.f = f;
  }

  SvgTransformMatrix.fromMatrix(Matrix3 matrix) {
    this.a = matrix[0];
    this.b = matrix[1];
    this.c = matrix[3];
    this.d = matrix[4];
    this.e = matrix[6];
    this.f = matrix[7];
  }

  Matrix3 get matrix => new Matrix3(a, b, 0.0, c, d, 0.0, e, f, 1.0);

  String toString() {
    return 'matrix($a, $b, $c, $d, $e, $f)';
  }
}


class SvgTransformRotate extends SvgTransform {
  double angleRad;
  double cx;
  double cy;

  SvgTransformRotate.withAngleRad(double angleRad, double cx, double cy) {
    this.angleRad = angleRad;
    this.cx = cx;
    this.cy = cy;
  }
  
  SvgTransformRotate.withAngleDeg(double angleDeg, double cx, double cy) {
    this.angleDeg = angleDeg;
    this.cx = cx;
    this.cy = cy;
  }

  Matrix3 get matrix => new Matrix3(cos(angleRad), sin(angleRad), 0.0, -sin(angleRad), cos(angleRad), 0.0, -cx * cos(angleRad) + cy * sin(angleRad) + cx, -cx * sin(angleRad) - cy * cos(angleRad) + cy, 1.0);

  double get angleDeg => angleRad / PI * 180.0;
  set angleDeg(double value) => angleRad = value / 180.0 * PI;

  String toString() {
    return 'rotate($angleDeg, $cx, $cy)';
  }
}


class SvgTransformTranslate extends SvgTransform {
  double tx;
  double ty;

  SvgTransformTranslate(double tx, double ty) {
    this.tx = tx.toDouble();
    this.ty = ty.toDouble();
  }

  Matrix3 get matrix => new Matrix3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, tx, ty, 1.0);

  String toString() {
    return 'translate($tx, $ty)';
  }
}


class SvgTransformScale extends SvgTransform {
  double sx;
  double sy;

  SvgTransformScale(double sx, double sy) {
    this.sx = sx;
    this.sy = sy;
  }

  Matrix3 get matrix => new Matrix3(sx, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, 1.0);

  String toString() {
    return 'scale($sx, $sy)';
  }
}