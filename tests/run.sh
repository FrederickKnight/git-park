#!/bin/sh
# Pruebas de humo: arma un remoto y un clon temporales y revisa la salida de cada comando.
# Uso: sh tests/run.sh
here=$(cd "$(dirname "$0")/.." && pwd)
PATH="$here/bin:$PATH"; export PATH
T=$(mktemp -d); HOME="$T/home"; export HOME; mkdir -p "$HOME"
unset PARK_ROOT NO_COLOR
fails=0
ok() { echo "ok    $1"; }
bad() { echo "FALLA $1"; fails=$((fails + 1)); }
# has <nombre> <texto esperado> <comando...>
has() { n=$1; want=$2; shift 2; out=$("$@" 2>&1); case "$out" in *"$want"*) ok "$n" ;; *) bad "$n"; echo "$out" | sed 's/^/        /' ;; esac; }
hasnt() { n=$1; want=$2; shift 2; out=$("$@" 2>&1); case "$out" in *"$want"*) bad "$n"; echo "$out" | sed 's/^/        /' ;; *) ok "$n" ;; esac; }
commit() { echo "$1" > "$1"; git add "$1"; git commit -qm "$1"; }

git config --global user.email t@t.t; git config --global user.name t
git config --global init.defaultBranch main; git config --global core.autocrlf false
git config --global park.storyPattern 'sc-[0-9]+'; git config --global park.root "$T/dev"
mkdir -p "$T/dev"; cd "$T" || exit 1
git init -q --bare remote.git
git clone -q remote.git seed 2>/dev/null; cd seed || exit 1
printf 'l1\nl2\nl3\n' > f; git add f; git commit -qm base; git push -q origin main
git switch -qc staging; printf 'l1\nSTG\nl3\n' > f; git commit -qam stg; git push -q origin staging
cd "$T/dev" || exit 1; git clone -q "$T/remote.git" work; cd work || exit 1
git remote set-head origin main >/dev/null

# --- park y memo
git switch -qc feature/sc-100/uno; commit a
has "park add" "estacionada: feature/sc-100/uno" git park add
has "park add repetida" "ya estaba" git park add
has "memo anota" "anotada: 0" git memo correr migraciones
has "memo add" "anotada: 1" git memo add rm cosa
has "memo -g" "anotada: 0" git memo -g nota global
has "park lista story" "[sc-100]" git park
has "park cuenta notas" "2 notas" git park
has "park nota global" "1 nota global" git park
has "memo lista" "correr migraciones" git memo
has "memo agrupa por rama" "feature/sc-100/uno  (actual)" git memo
has "memo globales debajo" "nota global" git memo
has "memo rm" "borrada: correr migraciones" git memo rm 0
has "memo trash" "correr migraciones" git memo trash
has "memo undo" "restaurada: correr migraciones" git memo undo
git switch -q main
has "park N salta" "rm cosa" git park 0
has "park en rama" "feature/sc-100/uno" git branch --show-current
# antiguedad
awk -F'\t' -v OFS='\t' '{ $2 = "2020-01-01" } 1' .git/parked-branches > x && mv x .git/parked-branches
if git park | grep -qE ' [0-9]+a +\[sc-100\]'; then ok "park viejo"; else bad "park viejo"; git park | sed 's/^/        /'; fi
# rama borrada: limpia entrada y notas
git switch -q main; git branch -qD feature/sc-100/uno
has "limpia rama borrada" "limpiada: feature/sc-100/uno (ya no existe)" git park
has "notas a la papelera" "rm cosa" git memo trash
has "undo sin rama" "restaurada sin rama" git memo undo
# squash merge: ya en main
git switch -qc squashed; commit d; git park add >/dev/null; git memo nota sq >/dev/null
git switch -q main; git merge -q --squash squashed >/dev/null 2>&1; git commit -qm sq
has "detecta squash" "ya en main, 1 nota" git park
n=$(git memo | awk '/nota sq/ { print $1 }'); git memo rm "$n" >/dev/null
has "limpia ya en main" "limpiada: squashed (ya en main)" git park
has "park vacio" "sin ramas estacionadas" git park
# estacionada antes de hacerle commits: no se limpia hasta que reciba alguno
git switch -qc recien; git park add >/dev/null
has "park sin commits" "recien  (sin commits)" git park
commit r1; git switch -q main; git merge -q --squash recien >/dev/null 2>&1; git commit -qm r1
has "limpia tras commits" "limpiada: recien (ya en main)" git park
# fechas limite
has "memo --due fecha" "(vence 2099-01-02)" git memo --due 2099-01-02 lejana
has "memo --due hoy" "vence $(date +%Y-%m-%d)" git memo --due hoy para hoy
has "memo --due +N" "anotada" git memo --due +1 para manana
has "memo --due dia" "anotada" git memo --due viernes el viernes
has "memo --due invalida" "fecha no valida" git memo --due nunca x
git memo --due 2020-01-01 vencida >/dev/null
has "lista vence fecha" "lejana  (vence 2099-01-02)" git memo
has "lista vence hoy" "vence hoy" git memo
has "lista vence manana" "vence manana" git memo
has "lista vencida" "vencio hace" git memo
: > .git/memos
git switch -qc otra; commit o; git park add >/dev/null; git switch -q main
has "park --all" "work" git park --all
has "park note" "anotada: 0" git park note 0 revisar sin saltar
has "park note no salta" "main" git branch --show-current
has "park note cuenta" "1 nota" git park
has "park note rama" "revisar sin saltar" git memo
has "park --plain" "$(printf '0\totra\t')" git park --plain
has "memo --plain" "$(printf '\totra\trevisar sin saltar')" git memo --plain
has "park encabezado" "base main, 1 estacionada" git park
out=$(git park rm 99 2>/dev/null); if [ -z "$out" ]; then ok "error a stderr"; else bad "error a stderr"; echo "        $out"; fi
git config park.twinTargets "staging main"
has "park -t columna" "staging: limpio     main: limpio     otra" git park -t
git config --unset park.twinTargets
: > .git/memos
hasnt "sin colores en pipe" "$(printf '\033')" git park
has "color always" "$(printf '\033')" git -c park.color=always park
git reset -q --hard origin/main

# --- up
has "up al dia" "main: al dia" git up
git config park.upBranches "main staging"
has "up crea rama" "staging: creada desde origin/staging" git up
(cd "$T/seed" && git switch -q main && commit m && git push -q origin main)
has "up nuevos" "main: 1 commit nuevo" git up
has "up inexistente" "nope: no se pudo bajar" git up nope

# --- twin
git config park.twinTargets "staging main"
git switch -qc feature/sc-12/limpia; commit x
has "twin limpia" "mergea limpio" git twin
has "twin story" "sc-12" git twin
git switch -qc choca main; printf 'l1\nMIO\nl3\n' > f; git commit -qam c
has "twin conflicto" "conflicto en:" git twin
git switch -q feature/sc-12/limpia; git push -q origin HEAD 2>/dev/null
(cd "$T/seed" && git fetch -q && git switch -q staging && git merge -q --squash origin/feature/sc-12/limpia >/dev/null 2>&1 && git commit -qm sq && git push -q origin staging)
has "twin falta PR" "! falta el PR a main" git twin
has "twin --plain" "$(printf 'staging\tentro\t')" git twin --plain
git switch -qc desde-staging origin/staging 2>/dev/null; commit y
has "twin nacida de staging" "de staging que no esta" git twin

# --- kit
has "kit sm" "" git kit sm nueva
has "kit sm desde base" "$(git rev-parse origin/main)" git rev-parse HEAD
has "kit bc" "nueva" git kit bc
commit n1; commit n2
has "kit mine" "git cherry-pick" git kit mine
echo w > w
has "kit ss" "wip nueva" git kit ss
has "kit sl" "stash@{0}" git kit sl
has "kit sd exige indice" "uso: git kit sd <n>" git kit sd
git kit sp >/dev/null 2>&1; rm -f w
git kit sc hija >/dev/null 2>&1; git park add >/dev/null; git push -q origin hija 2>/dev/null; git switch -q nueva
has "kit bd limpia park" "limpiada: hija (ya no existe)" git kit bd hija
has "kit bd borra remoto" "" git ls-remote --heads origin hija
has "kit bd protege base" "es la rama base" git kit bd main
has "kit sin rama" "uso: git kit sm <rama>" git kit sm
# nombres largos
git kit new larga >/dev/null 2>&1
has "kit new" "$(git rev-parse origin/main)" git rev-parse HEAD
has "kit where" "larga" git kit where
echo w > w
has "kit save" "wip larga" git kit save
has "kit list" "stash@{0}" git kit list
has "kit drop exige indice" "uso: git kit drop <n>" git kit drop
has "kit pop" "" git kit pop
rm -f w
git kit here larga2 >/dev/null 2>&1; git switch -q larga
has "kit del" "Deleted branch larga2" git kit del larga2
has "kit del protege base" "es la rama base" git kit del main
# redo de una rama que nunca se subio: la recrea igual
git kit here solo-local >/dev/null 2>&1; git switch -q larga
has "kit redo sin remoto" "solo-local no estaba en origin" git kit redo solo-local
has "kit redo recrea" "solo-local" git branch --show-current
git switch -q larga
has "kit ayuda" "save [mensaje] (ss)" git kit
# now, recent, gone, stale
commit z1; echo w > w; echo zz >> z1
has "kit now rama" "larga" git kit now
has "kit now commits" "1 commit sobre main" git kit now
has "kit now upstream" "sin upstream" git kit now
has "kit now cambios" "1 modificado, 1 sin trackear" git kit now
has "kit st" "larga" git kit st
git checkout -q z1; rm -f w
has "kit now limpio" "limpio" git kit now
has "kit recent" "0  " git kit recent
prev=$(git kit recent | awk 'NR == 1 { print $2 }')
has "kit recent N" "" git kit recent 0
has "kit recent salta" "$prev" git branch --show-current
git switch -q larga; git push -q -u origin larga 2>/dev/null
has "kit now al dia" "al dia con origin/larga" git kit now
hasnt "kit gone nada" "larga" git kit gone
git push -q origin --delete larga; git switch -q main 2>/dev/null
has "kit gone lista" "larga" git kit gone
has "kit gone --delete" "borrada: larga" git kit gone --delete
has "kit stale nada" "ninguna rama" git kit stale 9999
has "kit stale todas" "hace 0 dias" git kit stale 0
# lock
git kit new prot >/dev/null 2>&1; commit p1; git push -q -u origin prot 2>/dev/null; git park add >/dev/null
has "kit lock" "bloqueada: prot" git kit lock
has "kit lock repetida" "ya estaba bloqueada" git kit lock prot
has "kit locks" "prot" git kit locks
has "park muestra bloqueada" "bloqueada" git park
has "kit now bloqueada" "bloqueada" git kit now
git switch -q main
has "kit del bloqueada" "prot esta bloqueada" git kit del prot
has "kit redo bloqueada" "prot esta bloqueada" git kit redo prot
has "rama sigue en local" "prot" git branch --list prot
has "rama sigue en remoto" "refs/heads/prot" git ls-remote --heads origin prot
git push -q origin --delete prot
has "kit gone respeta lock" "no se borra prot: esta bloqueada" git kit gone --delete
has "kit unlock" "liberada: prot" git kit unlock prot
has "kit locks vacio" "sin ramas bloqueadas" git kit locks
has "kit gone tras unlock" "borrada: prot" git kit gone --delete
git kit new prot2 >/dev/null 2>&1; git kit lock >/dev/null; git switch -q main; git branch -q -D prot2
git park >/dev/null
has "lock de rama borrada se limpia" "sin ramas bloqueadas" git kit locks

cd /; rm -rf "$T"
echo
if [ "$fails" = 0 ]; then echo "todo bien"; else echo "$fails fallas"; exit 1; fi
