#!/usr/bin/env bash
set -e

APP_NAME="MarkdownViewer"
REPO="AnsCodeLab/MarkdownViewer"
INSTALL_DIR="$HOME/.local/share/markdownviewer"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[x]${NC} $1"; exit 1; }

if [[ "$(uname)" != "Linux" ]]; then
  error "This installer is for Linux only."
fi

# Find the AppImage — accept a path argument or auto-download latest release
APPIMAGE_PATH="$1"

if [[ -z "$APPIMAGE_PATH" ]]; then
  info "Fetching latest release from GitHub..."
  if command -v curl &>/dev/null; then
    DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
      | grep -o '"browser_download_url": *"[^"]*AppImage[^"]*"' \
      | grep -o 'https://[^"]*' | head -1)
  elif command -v wget &>/dev/null; then
    DOWNLOAD_URL=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" \
      | grep -o '"browser_download_url": *"[^"]*AppImage[^"]*"' \
      | grep -o 'https://[^"]*' | head -1)
  else
    error "curl or wget is required to download the AppImage."
  fi

  [[ -z "$DOWNLOAD_URL" ]] && error "Could not find AppImage in the latest release."

  APPIMAGE_PATH="/tmp/${APP_NAME}.AppImage"
  info "Downloading $DOWNLOAD_URL..."
  if command -v curl &>/dev/null; then
    curl -fL --progress-bar -o "$APPIMAGE_PATH" "$DOWNLOAD_URL"
  else
    wget -q --show-progress -O "$APPIMAGE_PATH" "$DOWNLOAD_URL"
  fi
  chmod +x "$APPIMAGE_PATH"
  DOWNLOADED=1
fi

[[ ! -f "$APPIMAGE_PATH" ]] && error "AppImage not found: $APPIMAGE_PATH"
chmod +x "$APPIMAGE_PATH"

# Extract AppImage (avoids libfuse.so.2 dependency)
info "Extracting AppImage..."
EXTRACT_TMP=$(mktemp -d)
cd "$EXTRACT_TMP"
"$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1
[[ ! -d "$EXTRACT_TMP/squashfs-root" ]] && error "Extraction failed."

# Install
info "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mv "$EXTRACT_TMP/squashfs-root" "$INSTALL_DIR"
cd "$HOME"
rmdir "$EXTRACT_TMP" 2>/dev/null || true

# Wrapper script so the binary is on PATH
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/markdownviewer" <<EOF
#!/usr/bin/env bash
exec "$INSTALL_DIR/markdownviewer" --no-sandbox "\$@"
EOF
chmod +x "$BIN_DIR/markdownviewer"

# Icon
mkdir -p "$ICON_DIR"
ICON_SRC="$INSTALL_DIR/usr/share/icons/hicolor/512x512/apps/markdownviewer.png"
[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$ICON_DIR/markdownviewer.png"

# Desktop entry
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/markdownviewer.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MarkdownViewer
Comment=A fast, lightweight Markdown viewer
Exec=$BIN_DIR/markdownviewer %f
Icon=markdownviewer
MimeType=text/markdown;text/x-markdown;
Categories=Utility;
StartupNotify=true
EOF

# MIME associations
if command -v xdg-mime &>/dev/null; then
  xdg-mime default markdownviewer.desktop text/markdown
  xdg-mime default markdownviewer.desktop text/x-markdown
fi

# Refresh caches
command -v update-desktop-database &>/dev/null && update-desktop-database "$DESKTOP_DIR"
command -v gtk-update-icon-cache   &>/dev/null && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true

# Restart Nemo if running
if pgrep -x nemo &>/dev/null; then
  info "Restarting Nemo..."
  nemo -q 2>/dev/null || true
fi

# Cleanup downloaded AppImage
[[ "${DOWNLOADED:-0}" == "1" ]] && rm -f "$APPIMAGE_PATH"

info "Done! $APP_NAME installed."
info "  Run:       markdownviewer [file.md]"
info "  Uninstall: $0 --uninstall"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  warn "$BIN_DIR is not in your PATH. Add it to ~/.bashrc or ~/.zshrc:"
  warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
