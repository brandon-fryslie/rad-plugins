# Re-sign a macOS .app bundle after patching inner binaries.
# Usage:
#   rad-mac-codesign-app "/path/to/Your.app"            # ad-hoc (IDENT="-")
#   rad-mac-codesign-app "/path/to/Your.app" "Developer ID Application: Your Name (TEAMID)" [/path/to/entitlements.plist]
#
# Notes:
#   - Uses codesign --deep to recursively sign all nested components
#   - If a real identity is provided and no entitlements path is given, entitlements are extracted from the app
#   - Uses hardened runtime + timestamp only when using a real signing identity

rad-mac-codesign-app() {
  emulate -L zsh -o PIPE_FAIL

  local APP="${1:-}"
  local IDENT="${2:-"-"}"
  local ENT_IN="${3:-""}"
  local ENT=""                           # resolved entitlements file (may be empty)
  local -a sign_opts verify_cmd

  # ANSI codes
  local HIDE_CURSOR=$'\e[?25l'
  local SHOW_CURSOR=$'\e[?25h'
  local CLEAR_LINE=$'\e[2K'
  local SAVE_POS=$'\e[s'
  local RESTORE_POS=$'\e[u'

  # Move cursor up N lines
  move_up() {
    printf '\e[%dA' "$1"
  }

  # Generate swirling rainbow text with offset
  rainbow_text() {
    local text="$1"
    local offset="${2:-0}"
    local -a rainbow_colors=(196 202 208 214 220 226 190 154 118 82 46 47 48 49 50 51 45 39 33 27 21 57 93 129 165 201 200 199 198 197)
    local output=""
    for (( j=0; j<${#text}; j++ )); do
      local char="${text:$j:1}"
      local color_idx=$(( (j + offset) % ${#rainbow_colors[@]} ))
      output+="$(printf '\e[38;5;%dm%s' "${rainbow_colors[$((color_idx + 1))]}" "$char")"
    done
    echo -n "$output\e[0m"
  }

  # Cycling rainbow border with rotation
  rainbow_border() {
    local char="$1"
    local length="$2"
    local offset="${3:-0}"
    local -a colors=(201 165 129 93 57 21 27 33 39 45 51 87 123 159 195 201)
    local output=""
    for (( i=0; i<length; i++ )); do
      local color_idx=$(( (i + offset) % ${#colors[@]} ))
      output+="$(printf '\e[38;5;%dm%s' "${colors[$((color_idx + 1))]}" "$char")"
    done
    echo -n "$output\e[0m"
  }

  # Gradient with shifting hue
  gradient_text() {
    local text="$1"
    local shift="${2:-0}"
    local output=""
    local len=${#text}
    local -a gradient_colors=(201 165 129 93 57 21 27 33 39 45 51 87 123 159 195 201 165 129 93 57)
    for (( i=0; i<len; i++ )); do
      [[ "${text:$i:1}" == " " ]] && { output+=" "; continue; }
      local color_idx=$(( (i + shift) % ${#gradient_colors[@]} ))
      output+="$(printf '\e[38;5;%dm%s' "${gradient_colors[$((color_idx + 1))]}" "${text:$i:1}")"
    done
    echo -n "$output\e[0m"
  }

  # Pulsing text with phase
  pulse_text() {
    local text="$1"
    local phase="${2:-0}"
    local -a pulse=(201 165 129 93 57 93 129 165)
    local output=""
    local idx=0
    for char in ${(s::)text}; do
      local color="${pulse[$(( (idx + phase) % ${#pulse[@]} + 1 ))]}"
      output+="$(printf '\e[1m\e[38;5;%dm%s' "$color" "$char")"
      ((idx++))
    done
    echo -n "$output\e[0m"
  }

  # Swirling spinner
  spinner_text() {
    local phase="$1"
    local -a frames=('∿' '∼' '≈' '∽' '∾' '∿')
    local -a spin_colors=(201 165 129 93 57 21 27 33 39 45 51)
    local frame="${frames[$(( phase % ${#frames[@]} + 1 ))]}"
    local color="${spin_colors[$(( phase % ${#spin_colors[@]} + 1 ))]}"
    printf '\e[38;5;%dm%s\e[0m' "$color" "$frame"
  }

  if [[ -z "$APP" || ! -d "$APP" || ! -e "$APP/Contents/Info.plist" ]]; then
    print -ru2 -- "$(printf '\e[1m\e[38;5;196m')✗ ERROR: APP must be a valid .app bundle$(printf '\e[0m')"
    return 2
  fi

  command -v codesign >/dev/null || { print -ru2 -- "$(printf '\e[38;5;196m')✗ error: codesign not found$(printf '\e[0m')"; return 2; }
  command -v security >/dev/null || { print -ru2 -- "$(printf '\e[38;5;196m')✗ error: security not found$(printf '\e[0m')"; return 2; }
  command -v spctl >/dev/null || { print -ru2 -- "$(printf '\e[38;5;196m')✗ error: spctl not found$(printf '\e[0m')"; return 2; }

  # Resolve entitlements
  if [[ "$IDENT" != "-" ]]; then
    if [[ -n "$ENT_IN" ]]; then
      [[ -f "$ENT_IN" ]] || { print -ru2 -- "$(printf '\e[38;5;196m')error: entitlements file not found: $ENT_IN$(printf '\e[0m')"; return 2; }
      ENT="$ENT_IN"
    else
      ENT="$(mktemp -t ent.XXXXXXXX.plist)"
      if ! codesign -d --entitlements :- "$APP" >"$ENT" 2>/dev/null; then
        : > "$ENT"
      fi
    fi
  fi

  # Signing options
  if [[ "$IDENT" = "-" ]]; then
    sign_opts=(--deep --force -s -)
  else
    if [[ -s "${ENT:-/dev/null}" ]]; then
      sign_opts=(--deep --force -s "$IDENT" --entitlements "$ENT" --options runtime --timestamp)
    else
      sign_opts=(--deep --force -s "$IDENT" --options runtime --timestamp)
    fi
  fi

  # Remove quarantine attributes recursively before signing
  printf "$HIDE_CURSOR"
  trap "printf '$SHOW_CURSOR'" EXIT INT TERM

  echo ""
  echo "$(rainbow_border "═" 70 0)"
  echo "$(rainbow_border "║" 1 0)  $(rainbow_text "✨ ∿ ∿ ∿  M A C O S   C O D E   S I G N I N G  ∿ ∿ ∿ ✨" 0)  $(rainbow_border "║" 1 0)"
  echo "$(rainbow_border "║" 1 0)  $(pulse_text "♢ ♦ P S Y C H E D E L I C  K A L E I D O S C O P E ♦ ♢" 0)  $(rainbow_border "║" 1 0)"
  echo "$(rainbow_border "═" 70 0)"
  echo ""
  echo "$(gradient_text "🎯 TARGET:" 0)  $(printf '\e[1m\e[38;5;226m')$APP$(printf '\e[0m')"
  echo "$(gradient_text "🔑 IDENTITY:" 0)  $(printf '\e[1m\e[38;5;208m')$IDENT$(printf '\e[0m')"
  echo ""
  echo "$(pulse_text "▶ ▶ ▶" 0)  $(gradient_text "R E M O V I N G   Q U A R A N T I N E   A T T R I B U T E S" 0)  $(spinner_text 0) $(spinner_text 1) $(spinner_text 2)"
  echo ""

  # Animation for quarantine removal
  animate_quarantine() {
    local phase=0
    local line_count=10
    while kill -0 $$ 2>/dev/null; do
      move_up "$line_count"
      printf "${CLEAR_LINE}$(rainbow_border "═" 70 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "║" 1 $phase)  $(rainbow_text "✨ ∿ ∿ ∿  M A C O S   C O D E   S I G N I N G  ∿ ∿ ∿ ✨" $phase)  $(rainbow_border "║" 1 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "║" 1 $phase)  $(pulse_text "♢ ♦ P S Y C H E D E L I C  K A L E I D O S C O P E ♦ ♢" $phase)  $(rainbow_border "║" 1 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "═" 70 $phase)\n"
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(gradient_text "🎯 TARGET:" $phase)  $(printf '\e[1m\e[38;5;226m')$APP$(printf '\e[0m')\n"
      printf "${CLEAR_LINE}$(gradient_text "🔑 IDENTITY:" $phase)  $(printf '\e[1m\e[38;5;208m')$IDENT$(printf '\e[0m')\n"
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(pulse_text "▶ ▶ ▶" $phase)  $(gradient_text "R E M O V I N G   Q U A R A N T I N E   A T T R I B U T E S" $phase)  $(spinner_text $phase) $(spinner_text $((phase+1))) $(spinner_text $((phase+2)))\n"
      printf "${CLEAR_LINE}\n"
      ((phase++))
      sleep 0.05
    done
  }

  animate_quarantine &
  local anim_pid=$!

  # Recursively remove quarantine attributes
  xattr -rd com.apple.quarantine "$APP" 2>/dev/null || true

  kill $anim_pid 2>/dev/null
  wait $anim_pid 2>/dev/null

  # Redraw with completion
  move_up 10
  printf "${CLEAR_LINE}$(rainbow_border "═" 70 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "║" 1 0)  $(rainbow_text "✨ ∿ ∿ ∿  M A C O S   C O D E   S I G N I N G  ∿ ∿ ∿ ✨" 0)  $(rainbow_border "║" 1 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "║" 1 0)  $(pulse_text "♢ ♦ P S Y C H E D E L I C  K A L E I D O S C O P E ♦ ♢" 0)  $(rainbow_border "║" 1 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "═" 70 0)\n"
  printf "${CLEAR_LINE}\n"
  printf "${CLEAR_LINE}$(gradient_text "🎯 TARGET:" 0)  $(printf '\e[1m\e[38;5;226m')$APP$(printf '\e[0m')\n"
  printf "${CLEAR_LINE}$(gradient_text "🔑 IDENTITY:" 0)  $(printf '\e[1m\e[38;5;208m')$IDENT$(printf '\e[0m')\n"
  printf "${CLEAR_LINE}\n"
  printf "${CLEAR_LINE}$(rainbow_text "✓ ✓ ✓  Q U A R A N T I N E   A T T R I B U T E S   R E M O V E D  ✓ ✓ ✓" 0)\n"
  printf "${CLEAR_LINE}\n"

  # Setup for signing phase
  echo ""
  echo "$(pulse_text "▶ ▶ ▶" 0)  $(gradient_text "I N I T I A T I N G   D E E P   S I G N A T U R E" 0)  $(spinner_text 0) $(spinner_text 1) $(spinner_text 2)"
  echo ""

  # Animation function for updating display
  animate_signing() {
    local phase=0
    local line_count=10  # Number of lines in our display

    while kill -0 $$ 2>/dev/null; do
      # Move cursor up to redraw
      move_up "$line_count"

      # Redraw header with swirling colors
      printf "${CLEAR_LINE}$(rainbow_border "═" 70 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "║" 1 $phase)  $(rainbow_text "✨ ∿ ∿ ∿  M A C O S   C O D E   S I G N I N G  ∿ ∿ ∿ ✨" $phase)  $(rainbow_border "║" 1 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "║" 1 $phase)  $(pulse_text "♢ ♦ P S Y C H E D E L I C  K A L E I D O S C O P E ♦ ♢" $phase)  $(rainbow_border "║" 1 $phase)\n"
      printf "${CLEAR_LINE}$(rainbow_border "═" 70 $phase)\n"
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(gradient_text "🎯 TARGET:" $phase)  $(printf '\e[1m\e[38;5;226m')$APP$(printf '\e[0m')\n"
      printf "${CLEAR_LINE}$(gradient_text "🔑 IDENTITY:" $phase)  $(printf '\e[1m\e[38;5;208m')$IDENT$(printf '\e[0m')\n"
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(pulse_text "▶ ▶ ▶" $phase)  $(gradient_text "I N I T I A T I N G   D E E P   S I G N A T U R E" $phase)  $(spinner_text $phase) $(spinner_text $((phase+1))) $(spinner_text $((phase+2)))\n"
      printf "${CLEAR_LINE}\n"

      ((phase++))
      sleep 0.05
    done
  }

  # Start background animation
  animate_signing &
  local anim_pid=$!

  # Perform the actual signing
  local sign_output
  local sign_status
  sign_output=$(codesign "${sign_opts[@]}" "$APP" 2>&1)
  sign_status=$?

  # Kill animation
  kill $anim_pid 2>/dev/null
  wait $anim_pid 2>/dev/null

  # Redraw one final time with success state
  move_up 10
  printf "${CLEAR_LINE}$(rainbow_border "═" 70 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "║" 1 0)  $(rainbow_text "✨ ∿ ∿ ∿  M A C O S   C O D E   S I G N I N G  ∿ ∿ ∿ ✨" 0)  $(rainbow_border "║" 1 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "║" 1 0)  $(pulse_text "♢ ♦ P S Y C H E D E L I C  K A L E I D O S C O P E ♦ ♢" 0)  $(rainbow_border "║" 1 0)\n"
  printf "${CLEAR_LINE}$(rainbow_border "═" 70 0)\n"
  printf "${CLEAR_LINE}\n"
  printf "${CLEAR_LINE}$(gradient_text "🎯 TARGET:" 0)  $(printf '\e[1m\e[38;5;226m')$APP$(printf '\e[0m')\n"
  printf "${CLEAR_LINE}$(gradient_text "🔑 IDENTITY:" 0)  $(printf '\e[1m\e[38;5;208m')$IDENT$(printf '\e[0m')\n"
  printf "${CLEAR_LINE}\n"

  if [[ $sign_status -eq 0 ]]; then
    printf "${CLEAR_LINE}$(rainbow_text "✓ ✓ ✓  S I G N I N G   C O M P L E T E D   S U C C E S S F U L L Y !  ✓ ✓ ✓" 0)\n"
  else
    printf "${CLEAR_LINE}$(printf '\e[1m\e[38;5;196m')✗ ✗ ✗  S I G N I N G   F A I L E D  ✗ ✗ ✗$(printf '\e[0m')\n"
    printf "$SHOW_CURSOR"
    return 1
  fi
  printf "${CLEAR_LINE}\n"

  # Animate verification
  echo ""
  echo "$(pulse_text "▶ ▶ ▶" 0)  $(gradient_text "V E R I F Y I N G   S I G N A T U R E" 0)  $(spinner_text 0) $(spinner_text 1) $(spinner_text 2)"
  echo ""

  animate_verify() {
    local phase=0
    while kill -0 $$ 2>/dev/null; do
      move_up 3
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(pulse_text "▶ ▶ ▶" $phase)  $(gradient_text "V E R I F Y I N G   S I G N A T U R E" $phase)  $(spinner_text $phase) $(spinner_text $((phase+1))) $(spinner_text $((phase+2)))\n"
      printf "${CLEAR_LINE}\n"
      ((phase++))
      sleep 0.05
    done
  }

  animate_verify &
  anim_pid=$!

  verify_cmd=(codesign --verify --deep --strict --verbose=2 "$APP")
  local verify_output
  local verify_status
  verify_output=$("${verify_cmd[@]}" 2>&1)
  verify_status=$?

  kill $anim_pid 2>/dev/null
  wait $anim_pid 2>/dev/null

  move_up 3
  printf "${CLEAR_LINE}\n"
  if [[ $verify_status -eq 0 ]]; then
    printf "${CLEAR_LINE}$(rainbow_text "✓ ✓ ✓  S I G N A T U R E   V E R I F I E D :   V A L I D  ✓ ✓ ✓" 0)\n"
  else
    printf "${CLEAR_LINE}$(printf '\e[1m\e[38;5;196m')✗ ✗ ✗  V E R I F I C A T I O N   F A I L E D  ✗ ✗ ✗$(printf '\e[0m')\n"
    printf "$SHOW_CURSOR"
    return 1
  fi
  printf "${CLEAR_LINE}\n"

  # Gatekeeper check
  if command -v spctl >/dev/null; then
    echo ""
    echo "$(pulse_text "▶ ▶ ▶" 0)  $(gradient_text "G A T E K E E P E R   C H E C K" 0)  $(spinner_text 0) $(spinner_text 1) $(spinner_text 2)"
    echo ""

    animate_gate() {
      local phase=0
      while kill -0 $$ 2>/dev/null; do
        move_up 3
        printf "${CLEAR_LINE}\n"
        printf "${CLEAR_LINE}$(pulse_text "▶ ▶ ▶" $phase)  $(gradient_text "G A T E K E E P E R   C H E C K" $phase)  $(spinner_text $phase) $(spinner_text $((phase+1))) $(spinner_text $((phase+2)))\n"
        printf "${CLEAR_LINE}\n"
        ((phase++))
        sleep 0.05
      done
    }

    animate_gate &
    anim_pid=$!

    local gate_output
    local gate_status
    gate_output=$(spctl --assess --type execute --verbose=2 "$APP" 2>&1)
    gate_status=$?

    kill $anim_pid 2>/dev/null
    wait $anim_pid 2>/dev/null

    move_up 3
    printf "${CLEAR_LINE}\n"
    if [[ $gate_status -eq 0 ]]; then
      printf "${CLEAR_LINE}$(rainbow_text "✓ ✓ ✓  G A T E K E E P E R :   A P P R O V E D  ✓ ✓ ✓" 0)\n"
    else
      printf "${CLEAR_LINE}$(gradient_text "⚠ ⚠ ⚠  G A T E K E E P E R :   B Y P A S S E D  ( a d - h o c )  ⚠ ⚠ ⚠" 0)\n"
    fi
    printf "${CLEAR_LINE}\n"
  fi

  # Remove quarantine attributes
  echo ""
  echo "$(pulse_text "▶ ▶ ▶" 0)  $(gradient_text "R E M O V I N G   Q U A R A N T I N E   A T T R I B U T E S" 0)  $(spinner_text 0) $(spinner_text 1) $(spinner_text 2)"
  echo ""

  animate_quarantine() {
    local phase=0
    while kill -0 $$ 2>/dev/null; do
      move_up 3
      printf "${CLEAR_LINE}\n"
      printf "${CLEAR_LINE}$(pulse_text "▶ ▶ ▶" $phase)  $(gradient_text "R E M O V I N G   Q U A R A N T I N E   A T T R I B U T E S" $phase)  $(spinner_text $phase) $(spinner_text $((phase+1))) $(spinner_text $((phase+2)))\n"
      printf "${CLEAR_LINE}\n"
      ((phase++))
      sleep 0.05
    done
  }

  animate_quarantine &
  anim_pid=$!

  # Remove quarantine recursively from the app
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  xattr -dr com.apple.provenance "$APP" 2>/dev/null || true

  kill $anim_pid 2>/dev/null
  wait $anim_pid 2>/dev/null

  move_up 3
  printf "${CLEAR_LINE}\n"
  printf "${CLEAR_LINE}$(rainbow_text "✓ ✓ ✓  Q U A R A N T I N E   R E M O V E D  ✓ ✓ ✓" 0)\n"
  printf "${CLEAR_LINE}\n"

  # Cleanup
  if [[ -n "${ENT:-}" && "$ENT" != "$ENT_IN" ]]; then
    rm -f "$ENT" || true
  fi

  # Final swirling celebration
  echo ""
  echo "$(rainbow_border "═" 70 0)"
  echo "$(rainbow_border "║" 1 0)  $(rainbow_text "🎉 ✨ ∿  C O D E   S I G N I N G   C O M P L E T E !  ∿ ✨ 🎉" 0)  $(rainbow_border "║" 1 0)"
  echo "$(rainbow_border "║" 1 0)  $(pulse_text "♢ ♦ ♢  S T A Y   G R O O V Y ,   S T A Y   S I G N E D  ♢ ♦ ♢" 0)  $(rainbow_border "║" 1 0)"
  echo "$(rainbow_border "═" 70 0)"
  echo ""

  printf "$SHOW_CURSOR"
}

# Unset the function if not on macOS
[[ "$OSTYPE" != darwin* ]] && unfunction rad-codesign-app 2>/dev/null || true
