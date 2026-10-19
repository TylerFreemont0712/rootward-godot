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
# Stop and start ComfyUI for a pipeline that needs both it and Blender in turn (scripts/world.sh make). The pattern's
# bracket keeps pgrep from matching the shell that runs it.
comfy_stop() {
	comfy_up || return 0
	pkill -f '[.]venv/bin/python main.py --listen 127.0.0.1 --port 8188' || true
	for _ in $(seq 1 30); do comfy_up || return 0; sleep 1; done
	echo "ComfyUI did not stop" >&2
	exit 1
}
comfy_start() {
	comfy_up && return 0
	if blender_up; then echo "Blender is running; close it first (the GPU cannot hold both)." >&2; exit 1; fi
	(cd "$HOME/personal-project/ComfyUI" && setsid nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 \
		>> .launcher/comfyui-server.log 2>&1 < /dev/null &)
	for _ in $(seq 1 120); do comfy_up && return 0; sleep 1; done
	echo "ComfyUI did not start (see ~/personal-project/ComfyUI/.launcher/comfyui-server.log)" >&2
	exit 1
}
