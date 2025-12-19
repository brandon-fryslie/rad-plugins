
alias clod="SHELL=bash claude --dangerously-skip-permissions"
alias zlod="ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic API_TIMEOUT_MS=3000000 ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-MUST_SET_ANTHROPIC_TOKEN} clod"
