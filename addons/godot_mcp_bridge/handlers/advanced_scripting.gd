## Handlers for the advanced_scripting tool category.
class_name GodotMCPAdvancedScriptingHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["run_editor_script"] = run_editor_script


## Executes arbitrary GDScript in the editor process with full editor
## privileges — no sandboxing exists (there is no sandboxed GDScript
## execution mode in Godot). The code runs as the body of a `run(ei)`
## function; `ei` is the EditorInterface, and whatever the code `return`s
## becomes the tool's result.
static func run_editor_script(params: Dictionary, ei: EditorInterface) -> Variant:
	var code: String = params.get("code", "")
	if code == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "code is required"}

	var indented := "\n".join(Array(code.split("\n")).map(func(line): return "\t" + line))
	var script := GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\nfunc run(ei):\n%s\n" % indented

	var compile_err: Error = script.reload(false)
	if compile_err != OK:
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Script failed to compile: %s" % error_string(compile_err),
		}

	var instance: Object = script.new()
	if not instance.has_method("run"):
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Generated script has no run() method"}

	var result: Variant = instance.call("run", ei)
	return {"result": result}
