# Sourced by the pipeline scripts. The GPU has 8 GB: ComfyUI and Blender must never run at the same time.
comfy_up() { curl -s -m 2 http://127.0.0.1:8188/system_stats >/dev/null; }
blender_up() { pgrep -f '/blender-[0-9.]+/blender( |$)' >/dev/null; }
need_comfy() {
	if blender_up; then echo "Blender is running; close it first (the GPU cannot hold both)." >&2; exit 1; fi
	if ! comfy_up; then
		echo "ComfyUI is not up. Start it (detached) with:" >&2
		echo "  cd ~/personal-project/ComfyUI && setsid nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 >> .launcher/comfyui-server.log 2>&1 < /dev/null &" >&2
		exit 1
	fi
}
need_no_comfy() {
	if comfy_up; then echo "ComfyUI is running; stop it first (the GPU cannot hold both)." >&2; exit 1; fi
}
reimport() { (cd "$ROOT/game" && godot --headless --import --path . >/dev/null 2>&1 || true); }
