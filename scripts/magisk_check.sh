#!/usr/bin/env bash
set -euo pipefail

OWNER="${OWNER:-topjohnwu}"
REPO="${REPO:-Magisk}"
BRANCH="${BRANCH:-master}"
KEYWORDS="${KEYWORDS:-zygisk|denylist|hide|namespace|mount}"

# Load last state
# shellcheck disable=SC1091
source ./last_state.env
LAST_TAG="${LAST_TAG:-}"
LAST_SHA="${LAST_SHA:-}"

# 1) Latest release info (for context: version/tag + release notes)
REL_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
curl -s "$REL_URL" > latest_release.json

TAG="$(jq -r '.tag_name // ""' latest_release.json)"
REL_NAME="$(jq -r '.name // ""' latest_release.json)"
PUBLISHED="$(jq -r '.published_at // ""' latest_release.json)"
REL_URL_HTML="$(jq -r '.html_url // ""' latest_release.json)"
BODY="$(jq -r '.body // ""' latest_release.json)"

echo "$BODY" > body.txt

# Extract highlights from release notes (optional)
grep -iE "$KEYWORDS" body.txt | head -n 8 > highlights.txt || true
if [ -s highlights.txt ]; then
  HIGHLIGHTS="$(sed 's/$/\\n/' highlights.txt | tr -d '\r')"
else
  HIGHLIGHTS="• (no keyword highlight detected)\\n"
fi

# 2) Latest commit on branch (detect code changes even without new release)
COMMIT_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits/${BRANCH}"
curl -s "$COMMIT_URL" > latest_commit.json

SHA="$(jq -r '.sha // ""' latest_commit.json)"
COMMIT_MSG="$(jq -r '.commit.message // ""' latest_commit.json | head -n 1)"
COMMIT_DATE="$(jq -r '.commit.committer.date // ""' latest_commit.json)"
COMMIT_AUTHOR="$(jq -r '.commit.author.name // ""' latest_commit.json)"
COMMIT_URL_HTML="$(jq -r '.html_url // ""' latest_commit.json)"

if [ -z "$TAG" ] || [ -z "$SHA" ]; then
  echo "Failed to fetch release tag or commit sha."
  exit 1
fi

# 2b) Fetch commit detail (changed files + folders)
DETAIL_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits/${SHA}"
curl -s "$DETAIL_URL" > commit_detail.json

# total changed files
FILE_COUNT="$(jq -r '.files | length' commit_detail.json 2>/dev/null || echo 0)"

# file list (top 15) - use '|' delimiter to store safely in env
FILE_LIST="$(jq -r '.files[].filename' commit_detail.json 2>/dev/null | head -n 15 | tr '\n' '|' || true)"

# folder list (top-level folders) - also '|' delimiter
FOLDER_LIST="$(jq -r '.files[].filename' commit_detail.json 2>/dev/null \
  | awk -F/ '{print $1}' \
  | sort -u \
  | head -n 10 \
  | tr '\n' '|' || true)"

# Decide whether to alert:
# - release tag changed OR commit sha changed
SHOULD_ALERT="false"
REASON=""

if [ "$TAG" != "$LAST_TAG" ]; then
  SHOULD_ALERT="true"
  REASON="NEW_RELEASE"
elif [ "$SHA" != "$LAST_SHA" ]; then
  SHOULD_ALERT="true"
  REASON="NEW_CODE_COMMIT"
fi

# Export env for next steps (telegram_send.sh)
{
  echo "SHOULD_ALERT=$SHOULD_ALERT"
  echo "REASON=$REASON"

  # Release context
  echo "CUR_TAG=$TAG"
  echo "CUR_REL_NAME=$REL_NAME"
  echo "CUR_PUBLISHED=$PUBLISHED"
  echo "CUR_REL_URL=$REL_URL_HTML"
  echo "CUR_HIGHLIGHTS=$HIGHLIGHTS"

  # Commit context
  echo "CUR_SHA=$SHA"
  echo "CUR_COMMIT_MSG=$COMMIT_MSG"
  echo "CUR_COMMIT_DATE=$COMMIT_DATE"
  echo "CUR_COMMIT_AUTHOR=$COMMIT_AUTHOR"
  echo "CUR_COMMIT_URL=$COMMIT_URL_HTML"

  # Changed files/folders
  echo "CUR_FILE_COUNT=$FILE_COUNT"
  echo "CUR_FILE_LIST=$FILE_LIST"
  echo "CUR_FOLDER_LIST=$FOLDER_LIST"
} >> "$GITHUB_ENV"

# Update state file (keep state current)
echo "LAST_TAG=$TAG" > last_state.env
echo "LAST_SHA=$SHA" >> last_state.env

echo "Last: tag=$LAST_TAG sha=$LAST_SHA"
echo "Now : tag=$TAG sha=$SHA"
echo "Alert? $SHOULD_ALERT ($REASON)"
echo "Changed files: $FILE_COUNT"
