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
  optionally routed to the Spark).
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
bootstrap.sh              top-level runner
scripts/00-preflight.sh   sanity checks (macOS, arm64, sudo)
scripts/01-xcode-clt.sh   Xcode Command Line Tools
scripts/02-homebrew.sh    Homebrew + Brewfile
scripts/03-power-settings.sh   pmset for always-on
scripts/04-amphetamine.sh      Amphetamine via mas
scripts/05-tailscale.sh   Tailscale install + up
scripts/06-ollama.sh      Ollama + Hermes 3 pull
scripts/07-dgx-spark.sh   SSH config stub for the Spark
scripts/99-verify.sh      verify every component
config/Brewfile           formulae + casks
config/ssh_config.spark   SSH host block for the Spark
```

## After bootstrap

1. Sign into Amphetamine, enable "Allow session while display is closed"
   and create a triggered session for "Power source is AC".
2. `tailscale up --ssh --advertise-tags=tag:hub` to join the tailnet.
3. Edit `~/.ssh/config.d/spark` with the Spark's tailnet hostname.
4. `./scripts/99-verify.sh` to confirm everything is healthy.
