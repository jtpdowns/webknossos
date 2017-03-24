// @flow
import _ from "lodash";
import * as THREE from "three";
import ParticleMaterialFactory from "oxalis/geometries/materials/particle_material_factory";
import type { Vector3 } from "oxalis/constants";
import type { TreeType, NodeType } from "oxalis/store";
import type Model from "oxalis/model";

class TGeometry {


  constructor(trees: Array<TreeType>, model: Model) {

    const nodeCount = Math.max(_.sumBy(trees, tree => _.size(tree.nodes)), 1000);
    const nodeGeometry = new THREE.BufferGeometry();
    nodeGeometry.addAttribute("position", new THREE.BufferAttribute(new Float32Array(nodeCount * 3), 3));
    nodeGeometry.addAttribute("radius", new THREE.BufferAttribute(new Float32Array(nodeCount), 1));
    nodeGeometry.addAttribute("typ", new THREE.BufferAttribute(new Float32Array(nodeCount), 1));
    nodeGeometry.addAttribute("nodeId", new THREE.BufferAttribute(new Float32Array(nodeCount), 1));
    nodeGeometry.addAttribute("treeId", new THREE.BufferAttribute(new Float32Array(nodeCount), 1));
    this.nodeGeometry = nodeGeometry;

    nodeGeometry.attributes.position.setDynamic(true);
    nodeGeometry.attributes.radius.setDynamic(true);
    nodeGeometry.attributes.typ.setDynamic(true);
    nodeGeometry.attributes.nodeId.setDynamic(true);
    nodeGeometry.attributes.treeId.setDynamic(true);

    const edgeCount = _.sumBy(trees, tree => tree.edges.length);
    const edgeGeometry = new THREE.BufferGeometry();
    edgeGeometry.setIndex(new THREE.BufferAttribute(new Uint16Array(edgeCount * 2), 1));
    edgeGeometry.addAttribute("position", nodeGeometry.attributes.position);
    edgeGeometry.addAttribute("treeId", new THREE.BufferAttribute(new Float32Array(edgeCount), 1));
    this.edgeGeometry = edgeGeometry;


    // this.edges = new THREE.LineSegments(
    //   edgeGeometry,
    //   new THREE.RawShaderMaterial({
    //     color: new THREE.Color().fromArray(treeColor),
    //     linewidth: this.getLineWidth(),
    //   }),
    // );

    this.particleMaterial = new ParticleMaterialFactory(model).getMaterial();
    this.nodes = new THREE.Points(nodeGeometry, this.particleMaterial);

    this.nodeCount = 0;
    this.nodeMap = new Map();

    for (const tree of trees) {
      this.addTree(tree);
    }
  }

  addNode(node: NodeType, treeId: number) {

    const index = this.nodeCount;
    const nodeGeometryAttributes = this.nodes.geometry.attributes;

    nodeGeometryAttributes.position.set(node.position, index * 3);
    nodeGeometryAttributes.radius.array[index] = node.radius;
    nodeGeometryAttributes.typ.array[index] = 0.0;
    nodeGeometryAttributes.nodeId.array[index] = node.id;
    nodeGeometryAttributes.treeId.array[index] = treeId;

    nodeGeometryAttributes.position.needsUpdate = true;
    nodeGeometryAttributes.radius.needsUpdate = true;
    nodeGeometryAttributes.typ.needsUpdate = true;
    nodeGeometryAttributes.nodeId.needsUpdate = true;
    nodeGeometryAttributes.treeId.needsUpdate = true;

    this.nodes.geometry.computeBoundingSphere();

    this.nodeMap.set(node.id, index);
    this.nodeCount += 1;
  }

  removeNode(nodeId: number) {
    const index = this.nodeMap.get(nodeId);
    const nodeGeometryAttributes = this.nodes.geometry.attributes;
    nodeGeometryAttributes.typ[index] = 1.0;
    nodeGeometryAttributes.typ.needsUpdate = true;
  }

  addEdge() {

  }

  removeEdge() {

  }

  addTree(tree: TreeType) {
    for (const node of Object.values(tree.nodes)) {
      this.addNode(node, tree.treeId);
    }
  }

  getMeshes() {
    return [this.nodes, ];//this.edges
  }

}

export default TGeometry;
