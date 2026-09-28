# coopzr-comfyui-forge-neo

A personal Runpod image with **Stable Diffusion WebUI Forge Neo** and **ComfyUI**, sharing one model folder, behind a login.

Image: `ghcr.io/coopzr/coopzr-comfyui-forge-neo`

## What's included

- Ubuntu 24.04, CUDA 13.0 build tools, Python 3.13
- torch 2.13.0 and torchvision 0.28.0 (cu130), with torchaudio and torchcodec
- [Forge Neo](https://github.com/Haoming02/sd-webui-forge-classic/tree/neo), at a pinned commit
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) v0.37.0, with ComfyUI-Manager
- JupyterLab, SSH, nginx, runpodctl, rclone, aria2, ffmpeg

The GPU host needs NVIDIA driver 580 or newer. On Runpod, filter for **CUDA 13.0**.

## Ports

| Port | What |
|---|---|
| 3000 | Forge Neo (login required) |
| 3020 | ComfyUI (login required) |
| 8888 | JupyterLab (needs `JUPYTER_PASSWORD`, see below) |
| 22 | SSH (TCP, key only) |

## Logging in

Ports 3000 and 3020 ask for a username and password:

- **Username:** `WEBUI_USERNAME`, or `admin` if it's not set.
- **Password:** `WEBUI_PASSWORD`. Using a Runpod secret is best, for example `{{ RUNPOD_SECRET_webui_password }}`.

If `WEBUI_PASSWORD` isn't set, a password is generated on the first boot. It's printed once in the container log, and saved in `/workspace/.webui_password`, so it stays the same across restarts.

**To change it,** set `WEBUI_PASSWORD` in the template, or edit `/workspace/.webui_password` and restart the pod. To get a new generated password, delete that file and restart the pod.

## Models

There's **one model folder for both apps: `/workspace/ComfyUI/models/<type>`**, for example `checkpoints`, `diffusion_models`, `loras`, `vae`, `text_encoders`, `controlnet`, `upscale_models` and `embeddings`. Forge Neo reads it too.

Download models with ComfyUI-Manager, or from a terminal:

```bash
cd /workspace/ComfyUI/models/checkpoints
aria2c -x 16 -s 16 "<url>"      # or: wget "<url>"
```

Don't put models in Forge's own `models/` folder; ComfyUI can't see them there.

## Extensions and custom nodes

Install them from each app's UI: Forge's **Extensions** tab, and **Extensions → Nodes Manager** in ComfyUI. They live on the volume, so they survive pod restarts.

ComfyUI-Manager is set to install with pip instead of uv (`use_uv = False` in `/workspace/ComfyUI/user/__manager/config.ini`). uv can't see the image's torch, so a custom node that lists `torch` would get a second, different torch. Keep it on pip.

## Launch arguments

Add extra arguments to `/workspace/forge_args.txt` or `/workspace/comfyui_args.txt`; lines starting with `#` are ignored. Then run `restart forge` or `restart comfyui`.

## Restarting and logs

```bash
restart forge      # or: restart comfyui, restart all
```

Logs are in `/workspace/logs/`: `forge.log`, `comfyui.log` and `jupyter.log`. The first boot of each new image version copies the apps to `/workspace`. Runpod volumes are slow with many small files, so this can take 15–20 minutes (network volumes can be slower). Until it's done, the web ports show a "not up yet" page. Later boots skip it.

## Environment variables

| Variable | Default | What it does |
|---|---|---|
| `WEBUI_USERNAME` | `admin` | Login username for ports 3000 and 3020 |
| `WEBUI_PASSWORD` | generated | Login password (see [Logging in](#logging-in)) |
| `PUBLIC_KEY` | unset | Your SSH public key. SSH only starts when this is set. |
| `JUPYTER_PASSWORD` | unset | JupyterLab's password. Jupyter only starts when this is set. Runpod sets it only if you tick **Start Jupyter Notebook** when deploying; otherwise set it in the template, e.g. `{{ RUNPOD_SECRET_jupyter_password }}`. |
| `DISABLE_AUTOLAUNCH` | unset | Set to anything to not start the apps; use `restart` to start them. |
| `DISABLE_SYNC` | unset | Set to anything to skip copying the apps to `/workspace`. |

## Maintaining it

### What's pinned, and why

Everything else installs at its latest version when the image is built. The pins are in `docker-bake.hcl`.

| Pin | Value | Why |
|---|---|---|
| `UBUNTU_VERSION` | 24.04 | Platform |
| `CUDA_VERSION_DASH` | 13-0 | Must match torch's cu130 build |
| `PYTHON_VERSION` | 3.13 | Forge Neo is tested on 3.13 |
| `TORCH_VERSION` / `TORCHVISION_VERSION` | 2.13.0+cu130 / 0.28.0+cu130 | Forge Neo's own pins, shared by both apps |
| `FORGE_COMMIT` | a commit SHA | Forge Neo has no release tags |
| `COMFYUI_VERSION` | v0.37.0 | The released ComfyUI version |

Torch can't be replaced by accident: `PIP_CONSTRAINT` makes every `pip install` keep the pinned versions, in the image and on the pod. `UV_CONSTRAINT` does the same for uv, if you run it by hand.

### Releasing a new version

1. In `docker-bake.hcl`, change what you want to update, for example `COMFYUI_VERSION` or `FORGE_COMMIT`.
2. Bump `RELEASE`, for example `1.0.0` to `1.0.1`.
3. Commit and push.
4. On GitHub, open **Actions → Build → Run workflow**. The build takes about 45 minutes.
5. In the Runpod template, change the image tag to the new `RELEASE`.

On the first boot of the new version, the apps are copied over the ones on the volume. Your models, extensions, custom nodes and settings stay. Old files aren't deleted, though, so after an upgrade, a Python package that was upgraded can leave a stale copy of its version info behind. If an app complains about package versions after an upgrade, the clean fix is to delete `/workspace/venvs/forge-neo` or `/workspace/ComfyUI/venv`, delete `/workspace/.coopzr-comfyui-forge-neo-version`, and restart the pod. Then reinstall any extensions that need extra packages.

### First-time setup (already done once)

1. Create the GitHub repo `coopzr-comfyui-forge-neo` and push this folder.
2. Run the **Build** workflow.
3. Make the package public: github.com/coopzr → **Packages** → `coopzr-comfyui-forge-neo` → **Package settings** → **Change visibility** → **Public**.
4. Create a Runpod template:
   - image `ghcr.io/coopzr/coopzr-comfyui-forge-neo:<RELEASE>`;
   - HTTP ports 3000, 3020 and 8888, and TCP port 22;
   - container disk of at least 30 GB, and a volume at `/workspace`.

## Credits and licenses

This project is licensed under the [GPL-3.0](LICENSE).

- Parts are adapted from Ashley Kleynhans' [stable-diffusion-docker](https://github.com/ashleykleynhans/stable-diffusion-docker) and [runpod-base-images](https://github.com/ashleykleynhans/runpod-base-images) (GPL-3.0): the sync logic, `fix_venv.sh`, the nginx forwarded-host map, the 502 page and the build workflow's disk-cleanup step.
- `scripts/start.sh` and `nginx/proxy.conf` are adapted from Runpod's [containers](https://github.com/runpod/containers) (MIT), under this notice:

> MIT License
>
> Copyright (c) 2022 RunPod, Inc.
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Forge Neo, ComfyUI and the other bundled software keep their own licenses.
