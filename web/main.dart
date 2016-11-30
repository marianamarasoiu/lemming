import 'dart:html';
import 'dart:math';
import 'dart:svg';

import 'package:statemachine/statemachine.dart';

import 'shapes.dart' as shapes;

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
  shapes.Shape _shape;

  /// Used when moving and resizing shapes.
  double mousePositionXAtActionStart;
  double mousePositionYAtActionStart;
  SvgElement controlHandle;

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
          _shape.x = _shape.oldX + moveEvent.client.x - mousePositionXAtActionStart;
          _shape.y = _shape.oldY + moveEvent.client.y - mousePositionYAtActionStart;

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
            var angleInRads = (_shape.rotationAngle + offset) * PI / 180.0;
            mousePositionXAtActionStart = moveEvent.client.x * cos(angleInRads) - moveEvent.client.y * sin(angleInRads);
            mousePositionYAtActionStart = moveEvent.client.x * sin(angleInRads) + moveEvent.client.y * cos(angleInRads);
            controlHandle = moveEvent.target;
            _shape.prepareModification();
          }
          var angleInRads = (_shape.rotationAngle + offset) * PI / 180.0;
          double mousePositionX = moveEvent.client.x * cos(angleInRads) - moveEvent.client.y * sin(angleInRads);
          double mousePositionY = moveEvent.client.x * sin(angleInRads) + moveEvent.client.y * cos(angleInRads);
          double movementX = mousePositionX - mousePositionXAtActionStart;
          double movementY = mousePositionY - mousePositionYAtActionStart;

          print(movementX);
          print(movementY);

          if (controlHandle.classes.contains('top-left')) {
            double tentativeWidth = _shape.oldWidth - movementX;
            double tentativeHeight = _shape.oldHeight - movementY;

            if (tentativeWidth < 0.0) {
              movementX = movementX + tentativeWidth;
            }
            if (tentativeHeight < 0.0) {
              movementY = movementY + tentativeHeight;
            }

            _shape.x = _shape.oldX + movementX;
            _shape.y = _shape.oldY + movementY;
            _shape.width = _shape.oldWidth - movementX;
            _shape.height = _shape.oldHeight - movementY;
          } else if (controlHandle.classes.contains('bottom-right')) {
            double tentativeWidth = _shape.oldWidth + movementX;
            double tentativeHeight = _shape.oldHeight + movementY;

            if (tentativeWidth < 0.0) {
              movementX = movementX - tentativeWidth;
            }
            if (tentativeHeight < 0.0) {
              movementY = movementY - tentativeHeight;
            }

            _shape.width = _shape.oldWidth + movementX;
            _shape.height = _shape.oldHeight + movementY;
          } else if (controlHandle.classes.contains('top-right')) {
            double tentativeWidth = _shape.oldWidth + movementX;
            double tentativeHeight = _shape.oldHeight - movementY;

            if (tentativeWidth < 0.0) {
              movementX = movementX - tentativeWidth;
            }
            if (tentativeHeight < 0.0) {
              movementY = movementY + tentativeHeight;
            }

            _shape.y = _shape.oldY + movementY;
            _shape.width = _shape.oldWidth + movementX;
            _shape.height = _shape.oldHeight - movementY;
          } else if (controlHandle.classes.contains('bottom-left')) {
            double tentativeWidth = _shape.oldWidth - movementX;
            double tentativeHeight = _shape.oldHeight + movementY;

            if (tentativeWidth < 0.0) {
              movementX = movementX + tentativeWidth;
            }
            if (tentativeHeight < 0.0) {
              movementY = movementY - tentativeHeight;
            }

            _shape.x = _shape.oldX + movementX;
            _shape.width = _shape.oldWidth - movementX;
            _shape.height = _shape.oldHeight + movementY;
          }

          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
          print('_resizing.onStream(onMouseUp)');
          // Clear the mouse position.
          mousePositionXAtActionStart = null;
          mousePositionYAtActionStart = null;
          controlHandle = null;
          _shape.commitModification();
          _waiting.enter();
        });

    _rotating = manipulationMachine.newState('rotating')
      ..onStream(root.onMouseMove, (MouseEvent moveEvent) {
          print('_rotating.onStream(onMouseMove)');
          if (controlHandle == null) {
            controlHandle = moveEvent.target;
            _shape.prepareModification();
          }

          // TODO: find an explanation for this
          var angle = -atan2(-moveEvent.offset.x + _shape.rotationPointAbsoluteX, -moveEvent.offset.y + _shape.rotationPointAbsoluteY);
          print(angle * (180.0 / PI));
          _shape.rotationAngle = angle * (180.0 / PI);
          showManipulationControls(_shape);
        })
      ..onStream(root.onMouseUp, (MouseEvent upEvent) {
          print('_rotating.onStream(onMouseUp)');
          controlHandle = null;
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
          var angleInRads = (_shape.rotationAngle + offset) * PI / 180.0;
            mousePositionXAtActionStart = downEvent.client.x * cos(angleInRads) - downEvent.client.y * sin(angleInRads);
            mousePositionYAtActionStart = downEvent.client.x * sin(angleInRads) + downEvent.client.y * cos(angleInRads);
            controlHandle = element;
            _shape.prepareModification();
            _resizing.enter();
          } else if (element.dataset.containsKey(rotateControlDataKey)) { // Click on the rotate control, enter rotate.
            controlHandle = element;
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