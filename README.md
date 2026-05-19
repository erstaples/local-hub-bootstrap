# local-hub-bootstrap

Bootstrap scripts to turn a MacBook Pro (M4 Max, 48 GB) into an always-on
local AI hub. Pairs with a NVIDIA DGX Spark on the same Tailnet for heavy
inference, with the Mac acting as the always-reachable coordinator.

## What it installs

- **Power profile** — `pmset` tuned for always-on, plus Amphetamine as a
  user-facing keep-awake (handles lid-close).
- **Tailscale** — mesh networking to reach the DGX Spark and other nodes
  from anywhere.
- **Ollama + two model families** — OpenAI `gpt-oss` (20B local, 120B
  on the Spark) as the daily-driver reasoner, plus Nous Research
  `hermes4` (14B local, 70B on the Spark) as the steerable agent
  fallback. `*-hub` presets are built from Modelfiles in `config/models/`
  with tuned context, sampling, and a hub-flavored system prompt.
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
scripts/06-ollama.sh               Ollama + pull gpt-oss:20b, hermes4:14b
scripts/07-dgx-spark.sh            SSH config stub for the Spark
scripts/08-ollama-spark.sh         install Ollama on Spark, pull gpt-oss:120b, hermes4:70b
scripts/09-model-presets.sh        build *-hub presets on the right host each
scripts/99-verify.sh               verify every component
bin/hub-ollama                     wrapper that routes by model
bin/hub-tunnel                     up/down/status of the Spark SSH tunnel
config/Brewfile                    formulae + casks
config/ssh_config.spark            SSH host block for the Spark
config/model-routes.conf           model -> endpoint map
config/models/Modelfile.gpt-oss-hub.20b    local gpt-oss preset
config/models/Modelfile.gpt-oss-hub.120b   Spark gpt-oss preset
config/models/Modelfile.hermes-hub.14b     local Hermes 4 preset
config/models/Modelfile.hermes-hub.70b     Spark Hermes 4 preset
```

## Routing models between Mac and Spark

```bash
hub-ollama run gpt-oss-hub:20b   "summarize this"     # local default
hub-ollama run hermes-hub:14b    "drive these tools"  # local agent
hub-ollama run gpt-oss-hub:120b  "hard reasoning..."  # Spark, via tunnel
hub-ollama run hermes-hub:70b    "long agent run..."  # Spark, via tunnel
hub-tunnel status                                     # up / down
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
