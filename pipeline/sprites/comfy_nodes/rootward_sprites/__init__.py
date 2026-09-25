"""Rootward's sprite-sheet nodes for ComfyUI (ADR-0029).

Three small nodes so the animation graph reads as "a pose sheet in, a sprite sheet out", with everything between them
stock ComfyUI:

- **Rootward Pose Sheet To Frames** cuts a grid of OpenPose skeletons into a frame batch, the control video.
- **Rootward VACE Keyframes** pins chosen frames of that control video to real pictures of the character (mask 0,
  "keep these pixels") and leaves the rest to the skeletons (mask 1, "draw here"). Pinning the first and last frame to
  the character's reference is what makes a clip start and end on exactly the drawing every other clip starts and ends
  on, so clips cut into each other without a jump, and a loop closes on itself.
- **Rootward Frames To Sheet** lays the decoded frames back out as a grid, with the matte as alpha.

Copied from the old repository (ProgramMe, ADR-0029 there) into Rootward; `pipeline/sprites/pipeline.py setup` checks
that ComfyUI has these nodes. The graphs in `pipeline/sprites/workflows/` are written against this version and
ComfyUI should run exactly this file (`custom_nodes/rootward_sprites/__init__.py`).
"""

from __future__ import annotations

import torch
import torch.nn.functional as F


def _resize(images: torch.Tensor, width: int, height: int) -> torch.Tensor:
    """Resize a [B, H, W, C] batch; ComfyUI images are channels-last floats in 0..1."""
    if images.shape[1] == height and images.shape[2] == width:
        return images
    moved = images.movedim(-1, 1)
    return F.interpolate(moved, size=(height, width), mode="bilinear", align_corners=False).movedim(1, -1)


class PoseSheetToFrames:
    CATEGORY = "rootward/sprites"
    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("frames",)
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "sheet": ("IMAGE",),
                "columns": ("INT", {"default": 8, "min": 1, "max": 64}),
                "frames": ("INT", {"default": 33, "min": 1, "max": 1024, "tooltip": "Cells to read, row by row."}),
            }
        }

    def run(self, sheet: torch.Tensor, columns: int, frames: int):
        rows = -(-frames // columns)
        _, height, width, _ = sheet.shape
        cell_w, cell_h = width // columns, height // rows
        cells = []
        for index in range(frames):
            row, column = divmod(index, columns)
            cells.append(sheet[0, row * cell_h : (row + 1) * cell_h, column * cell_w : (column + 1) * cell_w, :3])
        return (torch.stack(cells),)


class VaceKeyframes:
    CATEGORY = "rootward/sprites"
    RETURN_TYPES = ("IMAGE", "MASK")
    RETURN_NAMES = ("control_video", "control_masks")
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {"control": ("IMAGE",)},
            "optional": {
                "first": ("IMAGE", {"tooltip": "Pinned as the first frame."}),
                "last": ("IMAGE", {"tooltip": "Pinned as the last frame."}),
            },
        }

    def run(self, control: torch.Tensor, first: torch.Tensor | None = None, last: torch.Tensor | None = None):
        frames, height, width, _ = control.shape
        video = control[..., :3].clone()
        # LEARN: VACE reads the mask per pixel: 1 means "generate here, guided by the control pixels", 0 means "these
        # pixels are the answer". A skeleton frame is all 1s; a pinned frame is all 0s with the real picture in it.
        masks = torch.ones((frames, height, width), dtype=video.dtype, device=video.device)
        for image, index in ((first, 0), (last, frames - 1)):
            if image is None:
                continue
            video[index] = _resize(image[:1, ..., :3], width, height)[0].to(video)
            masks[index] = 0.0
        return (video, masks)


class FramesToSheet:
    CATEGORY = "rootward/sprites"
    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("sheet",)
    FUNCTION = "run"

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "frames": ("IMAGE",),
                "columns": ("INT", {"default": 8, "min": 1, "max": 64}),
            },
            "optional": {"alpha": ("MASK", {"tooltip": "One mask per frame; the sheet is RGBA when given."})},
        }

    def run(self, frames: torch.Tensor, columns: int, alpha: torch.Tensor | None = None):
        count, height, width, _ = frames.shape
        pixels = frames[..., :3]
        if alpha is not None:
            matte = alpha.to(pixels)
            if matte.shape[1:] != (height, width):
                matte = F.interpolate(matte.unsqueeze(1), size=(height, width), mode="bilinear").squeeze(1)
            pixels = torch.cat([pixels, matte.unsqueeze(-1)], dim=-1)
        rows = -(-count // columns)
        sheet = torch.zeros((1, rows * height, columns * width, pixels.shape[-1]), dtype=pixels.dtype)
        for index in range(count):
            row, column = divmod(index, columns)
            sheet[0, row * height : (row + 1) * height, column * width : (column + 1) * width] = pixels[index].cpu()
        return (sheet,)


NODE_CLASS_MAPPINGS = {
    "RootwardPoseSheetToFrames": PoseSheetToFrames,
    "RootwardVaceKeyframes": VaceKeyframes,
    "RootwardFramesToSheet": FramesToSheet,
}
NODE_DISPLAY_NAME_MAPPINGS = {
    "RootwardPoseSheetToFrames": "Rootward Pose Sheet To Frames",
    "RootwardVaceKeyframes": "Rootward VACE Keyframes",
    "RootwardFramesToSheet": "Rootward Frames To Sheet",
}
