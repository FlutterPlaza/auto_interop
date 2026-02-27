#!/usr/bin/env node
// AST-based TypeScript declaration parser for auto_interop.
//
// Uses the TypeScript Compiler API to parse .d.ts and .ts files and output
// a UTS JSON schema to stdout.
//
// Usage: node ts_ast_helper.mjs --package <name> --version <ver> <files...>
//
// Requires: typescript npm package (>= 5.0)

import { readFileSync } from 'fs';

let ts;
try {
  ts = await import('typescript');
  // Handle both default and named exports
  if (ts.default) ts = ts.default;
} catch {
  process.stderr.write(
    'Error: TypeScript compiler not found.\n' +
    'Install it with: npm install -g typescript\n' +
    'Or locally: npm install typescript\n'
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
let packageName = '';
let version = '0.0.0';
const filePaths = [];

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--package':
      packageName = args[++i];
      break;
    case '--version':
      version = args[++i];
      break;
    default:
      if (!args[i].startsWith('-')) filePaths.push(args[i]);
  }
}

if (!packageName || filePaths.length === 0) {
  process.stderr.write(
    'Usage: node ts_ast_helper.mjs --package <name> --version <ver> <files...>\n'
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Type mapping tables (mirrors JsToDartMapper)
// ---------------------------------------------------------------------------
const PRIMITIVE_MAP = {
  'number': { kind: 'primitive', name: 'double' },
  'string': { kind: 'primitive', name: 'String' },
  'boolean': { kind: 'primitive', name: 'bool' },
  'Date': { kind: 'primitive', name: 'DateTime' },
  'void': { kind: 'voidType', name: 'void' },
  'null': { kind: 'voidType', name: 'void' },
  'undefined': { kind: 'voidType', name: 'void' },
  'never': { kind: 'voidType', name: 'void' },
  'any': { kind: 'dynamic', name: 'dynamic' },
  'unknown': { kind: 'dynamic', name: 'dynamic' },
  'object': { kind: 'dynamic', name: 'dynamic' },
  'Buffer': { kind: 'primitive', name: 'Uint8List' },
  'ArrayBuffer': { kind: 'primitive', name: 'Uint8List' },
  'Uint8Array': { kind: 'primitive', name: 'Uint8List' },
  'Blob': { kind: 'primitive', name: 'Uint8List' },
  'URL': { kind: 'primitive', name: 'Uri' },
};

const NATIVE_OBJECTS = new Set([
  'Error', 'TypeError', 'Headers', 'Request', 'Response',
  'AbortController', 'AbortSignal',
]);

// ---------------------------------------------------------------------------
// Type conversion: TS AST node → UTS JSON type
// ---------------------------------------------------------------------------
function mapTsType(typeNode, checker, nullable = false) {
  if (!typeNode) return utsVoid();

  const kind = typeNode.kind;

  // Keyword types
  if (kind === ts.SyntaxKind.NumberKeyword)
    return utsPrimitive('double', nullable);
  if (kind === ts.SyntaxKind.StringKeyword)
    return utsPrimitive('String', nullable);
  if (kind === ts.SyntaxKind.BooleanKeyword)
    return utsPrimitive('bool', nullable);
  if (kind === ts.SyntaxKind.VoidKeyword) return utsVoid();
  if (kind === ts.SyntaxKind.UndefinedKeyword) return utsVoid();
  if (kind === ts.SyntaxKind.NullKeyword) return utsVoid();
  if (kind === ts.SyntaxKind.NeverKeyword) return utsVoid();
  if (kind === ts.SyntaxKind.AnyKeyword) return utsDynamic(nullable);
  if (kind === ts.SyntaxKind.UnknownKeyword) return utsDynamic(nullable);
  if (kind === ts.SyntaxKind.ObjectKeyword) return utsDynamic(nullable);
  if (kind === ts.SyntaxKind.SymbolKeyword) return utsDynamic(nullable);
  if (kind === ts.SyntaxKind.BigIntKeyword)
    return utsPrimitive('int', nullable);

  // Array types: T[]
  if (ts.isArrayTypeNode(typeNode)) {
    const elem = mapTsType(typeNode.elementType, checker);
    return utsList(elem, nullable);
  }

  // Tuple types: [A, B] → List<dynamic>
  if (ts.isTupleTypeNode(typeNode)) {
    return utsList(utsDynamic(false), nullable);
  }

  // Union types: A | B | null
  if (ts.isUnionTypeNode(typeNode)) {
    const types = typeNode.types;
    const isNullable = nullable || types.some(t =>
      t.kind === ts.SyntaxKind.NullKeyword ||
      t.kind === ts.SyntaxKind.UndefinedKeyword
    );
    const nonNullTypes = types.filter(t =>
      t.kind !== ts.SyntaxKind.NullKeyword &&
      t.kind !== ts.SyntaxKind.UndefinedKeyword
    );
    if (nonNullTypes.length === 0) return utsVoid();
    return mapTsType(nonNullTypes[0], checker, isNullable);
  }

  // Intersection types: A & B → take first
  if (ts.isIntersectionTypeNode(typeNode)) {
    if (typeNode.types.length > 0) {
      return mapTsType(typeNode.types[0], checker, nullable);
    }
    return utsDynamic(nullable);
  }

  // Parenthesized types: (T)
  if (ts.isParenthesizedTypeNode(typeNode)) {
    return mapTsType(typeNode.type, checker, nullable);
  }

  // Type references: Array<T>, Promise<T>, Map<K,V>, etc.
  if (ts.isTypeReferenceNode(typeNode)) {
    const typeName = typeNode.typeName.getText();
    const typeArgs = typeNode.typeArguments || [];

    // Array<T>
    if (typeName === 'Array' || typeName === 'ReadonlyArray') {
      const elem = typeArgs.length > 0
        ? mapTsType(typeArgs[0], checker)
        : utsDynamic(false);
      return utsList(elem, nullable);
    }

    // Set<T> → List<T>
    if (typeName === 'Set' || typeName === 'ReadonlySet') {
      const elem = typeArgs.length > 0
        ? mapTsType(typeArgs[0], checker)
        : utsDynamic(false);
      return utsList(elem, nullable);
    }

    // Promise<T>
    if (typeName === 'Promise') {
      const inner = typeArgs.length > 0
        ? mapTsType(typeArgs[0], checker)
        : utsVoid();
      return utsFuture(inner, nullable);
    }

    // ReadableStream<T>
    if (typeName === 'ReadableStream') {
      const inner = typeArgs.length > 0
        ? mapTsType(typeArgs[0], checker)
        : utsDynamic(false);
      return utsStream(inner, nullable);
    }

    // Map/Record<K, V>
    if (typeName === 'Map' || typeName === 'Record' ||
        typeName === 'ReadonlyMap') {
      const key = typeArgs.length > 0
        ? mapTsType(typeArgs[0], checker)
        : utsDynamic(false);
      const val = typeArgs.length > 1
        ? mapTsType(typeArgs[1], checker)
        : utsDynamic(false);
      return utsMap(key, val, nullable);
    }

    // Partial<T>, Required<T>, Readonly<T> → unwrap
    if ((typeName === 'Partial' || typeName === 'Required' ||
         typeName === 'Readonly') && typeArgs.length > 0) {
      return mapTsType(typeArgs[0], checker, nullable);
    }

    // Known primitives
    if (PRIMITIVE_MAP[typeName]) {
      const base = { ...PRIMITIVE_MAP[typeName], nullable };
      if (base.kind === 'voidType') return utsVoid();
      return { ...base, ref: null, typeArguments: null, parameterTypes: null, returnType: null };
    }

    // Known native objects
    if (NATIVE_OBJECTS.has(typeName)) {
      return utsNativeObject(typeName, nullable);
    }

    // Generic object type
    return utsObject(typeName, nullable);
  }

  // Function types: (a: T) => R
  if (ts.isFunctionTypeNode(typeNode)) {
    const paramTypes = typeNode.parameters.map(p =>
      mapTsType(p.type, checker)
    );
    const retType = mapTsType(typeNode.type, checker);
    return utsCallback(paramTypes, retType, nullable);
  }

  // Literal types: "foo", 42, true
  if (ts.isLiteralTypeNode(typeNode)) {
    const lit = typeNode.literal;
    if (lit.kind === ts.SyntaxKind.StringLiteral)
      return utsPrimitive('String', nullable);
    if (lit.kind === ts.SyntaxKind.NumericLiteral)
      return utsPrimitive('double', nullable);
    if (lit.kind === ts.SyntaxKind.TrueKeyword ||
        lit.kind === ts.SyntaxKind.FalseKeyword)
      return utsPrimitive('bool', nullable);
    if (lit.kind === ts.SyntaxKind.NullKeyword) return utsVoid();
    return utsDynamic(nullable);
  }

  // typeof X → dynamic
  if (ts.isTypeQueryNode(typeNode)) return utsDynamic(nullable);

  // Indexed access: T[K] → dynamic
  if (ts.isIndexedAccessTypeNode(typeNode)) return utsDynamic(nullable);

  // Mapped types → dynamic
  if (ts.isMappedTypeNode(typeNode)) return utsDynamic(nullable);

  // Conditional types → dynamic
  if (ts.isConditionalTypeNode(typeNode)) return utsDynamic(nullable);

  // Template literal → String
  if (ts.isTemplateLiteralTypeNode(typeNode))
    return utsPrimitive('String', nullable);

  // Rest type: ...T → take inner
  if (ts.isRestTypeNode && ts.isRestTypeNode(typeNode)) {
    return mapTsType(typeNode.type, checker, nullable);
  }

  // Fallback
  return utsDynamic(nullable);
}

// ---------------------------------------------------------------------------
// UTS type constructors
// ---------------------------------------------------------------------------
function utsPrimitive(name, nullable = false) {
  return { kind: 'primitive', name, nullable, ref: null, typeArguments: null, parameterTypes: null, returnType: null };
}
function utsVoid() {
  return { kind: 'voidType', name: 'void', nullable: false, ref: null, typeArguments: null, parameterTypes: null, returnType: null };
}
function utsDynamic(nullable = false) {
  return { kind: 'dynamic', name: 'dynamic', nullable, ref: null, typeArguments: null, parameterTypes: null, returnType: null };
}
function utsObject(name, nullable = false) {
  return { kind: 'object', name, nullable, ref: name, typeArguments: null, parameterTypes: null, returnType: null };
}
function utsNativeObject(name, nullable = false) {
  return { kind: 'nativeObject', name, nullable, ref: name, typeArguments: null, parameterTypes: null, returnType: null };
}
function utsList(elemType, nullable = false) {
  return { kind: 'list', name: 'List', nullable, ref: null, typeArguments: [elemType], parameterTypes: null, returnType: null };
}
function utsMap(keyType, valType, nullable = false) {
  return { kind: 'map', name: 'Map', nullable, ref: null, typeArguments: [keyType, valType], parameterTypes: null, returnType: null };
}
function utsFuture(innerType, nullable = false) {
  return { kind: 'future', name: 'Future', nullable, ref: null, typeArguments: [innerType], parameterTypes: null, returnType: null };
}
function utsStream(innerType, nullable = false) {
  return { kind: 'stream', name: 'Stream', nullable, ref: null, typeArguments: [innerType], parameterTypes: null, returnType: null };
}
function utsCallback(paramTypes, retType, nullable = false) {
  return { kind: 'callback', name: 'Function', nullable, ref: null, typeArguments: null, parameterTypes: paramTypes, returnType: retType };
}
function utsEnumType(name, nullable = false) {
  return { kind: 'enumType', name, nullable, ref: name, typeArguments: null, parameterTypes: null, returnType: null };
}

// ---------------------------------------------------------------------------
// AST visitor: extract declarations
// ---------------------------------------------------------------------------
const classes = [];
const functions = [];
const types = [];
const enums = [];
const typeAliases = new Map(); // name → TypeAliasDeclaration

function isExported(node) {
  if (!node.modifiers) return false;
  const hasExportOrDeclare = node.modifiers.some(m =>
    m.kind === ts.SyntaxKind.ExportKeyword ||
    m.kind === ts.SyntaxKind.DeclareKeyword
  );
  if (hasExportOrDeclare) return true;

  // Check parent for export default: export default class/interface/type/enum
  if (node.parent && ts.isExportAssignment(node.parent)) return true;

  return false;
}

function isPrivateName(name) {
  return name.startsWith('_');
}

function getDocumentation(node, sourceFile) {
  const fullText = sourceFile.getFullText();
  const ranges = ts.getLeadingCommentRanges(fullText, node.getFullStart());
  if (!ranges || ranges.length === 0) return null;

  // Take the last JSDoc comment before the node
  for (let i = ranges.length - 1; i >= 0; i--) {
    const range = ranges[i];
    const comment = fullText.substring(range.pos, range.end);
    if (comment.startsWith('/**')) {
      // Strip JSDoc syntax
      return comment
        .replace(/^\/\*\*\s*/, '')
        .replace(/\s*\*\/$/, '')
        .replace(/^\s*\*\s?/gm, '')
        .trim() || null;
    }
  }
  return null;
}

function extractParameter(param, checker, sourceFile) {
  const name = param.name.getText(sourceFile);
  const isOptional = !!param.questionToken || !!param.initializer;
  const isRest = !!param.dotDotDotToken;

  let type;
  if (isRest) {
    // ...args: T[] → treat as List<T>
    type = param.type ? mapTsType(param.type, checker) : utsDynamic(false);
    // If it's already an array type, use it; otherwise wrap
    if (type.kind !== 'list') {
      type = utsList(type, false);
    }
  } else {
    type = param.type ? mapTsType(param.type, checker) : utsDynamic(false);
  }

  let defaultValue = null;
  if (param.initializer) {
    defaultValue = param.initializer.getText(sourceFile);
  }

  return {
    name,
    type,
    isOptional,
    isNamed: false,
    defaultValue,
    documentation: null,
  };
}

function extractMethod(node, checker, sourceFile, isStatic = false) {
  const name = node.name ? node.name.getText(sourceFile) : '';
  if (!name || isPrivateName(name)) return null;

  const params = node.parameters
    .map(p => extractParameter(p, checker, sourceFile));

  const returnType = node.type
    ? mapTsType(node.type, checker)
    : utsVoid();

  // Check if async (returns Promise)
  const isAsync = returnType.kind === 'future';

  const doc = getDocumentation(node, sourceFile);

  return {
    name,
    isStatic,
    isAsync,
    parameters: params,
    returnType,
    documentation: doc,
    nativeBody: null,
  };
}

function visitNode(node, checker, sourceFile) {
  // Export function declarations
  if (ts.isFunctionDeclaration(node) && isExported(node)) {
    const name = node.name ? node.name.getText(sourceFile) : '';
    if (name && !isPrivateName(name)) {
      const method = extractMethod(node, checker, sourceFile, true);
      if (method) functions.push(method);
    }
  }

  // Class declarations
  if (ts.isClassDeclaration(node) && isExported(node)) {
    const name = node.name ? node.name.getText(sourceFile) : '';
    if (name && !isPrivateName(name)) {
      visitClass(node, checker, sourceFile);
    }
  }

  // Interface declarations → dataClass
  if (ts.isInterfaceDeclaration(node) && isExported(node)) {
    const name = node.name.getText(sourceFile);
    if (!isPrivateName(name)) {
      visitInterface(node, checker, sourceFile);
    }
  }

  // Type alias declarations
  if (ts.isTypeAliasDeclaration(node) && isExported(node)) {
    const name = node.name.getText(sourceFile);
    if (!isPrivateName(name)) {
      typeAliases.set(name, node);
      visitTypeAlias(node, checker, sourceFile);
    }
  }

  // Enum declarations
  if (ts.isEnumDeclaration(node) && isExported(node)) {
    const name = node.name.getText(sourceFile);
    if (!isPrivateName(name)) {
      visitEnum(node, checker, sourceFile);
    }
  }

  // Variable statements: export const X = ...
  if (ts.isVariableStatement(node) && isExported(node)) {
    for (const decl of node.declarationList.declarations) {
      if (ts.isVariableDeclaration(decl) && decl.name && ts.isIdentifier(decl.name)) {
        // Skip non-function exports
      }
    }
  }

  // Module declarations (namespaces)
  if (ts.isModuleDeclaration(node) && isExported(node) && node.body) {
    ts.forEachChild(node.body, child => visitNode(child, checker, sourceFile));
  }

  // Export assignment: export default <expression>
  // Handles: export default class Foo {}, export default interface Bar {}, etc.
  if (ts.isExportAssignment(node) && node.expression) {
    const expr = node.expression;
    // If the expression is an identifier referencing a declaration, skip
    // (it'll be picked up by its own declaration visit).
    // If it's an inline class/interface expression, visit it.
    if (ts.isClassExpression(expr)) {
      const name = expr.name ? expr.name.getText(sourceFile) : '';
      if (name && !isPrivateName(name)) {
        visitClass(expr, checker, sourceFile);
      }
    }
  }
}

function visitClass(node, checker, sourceFile) {
  const name = node.name.getText(sourceFile);
  const doc = getDocumentation(node, sourceFile);
  const methods = [];
  const fields = [];

  // Check if abstract
  const isAbstract = node.modifiers?.some(m =>
    m.kind === ts.SyntaxKind.AbstractKeyword
  );

  // Heritage clauses
  let superclass = null;
  const interfaces = [];
  if (node.heritageClauses) {
    for (const clause of node.heritageClauses) {
      for (const expr of clause.types) {
        const hName = expr.expression.getText(sourceFile);
        if (clause.token === ts.SyntaxKind.ExtendsKeyword) {
          superclass = hName;
        } else {
          interfaces.push(hName);
        }
      }
    }
  }

  for (const member of node.members) {
    // Skip private members
    if (member.modifiers?.some(m => m.kind === ts.SyntaxKind.PrivateKeyword)) continue;
    const memberName = member.name?.getText(sourceFile);
    if (memberName && isPrivateName(memberName)) continue;

    // Properties
    if (ts.isPropertyDeclaration(member) && memberName) {
      const isReadOnly = member.modifiers?.some(m =>
        m.kind === ts.SyntaxKind.ReadonlyKeyword
      ) ?? false;
      const isNullable = !!member.questionToken;
      const type = member.type
        ? mapTsType(member.type, checker, isNullable)
        : utsDynamic(isNullable);

      fields.push({
        name: memberName,
        type,
        nullable: isNullable,
        isReadOnly,
        defaultValue: member.initializer?.getText(sourceFile) ?? null,
        documentation: getDocumentation(member, sourceFile),
      });
    }

    // Methods
    if (ts.isMethodDeclaration(member) && memberName) {
      const isStatic = member.modifiers?.some(m =>
        m.kind === ts.SyntaxKind.StaticKeyword
      ) ?? false;
      const method = extractMethod(member, checker, sourceFile, isStatic);
      if (method) methods.push(method);
    }

    // Getters
    if (ts.isGetAccessor(member) && memberName) {
      const type = member.type
        ? mapTsType(member.type, checker)
        : utsDynamic(false);
      fields.push({
        name: memberName,
        type,
        nullable: false,
        isReadOnly: true,
        defaultValue: null,
        documentation: getDocumentation(member, sourceFile),
      });
    }
  }

  classes.push({
    name,
    kind: isAbstract ? 'abstractClass' : 'concreteClass',
    fields,
    methods,
    superclass,
    interfaces,
    sealedSubclasses: [],
    documentation: doc,
    constructorParameters: [],
  });
}

function visitInterface(node, checker, sourceFile) {
  const name = node.name.getText(sourceFile);
  const doc = getDocumentation(node, sourceFile);
  const fields = [];
  const methods = [];

  // Heritage
  const interfaces = [];
  if (node.heritageClauses) {
    for (const clause of node.heritageClauses) {
      for (const expr of clause.types) {
        interfaces.push(expr.expression.getText(sourceFile));
      }
    }
  }

  for (const member of node.members) {
    const memberName = member.name?.getText(sourceFile);
    if (memberName && isPrivateName(memberName)) continue;

    // Property signatures
    if (ts.isPropertySignature(member) && memberName) {
      const isReadOnly = member.modifiers?.some(m =>
        m.kind === ts.SyntaxKind.ReadonlyKeyword
      ) ?? false;
      const isNullable = !!member.questionToken;
      const type = member.type
        ? mapTsType(member.type, checker, isNullable)
        : utsDynamic(isNullable);

      fields.push({
        name: memberName,
        type,
        nullable: isNullable,
        isReadOnly,
        defaultValue: null,
        documentation: getDocumentation(member, sourceFile),
      });
    }

    // Method signatures
    if (ts.isMethodSignature(member) && memberName) {
      const method = extractMethod(member, checker, sourceFile, false);
      if (method) methods.push(method);
    }
  }

  // Interfaces with only fields → dataClass, with methods → abstractClass
  const kind = methods.length > 0 ? 'abstractClass' : 'dataClass';

  const target = kind === 'dataClass' ? types : classes;
  target.push({
    name,
    kind,
    fields,
    methods,
    superclass: null,
    interfaces,
    sealedSubclasses: [],
    documentation: doc,
    constructorParameters: [],
  });
}

function visitTypeAlias(node, checker, sourceFile) {
  const name = node.name.getText(sourceFile);
  const doc = getDocumentation(node, sourceFile);

  // Type aliases pointing to object literals → dataClass
  if (ts.isTypeLiteralNode(node.type)) {
    const fields = [];
    const methods = [];

    for (const member of node.type.members) {
      const memberName = member.name?.getText(sourceFile);
      if (!memberName || isPrivateName(memberName)) continue;

      if (ts.isPropertySignature(member)) {
        const isNullable = !!member.questionToken;
        const type = member.type
          ? mapTsType(member.type, checker, isNullable)
          : utsDynamic(isNullable);
        fields.push({
          name: memberName,
          type,
          nullable: isNullable,
          isReadOnly: member.modifiers?.some(m =>
            m.kind === ts.SyntaxKind.ReadonlyKeyword) ?? false,
          defaultValue: null,
          documentation: getDocumentation(member, sourceFile),
        });
      }

      if (ts.isMethodSignature(member)) {
        const method = extractMethod(member, checker, sourceFile);
        if (method) methods.push(method);
      }
    }

    if (fields.length > 0 || methods.length > 0) {
      types.push({
        name,
        kind: 'dataClass',
        fields,
        methods,
        superclass: null,
        interfaces: [],
        sealedSubclasses: [],
        documentation: doc,
        constructorParameters: [],
      });
    }
  }

  // Union of string literals → enum
  if (ts.isUnionTypeNode(node.type)) {
    const allLiterals = node.type.types.every(t =>
      ts.isLiteralTypeNode(t) && ts.isStringLiteral(t.literal)
    );
    if (allLiterals) {
      const values = node.type.types.map(t => ({
        name: t.literal.text,
        rawValue: t.literal.text,
        documentation: null,
      }));
      enums.push({ name, values, documentation: doc });
    }
  }
}

function visitEnum(node, checker, sourceFile) {
  const name = node.name.getText(sourceFile);
  const doc = getDocumentation(node, sourceFile);
  const values = [];

  for (const member of node.members) {
    const memberName = member.name.getText(sourceFile);
    let rawValue = null;
    if (member.initializer) {
      if (ts.isStringLiteral(member.initializer)) {
        rawValue = member.initializer.text;
      } else if (ts.isNumericLiteral(member.initializer)) {
        rawValue = Number(member.initializer.text);
      }
    }
    values.push({
      name: memberName,
      rawValue,
      documentation: getDocumentation(member, sourceFile),
    });
  }

  enums.push({ name, values, documentation: doc });
}

// ---------------------------------------------------------------------------
// Main: parse all files and produce UTS JSON
// ---------------------------------------------------------------------------
const sourceFiles = [];

for (const filePath of filePaths) {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const sourceFile = ts.createSourceFile(
      filePath,
      content,
      ts.ScriptTarget.Latest,
      /* setParentNodes */ true,
      filePath.endsWith('.d.ts')
        ? ts.ScriptKind.TS
        : ts.ScriptKind.TS
    );
    sourceFiles.push(sourceFile);
  } catch (err) {
    process.stderr.write(`Warning: Could not read ${filePath}: ${err.message}\n`);
  }
}

// Create a program for type checking (even without tsconfig)
const compilerHost = ts.createCompilerHost({});
const originalGetSourceFile = compilerHost.getSourceFile;
compilerHost.getSourceFile = (fileName, languageVersion, onError) => {
  const sf = sourceFiles.find(f => f.fileName === fileName);
  if (sf) return sf;
  return originalGetSourceFile.call(compilerHost, fileName, languageVersion, onError);
};

const program = ts.createProgram(
  filePaths,
  { target: ts.ScriptTarget.Latest, allowJs: true },
  compilerHost
);
const checker = program.getTypeChecker();

for (const sourceFile of sourceFiles) {
  try {
    ts.forEachChild(sourceFile, node => visitNode(node, checker, sourceFile));
  } catch (err) {
    process.stderr.write(`Warning: Error parsing ${sourceFile.fileName}: ${err.message}\n`);
  }
}

// Deduplicate by name
const seen = new Set();
const dedup = (arr) => {
  const result = [];
  for (const item of arr) {
    if (!seen.has(item.name)) {
      seen.add(item.name);
      result.push(item);
    }
  }
  return result;
};

const schema = {
  package: packageName,
  source: 'npm',
  version,
  classes: dedup(classes),
  functions: dedup(functions),
  types: dedup(types),
  enums: dedup(enums),
};

process.stdout.write(JSON.stringify(schema));
