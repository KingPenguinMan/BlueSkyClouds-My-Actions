#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${TG_BOT_TOKEN:-}" && -z "${TG_USER_ID:-}" ]]; then exit 0; fi
: "${TG_BOT_TOKEN:?Missing TG_BOT_TOKEN}" "${TG_USER_ID:?Missing TG_USER_ID}"
log="$RUNNER_TEMP/task-result"
result="未能确认签到，请查看运行记录。"
if [[ "$TASK_STATUS" != success ]]; then
  result="工作流执行失败，请查看运行记录。"
elif [[ -f "$log" ]]; then
  if [[ "$1" == tieba ]]; then
    counts=$(grep -oE '共签: [0-9]+/[0-9]+, 本次成功: [0-9]+, 本次失败: [0-9]+' "$log" | tail -1 || true)
    zhidao=$(grep -oE '百度知道: (成功|重复|失败)' "$log" | tail -1 || true)
    if [[ -n "$counts" ]]; then result="$counts"$'\n'"$zhidao"; fi
    if grep -q '获取清单失败' "$log"; then result="获取贴吧清单失败，请检查登录状态。"; fi
    if grep -q '未填写百度Cookie' "$log"; then result="未配置百度 Cookie，已跳过。"; fi
  else
    if grep -q '^打卡成功' "$log"; then result="今日打卡成功。"
    elif grep -q '^重复签到' "$log"; then result="今天已经打卡。"
    elif grep -q '未填写哔咔账号密码' "$log"; then result="未配置哔咔账号或密码，已跳过。"; fi
  fi
fi
link="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
text=$(printf '%s · %s\n%s\n%s' "$GITHUB_WORKFLOW" "$(TZ=Asia/Shanghai date '+%m-%d %H:%M')" "$result" "$link")
curl --silent --fail --max-time 20 --data-urlencode "chat_id=$TG_USER_ID" \
  --data-urlencode "text=$text" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" | jq -e '.ok == true' >/dev/null
