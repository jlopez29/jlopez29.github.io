import { readFileSync } from 'node:fs';
import ts from 'typescript';

// Isolate the real application class from Firebase/network and Angular rendering.
// The production Angular build separately checks types and templates.
export function loadSource(path, dependencies) {
  const source = readFileSync(new URL(`../src/${path}`, import.meta.url), 'utf8');
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, experimentalDecorators: true },
  });
  const module = { exports: {} };
  const require = name => {
    if (!(name in dependencies)) throw new Error(`Unmocked dependency: ${name}`);
    return dependencies[name];
  };
  new Function('require', 'module', 'exports', outputText)(require, module, module.exports);
  return module.exports;
}

export const decorator = () => target => target;
export function signal(initial) {
  let value = initial;
  const read = () => value;
  read.set = next => { value = next; };
  read.update = update => { value = update(value); };
  return read;
}
