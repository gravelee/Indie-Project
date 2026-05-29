#!/bin/bash
# sort_folders.sh
# Recursively sorts all subfolders by name in Finder (macOS only).
#
# First time only — make it executable:
#   chmod +x tools/sort_folders.sh
#
# Run from the project root to sort everything:
#   ./tools/sort_folders.sh
#
# Run on a specific folder only:
#   ./tools/sort_folders.sh "/Users/Grproth/Desktop/Indie Project/art_source"
#
# Takes 30–60 seconds depending on how many subfolders exist.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$ROOT}"

echo "Sorting: $TARGET"

osascript <<APPLESCRIPT
on sortFolder(f)
    tell application "Finder"
        try
            set w to make new Finder window to f
            set current view of w to icon view
            set arrangement of icon view options of w to arranged by name
            close w
        end try
        set subs to folders of f
    end tell
    repeat with s in subs
        sortFolder(s)
    end repeat
end sortFolder

sortFolder(POSIX file "$TARGET" as alias)
APPLESCRIPT

echo "Done."
