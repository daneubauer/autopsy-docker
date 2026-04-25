# Autopsy 4.23.0 in Docker

This repo builds Autopsy as a `linux/amd64` container and exposes the GUI through a browser using `noVNC`. It is intended for Docker Desktop on macOS Apple Silicon, which will run the container under x86_64 emulation.

## What this does

- Uses `docker compose`.
- Builds Sleuth Kit `4.15.0`, which is the version required by Autopsy `4.23.0`'s `unix_setup.sh`.
- Uses a local `./release/autopsy-*.zip` when you place one there.
- Falls back to the latest Autopsy release from GitHub when `./release` does not contain a zip.
- Exposes the GUI at `http://localhost:6080/`.
- Also exposes raw VNC on `localhost:5900` if you want a native VNC client.

## Expected layout

Optional local override:

```text
./release/autopsy-4.23.0.zip
```

The compose stack also creates these host-mounted directories:

```text
./cases
./config
./downloads
./evidence
```

Use `./evidence` for read-only source material if you want a simple shared path into the container.

## Run

Optional:

```bash
cp .env.example .env
```

Build and start:

```bash
docker compose up --build
```

Then open:

```text
http://localhost:6080/
```

By default, noVNC/VNC starts without a password for localhost access. Set `VNC_PASSWORD` in `.env` if you want authentication.

Set `AUTOPSY_RESOLUTION` in `.env` if you want a different desktop size, for example `AUTOPSY_RESOLUTION=1600x900`.

## Release Selection

- If `./release` contains an `autopsy-*.zip`, the build uses that local file.
- If `./release` is empty, the build fetches the latest release zip from `https://github.com/sleuthkit/autopsy`.
- You can also explicitly point at a local path within the build context by setting `AUTOPSY_ZIP` in `.env`.

## Notes for Apple Silicon

- The service is pinned to `platform: linux/amd64` because Autopsy and its native dependencies are not a practical ARM64 target here.
- Docker Desktop on Apple Silicon will use emulation. Expect slower startup and lower ingest performance than a native x86_64 Linux host.
- The GUI is software-rendered inside `Xvfb`, which is the most reliable option for this setup.

## Useful commands

Start detached:

```bash
docker compose up -d --build
```

Stop:

```bash
docker compose down
```

Watch logs:

```bash
docker compose logs -f
```

## Limitations

- Linux/macOS Autopsy support is still more limited than Windows for some features.
- Browser-based GUI access is convenient, but it will not feel as fast as a local desktop app.
- The first image build needs network access to install Ubuntu packages and download Sleuth Kit source.
# autopsy-docker
