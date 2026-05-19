# local-hub-bootstrap

Bootstrap scripts to turn a MacBook Pro (M4 Max, 48 GB) into an always-on
local AI hub. Pairs with a NVIDIA DGX Spark on the same Tailnet for heavy
inference, with the Mac acting as the always-reachable coordinator.

## What it installs

- **Power profile** — `pmset` tuned for always-on, plus Amphetamine as a
  user-facing keep-awake (handles lid-close).
- **Tailscale** — mesh networking to reach the DGX Spark and other nodes
  from anywhere.
- **Ollama + Hermes models** — Nous Research Hermes 3 (8B local, 70B
  optionally routed to the Spark) plus `hermes-hub:*` presets built
  from Modelfiles in `config/hermes/` (system prompt, tool-call stops,
  longer context).
- **Model routing** — `bin/hub-ollama` picks the right endpoint per
  model from `config/model-routes.conf`; `bin/hub-tunnel` brings up the
  SSH tunnel to the Spark on demand.
- **Dev baseline** — Homebrew, git, gh, jq, mas, plus an SSH config stub
  for the Spark.

## Usage

```bash
git clone https://github.com/erstaples/local-hub-bootstrap.git
cd local-hub-bootstrap
./bootstrap.sh           # runs every script in scripts/ in order
```

Each step is idempotent. To run a single step:

```bash
./scripts/03-power-settings.sh
```

## Layout

```
bootstrap.sh                       top-level runner
scripts/00-preflight.sh            sanity checks (macOS, arm64, sudo)
scripts/01-xcode-clt.sh            Xcode Command Line Tools
scripts/02-homebrew.sh             Homebrew + Brewfile + PATH
scripts/03-power-settings.sh       pmset for always-on
scripts/04-amphetamine.sh          Amphetamine via mas
scripts/05-tailscale.sh            Tailscale install + up
scripts/06-ollama.sh               Ollama + hermes3:8b pull
scripts/07-dgx-spark.sh            SSH config stub for the Spark
scripts/08-ollama-spark.sh         install Ollama on Spark, pull hermes3:70b
scripts/09-hermes-config.sh        build hermes-hub:{8b,70b} presets
scripts/99-verify.sh               verify every component
bin/hub-ollama                     wrapper that routes by model
bin/hub-tunnel                     up/down/status of the Spark SSH tunnel
config/Brewfile                    formulae + casks
config/ssh_config.spark            SSH host block for the Spark
config/model-routes.conf           model -> endpoint map
config/hermes/Modelfile.hub-8b     local Hermes preset
config/hermes/Modelfile.hub-70b    Spark Hermes preset
```

## Routing models between Mac and Spark

```bash
hub-ollama run hermes-hub:8b  "summarize this"   # local, snappy
hub-ollama run hermes-hub:70b "deep analysis..." # Spark, via tunnel
hub-tunnel status                                # up / down
```

The wrapper reads `config/model-routes.conf` and sets `OLLAMA_HOST` per
call, so any tool that already shells out to `ollama` works unchanged —
just swap `ollama` for `hub-ollama` (or alias it).

## After bootstrap

1. Sign into Amphetamine, enable "Allow session while display is closed"
   and create a triggered session for "Power source is AC".
2. `tailscale up --ssh --advertise-tags=tag:hub` to join the tailnet.
3. Edit `~/.ssh/config.d/spark` with the Spark's tailnet hostname.
4. `./scripts/99-verify.sh` to confirm everything is healthy.
