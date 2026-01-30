#!/bin/bash
set -euo pipefail

# enable glob matching
shopt -s globstar

# ========================
# USER CONFIG (per folder)
# ========================
REMOTE_DIR="!!! FILL THIS IN !!!"

# Excludes (customize as needed)
EXCLUDES=(
  "hours.csv"
  "copy_sharepoint.sh"
  "**/hours.csv"
  ".git/**"
  "**/.git/**"
  "__pycache__/**"
  "**/__pycache__/**"
  "*.tmp"
  "**/*.tmp"
  "~\$*"
)

# ========================
# INTERNALS
# ========================
LOCAL_DIR="$(pwd)"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

echo "======================================="
echo " SharePoint Sync Helper"
echo " Time: $TIMESTAMP"
echo " Local : $LOCAL_DIR"
echo " Remote: $REMOTE_DIR"
echo "======================================="
echo

# Sanity check: remote exists
echo "Checking remote destination..."
if ! rclone lsd "$REMOTE_DIR" >/dev/null 2>&1; then
  echo "❌ Remote directory does not exist or is not accessible:"
  echo "   $REMOTE_DIR"
  exit 1
fi
echo "✔  Remote OK"
echo

# Build exclude flags
EXCLUDE_FLAGS=()
for pattern in "${EXCLUDES[@]}"; do
  EXCLUDE_FLAGS+=(--exclude "$pattern")
done


# ------------------------
# STEP 1: READ-ONLY CHECK
# ------------------------
echo "---------------------------------------"
echo " CHECKING MODIFICATION TIME DIFFERENCES"
echo "---------------------------------------"
echo

# Local files: output <modtime> <relative_path>
find * -type f -printf "%T@\t%p\n" |
awk -F $'\t' '{printf "%d\t%s\n", $1, $2}' |
sort -k2 > /tmp/rclone_check_local_modtimes.txt

# Remote files: output <modtime> <path> (from rclone)
rclone lsl "$REMOTE_DIR" |
awk '{
    path = substr($0, index($0, $4))
    printf "%s\t%s\t%s\n", $2, $3, path
}' |
while IFS=$'\t' read -r date time path; do
    epoch=$(date -d "$date $time" +%s)
    printf "%s\t%s\n" "$epoch" "$path"
done |
sort -k2 > /tmp/rclone_check_remote_modtimes.txt

# compare the timestamps
tolerance=5  # seconds
ndiff=0
while IFS=$'\t' read -r path local_epoch remote_epoch; do
    # skip files in the exclude list
    skip=false
    for pattern in "${EXCLUDES[@]}"; do
        if [[ $path == $pattern ]]; then
            skip=true
            break
        fi
    done
    $skip && continue

    diff=$(( local_epoch - remote_epoch ))
    # Only flag differences larger than tolerance
    if (( diff > tolerance || diff < -tolerance )); then
        # Determine which file is newer
        if (( diff > 0 )); then
            newer="local"
        else
            newer="sharepoint"
        fi

        echo "FILES DIFFER ($newer newer): $path local=$local_epoch remote=$remote_epoch (diff=${diff#-}s)"
        ndiff=$((ndiff + 1))
    fi

done < <(
    join -t $'\t' -1 2 -2 2 -a 1 -a 2 -e 0 -o auto \
    /tmp/rclone_check_local_modtimes.txt \
    /tmp/rclone_check_remote_modtimes.txt
) 

echo
if [ "$ndiff" -eq 0 ]; then
    echo "No differences found."
    echo "Exiting"
    exit 1
else
    echo "Number of differences: $ndiff"
fi

echo
echo "↑ Review the differences above."
echo


# ------------------------
# STEP 2: CHOOSE MODE
# ------------------------
echo "Choose operation mode:"
echo "  1) copy from local to sharepoint "
echo "  2) copy from sharepoint to local "
read -rp "Enter 1 or 2. (Any other input will exit.) : " MODE_CHOICE
echo

case "$MODE_CHOICE" in
  1) SRC="$LOCAL_DIR"; DST="$REMOTE_DIR"; MODE="TO" ;;
  2) SRC="$REMOTE_DIR"; DST="$LOCAL_DIR"; MODE="FROM" ;;
  *) echo "Exiting"; exit 1 ;;
esac

# ------------------------
# STEP 3: EXECUTE
# ------------------------
echo "---------------------------------------"
echo " RUNNING rclone copy $MODE sharepoint"
echo "---------------------------------------"
rclone copy "$SRC" "$DST" \
  --progress \
  --ignore-checksum \
  --ignore-errors \
  --ignore-size \
  --update \
  --verbose \
  "${EXCLUDE_FLAGS[@]}"


echo
echo "✔  Done."

