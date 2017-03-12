/**
 * scaleinfo2.js
 * @flow
 */

import * as THREE from "three";
import type { Vector3 } from "oxalis/constants";

export function getBaseVoxel(dataSetScale: Vector3): number {
  // base voxel should be a cube with highest resolution
  return Math.min(...dataSetScale);
}

export function getBaseVoxelFactors(dataSetScale: Vector3): Vector3 {
  // base voxel should be a cube with highest resolution
  const baseVoxel = getBaseVoxel(dataSetScale);

  // scale factor to calculate the voxels in a certain
  // dimension from baseVoxels
  return [
    baseVoxel / dataSetScale[0],
    baseVoxel / dataSetScale[1],
    baseVoxel / dataSetScale[2],
  ];
}

export function getNmPerVoxelVector(dataSetScale: Vector3): THREE.Vector3 {
  return new THREE.Vector3(...dataSetScale);
}

export function getVoxelPerNMVector(dataSetScale: Vector3): THREE.Vector3 {
  const voxelPerNM = [0, 0, 0];
  for (let i = 0; i < 3; i++) {
    voxelPerNM[i] = 1 / dataSetScale[i];
  }
  return new THREE.Vector3(...voxelPerNM);
}

export function voxelToNm(dataSetScale: Vector3): Vector3 {
  return [0, 1, 2].map(i => posArray[i] * dataSetScale[i]);
}
