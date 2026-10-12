# git-park

Herramientas pequeñas para el dia a dia con git. Son scripts `sh` sin dependencias:
corren igual en macOS, Linux y Windows (Git Bash o PowerShell). Requieren git 2.38 o mayor.

| comando | para que |
|---|---|
| `git park` | lista de ramas estacionadas, pendientes de entrar a la rama base |
| `git memo` | notas cortas ligadas a la rama donde se escribieron, o globales |
| `git up` | actualiza ramas locales desde el remoto sin cambiar de rama |
| `git twin` | chequeo previo a los PRs: simula el merge contra cada rama destino |
| `git kit` | atajos de ramas y stash |

## Instalacion

Necesitas git 2.38 o mayor (`git --version`).

### macOS

Con [Homebrew](https://brew.sh) (recomendado):

```bash
brew install frederickknight/tap/git-park
```

Se actualiza con `brew upgrade`. Para los alias cortos `park`, `memo` y `kit`, agrega
a tu `~/.zshrc`:

```bash
alias park='git park' memo='git memo' kit='git kit'
```

Sin Homebrew, en una linea (instala en `~/.local/bin` y agrega los alias y el PATH a
tu `~/.zshrc`):

```bash
curl -fsSL https://raw.githubusercontent.com/FrederickKnight/git-park/main/install.sh | sh
```

### Linux

Igual que en macOS: `brew install frederickknight/tap/git-park` si usas Homebrew, o la
linea de `curl` (escribe en `~/.bashrc`, o en `~/.zshrc` si tu shell es zsh).

### Windows

Necesitas [Git for Windows](https://git-scm.com/download/win), que trae Git Bash.

**1.** Abre **Git Bash** y corre:

```bash
curl -fsSL https://raw.githubusercontent.com/FrederickKnight/git-park/main/install.sh | sh
```

Instala en `~/bin` (`C:\Users\<tu usuario>\bin`) y agrega los alias a `~/.bashrc`.
Cierra y abre Git Bash: ya funciona ahi.

**2.** Para usarlo tambien en **PowerShell**, corre esto una vez en PowerShell. Agrega la
carpeta al PATH de tu usuario y los alias a tu perfil:

```powershell
$bin = "$env:USERPROFILE\bin"
$p = [Environment]::GetEnvironmentVariable("Path", "User")
if (";$p;" -notlike "*;$bin;*") { [Environment]::SetEnvironmentVariable("Path", "$bin;$p", "User") }
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
Add-Content $PROFILE "`nfunction park { git park @args }`nfunction memo { git memo @args }`nfunction kit { git kit @args }"
```

Cierra y abre PowerShell (y VS Code, si usas su terminal). En PowerShell, una nota con
`;`, `|` o `&` necesita comillas: `memo "probar a & b"`.

### Comprobar que funciona

En cualquier repo:

```bash
git park help
```

Ojo: `git park --help` no sirve, porque git intercepta `--help` y busca un manual.

### Actualizar

- Homebrew: `brew upgrade git-park`
- curl: corre la misma linea otra vez (no duplica los alias ni el PATH)

### Otras opciones del instalador

`sh -s -- --no-aliases` instala sin los alias. `PARK_BIN=/ruta` elige otra carpeta y
`PARK_REF=v0.1.0` instala una version concreta en lugar de `main`. Las variables van
antes de `sh`: `curl ... | PARK_REF=v0.1.0 sh`.

Desde un clon, para modificar los scripts:

```bash
git clone https://github.com/FrederickKnight/git-park.git
cd git-park
./install.sh
```

Para actualizar: `git pull && ./install.sh`.

## Configuracion

Todo con `git config`, global (`--global`) o por repo:

| clave | para que | por defecto |
|---|---|---|
| `park.base` | rama base, la que manda | la de `origin/HEAD`, luego `main` o `master` |
| `park.remote` | remoto | `origin` |
| `park.storyPattern` | regex del ticket en el nombre de la rama, p.ej. `sc-[0-9]+` | sin columna |
| `park.upBranches` | ramas que actualiza `git up`, separadas por espacio | la rama base |
| `park.twinTargets` | destinos de `git twin` y `park -t`, en el orden de tus PRs | la rama base |
| `park.root` | carpeta con tus repos, para `--all` | ninguna |
| `park.staleDays` | dias para marcar algo como viejo | 7 |
| `park.color` | `auto`, `always` o `never` | `auto` (respeta `NO_COLOR`) |

Ejemplo:

```bash
git config --global park.storyPattern 'sc-[0-9]+'
git config --global park.root ~/dev
git config park.upBranches "main staging"     # solo en este repo
git config park.twinTargets "staging main"
```

## park

```
  0  [2026-09-30]  [sc-100619]  refactor-x  (1 nota, hace 9 dias)
  1  [2026-10-09]  [sc-77]      corto
  2  [2026-10-09]               squashed  (ya en main, 1 nota)

  + 1 stash, 1 nota global (memo -g)
```

| comando | que hace |
|---|---|
| `park` | limpia y lista |
| `park -t` | lo mismo, con el estado de cada rama contra cada destino de `park.twinTargets` |
| `park add [rama]` | estaciona la rama actual o la indicada |
| `park N` | salta a la rama N y muestra sus notas |
| `park rm N` | la quita de la lista (no la borra) y manda sus notas a la papelera |
| `park note N texto` | anota en la rama N sin saltar a ella (acepta `--due`) |
| `park --all` | todos los repos bajo `park.root` |

Con `-t` hace fetch y agrega una columna por destino: `entro` (ya esta todo ahi),
`limpio` (mergea sin conflicto) o `conflicto`.

```
  0  [2026-10-09]  [sc-100619]  staging: entro  main: limpio      refactor-x  (1 nota)
  1  [2026-10-09]  [sc-77]      staging: conflicto  main: limpio  choca
```

Limpieza automatica al listar: se quitan las ramas que ya no existen y las que ya
entraron a la base (merge normal o squash) y no tienen notas pendientes. "Ya en la
base" se compara contra tu rama local, asi que `git up` la mantiene al dia. Una rama
que estacionas antes de hacerle commits se muestra como `sin commits` y no se limpia
hasta que reciba alguno.

## memo

| comando | que hace |
|---|---|
| `memo texto...` | anota en la rama actual |
| `memo add texto...` | lo mismo, para notas que empiezan con un subcomando |
| `memo --due <cuando> texto...` | con fecha limite: `2026-10-16`, `+3`, `hoy`, `manana` o un dia (`viernes`) |
| `memo` | lista las notas del repo y debajo las globales |
| `memo .` | solo las de la rama actual |
| `memo rm N` | manda la nota N a la papelera |
| `memo trash` / `memo undo [N]` | ver la papelera / recuperar una nota |
| `memo edit` | abre el archivo en `$VISUAL`, `$EDITOR` o `vi` |
| `memo -g ...` | lo mismo con las notas globales |
| `memo --all` | todos los repos bajo `park.root` |

Las notas con fecha limite muestran `vence ...` y se marcan en amarillo el dia que
vencen. Fuera de un repo, `memo` usa las globales. La papelera guarda las ultimas 50.

## up

`git up` actualiza las ramas de `park.upBranches`; `git up main staging` las que le
pases. Nunca fuerza: si una rama local tiene commits propios, avisa y no la toca.
Si una rama no existe en local, la crea desde el remoto.

## twin

```
limpia  sc-12
1 commit sobre main

  staging  ok  ya entro
  main     ok  mergea limpio
  -> falta el PR a main
```

`git twin [rama]` solo lee. Por cada destino dice si la rama ya entro, si mergea
limpio o en que archivos hay conflicto. Avisa de cambios sin commitear y de commits
que vienen de otro destino y no estan en la base.

## kit

| comando | corto | que hace |
|---|---|---|
| `kit new <rama>` | `sm` | crea la rama desde la base del remoto, recien bajada |
| `kit here <rama>` | `sc` | crea la rama desde donde estas parado |
| `kit del <rama>` | `bd` | borra la rama en local y en el remoto, y limpia su entrada en `park` |
| `kit redo <rama>` | `rc` | borra la rama (local y remoto) y la recrea desde donde estas parado |
| `kit save [mensaje]` | `ss` | stash de todo, incluido lo no trackeado |
| `kit list` | `sl` | lista los stashes |
| `kit pop [n]` | `sp` | recupera el stash n (por defecto el ultimo) |
| `kit drop <n>` | `sd` | borra el stash n (exige el indice) |
| `kit where` | `bc` | imprime la rama actual |
| `kit mine [base]` | | tus commits sobre la base y el `cherry-pick` listo |
| `kit now` | `st` | resumen de la rama: commits sobre la base, push pendiente, cambios, stashes y notas |
| `kit recent [n]` | | ultimas ramas en las que estuviste; con `n`, salta a esa |
| `kit gone [--delete]` | | ramas locales cuyo remoto ya no existe; con `--delete` las borra |
| `kit stale [dias]` | | ramas locales sin commits en esos dias (por defecto `park.staleDays`) |
| `kit lock [rama]` | | bloquea la rama (la actual si no indicas una) |
| `kit unlock [rama]` | | la libera |
| `kit locks` | | lista las ramas bloqueadas |

`del` y `redo` se niegan a borrar la rama base.

Una rama bloqueada con `kit lock` no la borran `del`, `redo` ni `gone --delete`: sirve
para ramas con un PR abierto, que se cerraria al borrar la rama remota. `park` la
muestra como `bloqueada`. El bloqueo solo frena estos atajos, no `git branch -D`.

La forma corta hace lo mismo: `kit ss` es `kit save`. Si la rama nunca se subio,
`del` y `redo` solo la borran en local (y `redo` la recrea igual).

## Datos

Texto plano dentro de `.git` (sin versionar, compartido entre worktrees):
`parked-branches`, `memos`, `memos-trash` y `locked-branches`. Las globales viven en `~/.memos`.

## Pruebas

```bash
sh tests/run.sh
```

El CI las corre en Ubuntu, macOS y Windows.
