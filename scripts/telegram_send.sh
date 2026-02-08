#!/usr/bin/env bash
set -euo pipefail

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "Missing TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID"
  exit 1
fi

# Encode newline for URL form (Telegram needs URL-encoded newlines if using -d text=...).
# We'll build message using %0A.
reason="${REASON:-UPDATE}"
tag="${CUR_TAG:-}"
rel_name="${CUR_REL_NAME:-}"
published="${CUR_PUBLISHED:-}"
rel_url="${CUR_REL_URL:-}"

sha="${CUR_SHA:-}"
commit_msg="${CUR_COMMIT_MSG:-}"
commit_date="${CUR_COMMIT_DATE:-}"
commit_url="${CUR_COMMIT_URL:-}"

author="${CUR_COMMIT_AUTHOR:-}"
file_count="${CUR_FILE_COUNT:-0}"
file_list="${CUR_FILE_LIST:-}"
folder_list="${CUR_FOLDER_LIST:-}"

# Convert '|' separators into %0A bullet lines
files_block="• (no file list)"
if [ -n "$file_list" ]; then
  files_block=$(printf "%s" "$file_list" \
    | tr '|' '\n' \
    | sed '/^$/d' \
    | head -n 15 \
    | sed 's/^/• /' \
    | sed 's/$/%0A/' \
    | tr -d '\n')
fi

folders_block="• (no folder list)"
if [ -n "$folder_list" ]; then
  folders_block=$(printf "%s" "$folder_list" \
    | tr '|' '\n' \
    | sed '/^$/d' \
    | head -n 10 \
    | sed 's/^/• /' \
    | sed 's/$/%0A/' \
    | tr -d '\n')
fi

# Highlights contains \n escaped already; convert to %0A
hl="${CUR_HIGHLIGHTS:-• (no highlight)\\n}"
hl_encoded=$(printf "%s" "$hl" | sed 's/\\n/%0A/g')

title=""
if [ "$reason" = "NEW_RELEASE" ]; then
  title="🚀 <b>Magisk NEW RELEASE</b>"
elif [ "$reason" = "NEW_CODE_COMMIT" ]; then
  title="🛠️ <b>Magisk CODE UPDATE (no new release)</b>"
else
  title="🔔 <b>Magisk Update</b>"
fi

msg="${title}%0A"
msg="${msg}<b>Release:</b> ${rel_name}%0A"
msg="${msg}<b>Version/Tag:</b> ${tag}%0A"
msg="${msg}<b>Release Date:</b> ${published}%0A"
msg="${msg}<b>Release Link:</b> ${rel_url}%0A%0A"

msg="${msg}<b>Latest Commit:</b> ${sha}%0A"
msg="${msg}<b>Commit Author:</b> ${author}%0A"
msg="${msg}<b>Changed Folders (top-level):</b>%0A${folders_block}%0A"
msg="${msg}<b>Changed Files (top 15 / total ${file_count}):</b>%0A${files_block}%0A"
msg="${msg}<b>Commit Date:</b> ${commit_date}%0A"
msg="${msg}<b>Commit Msg:</b> ${commit_msg}%0A"
msg="${msg}<b>Commit Link:</b> ${commit_url}%0A%0A"

msg="${msg}<b>Highlights (keywords):</b>%0A${hl_encoded}"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "text=${msg}" \
  -d "parse_mode=HTML" \
  -d "disable_web_page_preview=true"