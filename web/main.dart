import 'dart:html';
import 'dart:math';
import 'dart:svg';

import 'package:statemachine/statemachine.dart';

import 'shapes.dart' as shapes;
import 'transforms.dart';

Map<RectElement, shapes.Rectangle> svgToShapes = {};

double offset = 0.0;

main() {
  SvgSvgElement container = querySelector('#vis-container');
  shapes.Rectangle rect = new shapes.Rectangle();
  rect.attachToParent(container.querySelector('#vis'));
  svgToShapes[rect.svgElement] = rect;

  shapes.Rectangle rect2 = new shapes.Rectangle(x: 300.0, fillColour: 'rgb(30%, 60%, 0%)');
  rect2.attachToParent(container.querySelector('#vis'));
  svgToShapes[rect2.svgElement] = rect2;

  new VisStateMachine(root: container);
}

class VisStateMachine {
  /// The element this shape machine is installed on.
  final SvgElement root;

  /// The id used to store the visualisation.
  final GElement visGroup;
  
  /// The id used to store the controls, such as resize controls, the rotate control, highlights.
  final GElement controlsGroup;

  /// The data key used to identify resize controls.
  final String resizeControlDataKey;

  /// The data key used to identify rotate controls.
  final String rotateControlDataKey;

  /// The CSS class applied to the controllers to show them.
  final String visibleCssClass;

  /// The state machine for selecting the shapes.
  final Machine selectionMachine = new Machine();

  /// The state machine for selecting the shapes.
  final Machine manipulationMachine = new Machine();

  // Various (internal) states of the selection machine.
  State _deselected;
  State _highlighted;
  State _selected;

  // Various (internal) states of the manipulation machine.
  State _waiting;
  State _moving;
  State _resizing;
  State _rotating;

  /// The currently active shape.
  shapes.Rectangle _shape;

  /// Used when moving and resizing shapes.
  double mousePositionXAtActionStart;
  double mousePositionYAtActionStart;
  SvgElement controlHandle;
  String resizeDirection = '';

  /// Constructor for the shape machine.
  factory VisStateMachine({
      SvgElement root: null,
      String visGroupId: 'vis',
      String controlsGroupId: 'controls',
      String resizeControlDataKey: 'resize-control',
      String rotateControlDataKey: 'rotate-control',
      String visibleCssClass: 'visible'}) {
    return new VisStateMachine._internal(
      root == null ? document.body : root,
      root.querySelector('#${visGroupId}'),
      root.querySelector('#${controlsGroupId}'),
      resizeControlDataKey, rotateControlDataKey,
      visibleCssClass);
  }

  VisStateMachine._internal(this.root, this.visGroup, this.controlsGroup,
      this.resizeControlDataKey, this.rotateControlDataKey, this.visibleCssClass) {
    // States of the selectionMachine.
    _deselected = selectionMachine.newState('deselected')
      // Hovering over a shape makes it highlighted.
      ..onStream(root.onMouseOver, (MouseEvent overEvent) {
          print('_deselected.onStream(onMouseOver)');
          Element element = overEvent.target;
          if (svgToShapes.containsKey(element)) {
            _shape = svgToShapes[element];
            _highlighted.enter();
          }
        });

    _highlighted = selectionMachine.newState('highlighted')
      ..onEntry(() {
          print('_highlighted.onEntry()');
          _shape.showHighlight();
        })
      // Clicking a highlighted shape selects it.
      ..onStream(root.onMouseDown, (MouseEvent downEvent) {
          print('_highlighted.onStream(onMouseDown)');
          Element element = downEvent.target;
          if (svgToShapes.containsKey(element)) {
            _shape = svgToShapes[element];
            _selected.enter();
          }
        })
      // Moving the mouse out de-highlights the shape.
      ..onStream(root.onMouseOut, (MouseEvent outEvent) {
          print('_highlighted.onStream(onMouseOut)');
          _shape.hideHighlight();
          _shape = null;
          _deselected.enter();
        });

    _selected = selectionMachine.newState('selected')
      ..addNested(manipulationMachine)
      ..onEntry(() {
          print('_selected.onEntry()');
          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
          print('_selected.onStream(onMouseUp)');
          Element element = upEvent.target;
          if (svgToShapes.containsKey(element)) {
            if (element != _shape.svgElement) {
              hideManipulationControls(_shape);
              _shape.hideHighlight();
              _shape = svgToShapes[element];
              showManipulationControls(_shape);
            }
          } else if (element.dataset.containsKey(resizeControlDataKey)) { // Nothing to do here
          } else if (manipulationMachine.current == _rotating) { // Nothing to do here
          } else {
            _shape.hideHighlight();
            hideManipulationControls(_shape);
            _shape = null;
            _deselected.enter();
          }
        });

    selectionMachine.start();

    // States of the manipulationMachine.
    _moving = manipulationMachine.newState('moving')
      ..onStream(root.onMouseMove, (MouseEvent moveEvent) {
          print('_moving.onStream(onMouseMove)');
          if (mousePositionXAtActionStart == null || mousePositionYAtActionStart == null) {
            mousePositionXAtActionStart = moveEvent.client.x;
            mousePositionYAtActionStart = moveEvent.client.y;
            _shape.prepareModification();
          }
          double movementX = moveEvent.client.x - mousePositionXAtActionStart;
          double movementY = moveEvent.client.y - mousePositionYAtActionStart;
  
          // If rotated, adjust the movement values, which are projections onto a rotated coordinate system.
          // See https://drive.google.com/open?id=0B7t9zvRbqLSybXRnNkM2RlE0Unc for a visual description of the formulas.
          if (_shape.rotationAngleRad > 0.0 || _shape.rotationAngleRad < 0.0) {
            var r = sqrt(movementX * movementX + movementY * movementY);
            var theta = atan2(movementY, movementX) - _shape.rotationAngleRad;
            movementX = r * cos(theta);
            movementY = r * sin(theta);
          }

          SvgTransform translate = new SvgTransformTranslate(movementX, movementY);

          if (_shape.transformList.length == 0 || // No other transform
             (_shape.transformList.length == 1 && _shape.transformList.getItem(0) is SvgTransformRotate)) { // There is one transform, and it's a rotation
            _shape.transformList.appendItem(translate);
          } else {
            bool hasRotationTransform = _shape.transformList.getItem(0) is SvgTransformRotate;
            _shape.transformList.replaceItem(translate, hasRotationTransform ? 1 : 0);
          }

          _shape.updateBounds();
          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
        print('_moving.onStream(onMouseUp)');
          // Clear the mouse position.
          mousePositionXAtActionStart = null;
          mousePositionYAtActionStart = null;
          _shape.commitModification();
          _waiting.enter();
        });

    _resizing = manipulationMachine.newState('resizing')
      ..onStream(root.onMouseMove, (MouseEvent moveEvent) {
          print('_resizing.onStream(onMouseMove)');
          if (mousePositionXAtActionStart == null || mousePositionYAtActionStart == null) {
            mousePositionXAtActionStart = moveEvent.client.x;
            mousePositionYAtActionStart = moveEvent.client.y;
            controlHandle = moveEvent.target;
            _shape.prepareModification();
          }

          double movementX = moveEvent.client.x - mousePositionXAtActionStart;
          double movementY = moveEvent.client.y - mousePositionYAtActionStart;
  
          // If rotated, adjust the movement values, which are projections onto a rotated coordinate system.
          // See https://drive.google.com/open?id=0B7t9zvRbqLSybXRnNkM2RlE0Unc for a visual description of the formulas.
          if (_shape.rotationAngleRad > 0.0 || _shape.rotationAngleRad < 0.0) {
            var r = sqrt(movementX * movementX + movementY * movementY);
            var theta = atan2(movementY, movementX) - _shape.rotationAngleRad;
            movementX = r * cos(theta);
            movementY = r * sin(theta);
          }

          double tx = _shape.x;
          double ty = _shape.y;
          double sx = (_shape.width + movementX) / _shape.width;
          double sy = (_shape.height + movementY) / _shape.height;

          if (resizeDirection.contains('left')) {
            tx = _shape.x + _shape.width;
            sx = (_shape.width - movementX) / _shape.width;
          }

          if (resizeDirection.contains('top')) {
            ty = _shape.y + _shape.height;
            sy = (_shape.height - movementY) / _shape.height;
          }

          SvgTransform translateAway = new SvgTransformTranslate(tx, ty);
          SvgTransform scale = new SvgTransformScale(sx , sy);
          SvgTransform translateBack = new SvgTransformTranslate(-tx, -ty);

          if (_shape.transformList.length == 0 || // No other transform
             (_shape.transformList.length == 1 && _shape.transformList.getItem(0) is SvgTransformRotate)) { // There is one transform, and it's a rotation
            _shape.transformList
              ..appendItem(translateAway)
              ..appendItem(scale)
              ..appendItem(translateBack);
          } else {
            bool hasRotationTransform = _shape.transformList.getItem(0) is SvgTransformRotate;
            _shape.transformList
              ..replaceItem(translateAway, hasRotationTransform ? 1 : 0)
              ..replaceItem(scale, hasRotationTransform ? 2 : 1)
              ..replaceItem(translateBack, hasRotationTransform ? 3 : 2);
          }

          _shape.updateBounds();
          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
          print('_resizing.onStream(onMouseUp)');
          // Clear the mouse position.
          mousePositionXAtActionStart = null;
          mousePositionYAtActionStart = null;
          controlHandle = null;
          resizeDirection = '';
          _shape.commitModification();
          _waiting.enter();
        });

    _rotating = manipulationMachine.newState('rotating')
      ..onStream(root.onMouseMove, (MouseEvent moveEvent) {
          print('_rotating.onStream(onMouseMove)');
          if (controlHandle == null) {
            controlHandle = moveEvent.target;
            resizeDirection = controlHandle.dataset['resizeDirection'];
            _shape.prepareModification();
          }

          // Find the angle between the current mouse position and the rotation center.
          // See https://drive.google.com/open?0B7t9zvRbqLSyTk1pdFJOdFRRQmc for a visual description of the formulas.
          double centerX, centerY;
          if (_shape.transformList.length > 0 && _shape.transformList.getItem(0) is SvgTransformRotate) {
            SvgTransformRotate oldRotate = _shape.transformList.getItem(0);
            centerX = oldRotate.cx;
            centerY = oldRotate.cy;
          } else {
            centerX = _shape.centerX;
            centerY = _shape.centerY;
          }
          var angle = atan2(centerY - moveEvent.offset.y, centerX - moveEvent.offset.x) - PI / 2;

          SvgTransform rotate = new SvgTransformRotate.withAngleRad(angle, centerX, centerY);
          print(rotate);

          // The rotation is always the first transformation in the list.
          if (_shape.transformList.length == 0) {
            _shape.transformList.appendItem(rotate);
          } else if (_shape.transformList.getItem(0) is SvgTransformRotate) {
            _shape.transformList.replaceItem(rotate, 0);
          } else {
            _shape.transformList.insertItemBefore(rotate, 0);
          }

          _shape.updateBounds();
          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
          print('_rotating.onStream(onMouseUp)');
          controlHandle = null;
          resizeDirection = '';
          _shape.commitModification();
          _waiting.enter();
        });

    _waiting = manipulationMachine.newState('waiting')
      ..onStream(root.onMouseDown, (MouseEvent downEvent) {
          print('_waiting.onStream(onMouseDown)');
          Element element = downEvent.target;
          if (element == _shape.svgElement) { // Click on the shape, enter move.
            mousePositionXAtActionStart = downEvent.client.x;
            mousePositionYAtActionStart = downEvent.client.y;
            _shape.prepareModification();
            _moving.enter();
          } else if (element.dataset.containsKey(resizeControlDataKey)) { // Click on a resize control, enter resize.
            mousePositionXAtActionStart = downEvent.client.x;
            mousePositionYAtActionStart = downEvent.client.y;
            controlHandle = element;
            resizeDirection = controlHandle.dataset['resizeDirection'];
            _shape.prepareModification();
            _resizing.enter();
          } else if (element.dataset.containsKey(rotateControlDataKey)) { // Click on the rotate control, enter rotate.
            controlHandle = element;
            resizeDirection = controlHandle.dataset['resizeDirection'];
            _shape.prepareModification();
            _rotating.enter();
          }
        });
  }

  showManipulationControls(shapes.Shape shape) {
    GElement highlights = controlsGroup.querySelector('#highlights');
    RectElement borderHighlight = highlights.querySelector('.border-highlight');
    if (shape is shapes.Rectangle) {
      borderHighlight.setAttribute('x', '${shape.x}px');
      borderHighlight.setAttribute('y', '${shape.y}px');
      borderHighlight.setAttribute('width', '${shape.width}px');
      borderHighlight.setAttribute('height', '${shape.height}px');
    }
    highlights.classes.add(visibleCssClass);

    GElement resizeControls = controlsGroup.querySelector('#resize-controls');
    RectElement topLeft = resizeControls.querySelector('.top-left');
    RectElement bottomRight = resizeControls.querySelector('.bottom-right');
    RectElement topRight = resizeControls.querySelector('.top-right');
    RectElement bottomLeft = resizeControls.querySelector('.bottom-left');
    if (shape is shapes.Rectangle) {
      topLeft.setAttribute('x', '${shape.x - 2}px');
      topLeft.setAttribute('y', '${shape.y - 2}px');
      bottomRight.setAttribute('x', '${shape.x + shape.width - 2}px');
      bottomRight.setAttribute('y', '${shape.y + shape.height - 2}px');
      topRight.setAttribute('x', '${shape.x + shape.width - 2}px');
      topRight.setAttribute('y', '${shape.y - 2}px');
      bottomLeft.setAttribute('x', '${shape.x - 2}px');
      bottomLeft.setAttribute('y', '${shape.y + shape.height - 2}px');
    }
    resizeControls.classes.add(visibleCssClass);

    GElement rotateControls = controlsGroup.querySelector('#rotate-controls');
    LineElement line = rotateControls.querySelector('line');
    EllipseElement ellipse = rotateControls.querySelector('ellipse');
    if (shape is shapes.Rectangle) {
      line.setAttribute('x1', '${shape.x + shape.width / 2}px');
      line.setAttribute('y1', '${shape.y}px');
      line.setAttribute('x2', '${shape.x + shape.width / 2}px');
      line.setAttribute('y2', '${shape.y - 10}px');

      ellipse.setAttribute('cx', '${shape.x + shape.width / 2}px');
      ellipse.setAttribute('cy', '${shape.y - 12}px');
    }
    rotateControls.classes.add(visibleCssClass);
    controlsGroup.attributes['transform'] = shape.svgElement.attributes['transform'];
  }

  hideManipulationControls(shapes.Shape shape) {
    GElement highlights = controlsGroup.querySelector('#highlights');
    highlights.classes.remove(visibleCssClass);
    GElement resizeControls = controlsGroup.querySelector('#resize-controls');
    resizeControls.classes.remove(visibleCssClass);
    GElement rotateControls = controlsGroup.querySelector('#rotate-controls');
    rotateControls.classes.remove(visibleCssClass);
  }
}