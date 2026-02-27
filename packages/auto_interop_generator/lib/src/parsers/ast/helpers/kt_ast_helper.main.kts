#!/usr/bin/env kotlinc -script
// AST-based Kotlin/Java source parser for auto_interop.
//
// Uses Kotlin's embedded compiler PSI to parse .kt and .java files and output
// a UTS JSON schema to stdout.
//
// Usage: kotlinc -script kt_ast_helper.main.kts -- --package <name> --version <ver> <files...>

@file:DependsOn("org.jetbrains.kotlin:kotlin-compiler-embeddable:1.9.22")

import org.jetbrains.kotlin.cli.common.CLIConfigurationKeys
import org.jetbrains.kotlin.cli.common.messages.MessageCollector
import org.jetbrains.kotlin.cli.jvm.compiler.EnvironmentConfigFiles
import org.jetbrains.kotlin.cli.jvm.compiler.KotlinCoreEnvironment
import org.jetbrains.kotlin.com.intellij.openapi.util.Disposer
import org.jetbrains.kotlin.com.intellij.psi.PsiManager
import org.jetbrains.kotlin.com.intellij.testFramework.LightVirtualFile
import org.jetbrains.kotlin.config.CompilerConfiguration
import org.jetbrains.kotlin.idea.KotlinFileType
import org.jetbrains.kotlin.psi.*
import java.io.File

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------
var packageName = ""
var version = "0.0.0"
val filePaths = mutableListOf<String>()

var i = 0
while (i < args.size) {
    when (args[i]) {
        "--package" -> { i++; packageName = args[i] }
        "--version" -> { i++; version = args[i] }
        else -> if (!args[i].startsWith("-")) filePaths.add(args[i])
    }
    i++
}

if (packageName.isEmpty() || filePaths.isEmpty()) {
    System.err.println("Usage: kotlinc -script kt_ast_helper.main.kts -- --package <name> --version <ver> <files...>")
    kotlin.system.exitProcess(1)
}

// ---------------------------------------------------------------------------
// Type mapping tables (mirrors KotlinToDartMapper + JavaToDartMapper)
// ---------------------------------------------------------------------------
val primitiveMap = mapOf(
    "Int" to ("primitive" to "int"),
    "Short" to ("primitive" to "int"),
    "Byte" to ("primitive" to "int"),
    "Long" to ("primitive" to "int"),
    "Double" to ("primitive" to "double"),
    "Float" to ("primitive" to "double"),
    "String" to ("primitive" to "String"),
    "Boolean" to ("primitive" to "bool"),
    "ByteArray" to ("primitive" to "Uint8List"),
    "URI" to ("primitive" to "Uri"),
    "URL" to ("primitive" to "Uri"),
    "Duration" to ("primitive" to "Duration"),
    "BigDecimal" to ("primitive" to "double"),
    "BigInteger" to ("primitive" to "int"),
    "UUID" to ("primitive" to "String"),
    "CharSequence" to ("primitive" to "String"),
    // Java types
    "int" to ("primitive" to "int"),
    "Integer" to ("primitive" to "int"),
    "short" to ("primitive" to "int"),
    "byte" to ("primitive" to "int"),
    "long" to ("primitive" to "int"),
    "double" to ("primitive" to "double"),
    "float" to ("primitive" to "double"),
    "boolean" to ("primitive" to "bool"),
    "Boolean" to ("primitive" to "bool"),
)

val voidTypes = setOf("Unit", "Nothing", "void", "Void")

val dynamicTypes = setOf("Any", "Object", "object")

val nativeObjects = setOf(
    "Exception", "Throwable", "IOException", "InputStream", "OutputStream",
    "Certificate", "SSLSocket", "Executor", "Context", "Handler",
)

// ---------------------------------------------------------------------------
// UTS JSON type constructors
// ---------------------------------------------------------------------------
fun utsPrimitive(name: String, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "primitive", "name" to name, "nullable" to nullable,
    "ref" to null, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

fun utsVoid(): Map<String, Any?> = mapOf(
    "kind" to "voidType", "name" to "void", "nullable" to false,
    "ref" to null, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

fun utsDynamic(nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "dynamic", "name" to "dynamic", "nullable" to nullable,
    "ref" to null, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

fun utsObject(name: String, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "object", "name" to name, "nullable" to nullable,
    "ref" to name, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

fun utsNativeObject(name: String, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "nativeObject", "name" to name, "nullable" to nullable,
    "ref" to name, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

fun utsList(elem: Map<String, Any?>, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "list", "name" to "List", "nullable" to nullable,
    "ref" to null, "typeArguments" to listOf(elem), "parameterTypes" to null, "returnType" to null,
)

fun utsMap(key: Map<String, Any?>, value: Map<String, Any?>, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "map", "name" to "Map", "nullable" to nullable,
    "ref" to null, "typeArguments" to listOf(key, value), "parameterTypes" to null, "returnType" to null,
)

fun utsFuture(inner: Map<String, Any?>, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "future", "name" to "Future", "nullable" to nullable,
    "ref" to null, "typeArguments" to listOf(inner), "parameterTypes" to null, "returnType" to null,
)

fun utsStream(inner: Map<String, Any?>, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "stream", "name" to "Stream", "nullable" to nullable,
    "ref" to null, "typeArguments" to listOf(inner), "parameterTypes" to null, "returnType" to null,
)

fun utsCallback(paramTypes: List<Map<String, Any?>>, retType: Map<String, Any?>, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "callback", "name" to "Function", "nullable" to nullable,
    "ref" to null, "typeArguments" to null, "parameterTypes" to paramTypes, "returnType" to retType,
)

fun utsEnumType(name: String, nullable: Boolean = false): Map<String, Any?> = mapOf(
    "kind" to "enumType", "name" to name, "nullable" to nullable,
    "ref" to name, "typeArguments" to null, "parameterTypes" to null, "returnType" to null,
)

// ---------------------------------------------------------------------------
// Type conversion
// ---------------------------------------------------------------------------
fun mapKotlinType(typeRef: KtTypeReference?, nullable: Boolean = false): Map<String, Any?> {
    if (typeRef == null) return utsDynamic(nullable)
    val isNullable = nullable || typeRef.typeElement is KtNullableType

    val typeElement = if (typeRef.typeElement is KtNullableType) {
        (typeRef.typeElement as KtNullableType).innerType
    } else {
        typeRef.typeElement
    }

    return mapTypeElement(typeElement, isNullable)
}

fun mapTypeElement(typeElement: KtTypeElement?, nullable: Boolean): Map<String, Any?> {
    if (typeElement == null) return utsDynamic(nullable)

    // Function type: (A, B) -> C
    if (typeElement is KtFunctionType) {
        val paramTypes = typeElement.parameters.map { param ->
            mapKotlinType(param.typeReference)
        }
        val retType = mapKotlinType(typeElement.returnTypeReference)
        // Check for suspend → wrap in Future
        return utsCallback(paramTypes, retType, nullable)
    }

    // User type (named types with possible generics)
    if (typeElement is KtUserType) {
        val name = typeElement.referencedName ?: return utsDynamic(nullable)
        val typeArgs = typeElement.typeArguments.mapNotNull { it.typeReference?.let { ref -> mapKotlinType(ref) } }

        // Generic containers
        when (name) {
            "List", "MutableList", "ArrayList", "Collection" -> {
                val elem = typeArgs.firstOrNull() ?: utsDynamic()
                return utsList(elem, nullable)
            }
            "Set", "MutableSet", "HashSet" -> {
                val elem = typeArgs.firstOrNull() ?: utsDynamic()
                return utsList(elem, nullable)
            }
            "Map", "MutableMap", "HashMap", "LinkedHashMap" -> {
                val key = typeArgs.getOrElse(0) { utsDynamic() }
                val value = typeArgs.getOrElse(1) { utsDynamic() }
                return utsMap(key, value, nullable)
            }
            "Flow", "StateFlow", "SharedFlow" -> {
                val inner = typeArgs.firstOrNull() ?: utsDynamic()
                return utsStream(inner, nullable)
            }
            "Deferred" -> {
                val inner = typeArgs.firstOrNull() ?: utsDynamic()
                return utsFuture(inner, nullable)
            }
            "Array" -> {
                val elem = typeArgs.firstOrNull() ?: utsDynamic()
                return utsList(elem, nullable)
            }
            "Optional" -> {  // Java Optional
                val inner = typeArgs.firstOrNull() ?: utsDynamic()
                return inner.toMutableMap().also { it["nullable"] = true }
            }
        }

        // Simple types
        return resolveSimpleType(name, nullable)
    }

    return utsDynamic(nullable)
}

fun resolveSimpleType(name: String, nullable: Boolean): Map<String, Any?> {
    if (voidTypes.contains(name)) return utsVoid()
    if (dynamicTypes.contains(name)) return utsDynamic(nullable)
    primitiveMap[name]?.let { (_, dartName) ->
        return utsPrimitive(dartName, nullable)
    }
    if (nativeObjects.contains(name)) return utsNativeObject(name, nullable)
    return utsObject(name, nullable)
}

// ---------------------------------------------------------------------------
// Declaration visitors
// ---------------------------------------------------------------------------
val classes = mutableListOf<Map<String, Any?>>()
val functions = mutableListOf<Map<String, Any?>>()
val types = mutableListOf<Map<String, Any?>>()
val enums = mutableListOf<Map<String, Any?>>()
val seenNames = mutableSetOf<String>()

// Companion object methods: className → [methods]
val companionMethods = mutableMapOf<String, MutableList<Map<String, Any?>>>()

// Extension methods: receiverType → [methods]
val extensionMethods = mutableMapOf<String, MutableList<Map<String, Any?>>>()

fun isPublic(modifiers: KtModifierList?): Boolean {
    if (modifiers == null) return true // Kotlin default is public
    if (modifiers.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.PRIVATE_KEYWORD)) return false
    if (modifiers.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.INTERNAL_KEYWORD)) return false
    if (modifiers.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.PROTECTED_KEYWORD)) return false
    return true
}

fun extractDoc(decl: KtDeclaration): String? {
    val docComment = decl.docComment ?: return null
    return docComment.getDefaultSection().getContent()
        .trim()
        .takeIf { it.isNotEmpty() }
}

fun extractParameter(param: KtParameter): Map<String, Any?> {
    val name = param.name ?: "arg"
    val type = mapKotlinType(param.typeReference)
    val isOptional = param.hasDefaultValue() || (type["nullable"] as? Boolean ?: false)
    val defaultValue = param.defaultValue?.text

    return mapOf(
        "name" to name,
        "type" to type,
        "isOptional" to isOptional,
        "isNamed" to false,
        "defaultValue" to defaultValue,
        "documentation" to null,
    )
}

fun extractFunction(func: KtNamedFunction, isStatic: Boolean = false): Map<String, Any?> {
    val name = func.name ?: return emptyMap()
    val params = func.valueParameters.map { extractParameter(it) }

    // Kotlin functions without explicit return type return Unit (void)
    var returnType = if (func.typeReference == null) utsVoid() else mapKotlinType(func.typeReference)

    val isSuspend = func.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.SUSPEND_KEYWORD)
    if (isSuspend && (returnType["kind"] as? String) != "future") {
        returnType = utsFuture(returnType)
    }

    return mapOf(
        "name" to name,
        "isStatic" to isStatic,
        "isAsync" to isSuspend,
        "parameters" to params,
        "returnType" to returnType,
        "documentation" to extractDoc(func),
        "nativeBody" to null,
    )
}

fun visitClass(cls: KtClass) {
    if (!isPublic(cls.modifierList)) return
    val name = cls.name ?: return
    if (name.startsWith("_") || !seenNames.add(name)) return

    val doc = extractDoc(cls)
    val methods = mutableListOf<Map<String, Any?>>()
    val fields = mutableListOf<Map<String, Any?>>()

    // Determine kind
    val kind = when {
        cls.isEnum() -> "enum" // handled separately
        cls.isSealed() -> "sealedClass"
        cls.isData() -> "dataClass"
        cls.isInterface() -> "abstractClass"
        cls.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.ABSTRACT_KEYWORD) -> "abstractClass"
        else -> "concreteClass"
    }

    // Handle enums separately
    if (cls.isEnum()) {
        val values = cls.declarations.filterIsInstance<KtEnumEntry>().map { entry ->
            mapOf<String, Any?>(
                "name" to (entry.name ?: ""),
                "rawValue" to entry.name,
                "documentation" to null,
            )
        }
        enums.add(mapOf(
            "name" to name,
            "values" to values,
            "documentation" to doc,
        ))
        return
    }

    // Extract constructor parameters for data classes
    val constructorParams = if (kind == "dataClass") {
        cls.primaryConstructorParameters.map { param ->
            val paramName = param.name ?: "arg"
            val type = mapKotlinType(param.typeReference)
            val isReadOnly = param.hasValOrVar() && param.valOrVarKeyword?.text == "val"

            // Data class params → fields
            fields.add(mapOf(
                "name" to paramName,
                "type" to type,
                "nullable" to (type["nullable"] as? Boolean ?: false),
                "isReadOnly" to isReadOnly,
                "defaultValue" to param.defaultValue?.text,
                "documentation" to null,
            ))

            extractParameter(param)
        }
    } else {
        emptyList()
    }

    // Extract members (deduplicate overloaded methods by name)
    val seenMethodNames = mutableSetOf<String>()
    for (decl in cls.declarations) {
        when (decl) {
            is KtNamedFunction -> {
                if (!isPublic(decl.modifierList)) continue
                val funcName = decl.name ?: continue
                if (funcName.startsWith("_")) continue
                if (!seenMethodNames.add(funcName)) continue  // skip overloads

                val isStatic = decl.hasModifier(org.jetbrains.kotlin.lexer.KtTokens.OVERRIDE_KEYWORD) ||
                    decl.parent?.parent is KtObjectDeclaration
                methods.add(extractFunction(decl, isStatic))
            }
            is KtProperty -> {
                if (!isPublic(decl.modifierList)) continue
                val propName = decl.name ?: continue
                if (propName.startsWith("_")) continue

                val type = mapKotlinType(decl.typeReference)
                val isReadOnly = !decl.isVar
                val isNullable = type["nullable"] as? Boolean ?: false

                fields.add(mapOf(
                    "name" to propName,
                    "type" to type,
                    "nullable" to isNullable,
                    "isReadOnly" to isReadOnly,
                    "defaultValue" to decl.initializer?.text,
                    "documentation" to extractDoc(decl),
                ))
            }
            is KtObjectDeclaration -> {
                // Companion object → extract methods as static
                if (decl.isCompanion()) {
                    for (companionDecl in decl.declarations) {
                        if (companionDecl is KtNamedFunction && isPublic(companionDecl.modifierList)) {
                            val funcName = companionDecl.name ?: continue
                            if (funcName.startsWith("_")) continue
                            if (!seenMethodNames.add(funcName)) continue  // skip overloads
                            methods.add(extractFunction(companionDecl, isStatic = true))
                        }
                    }
                }
            }
        }
    }

    // Superclass and interfaces
    val superTypes = cls.superTypeListEntries.mapNotNull { entry ->
        when (entry) {
            is KtSuperTypeCallEntry -> entry.typeReference?.text
            is KtSuperTypeEntry -> entry.typeReference?.text
            else -> null
        }
    }

    // Heuristic: first supertype that doesn't end in common interface suffixes
    var superclass: String? = null
    val interfaces = mutableListOf<String>()
    for (st in superTypes) {
        if (superclass == null && !st.endsWith("able") && !st.endsWith("Listener") &&
            !st.endsWith("Callback") && !st.endsWith("Observer") &&
            st != "Serializable" && st != "Parcelable" && st != "Comparable" &&
            st != "Cloneable") {
            superclass = st
        } else {
            interfaces.add(st)
        }
    }

    // Sealed subclasses
    val sealedSubclasses = if (kind == "sealedClass") {
        cls.declarations.filterIsInstance<KtClass>().mapNotNull { it.name }
    } else {
        emptyList()
    }

    val target = if (kind == "dataClass") types else classes
    target.add(mapOf(
        "name" to name,
        "kind" to kind,
        "fields" to fields,
        "methods" to methods,
        "superclass" to superclass,
        "interfaces" to interfaces,
        "sealedSubclasses" to sealedSubclasses,
        "documentation" to doc,
        "constructorParameters" to constructorParams,
    ))
}

fun visitTopLevelFunction(func: KtNamedFunction) {
    if (!isPublic(func.modifierList)) return
    val name = func.name ?: return
    if (name.startsWith("_")) return

    // Extension function: has a receiver type (e.g. fun String.isValid(): Boolean)
    val receiverType = func.receiverTypeReference?.text
    if (receiverType != null) {
        val method = extractFunction(func, isStatic = false)
        extensionMethods.getOrPut(receiverType) { mutableListOf() }.add(method)
        return
    }

    // Regular top-level function — deduplicate overloads by name
    if (!seenNames.add(name)) return
    functions.add(extractFunction(func, isStatic = true))
}

// ---------------------------------------------------------------------------
// PSI setup + parse
// ---------------------------------------------------------------------------
val configuration = CompilerConfiguration().apply {
    put(CLIConfigurationKeys.MESSAGE_COLLECTOR_KEY, MessageCollector.NONE)
}

val disposable = Disposer.newDisposable()
val environment = KotlinCoreEnvironment.createForProduction(
    disposable,
    configuration,
    EnvironmentConfigFiles.JVM_CONFIG_FILES,
)

val psiManager = PsiManager.getInstance(environment.project)

for (filePath in filePaths) {
    try {
        val file = File(filePath)
        if (!file.exists()) {
            System.err.println("Warning: File not found: $filePath")
            continue
        }

        val content = file.readText()
        val isKotlin = filePath.endsWith(".kt") || filePath.endsWith(".kts")

        if (isKotlin) {
            val virtualFile = LightVirtualFile(file.name, KotlinFileType.INSTANCE, content)
            val psiFile = psiManager.findFile(virtualFile) as? KtFile ?: continue

            for (decl in psiFile.declarations) {
                try {
                    when (decl) {
                        is KtClass -> visitClass(decl)
                        is KtNamedFunction -> visitTopLevelFunction(decl)
                        is KtObjectDeclaration -> {
                            // Top-level objects → treat as class with static methods
                            if (isPublic(decl.modifierList)) {
                                val objName = decl.name ?: continue
                                if (objName.startsWith("_") || !seenNames.add(objName)) continue

                                val objSeenMethods = mutableSetOf<String>()
                                val methods = decl.declarations
                                    .filterIsInstance<KtNamedFunction>()
                                    .filter { isPublic(it.modifierList) && !(it.name ?: "").startsWith("_") && objSeenMethods.add(it.name ?: "") }
                                    .map { extractFunction(it, isStatic = true) }

                                val fields = decl.declarations
                                    .filterIsInstance<KtProperty>()
                                    .filter { isPublic(it.modifierList) && !(it.name ?: "").startsWith("_") }
                                    .map { prop ->
                                        val type = mapKotlinType(prop.typeReference)
                                        mapOf<String, Any?>(
                                            "name" to (prop.name ?: ""),
                                            "type" to type,
                                            "nullable" to (type["nullable"] as? Boolean ?: false),
                                            "isReadOnly" to !prop.isVar,
                                            "defaultValue" to prop.initializer?.text,
                                            "documentation" to extractDoc(prop),
                                        )
                                    }

                                classes.add(mapOf(
                                    "name" to objName,
                                    "kind" to "concreteClass",
                                    "fields" to fields,
                                    "methods" to methods,
                                    "superclass" to null,
                                    "interfaces" to emptyList<String>(),
                                    "sealedSubclasses" to emptyList<String>(),
                                    "documentation" to extractDoc(decl),
                                    "constructorParameters" to emptyList<Map<String, Any?>>(),
                                ))
                            }
                        }
                    }
                } catch (e: Exception) {
                    System.err.println("Warning: Error processing declaration in $filePath: ${e.message}")
                }
            }
        } else if (filePath.endsWith(".java")) {
            // For Java files, we use a simplified regex approach since Kotlin PSI
            // doesn't parse Java. Java support through AST would require a separate
            // Java parser. For now, skip Java files in AST mode — the regex fallback
            // handles them.
            System.err.println("Note: Java file $filePath skipped in AST mode (use regex fallback)")
        }
    } catch (e: Exception) {
        System.err.println("Warning: Error parsing $filePath: ${e.message}")
    }
}

Disposer.dispose(disposable)

// ---------------------------------------------------------------------------
// Fold extension methods into matching classes/types
// ---------------------------------------------------------------------------
for ((receiverType, extMethods) in extensionMethods) {
    var folded = false

    // Try to fold into existing class
    for (i in classes.indices) {
        if (classes[i]["name"] == receiverType) {
            val existing = (classes[i]["methods"] as? List<*>)?.toMutableList() ?: mutableListOf()
            val existingNames = existing.mapNotNull { (it as? Map<*, *>)?.get("name") as? String }.toMutableSet()
            for (ext in extMethods) {
                val extName = ext["name"] as? String ?: continue
                if (existingNames.add(extName)) {  // only add if name not already present
                    existing.add(ext)
                }
            }
            classes[i] = classes[i].toMutableMap().also { it["methods"] = existing }
            folded = true
            break
        }
    }

    // Try to fold into existing type (data class)
    if (!folded) {
        for (i in types.indices) {
            if (types[i]["name"] == receiverType) {
                val existing = (types[i]["methods"] as? List<*>)?.toMutableList() ?: mutableListOf()
                val existingNames = existing.mapNotNull { (it as? Map<*, *>)?.get("name") as? String }.toMutableSet()
                for (ext in extMethods) {
                    val extName = ext["name"] as? String ?: continue
                    if (existingNames.add(extName)) {
                        existing.add(ext)
                    }
                }
                types[i] = types[i].toMutableMap().also { it["methods"] = existing }
                folded = true
                break
            }
        }
    }

    // No matching class/type: emit as top-level functions with receiver as first param
    if (!folded) {
        for (method in extMethods) {
            val methodName = method["name"] as? String ?: continue
            // Use compound key so same-named extensions on different receivers don't collide
            // e.g. fun String.format() and fun Int.format() both get emitted
            if (!seenNames.add("$receiverType.$methodName")) continue

            val receiverParam = mapOf<String, Any?>(
                "name" to "self",
                "type" to resolveSimpleType(receiverType, false),
                "isOptional" to false,
                "isNamed" to false,
                "defaultValue" to null,
                "documentation" to null,
            )
            val existingParams = (method["parameters"] as? List<*>) ?: emptyList<Any>()
            val allParams = listOf(receiverParam) + existingParams

            functions.add(method.toMutableMap().also {
                it["isStatic"] = true
                it["parameters"] = allParams
            })
        }
    }
}

// ---------------------------------------------------------------------------
// Output UTS JSON
// ---------------------------------------------------------------------------
fun toJson(obj: Any?): String {
    return when (obj) {
        null -> "null"
        is String -> "\"${obj.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")}\""
        is Number -> obj.toString()
        is Boolean -> obj.toString()
        is List<*> -> obj.joinToString(",", "[", "]") { toJson(it) }
        is Map<*, *> -> obj.entries.joinToString(",", "{", "}") { (k, v) ->
            "\"$k\":${toJson(v)}"
        }
        else -> "\"$obj\""
    }
}

val schema = mapOf(
    "package" to packageName,
    "source" to "gradle",
    "version" to version,
    "classes" to classes,
    "functions" to functions,
    "types" to types,
    "enums" to enums,
)

print(toJson(schema))
