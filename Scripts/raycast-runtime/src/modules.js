// The `require` an extension bundle sees. Provided modules (React, `react/jsx-runtime`,
// `@raycast/api`, the Node builtins) always win; anything else resolves Node-style from the
// prebuilt `node_modules/` that `ray build` ships beside the bundles, never above the extension root.

import { nodeModules } from "./node-shims.js";

const { fs, path } = nodeModules;
const registry = new Map();
// Keyed by absolute filename, which is already unique per extension sharing one context.
const moduleCache = Object.create(null);
const packageJsonCache = new Map();
const CONDITIONS = new Set(["require", "node", "default"]);
const EXTENSIONS = [".js", ".json", ".cjs"];

export function defineModule(name, exports) {
  registry.set(name, exports);
}

for (const name of Object.keys(nodeModules)) defineModule(name, nodeModules[name]);

function providedModule(key) {
  if (registry.has(key)) return registry.get(key);
  // Deep imports into a provided package (`react-dom/client`) resolve to the package itself rather
  // than exploding, which is enough for the handful of bundles that reference them defensively.
  const root = packageName(key);
  return registry.has(root) ? registry.get(root) : undefined;
}

function packageName(request) {
  const parts = request.split("/");
  return request.startsWith("@") ? parts.slice(0, 2).join("/") : parts[0];
}

function notFound(request) {
  const error = new Error(
    `Cannot find module '${request}'. Minicast provides React, @raycast/api and a subset of Node builtins, and loads the node_modules that \`ray build\` ships — see docs/features/extensions.md.`,
  );
  error.code = "MODULE_NOT_FOUND";
  return error;
}

// One host call per probe: a missing path comes back undefined instead of throwing.
function statKind(file) {
  try {
    const stats = fs.statSync(file, { throwIfNoEntry: false });
    if (!stats) return null;
    return stats.isDirectory() ? "dir" : "file";
  } catch {
    return null;
  }
}

function readPackageJson(dir) {
  if (packageJsonCache.has(dir)) return packageJsonCache.get(dir);
  let parsed = null;
  try {
    parsed = JSON.parse(fs.readFileSync(path.join(dir, "package.json"), "utf8"));
  } catch {}
  packageJsonCache.set(dir, parsed);
  return parsed;
}

function resolveFile(file) {
  const kind = statKind(file);
  if (kind === "file") return file;
  for (const extension of EXTENSIONS) {
    if (statKind(file + extension) === "file") return file + extension;
  }
  if (kind === "dir") return resolveDirectory(file);
  return null;
}

function resolveDirectory(dir) {
  const main = readPackageJson(dir)?.main;
  if (typeof main === "string") {
    const resolved = resolveFile(path.resolve(dir, main));
    if (resolved) return resolved;
  }
  for (const extension of EXTENSIONS) {
    const index = path.join(dir, "index" + extension);
    if (statKind(index) === "file") return index;
  }
  return null;
}

// Condition objects pick the first key, in authored order, that this runtime satisfies.
function exportTarget(target, star) {
  if (typeof target === "string") return star === undefined ? target : target.replaceAll("*", star);
  if (Array.isArray(target)) {
    for (const entry of target) {
      const resolved = exportTarget(entry, star);
      if (resolved) return resolved;
    }
    return null;
  }
  if (target && typeof target === "object") {
    for (const key of Object.keys(target)) {
      if (!CONDITIONS.has(key)) continue;
      const resolved = exportTarget(target[key], star);
      if (resolved) return resolved;
    }
  }
  return null;
}

function resolveExports(exports, subpath) {
  const isSubpathMap =
    exports && typeof exports === "object" && !Array.isArray(exports) &&
    Object.keys(exports).some((key) => key.startsWith("."));
  const map = isSubpathMap ? exports : { ".": exports };
  if (subpath in map) return exportTarget(map[subpath]);
  let best = null;
  for (const key of Object.keys(map)) {
    const star = key.indexOf("*");
    if (star < 0) continue;
    const prefix = key.slice(0, star);
    const suffix = key.slice(star + 1);
    if (!subpath.startsWith(prefix) || !subpath.endsWith(suffix)) continue;
    if (subpath.length < prefix.length + suffix.length) continue;
    if (best && prefix.length <= best.prefix.length) continue;
    best = { key, prefix, match: subpath.slice(prefix.length, subpath.length - suffix.length) };
  }
  return best ? exportTarget(map[best.key], best.match) : null;
}

function resolvePackage(packageDir, subpath) {
  const manifest = readPackageJson(packageDir);
  if (manifest?.exports !== undefined && manifest.exports !== null) {
    const target = resolveExports(manifest.exports, subpath);
    return target ? resolveFile(path.resolve(packageDir, target)) : null;
  }
  return subpath === "." ? resolveDirectory(packageDir) : resolveFile(path.join(packageDir, subpath));
}

function resolveBare(request, fromDir, rootDir) {
  const name = packageName(request);
  const subpath = request === name ? "." : "." + request.slice(name.length);
  let dir = fromDir;
  while (true) {
    if (path.basename(dir) !== "node_modules") {
      const packageDir = path.join(dir, "node_modules", name);
      if (statKind(packageDir) === "dir") {
        const resolved = resolvePackage(packageDir, subpath);
        if (resolved) return resolved;
      }
    }
    if (dir === rootDir || !dir.startsWith(rootDir)) return null;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function resolveRequest(request, fromDir, rootDir) {
  if (request.startsWith("./") || request.startsWith("../") || request === "." || request === "..") {
    return resolveFile(path.resolve(fromDir, request));
  }
  if (request.startsWith("/")) return resolveFile(request);
  return resolveBare(request, fromDir, rootDir);
}

function compile(code, filename) {
  const source = code.replace(/^﻿/, "").replace(/^#!.*/, "");
  try {
    return globalThis.__tinycastCompile(source, filename);
  } catch (error) {
    if (/^\s*(import\s|export\s)/m.test(source)) {
      throw new Error(`'${filename}' is an ES module; Minicast loads only CommonJS dependencies.`);
    }
    throw error;
  }
}

function loadFile(filename, rootDir) {
  if (filename in moduleCache) return moduleCache[filename].exports;
  if (filename.endsWith(".mjs")) {
    throw new Error(`'${filename}' is an ES module; Minicast loads only CommonJS dependencies.`);
  }
  const code = fs.readFileSync(filename, "utf8");
  const module = { exports: {}, id: filename, filename, loaded: false, children: [], paths: [] };
  if (filename.endsWith(".json")) {
    module.exports = JSON.parse(code.replace(/^﻿/, ""));
    module.loaded = true;
    moduleCache[filename] = module;
    return module.exports;
  }
  // Cached before running so a circular require sees the partial exports, as in Node.
  moduleCache[filename] = module;
  try {
    runModule(module, compile(code, filename), rootDir);
  } catch (error) {
    delete moduleCache[filename];
    throw error;
  }
  return module.exports;
}

function runModule(module, factory, rootDir) {
  const dirname = path.dirname(module.filename);
  factory(module.exports, makeRequire(dirname, rootDir), module, module.filename, dirname);
  module.loaded = true;
}

function makeRequire(fromDir, rootDir) {
  const resolve = (request) => {
    const key = String(request);
    const resolved = resolveRequest(key, fromDir, rootDir);
    if (!resolved) throw notFound(key);
    return resolved;
  };
  const require = (request) => {
    const key = String(request);
    const provided = providedModule(key);
    if (provided !== undefined) return provided;
    return loadFile(resolve(key), rootDir);
  };
  require.resolve = (request) => (providedModule(String(request)) !== undefined ? String(request) : resolve(request));
  require.cache = moduleCache;
  return require;
}

/// Evaluate one CJS bundle. `filename`/`dirname` matter: extensions resolve bundled assets relative
/// to `__dirname`, and `environment.assetsPath` points at the same directory.
export function evaluateCommonJS(code, filename, dirname) {
  const module = { exports: {}, id: filename, filename, loaded: false, children: [], paths: [] };
  const factory = globalThis.__tinycastCompile(code, filename);
  factory(module.exports, makeRequire(dirname, dirname), module, filename, dirname);
  module.loaded = true;
  return module.exports;
}
