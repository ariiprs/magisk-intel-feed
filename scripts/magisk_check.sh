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

# 1) Latest release info
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

# 2) Latest commit SHA on branch
COMMIT_URL="https://api.github.com/repos/${OWNER}/${REPO}/commits/${BRANCH}"
curl -s "$COMMIT_URL" > latest_commit.json

SHA="$(jq -r '.sha // ""' latest_commit.json)"
COMMIT_MSG="$(jq -r '.commit.message // ""' latest_commit.json | head -n 1)"
COMMIT_DATE="$(jq -r '.commit.committer.date // ""' latest_commit.json)"
COMMIT_URL_HTML="$(jq -r '.html_url // ""' latest_commit.json)"

if [ -z "$TAG" ] || [ -z "$SHA" ]; then
  echo "Failed to fetch release tag or commit sha."
  exit 1
fi

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

# Export env for next steps
{
  echo "SHOULD_ALERT=$SHOULD_ALERT"
  echo "REASON=$REASON"

  echo "CUR_TAG=$TAG"
  echo "CUR_REL_NAME=$REL_NAME"
  echo "CUR_PUBLISHED=$PUBLISHED"
  echo "CUR_REL_URL=$REL_URL_HTML"

  echo "CUR_SHA=$SHA"
  echo "CUR_COMMIT_MSG=$COMMIT_MSG"
  echo "CUR_COMMIT_DATE=$COMMIT_DATE"
  echo "CUR_COMMIT_URL=$COMMIT_URL_HTML"

  echo "CUR_HIGHLIGHTS=$HIGHLIGHTS"
} >> "$GITHUB_ENV"

# Update state file (even if no alert, keep state current)
# NOTE: If you prefer only update state when alert sent, move this to after Telegram step.
echo "LAST_TAG=$TAG" > last_state.env
echo "LAST_SHA=$SHA" >> last_state.env

echo "Last: tag=$LAST_TAG sha=$LAST_SHA"
echo "Now : tag=$TAG sha=$SHA"
echo "Alert? $SHOULD_ALERT ($REASON)"