library shapes;

import 'dart:math' as math;
import 'dart:svg';

import 'package:vector_math/vector_math.dart';

import 'transforms.dart';
import 'utils.dart';

abstract class Shape {
  double get rotationAngleDeg;
  double get rotationAngleRad;
  double get centerX;
  double get centerY;
  double get oldX;
  double get oldY;
  double get oldWidth;
  double get oldHeight;
  SvgElement get svgElement;
  attachToParent(SvgElement parent);
  showHighlight();
  hideHighlight();
  prepareModification();
  commitModification();
  cancelModification();
}

class Rectangle implements Shape {
  /// The topLeft x coordinate of the rectangle.
  double _x;
  double __x;

  /// The topLeft y coordinate of the rectangle.
  double _y;
  double __y;

  /// The width of the rectangle.
  double _width;
  double __width;

  /// The height of the rectangle.
  double _height;
  double __height;

  /// The colour of the rectangle.
  String _fillColour;

  /// Reference to the SVG element that represents this rectangle.
  RectElement _rect;

  /// Reference to the SVG element that represents the bounding box of this rectangle.
  RectElement _bounds;

  /// Reference to the parent of this rectangle.
  SvgElement _parent;

  /// The list of transformations.
  SvgTransformList _transformList;

  factory Rectangle({
      double x: 100.0,
      double y: 100.0,
      double width: 100.0,
      double height: 100.0,
      String fillColour: 'rgb(100%, 67.1%, 0%)'}) {
    return new Rectangle._internal(x, y, width, height, fillColour);
  }

  Rectangle._internal(this._x, this._y, this._width, this._height, this._fillColour) {
    __x = _x;
    __y = _y;
    __width = _width;
    __height = _height;
    _rect = new RectElement()
      ..attributes['x'] = '${_x}px'
      ..attributes['y'] = '${_y}px'
      ..attributes['width'] = '${_width}px'
      ..attributes['height'] = '${_height}px'
      ..style.setProperty('fill', _fillColour);
    _transformList = new SvgTransformList(_rect);
    
    _bounds = new RectElement()
      ..attributes['x'] = '${_x}px'
      ..attributes['y'] = '${_y}px'
      ..attributes['width'] = '${_width}px'
      ..attributes['height'] = '${_height}px'
      ..style.setProperty('fill', '#eeeeee');
  }

  double get x => _x;
  set x(double value) {
    _x = value;
    _rect.attributes['x'] = '${_x}px';
  }

  double get y => _y;
  set y(double value) {
    _y = value;
    _rect.attributes['y'] = '${_y}px';
  }

  double get width => _width;
  set width(double value) {
    _width = value;
    _rect.attributes['width'] = '${_width}px';
  }

  double get height => _height;
  set height(double value) {
    _height = value;
    _rect.attributes['height'] = '${_height}px';
  }

  double get rotationAngleRad => transformList.isNotEmpty && transformList.getItem(0) is SvgTransformRotate ? (transformList.getItem(0) as SvgTransformRotate).angleRad : 0.0;
  double get rotationAngleDeg => transformList.isNotEmpty && transformList.getItem(0) is SvgTransformRotate ? (transformList.getItem(0) as SvgTransformRotate).angleDeg : 0.0;

  double get centerX => bounds.left + bounds.width / 2;
  double get centerY => bounds.top + bounds.height / 2;

  double get oldX => __x;
  double get oldY => __y;
  double get oldWidth => __width;
  double get oldHeight => __height;
  double get oldCenterX => __x + __width / 2;
  double get oldCenterY => __y + __height / 2;

  String get fillColour => _fillColour;
  set fillColour(String value) {
    _fillColour = value;
    _rect.attributes['fill'] = '${_fillColour}px';
  }

  math.Rectangle get bounds {
    math.Rectangle boundingRect = _rect.getBoundingClientRect();
    math.Rectangle parentBoundingRect = getNearestParentSvg(_parent).getBoundingClientRect();
    return new math.Rectangle(
      boundingRect.left - parentBoundingRect.left,
      boundingRect.top - parentBoundingRect.top,
      boundingRect.width,
      boundingRect.height);
  }

  SvgTransformList get transformList => _transformList;

  RectElement get svgElement => _rect;

  attachToParent(SvgElement parent) {
    if (_parent != null || _parent != parent) {
      _rect.remove();
      _bounds.remove();
    }
    _parent = parent;
    updateBounds();
    parent.append(_bounds);
    parent.append(_rect);
  }

  updateBounds() {
    math.Rectangle relativeBoundingRect = bounds;
    print('x: ${relativeBoundingRect.left}, y: ${relativeBoundingRect.top}, width: ${relativeBoundingRect.width}, height: ${relativeBoundingRect.height}');
    _bounds
      ..attributes['x'] = '${relativeBoundingRect.left}px'
      ..attributes['y'] = '${relativeBoundingRect.top}px'
      ..attributes['width'] = '${relativeBoundingRect.width}px'
      ..attributes['height'] = '${relativeBoundingRect.height}px';
  }

  showHighlight() {
    _rect.style.setProperty('stroke', 'black');
  }

  hideHighlight() {
    _rect.style.setProperty('stroke', 'none');
  }

  prepareModification() {
    __x = _x;
    __y = _y;
    __width = _width;
    __height = _height;
  }

  commitModification() {
    __x = _x;
    __y = _y;
    __width = _width;
    __height = _height;

    // Exit here if the shape has no transforms.
    if (transformList.length == 0) {
      return;
    }

    bool firstTransformIsRotation = transformList.getItem(0) is SvgTransformRotate;

    // Exit here if the shape has just one rotational transform.
    if (transformList.length == 1 && firstTransformIsRotation) {
      return;
    }

    // If the shape has a rotational transform and a translation, or just a translation,
    // remove the translation and update the position of the shape.
    if (transformList.length <= 2) {
      int translateIndex = firstTransformIsRotation ? 1 : 0;
      SvgTransform translation = transformList.getItem(translateIndex);
      Matrix3 translationMatrix = translation.matrix;
      Vector3 xy = translationMatrix.transform(new Vector3(x, y, 1.0));
      x = xy.x;
      y = xy.y;

      transformList.removeItem(translateIndex);
    } else {
      // Otherwise, expect that the shape has a rotational transform ([R])
      // and a scaling transform ([T][S][-T]) or just a scaling transform ([T][S][-T]).
      int translateAwayIndex = firstTransformIsRotation ? 1 : 0;
      int scaleIndex = firstTransformIsRotation ? 2 : 1;
      int translateBackIndex = firstTransformIsRotation ? 3 : 2;
      
      Matrix3 scaleMatrix = transformList.getItem(translateAwayIndex).matrix
        ..multiply(transformList.getItem(scaleIndex).matrix)
        ..multiply(transformList.getItem(translateBackIndex).matrix);

      Vector3 xy = scaleMatrix.transform(new Vector3(x, y, 1.0));
      x = xy.x;
      y = xy.y;
      width = scaleMatrix[0] * width;
      height = scaleMatrix[4] * height;

      transformList
        ..removeItem(translateBackIndex)
        ..removeItem(scaleIndex)
        ..removeItem(translateAwayIndex);
    }

    // If the first transform is a rotation, then update it to match the center of the new dimensions.
    if (transformList.length == 1 && firstTransformIsRotation) {
      // [Rold][T][S][-T] became [Rold] for a different set of dimensions (i.e. x, y, width, height).
      // We want it to be [Rnew][Tr] where [Rnew] is centered on the new dimensions and
      // Tr is the translation required to re-center it.
      // Therefore, [Tr] = [Rnew_inv][Rold]
      SvgTransformRotate oldRotation = transformList.getItem(0);
      SvgTransformRotate newRotation = new SvgTransformRotate.withAngleRad(rotationAngleRad, centerX, centerY);

      Matrix3 oldRotationMatrix = oldRotation.matrix;
      Matrix3 newRotationMatrix = newRotation.matrix;
      Matrix3 translateMatrix = newRotationMatrix;
      translateMatrix.invert();
      translateMatrix.multiply(oldRotationMatrix);

      Vector3 xy = translateMatrix.transform(new Vector3(x, y, 1.0));
      x = xy.x;
      y = xy.y;

      transformList.replaceItem(newRotation, 0);
    }
  }

  cancelModification() {
    _x = __x;
    _y = __y;
    _width = __width;
    _height = __height;
  }
}