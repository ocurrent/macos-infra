# HOWTO: Update the macOS OCaml base images

How to add a new OCaml base image (e.g. 5.5.0) and/or replace an existing one
(e.g. 4.14.3 → 4.14.4) across the macOS OCluster workers, without wiping the
ZFS pool. Driven one worker at a time so the pools keep serving jobs.

## Background

Each macOS worker keeps a set of per-OCaml-version base images as ZFS datasets:

```
obuilder/base-image/macos-homebrew-ocaml-<short>          # e.g. 4.14, 5.4, 5.5
obuilder/base-image/macos-homebrew-ocaml-<short>/brew     # the Homebrew tree
obuilder/base-image/macos-homebrew-ocaml-<short>/home     # /Users/mac1000 with the opam switch
obuilder/base-image/macos-homebrew                        # clone of the DEFAULT version
obuilder/base-image/busybox                               # busybox base
```

Key facts:

- **The `base-image` role keys on the *short* version** (`major.minor`), e.g.
  `4.14`. Installing **4.14.4 destroys and rebuilds** the existing `4.14`
  dataset (which held 4.14.3). Installing **5.5.0 creates a brand-new `5.5`**
  dataset (additional). The patch number only changes which OCaml the switch
  is built with; the dataset name is unchanged.
- The role is **not idempotent** — it deletes user `mac1000` and its home at the
  end, so re-running always rebuilds from scratch.
- **The default image** is whichever version was installed with `default: true`;
  it is cloned to `obuilder/base-image/macos-homebrew`. Currently **5.4**. Leave
  this alone unless you intend to change the cluster-wide default.
- ZFS binaries live at `$HOME/zfs/bin` on every worker. The admin cap is
  `~/admin.cap` on the control host.

### Workers and pools

| Pool            | Workers                                            |
|-----------------|----------------------------------------------------|
| `macos-arm64`   | m1-worker-01, m1-worker-02, m1-worker-03, m1-worker-04 |
| `macos-x86_64`  | i7-worker-01, i7-worker-02, i7-worker-03, i7-worker-04 |

The inventory (`hosts`) lists them as `<name>.macos.ci.dev`.

## The playbook

`deploy-base-images.yml` is the **non-destructive** deploy (it does NOT recreate
the zpool — contrast with `update-ocluster.yml`, which wipes everything). For
one worker it: `pause --wait` → `launchctl unload` ocluster → run `base-image`
for **5.5.0** (`default: false`) → conditionally **4.14.4** (`default: false`) →
`launchctl load` → `unpause`.

Edit the `version:` values in the playbook for whatever you are deploying this
round. The 4.14.4 step is gated by `install_4144` (default `true`) so you can
skip it on workers that already have the new image.

## Procedure

### 1. Survey the current state

List the pools and see which workers are idle (prefer idle ones first — then
`pause --wait` returns immediately instead of draining a running job):

```shell
ocluster-admin -c ~/admin.cap show macos-arm64
ocluster-admin -c ~/admin.cap show macos-x86_64
```

The dataset name can't tell you 4.14.3 from 4.14.4 (both are `4.14`). Use the
**snapshot creation date** to see which workers already have the new build:

```shell
for w in m1-worker-01 m1-worker-02 m1-worker-03 m1-worker-04 \
         i7-worker-01 i7-worker-02 i7-worker-03 i7-worker-04; do
  echo "===== $w ====="
  ssh $w 'PATH=$HOME/zfs/bin:$PATH zfs list -o name,creation -r obuilder/base-image \
          2>/dev/null | grep -E "ocaml-[0-9]" | grep -vE "/brew|/home"'
done
```

Note which workers already carry the target patch version — you'll pass
`-e install_4144=false` for those.

> SSH to the workers goes through a jump host (`109.74.248.109`). Connecting to
> all 8 FQDNs in parallel (e.g. a plain `ansible all ...`) overwhelms it and
> times out with "banner exchange" errors. Use the short names (`ssh m1-worker-01`,
> which the `~/.ssh/config` `??-worker-??` rule proxies) and work **one worker at
> a time**.

### 2. Set the versions in the playbook

Edit `deploy-base-images.yml` so the two `base-image` blocks have the versions
you want this round (e.g. bump `5.5.0`, and the replacement patch `4.14.4`).
Confirm the version actually exists in opam-repository before relying on it —
the build will fail late if the switch can't be resolved.

### 3. Deploy, one worker at a time

Idle worker that needs both images:

```shell
ansible-playbook deploy-base-images.yml --limit i7-worker-03.macos.ci.dev
```

Worker that already has the new 4.14 (skip the 4.14 rebuild):

```shell
ansible-playbook deploy-base-images.yml --limit m1-worker-03.macos.ci.dev -e install_4144=false
```

Each worker takes roughly:
- image build: ~10–15 min for one image (5.5.0 only), ~30–50 min for both;
- **plus** the obuilder cache clear at the end (see step 4) — this destroys
  `obuilder/result`, which on a long-running worker is 100+ GB and can take
  **~1 hour** (~2–3 GB/min, per-snapshot `.zfs/snapshot` unmounts). So budget
  roughly 1–1.5 h of worker downtime per worker. The playbook runs the destroy
  asynchronously and polls, so a flaky SSH connection through the jump host
  won't abort it.

`pause --wait` only waits for the **one in-flight job** to finish (not the whole
queue), then the build starts. A clean run ends with `failed=0` in the PLAY
RECAP. (You'll see ~35 "skipping" lines when `install_4144=false` — that's the
whole 4.14.4 role being skipped, which is correct. Both role invocations show
"for 5.5" in their task names; that's a static `import_role` display quirk, not
a bug — trust the ZFS ground truth in step 5.)

To process several in sequence, loop and **abort on the first failure** so a
problem doesn't cascade:

```shell
for w in m1-worker-04 i7-worker-01 i7-worker-02; do
  echo "=== $w ==="
  ansible-playbook deploy-base-images.yml --limit "$w.macos.ci.dev" || { echo "ABORT: $w"; break; }
done
```

You can safely run **two** deploys concurrently (e.g. recover one worker while
another loop runs) — just don't fan out to all 8 at once (jump host).

### 4. obuilder cache clear (automatic — but understand it)

`deploy-base-images.yml` does this for you at the end of every run; you don't
run anything extra. **It is the step that, if skipped, breaks the whole fleet**,
so understand why it's there: rebuilding the `obuilder/base-image/*` datasets
alone does nothing, because obuilder identifies a `FROM macos-homebrew-ocaml-4.14`
base by **name** and keeps reusing its previously-imported layers and cached
results in `obuilder/result` / `obuilder/state`. Builds then silently get the
**old compiler** (e.g. 4.14.2 instead of the 4.14.4 you just installed), and
because the old result datasets predate the brew/home sub-volume layout, every
build dies with:

```
zfs set mountpoint=/Users/mac1000 obuilder/result/<hash>/home failed with exit status 1
   -> cannot open 'obuilder/result/<hash>/home': dataset does not exist
```

(`update-ocluster.yml` never hits this only because it destroys the entire
zpool, which wipes the results too.)

The deploy playbook therefore destroys — while the worker service is stopped —
**only** `obuilder/result`, `result-tmp`, `state`, and `cache-tmp` (exact
top-level name match; it never touches `obuilder/base-image` or
`obuilder/cache`). On restart obuilder recreates those datasets and re-imports
the current base images. `obuilder/cache` (the Homebrew + opam download caches)
is deliberately kept so the first rebuilds aren't starting cold.

Standalone recovery: if you ever need to clear the cache **without**
re-deploying images (e.g. to recover a fleet that was deployed before this step
existed), run the same logic on its own, one worker at a time:

```shell
ansible-playbook clean-obuilder-cache.yml --limit i7-worker-01.macos.ci.dev
```

Either way the destroy of `obuilder/result` is slow (100+ GB, ~1 h). The
playbooks run it asynchronously and poll for completion. If you ever do it by
hand over SSH, run it detached/in the background — a foreground shell with a
short timeout gets killed mid-destroy and leaves the worker stopped with
`result` half-gone (just re-run to finish). You can clear several workers in
parallel (one brief SSH each won't stress the jump host).

### 5. Verify

Confirm every worker has the new 5.5 image and a freshly-dated 4.14 (= 4.14.4),
and that they're all back in the pool, unpaused, none disconnected:

```shell
for w in m1-worker-01 m1-worker-02 m1-worker-03 m1-worker-04 \
         i7-worker-01 i7-worker-02 i7-worker-03 i7-worker-04; do
  echo "===== $w ====="
  ssh $w 'PATH=$HOME/zfs/bin:$PATH zfs list -o name,creation -r obuilder/base-image \
          2>/dev/null | grep -E "ocaml-[0-9]" | grep -vE "/brew|/home"'
done

ocluster-admin -c ~/admin.cap show macos-arm64
ocluster-admin -c ~/admin.cap show macos-x86_64
```

## Troubleshooting

### `pause --wait` hangs forever / worker stuck on a ZFS unmount deadlock

Symptom: a worker shows `(N running)` for hours and never drains; `pause --wait`
blocks. On the host you'll find a storm of stuck `zfs unmount` / `diskutil
unmount` / `/sbin/umount` processes against `.zfs/snapshot/snap/` automounts,
with **one process in state `U` (uninterruptible kernel wait)** — this is the
OpenZFS-on-macOS snapshot-unmount deadlock (obuilder pruning result snapshots).
The `obuilder` zpool itself stays `ONLINE` / no errors — it is **not** pool
corruption. The wedged process inherits the worker's scheduler socket, so the
scheduler keeps counting the job even after you stop the service.

Diagnose:

```shell
ssh <worker> 'ps -axo pid,state,etime,command | grep -iE "/zfs |diskutil|umount" | grep -v grep'
ssh <worker> 'sudo lsof -nP -i :8103'                 # which PID holds the scheduler socket
ssh <worker> 'PATH=$HOME/zfs/bin:$PATH sudo zpool status obuilder'   # confirm ONLINE
```

A `U`-state process cannot be killed — **only a reboot clears it**:

```shell
ssh <worker> 'sudo launchctl unload /Library/LaunchDaemons/com.tarides.ocluster.worker.plist'
ssh <worker> 'sudo shutdown -r now'
```

After it comes back (wait ~30–60 s — checking too early shows
`cannot open 'obuilder': no such pool` while the pool is still importing):

```shell
ssh <worker> 'PATH=$HOME/zfs/bin:$PATH sudo zpool status obuilder'   # ONLINE, images intact
```

On reconnect the scheduler reconciles the phantom job back to `(0 running)`; the
worker returns admin-paused if it was paused — no `forget` needed. Then just run
the deploy playbook on it as normal. (`timeout` is not installed on the macOS
hosts; they run zsh — rely on `ssh -o ConnectTimeout=...` to bound a hung command.)

### Every build fails with `.../home: dataset does not exist`, or uses the wrong compiler

Symptom: after a base-image deploy, all builds on a worker fail with
`zfs set mountpoint=/Users/mac1000 obuilder/result/<hash>/home failed with exit
status 1` (the real error, hidden behind "exit status 1", is
`cannot open '.../home': dataset does not exist`); and/or a build reports an
older OCaml (e.g. 4.14.2) than the base image you installed. The base image on
disk is correct — confirm with:

```shell
ssh <worker> 'PATH=$HOME/zfs/bin:$PATH zfs list -o name,creation -r obuilder/base-image | grep ocaml'
```

Cause: obuilder is reusing **stale cached imports / results** because the
non-destructive deploy didn't clear them. Fix = step 4 above
(`clean-obuilder-cache.yml`). You can see it in the worker log
(`/Users/administrator/ocluster.log`): obuilder clones an old `obuilder/result/<hash>`
that has no `/home` child (`zfs list -r obuilder/result/<hash>` shows only the
dataset itself, no `brew`/`home`), then fails setting the home mountpoint.

## Notes

- The older `5.3` image is still present on workers that haven't been fully
  rebuilt via `update-ocluster.yml`. This deploy doesn't remove it; it's a
  harmless extra image. Remove it explicitly if you want it gone:
  `zfs destroy -R obuilder/base-image/macos-homebrew-ocaml-5.3`.
- To change the cluster-wide **default** OCaml version, set `default: true` on
  that version's `base-image` block (it re-clones `macos-homebrew`). Only one
  version should be the default.
- `update-ocluster.yml` is the heavier, **destructive** alternative: it recreates
  the whole zpool and rebuilds from scratch (loses all cached results). Use that
  only when the pool needs rebuilding, not for a routine image bump.
