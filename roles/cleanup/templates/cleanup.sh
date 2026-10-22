#!/bin/sh
# Housekeeping for a macOS OCluster worker. Run hourly from launchd as root.
#
# Homebrew compiles a depext from source whenever no bottle exists for the
# platform -- which on Intel is now always, since Homebrew 7.0.0 (2026-09-13)
# demoted x86_64 to tier 3. It unpacks into HOMEBREW_TEMP, i.e. /private/tmp,
# which sits on the APFS system volume and not on the ZFS store, so obuilder's
# --obuilder-prune-threshold never sees it and the boot disk fills instead.
# A cmake-class source tree is ~3 GB; i7-worker-04 accrues ~16 GB/day this way
# and hit `No space left on device` on 2026-10-17.

set -u

HOME_DIR={{ ansible_env.HOME }}
LOG=$HOME_DIR/ocluster.log
MAX_BYTES=$((128 * 1024 * 1024))
KEEP_BYTES=$((32 * 1024 * 1024))
SELF_LOG=$HOME_DIR/cleanup.log

before=$(df -g / | awk 'NR==2 {print $4}')

# Workers run --capacity=1, so at most one build is ever live. Anything here
# untouched for 12 h is abandoned -- no macOS CI job runs remotely that long.
# Leave powerlog, lofs.test and other system entries alone.
found=$(find /private/tmp -maxdepth 1 -mindepth 1 \
            \( -name 's-*' -o -name 'homebrew-*' \) \
            -mmin +720 2>/dev/null | wc -l | tr -d ' ')
find /private/tmp -maxdepth 1 -mindepth 1 \
     \( -name 's-*' -o -name 'homebrew-*' \) \
     -mmin +720 -print0 2>/dev/null | xargs -0 rm -rf 2>/dev/null

# ocluster.log is launchd's StandardOutPath/StandardErrorPath, so the worker
# holds the fd open for the life of the process: renaming it would leave the
# worker writing to an orphaned inode and the new file empty until restart.
# Truncate in place instead, keeping a tail for context.
rotated=no
if [ -f "$LOG" ]; then
    size=$(stat -f %z "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_BYTES" ]; then
        tail -c "$KEEP_BYTES" "$LOG" > "$LOG.1" 2>/dev/null
        : > "$LOG"
        rotated=yes
    fi
fi

after=$(df -g / | awk 'NR==2 {print $4}')
echo "$(date '+%Y-%m-%d %H:%M:%S') removed=$found rotated=$rotated freeGB=${before}->${after}" >> "$SELF_LOG"

# Keep this script's own log from becoming the next problem.
tail -n 500 "$SELF_LOG" > "$SELF_LOG.tmp" 2>/dev/null && mv "$SELF_LOG.tmp" "$SELF_LOG"
