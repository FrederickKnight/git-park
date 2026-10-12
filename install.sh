#!/bin/sh
# Instala (o actualiza) git-park, git-memo, git-up, git-twin y git-kit.
#
#   ./install.sh                copia los scripts, agrega los alias park, memo y kit
#                               y, si hace falta, la carpeta al PATH (en .zshrc o .bashrc)
#   ./install.sh --no-aliases   lo mismo sin los alias
#
# Sin clonar el repo (descarga los scripts de GitHub):
#   curl -fsSL https://raw.githubusercontent.com/FrederickKnight/git-park/main/install.sh | sh
#
# Carpeta destino: $PARK_BIN si esta definida; si no, ~/bin en Git Bash (Windows)
# y ~/.local/bin en macOS y Linux. $PARK_REF elige la rama o tag a descargar (main).

# todo dentro de main: si la descarga por pipe se corta a medias, no se ejecuta nada
main() {
  set -e
  tools="git-park git-memo git-up git-twin git-kit"
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) def="$HOME/bin" ;; *) def="$HOME/.local/bin" ;; esac
  dest=${PARK_BIN:-$def}

  # con bin/ al lado (repo clonado) se copia de ahi; si no, se descarga
  src=$(cd "$(dirname "$0")" 2>/dev/null && pwd)/bin
  if [ ! -f "$src/git-park" ]; then
    url="https://raw.githubusercontent.com/FrederickKnight/git-park/${PARK_REF:-main}/bin"
    src=$(mktemp -d)
    trap 'rm -rf "$src"' EXIT
    for f in $tools; do
      if command -v curl >/dev/null 2>&1; then curl -fsSL "$url/$f" -o "$src/$f" || fail "$f"
      elif command -v wget >/dev/null 2>&1; then wget -qO "$src/$f" "$url/$f" || fail "$f"
      else echo "hace falta curl o wget para descargar"; exit 1; fi
      # se descarga todo antes de instalar nada, y cada archivo debe ser un script
      [ "$(head -c 9 "$src/$f")" = '#!/bin/sh' ] || fail "$f"
    done
  fi

  mkdir -p "$dest"
  for f in $tools; do
    cp "$src/$f" "$dest/$f"
    chmod +x "$dest/$f"
    echo "instalado: $dest/$f"
  done

  v=$(git --version 2>/dev/null | cut -d' ' -f3)
  case "$v" in
    "") echo; echo "OJO: no encontre git en el PATH" ;;
    1.*|2.[0-9].*|2.[0-2][0-9].*|2.3[0-7].*)
      echo; echo "OJO: tienes git $v; park y twin necesitan 2.38 o mayor" ;;
  esac

  # el PATH y los alias van al archivo de inicio de tu shell, salvo con --no-aliases
  case "${SHELL##*/}" in zsh) rc="$HOME/.zshrc" ;; *) rc="$HOME/.bashrc" ;; esac
  changed=
  case ":$PATH:" in
    *":$dest:"*) ;;
    *)
      # con $HOME en la linea, para que siga valiendo si cambia la ruta del home
      line="export PATH=\"$dest:\$PATH\""
      case "$dest" in "$HOME"/*) line="export PATH=\"\$HOME/${dest#"$HOME"/}:\$PATH\"" ;; esac
      if [ -f "$rc" ] && grep -qF -e "$line" "$rc"; then :
      else printf '\n# git-park\n%s\n' "$line" >> "$rc"; echo "PATH: $dest agregado a $rc"; changed=1; fi ;;
  esac

  if [ "$1" != --no-aliases ]; then
    touch "$rc"
    for a in park memo kit; do
      if grep -q "^alias $a=" "$rc"; then echo "alias $a: ya estaba en $rc"
      else echo "alias $a='git $a'" >> "$rc"; echo "alias $a: agregado a $rc"; changed=1; fi
    done
  fi

  echo
  if [ -n "$changed" ]; then echo "listo. Abre una terminal nueva (o: . $rc) y prueba: git park help"
  else echo "listo. Prueba: git park help"; fi
}

fail() { echo "no se pudo descargar $1 (revisa la conexion o PARK_REF)"; exit 1; }

main "$@"
