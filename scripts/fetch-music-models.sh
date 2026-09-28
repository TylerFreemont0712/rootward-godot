#!/usr/bin/env bash
# Installs the music models the pipeline performs with (pipeline/music/README.md), outside the repository like
# ComfyUI itself. Every download is pinned by SHA-256, the yue2.cpp build by commit. Safe to re-run: it only redoes
# what is missing or stale, and a download that stopped resumes.
#   scripts/fetch-music-models.sh            everything below
#   scripts/fetch-music-models.sh yue2       YuE2 (score-conditioned performance): yue2.cpp built for CUDA, its GGUFs
#   scripts/fetch-music-models.sh ace        ACE-Step 1.5 XL-SFT (text to music) into ComfyUI
#   scripts/fetch-music-models.sh sa3        Stable Audio 3 Medium (instrumental music, inpainting) into ComfyUI
set -euo pipefail

YUE2_DIR="${YUE2_DIR:-$HOME/personal-project/yue2.cpp}"
COMFY_DIR="${COMFY_DIR:-$HOME/personal-project/ComfyUI}"
YUE2_REPO="https://github.com/ServeurpersoCom/yue2.cpp.git"
YUE2_COMMIT="f17d5268483db25c9d79a9d53967f9d31fd1ccd3"
HF="https://huggingface.co"

fetch() { # url sha file
	local url="$1" sha="$2" file="$3"
	if [ -f "$file" ] && echo "$sha  $file" | sha256sum -c --quiet - 2>/dev/null; then
		echo "ok      $(basename "$file")"
		return
	fi
	mkdir -p "$(dirname "$file")"
	echo "fetch   $(basename "$file")"
	# -C - resumes a partial download; the checksum decides whether it is whole. A long transfer can be cut mid-stream
	# (an HTTP/2 stream reset is not one of the errors curl's own retry covers), so it resumes a few times over.
	local attempt
	for attempt in 1 2 3 4 5; do
		curl -fLsS --retry 5 --retry-delay 5 --retry-all-errors -C - -o "$file.part" "$url" && break
		echo "resume  $(basename "$file") (attempt $attempt failed)" >&2
		sleep 5
	done
	echo "$sha  $file.part" | sha256sum -c --quiet - || { echo "checksum mismatch: $file" >&2; rm -f "$file.part"; exit 1; }
	mv "$file.part" "$file"
}

yue2() {
	if [ ! -d "$YUE2_DIR/.git" ]; then
		git clone "$YUE2_REPO" "$YUE2_DIR"
	fi
	if [ "$(git -C "$YUE2_DIR" rev-parse HEAD)" != "$YUE2_COMMIT" ] || [ ! -x "$YUE2_DIR/build/yue-synth" ]; then
		git -C "$YUE2_DIR" fetch --quiet origin
		git -C "$YUE2_DIR" checkout --quiet "$YUE2_COMMIT"
		git -C "$YUE2_DIR" submodule update --init --recursive
		# LEARN: sm_86 is the RTX 30 series (Ampere); naming the one architecture the card has keeps the CUDA build to
		# minutes instead of compiling kernels for every GPU generation.
		cmake -S "$YUE2_DIR" -B "$YUE2_DIR/build" -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_BUILD_TYPE=Release
		cmake --build "$YUE2_DIR/build" --config Release -j "$(nproc)"
	fi
	fetch "$HF/Serveurperso/YuE2-GGUF/resolve/main/YuE2-3B-Q8_0.gguf" \
		41121ce97786d7795a325bcf123ca196956c03bb252c9e75384cfc1f2fc19e6b "$YUE2_DIR/models/YuE2-3B-Q8_0.gguf"
	fetch "$HF/Serveurperso/YuE2-GGUF/resolve/main/YuE2-Vae-F32.gguf" \
		93e49dfb1970e89ad64cacb17cf13b5d05f6bb30ef7ed3adae3050bcb728638a "$YUE2_DIR/models/YuE2-Vae-F32.gguf"
	fetch "$HF/Serveurperso/YuE2-GGUF/resolve/main/SheetSage2-Q8_0.gguf" \
		4507d8c1d9245f312c0894ea610ab18fbcbf31443764b5bd6a60e4b6df59e973 "$YUE2_DIR/models/SheetSage2-Q8_0.gguf"
}

ace() {
	fetch "$HF/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/split_files/diffusion_models/acestep_v1.5_xl_sft_bf16.safetensors" \
		3c05ae268353b3540fb1fd7db4fd77ffbda9802ec641b624e15648e030ecf3ce \
		"$COMFY_DIR/models/diffusion_models/acestep_v1.5_xl_sft_bf16.safetensors"
}

sa3() {
	fetch "$HF/Comfy-Org/stable-audio-3/resolve/main/checkpoints/stable_audio_3_medium.safetensors" \
		48d9c65e290e7bcd5194e0633bfc2424a59ee9683f5c2d58762d997b7d8ce0b5 \
		"$COMFY_DIR/models/checkpoints/stable_audio_3_medium.safetensors"
	fetch "$HF/Comfy-Org/stable-audio-3/resolve/main/text_encoders/t5gemma_b_b_ul2.safetensors" \
		1e1eba25be8872edb0d3c6335c6658fd6388e7b14b60da6e454e404cfcd8150e \
		"$COMFY_DIR/models/text_encoders/t5gemma_b_b_ul2.safetensors"
}

parts=("$@")
if [ ${#parts[@]} -eq 0 ]; then parts=(yue2 ace sa3); fi
for part in "${parts[@]}"; do
	case "$part" in
		yue2 | ace | sa3) "$part" ;;
		*) echo "unknown part: $part (yue2, ace, sa3)" >&2; exit 1 ;;
	esac
done
