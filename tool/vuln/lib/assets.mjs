import fs from "node:fs";
import path from "node:path";
import {
  PUBSPEC,
  PUBSPEC_LOCK,
  BACKEND_PKG,
  BACKEND_LOCK,
  ANDROID_DIR,
  ROOT,
} from "./config.mjs";

function read(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

/** Names of dependencies declared directly in pubspec.yaml. */
export function directPubDeps() {
  const text = read(PUBSPEC) ?? "";
  const out = new Set();
  let inDeps = false;
  for (const raw of text.split(/\r?\n/)) {
    if (/^dependencies:\s*$/.test(raw)) {
      inDeps = true;
      continue;
    }
    if (/^\S/.test(raw) && !/^#/.test(raw)) {
      if (inDeps) inDeps = false;
    }
    if (!inDeps) continue;
    const m = raw.match(/^ {2}([a-z0-9_]+):/);
    if (m) out.add(m[1]);
  }
  return out;
}

/** Parse pubspec.lock (a constrained YAML subset) into package records. */
export function parsePubspecLock() {
  const text = read(PUBSPEC_LOCK);
  if (!text) return [];
  const direct = directPubDeps();
  const lines = text.split(/\r?\n/);
  const packages = [];
  let current = null;
  let inPackages = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^packages:\s*$/.test(line)) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (/^\S/.test(line)) break; // next top-level section

    const nameMatch = line.match(/^ {2}([A-Za-z0-9_]+):\s*$/);
    if (nameMatch) {
      if (current) packages.push(current);
      current = { name: nameMatch[1], version: null, dependency: "transitive" };
      continue;
    }
    if (!current) continue;

    const depMatch = line.match(/^\s+dependency:\s*"?([^"]+)"?\s*$/);
    if (depMatch) current.dependency = depMatch[1].trim();

    const versionMatch = line.match(/^\s+version:\s*"([^"]+)"\s*$/);
    if (versionMatch) current.version = versionMatch[1];

    const sourceMatch = line.match(/^\s+source:\s*(\S+)\s*$/);
    if (sourceMatch) current.source = sourceMatch[1];
  }
  if (current) packages.push(current);

  return packages
    .filter((p) => p.version && (p.source ?? "hosted") === "hosted")
    .map((p) => ({
      kind: "pub",
      ecosystem: "Pub",
      name: p.name,
      version: p.version,
      scope: /direct/.test(p.dependency) || direct.has(p.name) ? "direct" : "transitive",
      channel: /dev/.test(p.dependency) ? "dev" : "prod",
      sourceFile: "pubspec.lock",
    }));
}

/** Parse backend/package-lock.json (lockfileVersion 2/3). */
export function parseNpmLock() {
  const text = read(BACKEND_LOCK);
  if (!text) return [];
  let lock;
  try {
    lock = JSON.parse(text);
  } catch {
    return [];
  }
  const root = lock.packages?.[""] ?? {};
  const direct = new Set([
    ...Object.keys(root.dependencies ?? {}),
    ...Object.keys(root.devDependencies ?? {}),
  ]);
  const assets = [];
  const seen = new Set();

  for (const [key, meta] of Object.entries(lock.packages ?? {})) {
    if (!key.startsWith("node_modules/")) continue;
    if (meta.link) continue;
    const name = key.replace(/^.*node_modules\//, "");
    if (!meta.version) continue;
    const dev = meta.dev === true;
    const id = `${name}@${meta.version}`;
    if (seen.has(id)) continue;
    seen.add(id);
    assets.push({
      kind: "npm",
      ecosystem: "npm",
      name,
      version: meta.version,
      scope: direct.has(name) && !key.slice("node_modules/".length).includes("node_modules")
        ? "direct"
        : "transitive",
      channel: dev ? "dev" : "prod",
      sourceFile: "backend/package-lock.json",
    });
  }

  // lockfileVersion 1 fallback
  if (!assets.length && lock.dependencies) {
    const walk = (deps, scope) => {
      for (const [name, meta] of Object.entries(deps ?? {})) {
        if (meta.version) {
          assets.push({
            kind: "npm",
            ecosystem: "npm",
            name,
            version: meta.version,
            scope,
            sourceFile: "backend/package-lock.json",
          });
        }
        walk(meta.dependencies, "transitive");
      }
    };
    walk(lock.dependencies, "direct");
  }
  return assets;
}

/**
 * Android build toolchain pinned by the project itself (AGP, Kotlin, Gradle).
 * These are build-time components, but a compromised or vulnerable build plugin
 * still executes on developer machines and in CI.
 */
export function parseAndroidBuildTools() {
  const assets = [];
  const settings = read(path.join(ANDROID_DIR, "settings.gradle.kts")) ?? "";
  const wrapper = read(path.join(ANDROID_DIR, "gradle", "wrapper", "gradle-wrapper.properties")) ?? "";

  const pluginRe = /id\("([^"]+)"\)\s+version\s+"([^"]+)"/g;
  const mavenId = {
    "com.android.application": "com.android.tools.build:gradle",
    "org.jetbrains.kotlin.android": "org.jetbrains.kotlin:kotlin-gradle-plugin",
  };
  let m;
  while ((m = pluginRe.exec(settings))) {
    const [, plugin, version] = m;
    const artifact = mavenId[plugin] ?? plugin;
    assets.push({
      kind: "maven",
      ecosystem: "Maven",
      name: artifact,
      version,
      scope: "build",
      channel: "dev",
      sourceFile: "android/settings.gradle.kts",
    });
  }

  const gradle = wrapper.match(/gradle-([0-9][^-]*)-all\.zip/) ?? wrapper.match(/gradle-([0-9.]+)-/);
  if (gradle) {
    assets.push({
      kind: "maven",
      ecosystem: "Maven",
      name: "org.gradle:gradle",
      version: gradle[1],
      scope: "build",
      channel: "dev",
      sourceFile: "android/gradle/wrapper/gradle-wrapper.properties",
    });
  }
  return assets;
}

/** Flutter SDK / engine version pinned by the local toolchain, when discoverable. */
export function parseFlutterToolchain() {
  const assets = [];
  const props = read(path.join(ANDROID_DIR, "local.properties")) ?? "";
  const sdk = props.match(/^flutter\.sdk=(.+)$/m)?.[1]?.trim();
  if (!sdk) return assets;

  const versionFile = path.join(sdk, "version");
  const versionText = read(versionFile);
  if (versionText) {
    const v = versionText.match(/([0-9]+\.[0-9]+\.[0-9]+)/)?.[1];
    if (v) {
      assets.push({
        kind: "maven",
        ecosystem: "Maven",
        name: "io.flutter:flutter_embedding_release",
        version: v,
        scope: "build",
        channel: "prod",
        sourceFile: "flutter SDK version",
      });
    }
  }

  // Android min/target SDK actually applied to the app.
  const ext = read(
    path.join(sdk, "packages", "flutter_tools", "gradle", "src", "main", "kotlin", "FlutterExtension.kt")
  );
  if (ext) {
    const min = ext.match(/minSdkVersion:\s*Int\s*=\s*(\d+)/)?.[1];
    const target = ext.match(/targetSdkVersion:\s*Int\s*=\s*(\d+)/)?.[1];
    if (min) {
      assets.push({
        kind: "android-platform",
        ecosystem: "Android",
        name: "android-os",
        version: min,
        scope: "platform",
        channel: "prod",
        sourceFile: "FlutterExtension.minSdkVersion",
      });
    }
    if (target) {
      assets.push({
        kind: "android-platform",
        ecosystem: "Android",
        name: "android-os",
        version: target,
        scope: "platform",
        channel: "prod",
        sourceFile: "FlutterExtension.targetSdkVersion",
      });
    }
  }
  return assets;
}

export function collectAssets() {
  const all = [
    ...parsePubspecLock(),
    ...parseNpmLock(),
    ...parseAndroidBuildTools(),
    ...parseFlutterToolchain(),
  ];
  // Same component may exist in both prod and dev trees: count it once, as prod.
  const byKey = new Map();
  for (const asset of all) {
    const key = `${asset.kind}|${asset.name}|${asset.version}|${asset.scope}`;
    const previous = byKey.get(key);
    if (!previous) {
      byKey.set(key, asset);
      continue;
    }
    if (previous.channel !== "prod" && asset.channel === "prod") {
      byKey.set(key, asset);
    }
  }
  return [...byKey.values()];
}

export function appVersion() {
  const text = read(PUBSPEC) ?? "";
  return text.match(/^version:\s*(\S+)/m)?.[1] ?? "unknown";
}

export function rel(p) {
  return path.relative(ROOT, p).replace(/\\/g, "/");
}
