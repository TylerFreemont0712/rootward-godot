class_name SandboxResult
extends RefCounted
## How a sandbox run ended. The statuses are the old runner contract's.

const OK := "ok"
const COMPILE_ERROR := "compile-error"
const RUNTIME_ERROR := "runtime-error"
const TIMEOUT := "timeout"
const OOM := "oom"
const SANDBOX_ERROR := "sandbox-error"

var status: String = SANDBOX_ERROR
var stdout: String = ""
var stderr: String = ""
## A short reason for anything other than "ok", in plain words.
var message: String = ""
var exit_code: int = -1
var wall_ms: int = 0


func is_ok() -> bool:
	return status == OK


func _to_string() -> String:
	return "SandboxResult(%s, exit %d, %d ms, %s)" % [status, exit_code, wall_ms, message]
