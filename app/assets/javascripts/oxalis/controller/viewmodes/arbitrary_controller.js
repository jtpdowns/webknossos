/**
 * arbitrary_controller.js
 * @flow
 */

import * as React from "react";
import BackboneEvents from "backbone-events-standalone";
import _ from "lodash";
import { InputKeyboard, InputMouse, InputKeyboardNoLoop } from "libs/input";
import type { ModifierKeys } from "libs/input";
import { V3 } from "libs/mjs";
import Utils from "libs/utils";
import Toast from "libs/toast";
import type { ModeType, Point2 } from "oxalis/constants";
import Store from "oxalis/store";
import Model from "oxalis/model";
import {
  updateUserSettingAction,
  setFlightmodeRecordingAction,
} from "oxalis/model/actions/settings_actions";
import {
  setActiveNodeAction,
  deleteNodeWithConfirmAction,
  createNodeAction,
  createBranchPointAction,
  requestDeleteBranchPointAction,
  toggleAllTreesAction,
  toggleInactiveTreesAction,
} from "oxalis/model/actions/skeletontracing_actions";
import { getBaseVoxel } from "oxalis/model/scaleinfo";
import ArbitraryPlane from "oxalis/geometries/arbitrary_plane";
import Crosshair from "oxalis/geometries/crosshair";
import app from "app";
import ArbitraryView from "oxalis/view/arbitrary_view";
import constants from "oxalis/constants";
import type { Matrix4x4 } from "libs/mjs";
import {
  yawFlycamAction,
  pitchFlycamAction,
  zoomInAction,
  zoomOutAction,
  moveFlycamAction,
} from "oxalis/model/actions/flycam_actions";
import { getRotation, getPosition } from "oxalis/model/accessors/flycam_accessor";
import { getActiveNode, getMaxNodeId } from "oxalis/model/accessors/skeletontracing_accessor";
import messages from "messages";
import { listenToStoreProperty } from "oxalis/model/helpers/listener_helpers";
import SceneController from "oxalis/controller/scene_controller";
import api from "oxalis/api/internal_api";

const CANVAS_SELECTOR = "#render-canvas";

type Props = {
  onRender: () => void,
  viewMode: ModeType,
};

class ArbitraryController extends React.PureComponent<Props> {
  // See comment in Controller class on general controller architecture.
  //
  // Arbitrary Controller: Responsible for Arbitrary Modes
  arbitraryView: ArbitraryView;
  isStarted: boolean;
  plane: ArbitraryPlane;
  crosshair: Crosshair;
  lastNodeMatrix: Matrix4x4;
  input: {
    mouse?: InputMouse,
    keyboard?: InputKeyboard,
    keyboardLoopDelayed?: InputKeyboard,
    keyboardNoLoop?: InputKeyboardNoLoop,
  };
  storePropertyUnsubscribers: Array<Function>;

  // Copied from backbone events (TODO: handle this better)
  listenTo: Function;
  stopListening: Function;

  componentDidMount() {
    _.extend(this, BackboneEvents);
    this.input = {};
    this.storePropertyUnsubscribers = [];
    this.start();
  }

  componentWillUnmount() {
    this.stop();
  }

  initMouse(): void {
    this.input.mouse = new InputMouse(CANVAS_SELECTOR, {
      leftDownMove: (delta: Point2) => {
        if (this.props.viewMode === constants.MODE_ARBITRARY) {
          Store.dispatch(
            yawFlycamAction(delta.x * Store.getState().userConfiguration.mouseRotateValue, true),
          );
          Store.dispatch(
            pitchFlycamAction(
              delta.y * -1 * Store.getState().userConfiguration.mouseRotateValue,
              true,
            ),
          );
        } else if (this.props.viewMode === constants.MODE_ARBITRARY_PLANE) {
          const f =
            Store.getState().flycam.zoomStep /
            (this.arbitraryView.width / constants.VIEWPORT_WIDTH);
          Store.dispatch(moveFlycamAction([delta.x * f, delta.y * f, 0]));
        }
      },
      scroll: this.scroll,
      pinch: (delta: number) => {
        if (delta < 0) {
          Store.dispatch(zoomOutAction());
        } else {
          Store.dispatch(zoomInAction());
        }
      },
    });
  }

  initKeyboard(): void {
    const getRotateValue = () => Store.getState().userConfiguration.rotateValue;
    const isArbitrary = () => this.props.viewMode === constants.MODE_ARBITRARY;

    this.input.keyboard = new InputKeyboard({
      // KeyboardJS is sensitive to ordering (complex combos first)

      // Move
      space: timeFactor => {
        this.setRecord(true);
        this.move(timeFactor);
      },
      "ctrl + space": timeFactor => {
        this.setRecord(true);
        this.move(-timeFactor);
      },

      f: timeFactor => {
        this.setRecord(false);
        this.move(timeFactor);
      },
      d: timeFactor => {
        this.setRecord(false);
        this.move(-timeFactor);
      },

      // Rotate at centre
      "shift + left": timeFactor => {
        Store.dispatch(yawFlycamAction(getRotateValue() * timeFactor));
      },
      "shift + right": timeFactor => {
        Store.dispatch(yawFlycamAction(-getRotateValue() * timeFactor));
      },
      "shift + up": timeFactor => {
        Store.dispatch(pitchFlycamAction(getRotateValue() * timeFactor));
      },
      "shift + down": timeFactor => {
        Store.dispatch(pitchFlycamAction(-getRotateValue() * timeFactor));
      },

      // Rotate in distance
      left: timeFactor => {
        Store.dispatch(yawFlycamAction(getRotateValue() * timeFactor, isArbitrary()));
      },
      right: timeFactor => {
        Store.dispatch(yawFlycamAction(-getRotateValue() * timeFactor, isArbitrary()));
      },
      up: timeFactor => {
        Store.dispatch(pitchFlycamAction(-getRotateValue() * timeFactor, isArbitrary()));
      },
      down: timeFactor => {
        Store.dispatch(pitchFlycamAction(getRotateValue() * timeFactor, isArbitrary()));
      },

      // Zoom in/out
      i: () => {
        Store.dispatch(zoomInAction());
      },
      o: () => {
        Store.dispatch(zoomOutAction());
      },
    });

    // Own InputKeyboard with delay for changing the Move Value, because otherwise the values changes to drastically
    this.input.keyboardLoopDelayed = new InputKeyboard(
      {
        h: () => this.changeMoveValue(25),
        g: () => this.changeMoveValue(-25),
      },
      { delay: Store.getState().userConfiguration.keyboardDelay },
    );

    this.input.keyboardNoLoop = new InputKeyboardNoLoop({
      "1": () => {
        Store.dispatch(toggleAllTreesAction());
      },
      "2": () => {
        Store.dispatch(toggleInactiveTreesAction());
      },

      // Branches
      b: () => this.pushBranch(),
      j: () => {
        Store.dispatch(requestDeleteBranchPointAction());
      },

      // Recenter active node
      s: () => {
        getActiveNode(Store.getState().tracing).map(activeNode =>
          api.tracing.centerPositionAnimated(activeNode.position, false, activeNode.rotation),
        );
      },

      ".": () => this.nextNode(true),
      ",": () => this.nextNode(false),

      // Rotate view by 180 deg
      r: () => {
        Store.dispatch(yawFlycamAction(Math.PI));
      },

      // Delete active node and recenter last node
      "shift + space": () => {
        Store.dispatch(deleteNodeWithConfirmAction());
      },
    });
  }

  setRecord(record: boolean): void {
    if (record !== Store.getState().temporaryConfiguration.flightmodeRecording) {
      Store.dispatch(setFlightmodeRecordingAction(record));
      this.setWaypoint();
    }
  }

  nextNode(nextOne: boolean): void {
    Utils.zipMaybe(
      getActiveNode(Store.getState().tracing),
      getMaxNodeId(Store.getState().tracing),
    ).map(([activeNode, maxNodeId]) => {
      if ((nextOne && activeNode.id === maxNodeId) || (!nextOne && activeNode.id === 1)) {
        return;
      }
      Store.dispatch(setActiveNodeAction(activeNode.id + 2 * Number(nextOne) - 1)); // implicit cast from boolean to int
    });
  }

  getVoxelOffset(timeFactor: number): number {
    const state = Store.getState();
    const { moveValue3d } = state.userConfiguration;
    const baseVoxel = getBaseVoxel(state.dataset.dataSource.scale);
    return moveValue3d * timeFactor / baseVoxel / constants.FPS;
  }

  move(timeFactor: number): void {
    if (!this.isStarted) {
      return;
    }
    Store.dispatch(moveFlycamAction([0, 0, this.getVoxelOffset(timeFactor)]));
    this.moved();
  }

  init(): void {
    const { clippingDistanceArbitrary } = Store.getState().userConfiguration;
    this.setClippingDistance(clippingDistanceArbitrary);
  }

  bindToEvents(): void {
    this.listenTo(this.arbitraryView, "render", this.props.onRender);

    const onBucketLoaded = () => {
      this.arbitraryView.draw();
      app.vent.trigger("rerender");
    };

    for (const dataLayer of Model.getAllLayers()) {
      this.listenTo(dataLayer.cube, "bucketLoaded", onBucketLoaded);
    }

    this.storePropertyUnsubscribers.push(
      listenToStoreProperty(
        state => state.userConfiguration,
        userConfiguration => {
          const { clippingDistanceArbitrary, displayCrosshair, crosshairSize } = userConfiguration;
          this.setClippingDistance(clippingDistanceArbitrary);
          this.crosshair.setScale(crosshairSize);
          this.crosshair.setVisibility(displayCrosshair);
          this.arbitraryView.resize();
        },
      ),
      listenToStoreProperty(
        state => state.temporaryConfiguration.flightmodeRecording,
        isRecording => {
          if (isRecording) {
            // This listener is responsible for setting a new waypoint, when the user enables
            // the "flightmode recording" toggle in the top-left corner of the flight canvas.
            this.setWaypoint();
          }
        },
      ),
      listenToStoreProperty(
        state => state.userConfiguration.keyboardDelay,
        keyboardDelay => {
          const { keyboardLoopDelayed } = this.input;
          if (keyboardLoopDelayed != null) {
            keyboardLoopDelayed.delay = keyboardDelay;
          }
        },
      ),
    );
  }

  start(): void {
    this.arbitraryView = new ArbitraryView();
    this.arbitraryView.start();

    this.plane = new ArbitraryPlane();
    this.crosshair = new Crosshair(Store.getState().userConfiguration.crosshairSize);
    this.crosshair.setVisibility(Store.getState().userConfiguration.displayCrosshair);

    this.arbitraryView.addGeometry(this.plane);
    this.arbitraryView.addGeometry(this.crosshair);

    this.bindToEvents();

    this.initKeyboard();
    this.initMouse();
    this.init();

    const { clippingDistance } = Store.getState().userConfiguration;
    SceneController.setClippingDistance(clippingDistance);

    this.arbitraryView.draw();

    this.isStarted = true;
  }

  unsubscribeStoreListeners() {
    this.storePropertyUnsubscribers.forEach(unsubscribe => unsubscribe());
    this.storePropertyUnsubscribers = [];
  }

  stop(): void {
    this.stopListening();
    this.unsubscribeStoreListeners();

    if (this.isStarted) {
      this.destroyInput();
    }

    this.arbitraryView.stop();

    this.isStarted = false;
  }

  scroll = (delta: number, type: ?ModifierKeys) => {
    if (type === "shift") {
      this.setParticleSize(Utils.clamp(-1, delta, 1));
    }
  };

  destroyInput() {
    Utils.__guard__(this.input.mouse, x => x.destroy());
    Utils.__guard__(this.input.keyboard, x => x.destroy());
    Utils.__guard__(this.input.keyboardLoopDelayed, x => x.destroy());
    Utils.__guard__(this.input.keyboardNoLoop, x => x.destroy());
  }

  setWaypoint(): void {
    if (!Store.getState().temporaryConfiguration.flightmodeRecording) {
      return;
    }
    const position = getPosition(Store.getState().flycam);
    const rotation = getRotation(Store.getState().flycam);

    Store.dispatch(createNodeAction(position, rotation, constants.ARBITRARY_VIEW, 0));
  }

  changeMoveValue(delta: number): void {
    let moveValue = Store.getState().userConfiguration.moveValue3d + delta;
    moveValue = Math.min(constants.MAX_MOVE_VALUE, moveValue);
    moveValue = Math.max(constants.MIN_MOVE_VALUE, moveValue);

    Store.dispatch(updateUserSettingAction("moveValue3d", moveValue));

    const moveValueMessage = messages["tracing.changed_move_value"] + moveValue;
    Toast.success(moveValueMessage, { key: "CHANGED_MOVE_VALUE" });
  }

  setParticleSize(delta: number): void {
    let particleSize = Store.getState().userConfiguration.particleSize + delta;
    particleSize = Math.min(constants.MAX_PARTICLE_SIZE, particleSize);
    particleSize = Math.max(constants.MIN_PARTICLE_SIZE, particleSize);

    Store.dispatch(updateUserSettingAction("particleSize", particleSize));
  }

  setClippingDistance(value: number): void {
    this.arbitraryView.setClippingDistance(value);
  }

  pushBranch(): void {
    // Consider for deletion
    this.setWaypoint();
    Store.dispatch(createBranchPointAction());
    Toast.success(messages["tracing.branchpoint_set"]);
  }

  moved(): void {
    const matrix = Store.getState().flycam.currentMatrix;

    if (this.lastNodeMatrix == null) {
      this.lastNodeMatrix = matrix;
    }

    const { lastNodeMatrix } = this;

    const vector = [
      lastNodeMatrix[12] - matrix[12],
      lastNodeMatrix[13] - matrix[13],
      lastNodeMatrix[14] - matrix[14],
    ];
    const vectorLength = V3.length(vector);

    if (vectorLength > 10) {
      this.setWaypoint();
      this.lastNodeMatrix = matrix;
    }
  }

  render() {
    return null;
  }
}

export default ArbitraryController;
