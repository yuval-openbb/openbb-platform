#!/usr/bin/env bash
# launchd.sh install|uninstall|status — start the platform at login and keep it up.
#
# macOS privacy (TCC) blocks launchd jobs from ~/Documents, and granting /bin/bash Full Disk Access is
# far too broad. Instead a tiny local applet, ~/Applications/OpenBB Platform Agent.app, runs ops/agent.sh;
# launchd only does `open -g` on it, so the one-time "access Documents" grant applies to that applet alone.
#   com.yuval-openbb.agent: at login + every 15 min -> ops/agent.sh (run.sh up; backup if newest > 20h old)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LA="$HOME/Library/LaunchAgents"; DOM="gui/$(id -u)"; LABEL=com.yuval-openbb.agent
APP="$HOME/Applications/OpenBB Platform Agent.app"; LOG="$ROOT/.run/agent.log"

case "${1:-status}" in
  install)
    mkdir -p "$LA" "$ROOT/.run" "$HOME/Applications"
    rm -rf "$APP"
    osacompile -o "$APP" -e "do shell script \"/bin/bash \" & quoted form of \"$ROOT/ops/agent.sh\" & \" >> \" & quoted form of \"$LOG\" & \" 2>&1\""
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"         # no Dock icon
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $LABEL" "$APP/Contents/Info.plist"
    codesign --force --sign - "$APP" 2>/dev/null
    cat >"$LA/$LABEL.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-g</string><string>-j</string><string>$APP</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>900</integer>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
EOF
    plutil -lint -s "$LA/$LABEL.plist"
    launchctl bootout "$DOM/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOM" "$LA/$LABEL.plist"
    echo "installed. First run: macOS asks to let 'OpenBB Platform Agent' access Documents; click Allow. Log: .run/agent.log" ;;
  uninstall)
    launchctl bootout "$DOM/$LABEL" 2>/dev/null || true
    rm -f "$LA/$LABEL.plist"; rm -rf "$APP"
    echo "uninstalled (services keep running; stop them with make down)" ;;
  status)
    if launchctl print "$DOM/$LABEL" >/dev/null 2>&1; then echo "  $LABEL loaded"; else echo "  $LABEL not loaded"; fi
    if [ -f "$LOG" ]; then
      echo "  last runs:"; grep -- '^--- ' "$LOG" | tail -3 | sed 's/^/    /'
      tail -n 5 "$LOG" | grep -i -E "error|not permitted|FAILED" | sed 's/^/    ! /' || true
    else echo "  no runs logged yet"; fi ;;
  *) echo "usage: $0 install|uninstall|status"; exit 1 ;;
esac
