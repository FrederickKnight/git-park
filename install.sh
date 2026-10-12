#!/bin/sh
# Instala (o actualiza) git-park, git-memo, git-up, git-twin y git-kit.
#
#   ./install.sh             copia los scripts a la carpeta de binarios
#   ./install.sh --aliases   ademas agrega los alias park, memo y kit a tu shell
#
# Carpeta destino: $PARK_BIN si esta definida; si no, ~/bin en Git Bash (Windows)
# y ~/.local/bin en macOS y Linux.
set -e
src=$(cd "$(dirname "$0")" && pwd)/bin
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) def="$HOME/bin" ;; *) def="$HOME/.local/bin" ;; esac
dest=${PARK_BIN:-$def}
mkdir -p "$dest"
for f in git-park git-memo git-up git-twin git-kit; do
  cp "$src/$f" "$dest/$f"
  chmod +x "$dest/$f"
  echo "instalado: $dest/$f"
done

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo
     echo "OJO: $dest no esta en tu PATH. Agregalo (y abre una terminal nueva):"
     echo "  export PATH=\"$dest:\$PATH\"" ;;
esac

if [ "$1" = --aliases ]; then
  case "${SHELL##*/}" in zsh) rc="$HOME/.zshrc" ;; *) rc="$HOME/.bashrc" ;; esac
  touch "$rc"
  for a in park memo kit; do
    if grep -q "^alias $a=" "$rc"; then echo "alias $a: ya estaba en $rc"
    else echo "alias $a='git $a'" >> "$rc"; echo "alias $a: agregado a $rc"; fi
  done
  echo "abre una terminal nueva para usarlos"
fi
