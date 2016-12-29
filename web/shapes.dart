library shapes;

import 'dart:math' as math;
import 'dart:svg';

abstract class Shape {
  Bounds get bounds;
  double rotationPointX;
  double rotationPointY;
  double rotationAngle;
  double rotationAngleRad;
  double get rotationPointAbsoluteX;
  double get rotationPointAbsoluteY;
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

class Bounds {
  double topLeftX;
  double topLeftY;
  double topRightX;
  double topRightY;
  double bottomLeftX;
  double bottomLeftY;
  double bottomRightX;
  double bottomRightY;

  factory Bounds.fromTwoPoints(double topLeftX, double topLeftY, double bottomRightX, double bottomRightY) {
    return new Bounds._internal(topLeftX, topLeftY, bottomRightX, topLeftY, topLeftX, bottomRightY, bottomRightX, bottomRightY);
  }
  factory Bounds.fromPointAndSize(double topLeftX, double topLeftY, double width, double height) {
    return new Bounds._internal(topLeftX, topLeftY, topLeftX + width, topLeftY, topLeftX, topLeftY + height, topLeftX + width, topLeftY + height);
  }
  Bounds._internal(this.topLeftX, this.topLeftY, this.topRightX, this.topRightY, this.bottomLeftX, this.bottomLeftY, this.bottomRightX, this.bottomRightY);

  bool operator ==(o) => o is Bounds && o.topLeftX == topLeftX && o.topLeftY == topLeftY && o.bottomRightX == bottomRightX && o.bottomRightY == bottomRightY;

  String toString() {
    return 'topLeft: <$topLeftX, $topLeftY>\ntopRight: <$topRightX, $topRightY>\nbottomLeft: <$bottomLeftX, $bottomLeftY>\nbottomRight: <$bottomRightX, $bottomRightY>\n';
  } 
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

  /// The rotation points relative to the center;
  double _rotationPointX;
  double _rotationPointY;
  double _rotationAngle;

  /// The colour of the rectangle.
  String _fillColour;

  /// Reference to the SVG element that represents this rectangle.
  RectElement _rect;

  /// Reference to the SVG element that represents the bounding box of this rectangle.
  RectElement _bounds;

  /// Reference to the parent of this rectangle.
  SvgElement _parent;

  factory Rectangle({
      double x: 100.0,
      double y: 100.0,
      double width: 100.0,
      double height: 100.0,
      String fillColour: 'rgb(100%, 67.1%, 0%)'}) {
    return new Rectangle._internal(x, y, width, height, fillColour);
  }

  Rectangle._internal(this._x, this._y, this._width, this._height, this._fillColour) {
    _rotationPointX = 0.0;
    _rotationPointY = 0.0;
    _rotationAngle = 0.0;
    _rect = new RectElement()
      ..attributes['x'] = '${_x}px'
      ..attributes['y'] = '${_y}px'
      ..attributes['width'] = '${_width}px'
      ..attributes['height'] = '${_height}px'
      ..attributes['transform'] = 'rotate($_rotationAngle, $_rotationPointX, $_rotationPointY)'
      ..style.setProperty('fill', _fillColour);
    Bounds b = bounds;
    _bounds = new RectElement()
      ..attributes['x'] = '${b.topLeftX}px'
      ..attributes['y'] = '${b.topLeftY}px'
      ..attributes['width'] = '${b.topRightX - b.topLeftX}px'
      ..attributes['height'] = '${b.bottomLeftY - b.topLeftY}px'
      ..style.setProperty('fill', '#eeeeee');
  }

  double get x => _x;
  set x(double value) {
    _x = value;
    _rect.attributes['x'] = '${_x}px';
    _updateTransformAttribute();
  }

  double get y => _y;
  set y(double value) {
    _y = value;
    _rect.attributes['y'] = '${_y}px';
    _updateTransformAttribute();
  }

  double get width => _width;
  set width(double value) {
    _width = value;
    _rect.attributes['width'] = '${_width}px';
    _updateTransformAttribute();
  }

  double get height => _height;
  set height(double value) {
    _height = value;
    _rect.attributes['height'] = '${_height}px';
    _updateTransformAttribute();
  }

  double get rotationPointX => _rotationPointX;
  set rotationPointX(double value) {
     _rotationPointX = value;
     _updateTransformAttribute();
  }

  double get rotationPointY => _rotationPointY;
  set rotationPointY(double value) {
     _rotationPointY = value;
     _updateTransformAttribute();
  }

  double get rotationAngle => _rotationAngle;
  set rotationAngle(double value) {
     _rotationAngle = value;
     _updateTransformAttribute();
  }

  double get rotationAngleRad => rotationAngle * math.PI / 180.0;
  set rotationAngleRad(double value) {
    _rotationAngle = value * 180.0 / math.PI;
    _updateTransformAttribute();
  }

  _updateTransformAttribute() {
    _rect.attributes['transform'] = 'rotate($rotationAngle, ${centerX + rotationPointX}, ${centerY + rotationPointY})';
    _updateBounds();
  }

  _updateBounds() {
    Bounds b = bounds;
    _bounds
      ..attributes['x'] = '${b.topLeftX}px'
      ..attributes['y'] = '${b.topLeftY}px'
      ..attributes['width'] = '${b.topRightX - b.topLeftX}px'
      ..attributes['height'] = '${b.bottomLeftY - b.topLeftY}px';
  }

  double get rotationPointAbsoluteX => centerX + rotationPointX;
  double get rotationPointAbsoluteY => centerY + rotationPointY;
  double get centerX => _x + _width / 2;
  double get centerY => _y + _height / 2;

  double get oldX => __x;
  double get oldY => __y;
  double get oldWidth => __width;
  double get oldHeight => __height;
  
  String get fillColour => _fillColour;
  set fillColour(String value) {
    _fillColour = value;
    _rect.attributes['fill'] = '${_fillColour}px';
  }

  Bounds get bounds {
    double topLeftX = centerX + (-width / 2) * math.cos(rotationAngleRad) - (-height / 2) * math.sin(rotationAngleRad);
    double topLeftY = centerY + (-height / 2) * math.cos(rotationAngleRad) + (-width / 2) * math.sin(rotationAngleRad);
    double topRightX = topLeftX + math.cos(rotationAngleRad) * width;
    double topRightY = topLeftY + math.sin(rotationAngleRad) * width;
    double bottomLeftX = topLeftX - math.sin(rotationAngleRad) * height;
    double bottomLeftY = topLeftY + math.cos(rotationAngleRad) * height;
    double bottomRightX = topLeftX + math.cos(rotationAngleRad) * width - math.sin(rotationAngleRad) * height;
    double bottomRightY = topLeftY + math.sin(rotationAngleRad) * width + math.cos(rotationAngleRad) * height;
    double boundsTopLeftX = [topLeftX, topRightX, bottomLeftX, bottomRightX].reduce(math.min);
    double boundsTopLeftY = [topLeftY, topRightY, bottomLeftY, bottomRightY].reduce(math.min);
    double boundsBottomRightX = [topLeftX, topRightX, bottomLeftX, bottomRightX].reduce(math.max);
    double boundsBottomRightY = [topLeftY, topRightY, bottomLeftY, bottomRightY].reduce(math.max);
    return new Bounds.fromTwoPoints(boundsTopLeftX, boundsTopLeftY, boundsBottomRightX, boundsBottomRightY);
  }

  RectElement get svgElement => _rect;

  attachToParent(SvgElement parent) {
    if (_parent != null || _parent != parent) {
      _rect.remove();
      _bounds.remove();
    }
    _parent = parent;
    parent.append(_bounds);
    parent.append(_rect);
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
    __x = null;
    __y = null;
    __width = null;
    __height = null;
  }

  cancelModification() {
    _x = __x;
    _y = __y;
    _width = __width;
    _height = __height;
  }
}