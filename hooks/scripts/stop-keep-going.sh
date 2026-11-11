#!/bin/bash
# Stop hook: when the agent ends a turn by asking permission or offering a next step,
# send it back to work once. ⏸ (a person has to act) and ⏳ (a job is still running) are legitimate stops and pass.

set -uo pipefail
export LC_ALL=en_US.UTF-8

INPUT=$(cat)

# Already continuing because a Stop hook blocked: let it stop so we never loop.
[[ "$(jq -r '.stop_hook_active // false' <<<"$INPUT" 2>/dev/null)" == "true" ]] && exit 0

TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null)
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

LAST=$(tail -n 400 "$TRANSCRIPT" | jq -rs '
  [.[] | select(.type == "assistant.message") | .data.content
       | select(type == "string" and length > 0)] | last // empty' 2>/dev/null)
[[ -n "$LAST" ]] || exit 0

if (( ${#LAST} > 300 )); then TAIL=${LAST: -300}; else TAIL=$LAST; fi

[[ "$TAIL" == *"⏸"* || "$TAIL" == *"⏳"* ]] && exit 0
grep -qiE 'password|passphrase|密码|登录|log ?in to|sign in|2FA|MFA|OTP|验证码' <<<"$TAIL" && exit 0

# 要不要 alone usually means "whether" (我来看要不要申请); it's only a question with 我 or a ？ before the sentence ends.
OFFER='want me to|should i [a-z]|shall i [a-z]|would you like (me )?to|do you want me to|let me know if you|say the word|(要|需要)我[^。！!]{0,24}[吗？?]|要不要我|要不要[^。！!；;]{0,40}[？?]|要的话|的话说一声|告诉我一声|是否(需要|要|继续)|可以吗|行吗|好吗|继续吗'
QUESTION_END='[?？][[:space:]*)）]*$'
LAST_LINE=$(grep -v '^[[:space:]]*$' <<<"$TAIL" | tail -n 1)

if grep -qiE "$OFFER" <<<"$TAIL" || [[ "$LAST_LINE" =~ $QUESTION_END ]]; then
  REASON="You ended by asking the user a question or offering a next step. Standing rule: don't ask. Technical choices are yours: pick what a FAANG+ senior engineer would and say why in one line. If the next step is part of the original request and reversible (that includes commit + push and env-branch merges), do it now and keep going. If it is extra, don't do it: finish with a plain statement that lists it as not done, with no question. Only stop for a message that goes to another person (including asking a PO or colleague to decide), a destructive or irreversible action, or a step only the user can do (a secret, a login, paying or the final submit; the clicks before it are yours), and start that line with ⏸. The user already read your answer, so don't repeat it: write only what changed (the work you just did, or the ⏸ line)."
  jq -n --arg r "$REASON" '{hookSpecificOutput: {hookEventName: "Stop", decision: "block", reason: $r}}'
fi
exit 0
