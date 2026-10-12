// The home page's 3D band: an ASUS ROG Hyperion GR701 (eTech item 1527),
// built from primitives in three.js, turning slowly behind the shop's name.
//
// Proportions are the maker's: 260 W x 640 D x 663 H mm, one unit per
// 100 mm. Front (the X frame) faces +Z, the glass side faces -X, Y is up.
// It is a stylised reconstruction from one product photo
// (design/3d/hyperion/reference.png): the hidden right side and rear are
// plain panels, and the ROG lettering is left out.
//
// The case's ARGB strips are set to eTech red. With no WebGL the photo
// already in #hero-stage stays; with reduced motion one still frame is
// drawn and nothing turns.
import * as THREE from "./vendor/three.module.min.js";

const W = 2.6, D = 6.4, H = 6.63;
const HX = W / 2, HZ = D / 2;
const RED = 0xff3a12; // the logo red, lifted for a light

function mat(color, metalness, roughness, extra) {
  return new THREE.MeshStandardMaterial({ color, metalness, roughness, ...extra });
}

const MATS = {
  frame: mat(0x9a9fa6, 0.75, 0.3),           // brushed aluminium X and handles
  body: mat(0x34363b, 0.5, 0.5),            // painted steel shell
  panel: mat(0x45484e, 0.6, 0.4),            // front triangles
  glass: new THREE.MeshPhysicalMaterial({
    color: 0x0c0d10, metalness: 0, roughness: 0.06, transparent: true,
    opacity: 0.38, clearcoat: 1, clearcoatRoughness: 0.05,
  }),
  light: new THREE.MeshStandardMaterial({ color: RED, emissive: RED, emissiveIntensity: 2.2 }),
  fanBlade: mat(0x101114, 0.2, 0.7),
};

// A vent plate: rows of slots drawn on a canvas, used as a bump and an
// alpha-free colour map so the triangles read as perforated metal.
function slotTexture() {
  const c = document.createElement("canvas");
  c.width = c.height = 256;
  const g = c.getContext("2d");
  g.fillStyle = "#2c2e33";
  g.fillRect(0, 0, 256, 256);
  g.fillStyle = "#0c0d0f";
  for (let y = 10; y < 256; y += 22) {
    for (let x = (y / 22) % 2 ? 6 : 18; x < 256; x += 24) {
      g.save();
      g.translate(x, y);
      g.rotate(-0.5);
      g.fillRect(-8, -3, 16, 6);
      g.restore();
    }
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(1.5, 1.5);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// A bar from point a to point b (in the front plane or anywhere), with a
// square section: the X arms and the foot rails are all this.
function bar(a, b, thick, deep, material) {
  const len = a.distanceTo(b);
  const m = new THREE.Mesh(new THREE.BoxGeometry(thick, len, deep), material);
  m.position.copy(a).add(b).multiplyScalar(0.5);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize());
  return m;
}

function triangle(points, depth, material) {
  const s = new THREE.Shape(points.map(([x, y]) => new THREE.Vector2(x, y)));
  const geo = new THREE.ExtrudeGeometry(s, { depth, bevelEnabled: false });
  // Map UVs from x/y so the slot texture sits flat on the face.
  const pos = geo.attributes.position, uv = geo.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / 2, pos.getY(i) / 2);
  return new THREE.Mesh(geo, material);
}

function fan(radius) {
  const g = new THREE.Group();
  g.name = "fan";
  const ring = new THREE.Mesh(new THREE.TorusGeometry(radius, 0.05, 10, 48), MATS.light);
  const hub = new THREE.Mesh(new THREE.CylinderGeometry(radius * 0.28, radius * 0.28, 0.12, 24), MATS.body);
  hub.rotation.x = Math.PI / 2;
  g.add(ring, hub);
  for (let i = 0; i < 9; i++) {
    const blade = new THREE.Mesh(new THREE.BoxGeometry(radius * 0.62, radius * 0.22, 0.03), MATS.fanBlade);
    const a = (i / 9) * Math.PI * 2;
    blade.position.set(Math.cos(a) * radius * 0.58, Math.sin(a) * radius * 0.58, 0);
    blade.rotation.set(0.4, 0, a);
    g.add(blade);
  }
  return g;
}

function buildHyperion() {
  const root = new THREE.Group();
  root.name = "rog-hyperion-gr701";

  // Body: the steel shell, a little inside the frame.
  // It stops short of the glass side, so the fans have a bay to sit in.
  const BAY = 0.75;
  const body = new THREE.Mesh(new THREE.BoxGeometry(W - 0.06 - BAY, H - 0.5, D - 0.3), MATS.body);
  body.name = "body";
  body.position.set(BAY / 2, H / 2, 0);
  // The bay's floor and roof, so the glass looks into a box, not a void.
  [0.25, H - 0.25].forEach((y) => {
    const plate = new THREE.Mesh(new THREE.BoxGeometry(BAY, 0.05, D - 0.3), MATS.body);
    plate.position.set(-HX + BAY / 2 + 0.03, y, 0);
    root.add(plate);
  });
  root.add(body);

  // Glass side panel (-X), with the fans and the GPU glow behind it.
  const side = new THREE.Group();
  side.name = "glass-side";
  const glass = new THREE.Mesh(new THREE.BoxGeometry(0.04, H - 0.9, D - 1.1), MATS.glass);
  glass.position.set(-HX + 0.02, H / 2 + 0.05, -0.15);
  side.add(glass);
  const fans = new THREE.Group();
  fans.name = "fans";
  [[1.6, -1.6], [3.0, -1.6], [4.4, -1.6]].forEach(([y, z]) => {
    const f = fan(0.62);
    f.position.set(-HX + 0.35, y, z - 0.6);
    f.rotation.y = -Math.PI / 2;
    fans.add(f);
  });
  const gpu = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.18, 3.1), MATS.light);
  gpu.name = "gpu-strip";
  gpu.position.set(-HX + 0.5, 2.5, 0.9);
  side.add(fans, gpu);
  root.add(side);

  // Front X frame: two arms corner to corner, standing proud of the face.
  const zf = HZ + 0.12;
  const frame = new THREE.Group();
  frame.name = "x-frame";
  const t = 0.42, d = 0.5;
  frame.add(
    bar(new THREE.Vector3(-HX - 0.1, H + 0.15, zf), new THREE.Vector3(HX + 0.1, -0.05, zf), t, d, MATS.frame),
    bar(new THREE.Vector3(HX + 0.1, H + 0.15, zf), new THREE.Vector3(-HX - 0.1, -0.05, zf), t, d, MATS.frame),
  );
  root.add(frame);

  // Front triangles: the vents top and bottom between the arms, each
  // edged by a light strip; plain dark panels left and right.
  const vents = new THREE.MeshStandardMaterial({ map: slotTexture(), metalness: 0.6, roughness: 0.5 });
  const cy = H / 2;
  const top = triangle([[-HX + 0.3, H - 0.25], [HX - 0.3, H - 0.25], [0, cy + 0.9]], 0.06, vents);
  const bottom = triangle([[-HX + 0.3, 0.25], [HX - 0.3, 0.25], [0, cy - 0.9]], 0.06, vents);
  const left = triangle([[-HX, 0.4], [-HX, H - 0.4], [-0.35, cy]], 0.04, MATS.panel);
  const right = triangle([[HX, 0.4], [HX, H - 0.4], [0.35, cy]], 0.04, MATS.panel);
  [top, bottom, left, right].forEach((m) => { m.position.z = HZ - 0.02; });
  top.name = "vent-top"; bottom.name = "vent-bottom";
  root.add(top, bottom, left, right);

  const strips = new THREE.Group();
  strips.name = "light-strips";
  strips.add(
    bar(new THREE.Vector3(-HX + 0.45, H - 0.42, HZ + 0.06), new THREE.Vector3(-0.15, cy + 1.25, HZ + 0.06), 0.05, 0.03, MATS.light),
    bar(new THREE.Vector3(HX - 0.45, 0.42, HZ + 0.06), new THREE.Vector3(0.15, cy - 1.25, HZ + 0.06), 0.05, 0.03, MATS.light),
    bar(new THREE.Vector3(-HX + 0.5, 0.36, HZ + 0.06), new THREE.Vector3(HX - 0.5, 0.36, HZ + 0.06), 0.04, 0.03, MATS.light),
  );
  // The ROG eye: a small lit slash in the top vent.
  const eye = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.12, 0.03), MATS.light);
  eye.name = "rog-eye";
  eye.position.set(0, H - 0.75, HZ + 0.06);
  eye.rotation.z = -0.25;
  strips.add(eye);
  root.add(strips);

  // Carry handles: a loop along each top edge, front to back.
  const handles = new THREE.Group();
  handles.name = "handles";
  [-HX - 0.05, HX + 0.05].forEach((x) => {
    const curve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(x, H + 0.1, zf - 0.1),
      new THREE.Vector3(x, H + 0.7, HZ - 1.4),
      new THREE.Vector3(x, H + 0.75, -HZ + 1.6),
      new THREE.Vector3(x, H + 0.15, -HZ + 0.15),
    ]);
    handles.add(new THREE.Mesh(new THREE.TubeGeometry(curve, 48, 0.17, 8, false), MATS.frame));
  });
  root.add(handles);

  // Foot rails along the bottom edges.
  const feet = new THREE.Group();
  feet.name = "feet";
  [-HX - 0.05, HX + 0.05].forEach((x) => {
    feet.add(bar(new THREE.Vector3(x, 0.05, zf), new THREE.Vector3(x, 0.05, -HZ), 0.2, 0.18, MATS.frame));
  });
  root.add(feet);

  // Centre the model on its own middle so it turns in place.
  root.position.set(0, -H / 2 - 0.2, 0);
  const pivot = new THREE.Group();
  pivot.name = "pivot";
  pivot.add(root);
  return pivot;
}

// A soft studio for the metal to reflect: a dark room with two light
// panels and a red one, prefiltered once.
function studioEnvironment(renderer) {
  const env = new THREE.Scene();
  env.background = new THREE.Color(0x0b0c0e);
  const panel = (color, intensity, w, h, pos) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h),
      new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(intensity), side: THREE.DoubleSide }));
    m.position.copy(pos);
    m.lookAt(0, 0, 0);
    env.add(m);
  };
  panel(0xffffff, 2.5, 8, 4, new THREE.Vector3(6, 6, 6));
  panel(0xffffff, 1.2, 6, 6, new THREE.Vector3(-8, 2, -2));
  panel(RED, 2.0, 4, 8, new THREE.Vector3(-2, 0, -8));
  const pmrem = new THREE.PMREMGenerator(renderer);
  const tex = pmrem.fromScene(env, 0.04).texture;
  pmrem.dispose();
  return tex;
}

function start() {
  const stage = document.getElementById("hero-stage");
  const hero = stage && stage.closest(".hero");
  if (!stage || !hero) return;

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" });
  } catch (e) {
    return; // no WebGL: the photo stays
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  stage.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.environment = studioEnvironment(renderer);

  const key = new THREE.DirectionalLight(0xffffff, 3.2);
  key.position.set(6, 8, 8);
  const rim = new THREE.DirectionalLight(RED, 2.4);
  rim.position.set(-6, 3, -8);
  const fill = new THREE.DirectionalLight(0xdfe6ff, 1.4);
  fill.position.set(-8, 4, 6);
  scene.add(key, fill, rim, new THREE.AmbientLight(0xffffff, 0.45));

  const model = buildHyperion();
  scene.add(model);

  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);

  // Wide band: the case sits in the right third. Narrow: top centre.
  function layout() {
    const w = stage.clientWidth, h = stage.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    const narrow = w < 760;
    camera.position.set(0, 3.2, narrow ? 26 : 19);
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
    // Shift the view so the model lands right of the copy (or above it).
    camera.setViewOffset(w, h, narrow ? 0 : -w * 0.24, narrow ? h * 0.27 : 0, w, h);
    model.scale.setScalar(narrow ? 0.68 : 1);
  }

  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const BASE = 0.4; // the photo's three-quarter view: glass left, X right
  let visible = true, raf = 0, t0 = performance.now();

  function frame(now) {
    const t = (now - t0) / 1000;
    model.rotation.y = BASE + Math.sin(t * 0.25) * 0.25;
    model.position.y = Math.sin(t * 0.6) * 0.08;
    renderer.render(scene, camera);
    raf = visible && !document.hidden ? requestAnimationFrame(frame) : 0;
  }

  function resume() {
    if (!raf && visible && !document.hidden && !reduce) raf = requestAnimationFrame(frame);
  }

  layout();
  model.rotation.y = BASE;
  renderer.render(scene, camera);
  hero.classList.add("is-3d");

  // ?hero-still: a transparent cutout of the case, for the Android
  // app's home band (mobile/assets/images/hero-hyperion.png).
  if (new URLSearchParams(location.search).has("hero-still")) {
    window.heroStill = (w, h) => {
      const cam = new THREE.PerspectiveCamera(30, w / h, 0.1, 100);
      cam.position.set(0, 3.2, 21);
      cam.lookAt(0, 0.3, 0);
      model.rotation.y = BASE;
      model.position.y = 0;
      renderer.setPixelRatio(1);
      renderer.setSize(w, h, false);
      renderer.render(scene, cam);
      return renderer.domElement.toDataURL("image/png");
    };
    return;
  }

  window.addEventListener("resize", () => { layout(); if (reduce) renderer.render(scene, camera); });
  document.addEventListener("visibilitychange", resume);
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; resume(); }).observe(hero);
  resume();
}

start();
