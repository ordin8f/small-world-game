const EPSILON = 1e-6;

export const vec3 = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
  scale: (a, s) => [a[0] * s, a[1] * s, a[2] * s],
  length: (a) => Math.hypot(a[0], a[1], a[2]),
  normalize(a) {
    const len = Math.max(EPSILON, Math.hypot(a[0], a[1], a[2]));
    return [a[0] / len, a[1] / len, a[2] / len];
  },
  cross: (a, b) => [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0]
  ],
  lerp: (a, b, t) => [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t
  ]
};

export const mat4 = {
  identity() {
    return new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  },
  multiply(a, b) {
    const out = new Float32Array(16);
    for (let c = 0; c < 4; c += 1) {
      for (let r = 0; r < 4; r += 1) {
        out[c * 4 + r] =
          a[0 * 4 + r] * b[c * 4 + 0] +
          a[1 * 4 + r] * b[c * 4 + 1] +
          a[2 * 4 + r] * b[c * 4 + 2] +
          a[3 * 4 + r] * b[c * 4 + 3];
      }
    }
    return out;
  },
  translation(x, y, z) {
    const out = mat4.identity();
    out[12] = x; out[13] = y; out[14] = z;
    return out;
  },
  scale(x, y, z) {
    const out = mat4.identity();
    out[0] = x; out[5] = y; out[10] = z;
    return out;
  },
  rotationX(rad) {
    const c = Math.cos(rad), s = Math.sin(rad);
    return new Float32Array([1,0,0,0, 0,c,s,0, 0,-s,c,0, 0,0,0,1]);
  },
  rotationY(rad) {
    const c = Math.cos(rad), s = Math.sin(rad);
    return new Float32Array([c,0,-s,0, 0,1,0,0, s,0,c,0, 0,0,0,1]);
  },
  rotationZ(rad) {
    const c = Math.cos(rad), s = Math.sin(rad);
    return new Float32Array([c,s,0,0, -s,c,0,0, 0,0,1,0, 0,0,0,1]);
  },
  perspective(fovRadians, aspect, near, far) {
    const f = 1 / Math.tan(fovRadians / 2);
    const nf = 1 / (near - far);
    return new Float32Array([
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (far + near) * nf, -1,
      0, 0, 2 * far * near * nf, 0
    ]);
  },
  lookAt(eye, target, up = [0, 1, 0]) {
    const z = vec3.normalize(vec3.sub(eye, target));
    const x = vec3.normalize(vec3.cross(up, z));
    const y = vec3.cross(z, x);
    return new Float32Array([
      x[0], y[0], z[0], 0,
      x[1], y[1], z[1], 0,
      x[2], y[2], z[2], 0,
      -x[0] * eye[0] - x[1] * eye[1] - x[2] * eye[2],
      -y[0] * eye[0] - y[1] * eye[1] - y[2] * eye[2],
      -z[0] * eye[0] - z[1] * eye[1] - z[2] * eye[2],
      1
    ]);
  },
  compose(position, rotation = [0, 0, 0], scale = [1, 1, 1]) {
    const t = mat4.translation(position[0], position[1], position[2]);
    const ry = mat4.rotationY(rotation[1] ?? 0);
    const rx = mat4.rotationX(rotation[0] ?? 0);
    const rz = mat4.rotationZ(rotation[2] ?? 0);
    const s = mat4.scale(scale[0], scale[1], scale[2]);
    return mat4.multiply(t, mat4.multiply(ry, mat4.multiply(rx, mat4.multiply(rz, s))));
  }
};

function normalMatrix(model) {
  const a00 = model[0], a01 = model[4], a02 = model[8];
  const a10 = model[1], a11 = model[5], a12 = model[9];
  const a20 = model[2], a21 = model[6], a22 = model[10];
  const b01 = a22 * a11 - a12 * a21;
  const b11 = -a22 * a10 + a12 * a20;
  const b21 = a21 * a10 - a11 * a20;
  let det = a00 * b01 + a01 * b11 + a02 * b21;
  det = Math.abs(det) < EPSILON ? 1 : 1 / det;
  return new Float32Array([
    b01 * det,
    (-a22 * a01 + a02 * a21) * det,
    (a12 * a01 - a02 * a11) * det,
    b11 * det,
    (a22 * a00 - a02 * a20) * det,
    (-a12 * a00 + a02 * a10) * det,
    b21 * det,
    (-a21 * a00 + a01 * a20) * det,
    (a11 * a00 - a01 * a10) * det
  ]);
}

function compileShader(gl, type, source) {
  const result = gl.createShader(type);
  gl.shaderSource(result, source);
  gl.compileShader(result);
  if (!gl.getShaderParameter(result, gl.COMPILE_STATUS)) {
    throw new Error(`Shader error: ${gl.getShaderInfoLog(result)}`);
  }
  return result;
}

function createProgram(gl, vertexSource, fragmentSource) {
  const result = gl.createProgram();
  gl.attachShader(result, compileShader(gl, gl.VERTEX_SHADER, vertexSource));
  gl.attachShader(result, compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource));
  gl.linkProgram(result);
  if (!gl.getProgramParameter(result, gl.LINK_STATUS)) {
    throw new Error(`Program error: ${gl.getProgramInfoLog(result)}`);
  }
  return result;
}

function createMesh(gl, positions, normals, indices) {
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);

  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 0, 0);

  const normalBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, normalBuffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(normals), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(1);
  gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 0, 0);

  const indexBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW);
  gl.bindVertexArray(null);
  return { vao, count: indices.length };
}

function cubeData() {
  const positions = [
    -0.5,-0.5,0.5, 0.5,-0.5,0.5, 0.5,0.5,0.5, -0.5,0.5,0.5,
    0.5,-0.5,-0.5, -0.5,-0.5,-0.5, -0.5,0.5,-0.5, 0.5,0.5,-0.5,
    -0.5,0.5,0.5, 0.5,0.5,0.5, 0.5,0.5,-0.5, -0.5,0.5,-0.5,
    -0.5,-0.5,-0.5, 0.5,-0.5,-0.5, 0.5,-0.5,0.5, -0.5,-0.5,0.5,
    0.5,-0.5,0.5, 0.5,-0.5,-0.5, 0.5,0.5,-0.5, 0.5,0.5,0.5,
    -0.5,-0.5,-0.5, -0.5,-0.5,0.5, -0.5,0.5,0.5, -0.5,0.5,-0.5
  ];
  const normals = [];
  [[0,0,1],[0,0,-1],[0,1,0],[0,-1,0],[1,0,0],[-1,0,0]].forEach((normal) => {
    for (let i = 0; i < 4; i += 1) normals.push(...normal);
  });
  const indices = [];
  for (let face = 0; face < 6; face += 1) {
    const offset = face * 4;
    indices.push(offset, offset + 1, offset + 2, offset, offset + 2, offset + 3);
  }
  return [positions, normals, indices];
}

function sphereData(latitude = 10, longitude = 16) {
  const positions = [], normals = [], indices = [];
  for (let y = 0; y <= latitude; y += 1) {
    const phi = (y / latitude) * Math.PI;
    for (let x = 0; x <= longitude; x += 1) {
      const theta = (x / longitude) * Math.PI * 2;
      const sx = Math.sin(phi) * Math.cos(theta);
      const sy = Math.cos(phi);
      const sz = Math.sin(phi) * Math.sin(theta);
      positions.push(sx * 0.5, sy * 0.5, sz * 0.5);
      normals.push(sx, sy, sz);
    }
  }
  for (let y = 0; y < latitude; y += 1) {
    for (let x = 0; x < longitude; x += 1) {
      const a = y * (longitude + 1) + x;
      const b = a + longitude + 1;
      indices.push(a, b, a + 1, b, b + 1, a + 1);
    }
  }
  return [positions, normals, indices];
}

function cylinderData(segments = 16, topRadius = 0.5, bottomRadius = 0.5) {
  const positions = [], normals = [], indices = [];
  for (let i = 0; i <= segments; i += 1) {
    const angle = (i / segments) * Math.PI * 2;
    const c = Math.cos(angle), s = Math.sin(angle);
    positions.push(c * bottomRadius, -0.5, s * bottomRadius, c * topRadius, 0.5, s * topRadius);
    const sideNormal = vec3.normalize([c, bottomRadius - topRadius, s]);
    normals.push(...sideNormal, ...sideNormal);
  }
  for (let i = 0; i < segments; i += 1) {
    const offset = i * 2;
    indices.push(offset, offset + 1, offset + 2, offset + 1, offset + 3, offset + 2);
  }
  const bottomCenter = positions.length / 3;
  positions.push(0, -0.5, 0); normals.push(0, -1, 0);
  const topCenter = positions.length / 3;
  positions.push(0, 0.5, 0); normals.push(0, 1, 0);
  for (let i = 0; i < segments; i += 1) {
    const a = i * 2, b = ((i + 1) % segments) * 2;
    indices.push(bottomCenter, b, a);
    const at = i * 2 + 1, bt = ((i + 1) % segments) * 2 + 1;
    indices.push(topCenter, at, bt);
  }
  return [positions, normals, indices];
}

const VERTEX_SHADER = `#version 300 es
layout(location=0) in vec3 aPosition;
layout(location=1) in vec3 aNormal;
uniform mat4 uModel;
uniform mat4 uViewProjection;
uniform mat3 uNormalMatrix;
out vec3 vNormal;
out vec3 vWorld;
void main(){
  vec4 world = uModel * vec4(aPosition, 1.0);
  vWorld = world.xyz;
  vNormal = normalize(uNormalMatrix * aNormal);
  gl_Position = uViewProjection * world;
}`;

const FRAGMENT_SHADER = `#version 300 es
precision highp float;
in vec3 vNormal;
in vec3 vWorld;
uniform vec3 uColor;
uniform vec3 uLightDirection;
uniform vec3 uLightColor;
uniform vec3 uAmbient;
uniform vec3 uFogColor;
uniform vec3 uCamera;
uniform float uFogNear;
uniform float uFogFar;
uniform float uAlpha;
uniform float uEmissive;
out vec4 outColor;
void main(){
  vec3 normal = normalize(vNormal);
  float diffuse = max(dot(normal, -normalize(uLightDirection)), 0.0);
  float wrapped = max((diffuse + 0.32) / 1.32, 0.0);
  vec3 color = uColor * (uAmbient + uLightColor * wrapped * 0.84) + uColor * uEmissive;
  float distanceToCamera = distance(vWorld, uCamera);
  float fog = smoothstep(uFogNear, uFogFar, distanceToCamera);
  color = mix(color, uFogColor, fog);
  outColor = vec4(color, uAlpha);
}`;

export class WebGLRenderer {
  constructor(canvas) {
    const gl = canvas.getContext('webgl2', {
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance'
    });
    if (!gl) throw new Error('WebGL2 unavailable');
    this.canvas = canvas;
    this.gl = gl;
    this.program = createProgram(gl, VERTEX_SHADER, FRAGMENT_SHADER);
    this.locations = {
      model: gl.getUniformLocation(this.program, 'uModel'),
      viewProjection: gl.getUniformLocation(this.program, 'uViewProjection'),
      normal: gl.getUniformLocation(this.program, 'uNormalMatrix'),
      color: gl.getUniformLocation(this.program, 'uColor'),
      lightDirection: gl.getUniformLocation(this.program, 'uLightDirection'),
      lightColor: gl.getUniformLocation(this.program, 'uLightColor'),
      ambient: gl.getUniformLocation(this.program, 'uAmbient'),
      fogColor: gl.getUniformLocation(this.program, 'uFogColor'),
      camera: gl.getUniformLocation(this.program, 'uCamera'),
      fogNear: gl.getUniformLocation(this.program, 'uFogNear'),
      fogFar: gl.getUniformLocation(this.program, 'uFogFar'),
      alpha: gl.getUniformLocation(this.program, 'uAlpha'),
      emissive: gl.getUniformLocation(this.program, 'uEmissive')
    };
    this.meshes = {};
    for (const [name, data] of Object.entries({
      cube: cubeData(),
      sphere: sphereData(),
      cylinder: cylinderData(),
      cone: cylinderData(16, 0.08, 0.5)
    })) {
      this.meshes[name] = createMesh(gl, ...data);
    }
    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    this.pixelRatio = Math.min(window.devicePixelRatio || 1, 1.6);
    this.resize();
  }

  setQuality(lowQuality) {
    this.pixelRatio = lowQuality ? 0.9 : Math.min(window.devicePixelRatio || 1, 1.6);
    this.resize();
  }

  resize() {
    const width = Math.max(1, Math.floor(this.canvas.clientWidth * this.pixelRatio));
    const height = Math.max(1, Math.floor(this.canvas.clientHeight * this.pixelRatio));
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
    }
    this.gl.viewport(0, 0, width, height);
  }

  begin(camera, environment) {
    this.resize();
    const gl = this.gl;
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.useProgram(this.program);
    const projection = mat4.perspective(
      (camera.fov * Math.PI) / 180,
      this.canvas.width / this.canvas.height,
      0.08,
      120
    );
    const view = mat4.lookAt(camera.position, camera.target);
    const viewProjection = mat4.multiply(projection, view);
    gl.uniformMatrix4fv(this.locations.viewProjection, false, viewProjection);
    gl.uniform3fv(this.locations.lightDirection, environment.lightDirection);
    gl.uniform3fv(this.locations.lightColor, environment.lightColor);
    gl.uniform3fv(this.locations.ambient, environment.ambient);
    gl.uniform3fv(this.locations.fogColor, environment.fogColor);
    gl.uniform3fv(this.locations.camera, camera.position);
    gl.uniform1f(this.locations.fogNear, environment.fogNear);
    gl.uniform1f(this.locations.fogFar, environment.fogFar);
  }

  draw({
    mesh = 'cube', position = [0,0,0], rotation = [0,0,0], scale = [1,1,1],
    color = [1,1,1], alpha = 1, emissive = 0, doubleSided = false
  }) {
    const gl = this.gl;
    const resource = this.meshes[mesh];
    if (!resource) throw new Error(`Unknown mesh: ${mesh}`);
    if (doubleSided) gl.disable(gl.CULL_FACE); else gl.enable(gl.CULL_FACE);
    gl.depthMask(alpha >= 0.999);
    const model = mat4.compose(position, rotation, scale);
    gl.uniformMatrix4fv(this.locations.model, false, model);
    gl.uniformMatrix3fv(this.locations.normal, false, normalMatrix(model));
    gl.uniform3fv(this.locations.color, color);
    gl.uniform1f(this.locations.alpha, alpha);
    gl.uniform1f(this.locations.emissive, emissive);
    gl.bindVertexArray(resource.vao);
    gl.drawElements(gl.TRIANGLES, resource.count, gl.UNSIGNED_SHORT, 0);
    gl.bindVertexArray(null);
    gl.depthMask(true);
  }
}
