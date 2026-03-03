// AST-based Swift source parser for auto_interop.
//
// Uses SwiftSyntax to parse .swift and .swiftinterface files and output
// a UTS JSON schema to stdout.
//
// Usage: swift_ast_helper --package <name> --version <ver> <files...>

import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - CLI argument parsing

var packageName = ""
var version = "0.0.0"
var filePaths: [String] = []

var args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    switch args[i] {
    case "--package":
        i += 1
        packageName = args[i]
    case "--version":
        i += 1
        version = args[i]
    default:
        if !args[i].hasPrefix("-") {
            filePaths.append(args[i])
        }
    }
    i += 1
}

guard !packageName.isEmpty, !filePaths.isEmpty else {
    FileHandle.standardError.write(
        "Usage: swift_ast_helper --package <name> --version <ver> <files...>\n".data(using: .utf8)!
    )
    exit(1)
}

// MARK: - Type mapping tables (mirrors SwiftToDartMapper)

let primitiveMap: [String: (String, String)] = [
    // swiftType: (kind, name)
    "Int": ("primitive", "int"),
    "Int8": ("primitive", "int"),
    "Int16": ("primitive", "int"),
    "Int32": ("primitive", "int"),
    "Int64": ("primitive", "int"),
    "UInt": ("primitive", "int"),
    "UInt8": ("primitive", "int"),
    "UInt16": ("primitive", "int"),
    "UInt32": ("primitive", "int"),
    "UInt64": ("primitive", "int"),
    "Double": ("primitive", "double"),
    "Float": ("primitive", "double"),
    "CGFloat": ("primitive", "double"),
    "String": ("primitive", "String"),
    "Bool": ("primitive", "bool"),
    "Date": ("primitive", "DateTime"),
    "Data": ("primitive", "Uint8List"),
    "URL": ("primitive", "Uri"),
    "Duration": ("primitive", "Duration"),
    "TimeInterval": ("primitive", "double"),
    "NSNumber": ("primitive", "num"),
    "NSInteger": ("primitive", "int"),
    "NSUInteger": ("primitive", "int"),
    "UUID": ("primitive", "String"),
    "NSUUID": ("primitive", "String"),
    "NSString": ("primitive", "String"),
]

let voidTypes: Set<String> = ["Void", "()", "Never"]

let dynamicTypes: Set<String> = ["Any", "AnyObject", "AnyClass"]

let nativeObjects: Set<String> = [
    "URLRequest", "URLResponse", "HTTPURLResponse", "URLSession",
    "URLSessionTask", "URLSessionConfiguration", "Error", "NSError",
    "DispatchQueue", "OperationQueue", "Notification", "NSObject",
]

// MARK: - UTS JSON type constructors

typealias UtsJSON = [String: Any?]

func utsPrimitive(_ name: String, nullable: Bool = false) -> UtsJSON {
    ["kind": "primitive", "name": name, "nullable": nullable,
     "ref": nil, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

func utsVoid() -> UtsJSON {
    ["kind": "voidType", "name": "void", "nullable": false,
     "ref": nil, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

func utsDynamic(nullable: Bool = false) -> UtsJSON {
    ["kind": "dynamic", "name": "dynamic", "nullable": nullable,
     "ref": nil, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

func utsObject(_ name: String, nullable: Bool = false) -> UtsJSON {
    ["kind": "object", "name": name, "nullable": nullable,
     "ref": name, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

func utsNativeObject(_ name: String, nullable: Bool = false) -> UtsJSON {
    ["kind": "nativeObject", "name": name, "nullable": nullable,
     "ref": name, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

func utsList(_ elem: UtsJSON, nullable: Bool = false) -> UtsJSON {
    ["kind": "list", "name": "List", "nullable": nullable,
     "ref": nil, "typeArguments": [elem], "parameterTypes": nil, "returnType": nil]
}

func utsMap(_ key: UtsJSON, _ val: UtsJSON, nullable: Bool = false) -> UtsJSON {
    ["kind": "map", "name": "Map", "nullable": nullable,
     "ref": nil, "typeArguments": [key, val], "parameterTypes": nil, "returnType": nil]
}

func utsFuture(_ inner: UtsJSON, nullable: Bool = false) -> UtsJSON {
    ["kind": "future", "name": "Future", "nullable": nullable,
     "ref": nil, "typeArguments": [inner], "parameterTypes": nil, "returnType": nil]
}

func utsStream(_ inner: UtsJSON, nullable: Bool = false) -> UtsJSON {
    ["kind": "stream", "name": "Stream", "nullable": nullable,
     "ref": nil, "typeArguments": [inner], "parameterTypes": nil, "returnType": nil]
}

func utsCallback(_ paramTypes: [UtsJSON], _ retType: UtsJSON, nullable: Bool = false) -> UtsJSON {
    ["kind": "callback", "name": "Function", "nullable": nullable,
     "ref": nil, "typeArguments": nil, "parameterTypes": paramTypes, "returnType": retType]
}

func utsEnumType(_ name: String, nullable: Bool = false) -> UtsJSON {
    ["kind": "enumType", "name": name, "nullable": nullable,
     "ref": name, "typeArguments": nil, "parameterTypes": nil, "returnType": nil]
}

// MARK: - Type conversion

func mapSwiftType(_ typeSyntax: TypeSyntaxProtocol, nullable: Bool = false) -> UtsJSON {
    // Optional type: T?
    if let optionalType = typeSyntax.as(OptionalTypeSyntax.self) {
        return mapSwiftType(optionalType.wrappedType, nullable: true)
    }

    // Implicitly unwrapped optional: T!
    if let iuoType = typeSyntax.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return mapSwiftType(iuoType.wrappedType, nullable: true)
    }

    // Array type: [T]
    if let arrayType = typeSyntax.as(ArrayTypeSyntax.self) {
        let elem = mapSwiftType(arrayType.element)
        return utsList(elem, nullable: nullable)
    }

    // Dictionary type: [K: V]
    if let dictType = typeSyntax.as(DictionaryTypeSyntax.self) {
        let key = mapSwiftType(dictType.key)
        let val = mapSwiftType(dictType.value)
        return utsMap(key, val, nullable: nullable)
    }

    // Tuple type: (A, B) → dynamic (unless void tuple)
    if let tupleType = typeSyntax.as(TupleTypeSyntax.self) {
        if tupleType.elements.count == 0 {
            return utsVoid()
        }
        return utsDynamic(nullable: nullable)
    }

    // Function type: (T) -> U
    if let funcType = typeSyntax.as(FunctionTypeSyntax.self) {
        let paramTypes = funcType.parameters.map { param in
            mapSwiftType(param.type)
        }
        let retType = mapSwiftType(funcType.returnClause.type)
        // Check for async/throws
        return utsCallback(paramTypes, retType, nullable: nullable)
    }

    // Attributed type: @escaping T, inout T, etc.
    if let attrType = typeSyntax.as(AttributedTypeSyntax.self) {
        return mapSwiftType(attrType.baseType, nullable: nullable)
    }

    // Some/any type: some P, any P
    if let someType = typeSyntax.as(SomeOrAnyTypeSyntax.self) {
        return mapSwiftType(someType.constraint, nullable: nullable)
    }

    // Composition type: P & Q → take first
    if let compType = typeSyntax.as(CompositionTypeSyntax.self) {
        if let first = compType.elements.first {
            return mapSwiftType(first.type, nullable: nullable)
        }
        return utsDynamic(nullable: nullable)
    }

    // Metatype: T.Type → dynamic
    if typeSyntax.is(MetatypeTypeSyntax.self) {
        return utsDynamic(nullable: nullable)
    }

    // Member type: Foo.Bar → flatten to FooBar
    if let memberType = typeSyntax.as(MemberTypeSyntax.self) {
        let fullName = flattenMemberType(memberType)
        return resolveSimpleType(fullName, nullable: nullable)
    }

    // Simple identifier type
    if let identType = typeSyntax.as(IdentifierTypeSyntax.self) {
        let name = identType.name.text

        // Handle generic arguments
        if let genericArgs = identType.genericArgumentClause {
            #if compiler(>=6.2)
            // SwiftSyntax 602+: argument is an enum (type or expr for value generics)
            let args = genericArgs.arguments.compactMap { arg -> UtsJSON? in
                if case .type(let typeSyntax) = arg.argument {
                    return mapSwiftType(typeSyntax)
                }
                return nil
            }
            #else
            // SwiftSyntax 510/600: argument is TypeSyntax directly
            let args = genericArgs.arguments.map { arg in
                mapSwiftType(arg.argument)
            }
            #endif

            switch name {
            case "Array":
                return utsList(args.first ?? utsDynamic(), nullable: nullable)
            case "Set":
                return utsList(args.first ?? utsDynamic(), nullable: nullable)
            case "Dictionary":
                let key = args.count > 0 ? args[0] : utsDynamic()
                let val = args.count > 1 ? args[1] : utsDynamic()
                return utsMap(key, val, nullable: nullable)
            case "Optional":
                return args.first.map { mapSwiftTypeFromJSON($0, nullable: true) } ?? utsDynamic(nullable: true)
            case "Result":
                return utsFuture(args.first ?? utsDynamic(), nullable: nullable)
            case "AsyncStream", "AsyncThrowingStream":
                return utsStream(args.first ?? utsDynamic(), nullable: nullable)
            default:
                // Generic object type
                return utsObject(name, nullable: nullable)
            }
        }

        return resolveSimpleType(name, nullable: nullable)
    }

    // Fallback
    return utsDynamic(nullable: nullable)
}

/// Helper: pass through an already-mapped type, just override nullable
func mapSwiftTypeFromJSON(_ json: UtsJSON, nullable: Bool) -> UtsJSON {
    var result = json
    result["nullable"] = nullable
    return result
}

func resolveSimpleType(_ name: String, nullable: Bool) -> UtsJSON {
    if voidTypes.contains(name) { return utsVoid() }
    if dynamicTypes.contains(name) { return utsDynamic(nullable: nullable) }
    if let (kind, dartName) = primitiveMap[name] {
        if kind == "primitive" {
            return utsPrimitive(dartName, nullable: nullable)
        }
    }
    if nativeObjects.contains(name) {
        return utsNativeObject(name, nullable: nullable)
    }
    return utsObject(name, nullable: nullable)
}

/// Flattens a MemberTypeSyntax (e.g. SHA2.Variant) into a single name (SHA2Variant).
func flattenMemberType(_ memberType: MemberTypeSyntax) -> String {
    var parts: [String] = []
    // Walk the baseType chain recursively
    func collectParts(_ type: TypeSyntaxProtocol) {
        if let member = type.as(MemberTypeSyntax.self) {
            collectParts(member.baseType)
            parts.append(member.name.text)
        } else if let ident = type.as(IdentifierTypeSyntax.self) {
            parts.append(ident.name.text)
        } else {
            parts.append(type.trimmedDescription)
        }
    }
    collectParts(memberType.baseType)
    parts.append(memberType.name.text)
    return parts.joined()
}

// MARK: - Access control filtering

func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
        let name = modifier.name.text
        if name == "private" || name == "fileprivate" || name == "internal" {
            return false
        }
    }
    // In Swift, declarations without access control in a module are internal.
    // For library API parsing, we include unmodified + public + open.
    return true
}

func hasPublicAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
        let name = modifier.name.text
        if name == "public" || name == "open" { return true }
    }
    return false
}

// MARK: - AST Visitor

/// Result of extracting members from a class/struct body.
struct ExtractedMembers {
    let methods: [[String: Any?]]
    let fields: [[String: Any?]]
    let constructorParameters: [[String: Any?]]?
    let constructorThrows: Bool
    let nestedEnums: [[String: Any?]]
    let nestedTypes: [[String: Any?]]    // structs (dataClass)
    let nestedClasses: [[String: Any?]]  // classes (concreteClass)
}

class SchemaVisitor: SyntaxVisitor {
    var classes: [[String: Any?]] = []
    var functions: [[String: Any?]] = []
    var types: [[String: Any?]] = []
    var enums: [[String: Any?]] = []
    // For extension folding: className → [methods]
    var extensionMethods: [String: [[String: Any?]]] = [:]
    var seenNames: Set<String> = []

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicAccess(node.modifiers) || isPublicOrOpen(node.modifiers) else { return .skipChildren }
        let name = node.name.text
        guard !name.hasPrefix("_"), seenNames.insert(name).inserted else { return .skipChildren }

        let doc = extractDoc(node)
        let extracted = extractMembersEx(node.memberBlock, parentName: name)
        let superclass = extractSuperclass(node.inheritanceClause)
        let interfaces = extractInterfaces(node.inheritanceClause)

        var classDict: [String: Any?] = [
            "name": name,
            "kind": "concreteClass",
            "fields": extracted.fields,
            "methods": extracted.methods,
            "superclass": superclass,
            "interfaces": interfaces,
            "sealedSubclasses": [] as [String],
            "documentation": doc,
            "constructorThrows": extracted.constructorThrows,
        ]
        if let ctorParams = extracted.constructorParameters {
            classDict["constructorParameters"] = ctorParams
        }
        classes.append(classDict)

        // Append nested types to top-level collections
        for nested in extracted.nestedEnums {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                enums.append(nested)
            }
        }
        for nested in extracted.nestedTypes {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                types.append(nested)
            }
        }
        for nested in extracted.nestedClasses {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                classes.append(nested)
            }
        }
        return .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicAccess(node.modifiers) || isPublicOrOpen(node.modifiers) else { return .skipChildren }
        let name = node.name.text
        guard !name.hasPrefix("_"), seenNames.insert(name).inserted else { return .skipChildren }

        let doc = extractDoc(node)
        let extracted = extractMembersEx(node.memberBlock, parentName: name)
        let interfaces = extractInterfaces(node.inheritanceClause)

        var typeDict: [String: Any?] = [
            "name": name,
            "kind": "dataClass",
            "fields": extracted.fields,
            "methods": extracted.methods,
            "superclass": nil as String?,
            "interfaces": interfaces,
            "sealedSubclasses": [] as [String],
            "documentation": doc,
            "constructorThrows": extracted.constructorThrows,
        ]
        if let ctorParams = extracted.constructorParameters {
            typeDict["constructorParameters"] = ctorParams
        }
        types.append(typeDict)

        // Append nested types to top-level collections
        for nested in extracted.nestedEnums {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                enums.append(nested)
            }
        }
        for nested in extracted.nestedTypes {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                types.append(nested)
            }
        }
        for nested in extracted.nestedClasses {
            if let nestedName = nested["name"] as? String, seenNames.insert(nestedName).inserted {
                classes.append(nested)
            }
        }
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicAccess(node.modifiers) || isPublicOrOpen(node.modifiers) else { return .skipChildren }
        let name = node.name.text
        guard !name.hasPrefix("_"), seenNames.insert(name).inserted else { return .skipChildren }

        let doc = extractDoc(node)
        let (methods, fields) = extractMembers(node.memberBlock)
        let interfaces = extractInterfaces(node.inheritanceClause)

        // Protocols don't have constructors — omit constructorParameters key
        classes.append([
            "name": name,
            "kind": "abstractClass",
            "fields": fields,
            "methods": methods,
            "superclass": nil as String?,
            "interfaces": interfaces,
            "sealedSubclasses": [] as [String],
            "documentation": doc,
        ])
        return .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicAccess(node.modifiers) || isPublicOrOpen(node.modifiers) else { return .skipChildren }
        let name = node.name.text
        guard !name.hasPrefix("_"), seenNames.insert(name).inserted else { return .skipChildren }

        let doc = extractDoc(node)
        var values: [[String: Any?]] = []
        var hasAssociatedValues = false

        for member in node.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                for element in caseDecl.elements {
                    let caseName = element.name.text
                    if element.parameterClause != nil {
                        hasAssociatedValues = true
                    }
                    let rawValue: Any? = element.rawValue?.value.description
                        .trimmingCharacters(in: .init(charactersIn: "\""))
                    values.append([
                        "name": caseName,
                        "rawValue": rawValue,
                        "documentation": nil as String?,
                    ])
                }
            }
        }

        if hasAssociatedValues {
            // Enum with associated values → sealedClass (no constructor)
            classes.append([
                "name": name,
                "kind": "sealedClass",
                "fields": [] as [[String: Any?]],
                "methods": [] as [[String: Any?]],
                "superclass": nil as String?,
                "interfaces": extractInterfaces(node.inheritanceClause),
                "sealedSubclasses": values.map { $0["name"] as! String },
                "documentation": doc,
            ])
        } else {
            enums.append([
                "name": name,
                "values": values,
                "documentation": doc,
            ])
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasPublicAccess(node.modifiers) || isPublicOrOpen(node.modifiers) else { return .skipChildren }
        let name = node.name.text
        guard !name.hasPrefix("_") else { return .skipChildren }

        // Only top-level functions (not methods — those are in extractMembers)
        if node.parent?.is(MemberBlockItemSyntax.self) == true { return .skipChildren }

        let method = extractFunction(node, isStatic: true)
        if seenNames.insert(name).inserted {
            functions.append(method)
        }
        return .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check access control on extension
        let hasExplicitPublic = hasPublicAccess(node.modifiers)
        let typeName = node.extendedType.trimmedDescription

        let (methods, _) = extractMembers(node.memberBlock, requirePublic: !hasExplicitPublic)

        if !methods.isEmpty {
            extensionMethods[typeName, default: []].append(contentsOf: methods)
        }
        return .skipChildren
    }

    // MARK: - Member extraction

    /// Extracts methods and fields from a member block (used by protocols and extensions).
    func extractMembers(_ memberBlock: MemberBlockSyntax, requirePublic: Bool = false) -> ([[String: Any?]], [[String: Any?]]) {
        let result = extractMembersEx(memberBlock, parentName: nil, requirePublic: requirePublic)
        return (result.methods, result.fields)
    }

    /// Full member extraction: methods, fields, constructor params, and nested types.
    func extractMembersEx(_ memberBlock: MemberBlockSyntax, parentName: String?, requirePublic: Bool = false) -> ExtractedMembers {
        var methods: [[String: Any?]] = []
        var fields: [[String: Any?]] = []
        var foundInit = false
        var initParams: [[String: Any?]] = []
        var initThrows = false
        var nestedEnums: [[String: Any?]] = []
        var nestedTypes: [[String: Any?]] = []
        var nestedClasses: [[String: Any?]] = []

        for member in memberBlock.members {
            // Functions / methods
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let modifiers = funcDecl.modifiers
                if requirePublic && !hasPublicAccess(modifiers) { continue }
                guard isPublicOrOpen(modifiers) else { continue }
                let name = funcDecl.name.text
                guard !name.hasPrefix("_") else { continue }

                let isStatic = modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
                let method = extractFunction(funcDecl, isStatic: isStatic)
                methods.append(method)
            }

            // Init (constructors) → populate constructorParameters
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let modifiers = initDecl.modifiers
                if requirePublic && !hasPublicAccess(modifiers) { continue }
                guard isPublicOrOpen(modifiers) else { continue }

                foundInit = true
                let params = extractParameters(initDecl.signature.parameterClause)
                initParams = params

                let doesThrow = initDecl.signature.effectSpecifiers?.throwsClause != nil
                if doesThrow {
                    initThrows = true
                }
            }

            // Nested enum declarations
            if let enumDecl = member.decl.as(EnumDeclSyntax.self), let parentName = parentName {
                guard hasPublicAccess(enumDecl.modifiers) || isPublicOrOpen(enumDecl.modifiers) else { continue }
                let nestedName = enumDecl.name.text
                guard !nestedName.hasPrefix("_") else { continue }
                let prefixedName = "\(parentName)\(nestedName)"

                let doc = extractDoc(enumDecl)
                var values: [[String: Any?]] = []
                var hasAssociatedValues = false

                for caseMember in enumDecl.memberBlock.members {
                    if let caseDecl = caseMember.decl.as(EnumCaseDeclSyntax.self) {
                        for element in caseDecl.elements {
                            let caseName = element.name.text
                            if element.parameterClause != nil {
                                hasAssociatedValues = true
                            }
                            let rawValue: Any? = element.rawValue?.value.description
                                .trimmingCharacters(in: .init(charactersIn: "\""))
                            values.append([
                                "name": caseName,
                                "rawValue": rawValue,
                                "documentation": nil as String?,
                            ])
                        }
                    }
                }

                if hasAssociatedValues {
                    nestedClasses.append([
                        "name": prefixedName,
                        "kind": "sealedClass",
                        "fields": [] as [[String: Any?]],
                        "methods": [] as [[String: Any?]],
                        "superclass": nil as String?,
                        "interfaces": extractInterfaces(enumDecl.inheritanceClause),
                        "sealedSubclasses": values.map { $0["name"] as! String },
                        "documentation": doc,
                    ])
                } else {
                    nestedEnums.append([
                        "name": prefixedName,
                        "values": values,
                        "documentation": doc,
                    ])
                }
            }

            // Nested struct declarations
            if let structDecl = member.decl.as(StructDeclSyntax.self), let parentName = parentName {
                guard hasPublicAccess(structDecl.modifiers) || isPublicOrOpen(structDecl.modifiers) else { continue }
                let nestedName = structDecl.name.text
                guard !nestedName.hasPrefix("_") else { continue }
                let prefixedName = "\(parentName)\(nestedName)"

                let doc = extractDoc(structDecl)
                let nested = extractMembersEx(structDecl.memberBlock, parentName: prefixedName)
                let interfaces = extractInterfaces(structDecl.inheritanceClause)

                var typeDict: [String: Any?] = [
                    "name": prefixedName,
                    "kind": "dataClass",
                    "fields": nested.fields,
                    "methods": nested.methods,
                    "superclass": nil as String?,
                    "interfaces": interfaces,
                    "sealedSubclasses": [] as [String],
                    "documentation": doc,
                    "constructorThrows": nested.constructorThrows,
                ]
                if let ctorParams = nested.constructorParameters {
                    typeDict["constructorParameters"] = ctorParams
                }
                nestedTypes.append(typeDict)

                // Propagate deeply nested types
                nestedEnums.append(contentsOf: nested.nestedEnums)
                nestedTypes.append(contentsOf: nested.nestedTypes)
                nestedClasses.append(contentsOf: nested.nestedClasses)
            }

            // Nested class declarations
            if let classDecl = member.decl.as(ClassDeclSyntax.self), let parentName = parentName {
                guard hasPublicAccess(classDecl.modifiers) || isPublicOrOpen(classDecl.modifiers) else { continue }
                let nestedName = classDecl.name.text
                guard !nestedName.hasPrefix("_") else { continue }
                let prefixedName = "\(parentName)\(nestedName)"

                let doc = extractDoc(classDecl)
                let nested = extractMembersEx(classDecl.memberBlock, parentName: prefixedName)
                let superclass = extractSuperclass(classDecl.inheritanceClause)
                let interfaces = extractInterfaces(classDecl.inheritanceClause)

                var classDict: [String: Any?] = [
                    "name": prefixedName,
                    "kind": "concreteClass",
                    "fields": nested.fields,
                    "methods": nested.methods,
                    "superclass": superclass,
                    "interfaces": interfaces,
                    "sealedSubclasses": [] as [String],
                    "documentation": doc,
                    "constructorThrows": nested.constructorThrows,
                ]
                if let ctorParams = nested.constructorParameters {
                    classDict["constructorParameters"] = ctorParams
                }
                nestedClasses.append(classDict)

                // Propagate deeply nested types
                nestedEnums.append(contentsOf: nested.nestedEnums)
                nestedTypes.append(contentsOf: nested.nestedTypes)
                nestedClasses.append(contentsOf: nested.nestedClasses)
            }

            // Properties
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let modifiers = varDecl.modifiers
                if requirePublic && !hasPublicAccess(modifiers) { continue }
                guard isPublicOrOpen(modifiers) else { continue }

                let _ = modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
                let isReadOnly = varDecl.bindingSpecifier.text == "let"

                for binding in varDecl.bindings {
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                    let propName = pattern.identifier.text
                    guard !propName.hasPrefix("_") else { continue }

                    var type: UtsJSON
                    if let typeAnnotation = binding.typeAnnotation {
                        type = mapSwiftType(typeAnnotation.type)
                    } else {
                        type = utsDynamic()
                    }

                    // Computed properties with only getter are read-only
                    var computedReadOnly = isReadOnly
                    if let accessor = binding.accessorBlock {
                        // If it has get but no set, it's read-only
                        if case .accessors(let list) = accessor.accessors {
                            let hasSet = list.contains { $0.accessorSpecifier.text == "set" }
                            if !hasSet { computedReadOnly = true }
                        }
                    }

                    let doc = extractDoc(varDecl)
                    let isNullable = (type["nullable"] as? Bool) ?? false

                    fields.append([
                        "name": propName,
                        "type": type,
                        "nullable": isNullable,
                        "isReadOnly": computedReadOnly,
                        "defaultValue": nil as String?,
                        "documentation": doc,
                    ])
                }
            }
        }

        return ExtractedMembers(
            methods: methods,
            fields: fields,
            constructorParameters: foundInit ? initParams : nil,
            constructorThrows: initThrows,
            nestedEnums: nestedEnums,
            nestedTypes: nestedTypes,
            nestedClasses: nestedClasses
        )
    }

    func extractFunction(_ node: FunctionDeclSyntax, isStatic: Bool) -> [String: Any?] {
        let name = node.name.text
        let params = extractParameters(node.signature.parameterClause)

        var returnType: UtsJSON
        if let retClause = node.signature.returnClause {
            returnType = mapSwiftType(retClause.type)
        } else {
            returnType = utsVoid()
        }

        let isAsync = node.signature.effectSpecifiers?.asyncSpecifier != nil
        let doesThrow = node.signature.effectSpecifiers?.throwsClause != nil

        // Throwing functions need async handling in Dart (try/catch via Future)
        let isEffectivelyAsync = isAsync || doesThrow

        // If async or throws, wrap return type in Future
        if isEffectivelyAsync && returnType["kind"] as? String != "future" {
            returnType = utsFuture(returnType)
        }

        let doc = extractDoc(node)

        return [
            "name": name,
            "isStatic": isStatic,
            "isAsync": isEffectivelyAsync,
            "parameters": params,
            "returnType": returnType,
            "documentation": doc,
            "nativeBody": nil as [String: String]?,
        ]
    }

    func extractParameters(_ paramClause: FunctionParameterClauseSyntax) -> [[String: Any?]] {
        return paramClause.parameters.map { param in
            let name = param.secondName?.text ?? param.firstName.text
            let externalLabel = param.firstName.text
            let type = mapSwiftType(param.type)

            let isOptional = param.defaultValue != nil ||
                (type["nullable"] as? Bool ?? false)

            // Swift external label
            var nativeLabel: String? = nil
            if externalLabel != name {
                nativeLabel = externalLabel
            }

            let defaultValue: String? = param.defaultValue?.value.trimmedDescription

            return [
                "name": name,
                "type": type,
                "isOptional": isOptional,
                "isNamed": false,
                "defaultValue": defaultValue,
                "documentation": nil as String?,
                "nativeLabel": nativeLabel,
                "nativeType": nil as String?,
            ] as [String: Any?]
        }
    }

    func extractDoc(_ node: some SyntaxProtocol) -> String? {
        let trivia = node.leadingTrivia
        var docLines: [String] = []

        for piece in trivia {
            switch piece {
            case .docLineComment(let text):
                let stripped = text.hasPrefix("///")
                    ? String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    : text
                docLines.append(stripped)
            case .docBlockComment(let text):
                let stripped = text
                    .replacingOccurrences(of: "/**", with: "")
                    .replacingOccurrences(of: "*/", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty { docLines.append(stripped) }
            default:
                break
            }
        }

        let result = docLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    func extractSuperclass(_ clause: InheritanceClauseSyntax?) -> String? {
        // In Swift, the superclass is the first inherited type that starts with uppercase
        // and isn't a known protocol. This is a heuristic.
        guard let clause = clause else { return nil }
        for inherited in clause.inheritedTypes {
            let name = inherited.type.trimmedDescription
            // Skip protocol-looking names (heuristic: common protocol suffixes)
            if name.hasSuffix("Protocol") || name.hasSuffix("Delegate") ||
               name == "Codable" || name == "Hashable" || name == "Equatable" ||
               name == "Identifiable" || name == "Sendable" || name == "ObservableObject" {
                continue
            }
            return name
        }
        return nil
    }

    func extractInterfaces(_ clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause = clause else { return [] }
        return clause.inheritedTypes.map { $0.type.trimmedDescription }
    }

    // MARK: - Fold extensions into classes

    func foldExtensions() {
        for (typeName, methods) in extensionMethods {
            // Find matching class
            for i in 0..<classes.count {
                if let name = classes[i]["name"] as? String, name == typeName {
                    var existing = classes[i]["methods"] as? [[String: Any?]] ?? []
                    var existingNames = Set(existing.compactMap { $0["name"] as? String })
                    for ext in methods {
                        if let extName = ext["name"] as? String, existingNames.insert(extName).inserted {
                            existing.append(ext)
                        }
                    }
                    classes[i]["methods"] = existing
                    break
                }
            }
            // Also check types (structs)
            for i in 0..<types.count {
                if let name = types[i]["name"] as? String, name == typeName {
                    var existing = types[i]["methods"] as? [[String: Any?]] ?? []
                    var existingNames = Set(existing.compactMap { $0["name"] as? String })
                    for ext in methods {
                        if let extName = ext["name"] as? String, existingNames.insert(extName).inserted {
                            existing.append(ext)
                        }
                    }
                    types[i]["methods"] = existing
                    break
                }
            }
        }
    }
}

// MARK: - Main: parse all files

let visitor = SchemaVisitor(viewMode: .all)

for filePath in filePaths {
    guard let data = FileManager.default.contents(atPath: filePath),
          let source = String(data: data, encoding: .utf8) else {
        FileHandle.standardError.write("Warning: Could not read \(filePath)\n".data(using: .utf8)!)
        continue
    }

    let tree = Parser.parse(source: source)
    visitor.walk(tree)
}

// Fold extension methods
visitor.foldExtensions()

// Post-parse type resolution: resolve "object" kinds to "enumType" where appropriate
func resolveTypeRefs() {
    let enumNames = Set(visitor.enums.compactMap { $0["name"] as? String })

    func resolveType(_ type: UtsJSON) -> UtsJSON {
        var t = type
        if let kind = t["kind"] as? String, kind == "object",
           let name = t["name"] as? String, enumNames.contains(name) {
            t["kind"] = "enumType"
        }
        // Recurse into typeArguments
        if let typeArgs = t["typeArguments"] as? [UtsJSON] {
            t["typeArguments"] = typeArgs.map { resolveType($0) }
        }
        return t
    }

    func resolveParam(_ param: [String: Any?]) -> [String: Any?] {
        var p = param
        if let type = p["type"] as? UtsJSON {
            p["type"] = resolveType(type)
        }
        return p
    }

    func resolveMethod(_ method: [String: Any?]) -> [String: Any?] {
        var m = method
        if let retType = m["returnType"] as? UtsJSON {
            m["returnType"] = resolveType(retType)
        }
        if let params = m["parameters"] as? [[String: Any?]] {
            m["parameters"] = params.map { resolveParam($0) }
        }
        return m
    }

    func resolveField(_ field: [String: Any?]) -> [String: Any?] {
        var f = field
        if let type = f["type"] as? UtsJSON {
            f["type"] = resolveType(type)
        }
        return f
    }

    func resolveClassDict(_ cls: inout [String: Any?]) {
        if let methods = cls["methods"] as? [[String: Any?]] {
            cls["methods"] = methods.map { resolveMethod($0) }
        }
        if let fields = cls["fields"] as? [[String: Any?]] {
            cls["fields"] = fields.map { resolveField($0) }
        }
        if let ctorParams = cls["constructorParameters"] as? [[String: Any?]] {
            cls["constructorParameters"] = ctorParams.map { resolveParam($0) }
        }
    }

    for i in 0..<visitor.classes.count {
        resolveClassDict(&visitor.classes[i])
    }
    for i in 0..<visitor.types.count {
        resolveClassDict(&visitor.types[i])
    }
    for i in 0..<visitor.functions.count {
        visitor.functions[i] = resolveMethod(visitor.functions[i])
    }
}
resolveTypeRefs()

// Build output
let schema: [String: Any] = [
    "package": packageName,
    "source": "cocoapods",
    "version": version,
    "classes": visitor.classes,
    "functions": visitor.functions,
    "types": visitor.types,
    "enums": visitor.enums,
]

// Serialize to JSON
let jsonData = try JSONSerialization.data(withJSONObject: schema, options: [])
FileHandle.standardOutput.write(jsonData)
