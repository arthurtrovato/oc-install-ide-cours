#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="MeteoblueWeather.xcodeproj"
SCHEME="MeteoblueWatch"
SECRETS="Config/Secrets.xcconfig"
EXAMPLE_SECRETS="Config/Secrets.example.xcconfig"

fail() {
  printf '\nERREUR: %s\n' "$1" >&2
  exit 1
}

printf '=== Preparation installation Apple Watch Meteoblue ===\n'

[[ "$(uname -s)" == "Darwin" ]] || fail "Ce script doit etre lance sur macOS."
command -v xcodebuild >/dev/null 2>&1 || fail "Xcode/xcodebuild est introuvable. Installe ou ouvre Xcode une premiere fois."
xcode-select -p >/dev/null 2>&1 || fail "Aucun Xcode actif. Ouvre Xcode puis relance le script."

if [[ -d .git ]]; then
  branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ -n "$branch" && "$branch" != "meteoblue-widget" ]]; then
    fail "Branche actuelle: $branch. Passe d'abord sur meteoblue-widget."
  fi
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    printf 'XcodeGen absent: installation via Homebrew...\n'
    brew install xcodegen
  else
    fail "XcodeGen est absent et Homebrew n'est pas installe. Installe XcodeGen, puis relance ce script."
  fi
fi

[[ -f "$EXAMPLE_SECRETS" ]] || fail "$EXAMPLE_SECRETS est introuvable."

if [[ ! -f "$SECRETS" ]]; then
  cp "$EXAMPLE_SECRETS" "$SECRETS"
fi

current_key="$(sed -n 's/^[[:space:]]*METEOBLUE_API_KEY[[:space:]]*=[[:space:]]*//p' "$SECRETS" | head -n 1 | tr -d '\r')"
if [[ -z "$current_key" || "$current_key" == *"votre_cle"* || "$current_key" == *"your_key"* || "$current_key" == *"YOUR_KEY"* ]] || cmp -s "$SECRETS" "$EXAMPLE_SECRETS"; then
  printf 'La cle meteoblue n est pas encore configuree localement.\n'
  read -r -s -p 'Colle la cle API meteoblue (elle ne sera pas affichee): ' meteoblue_key
  printf '\n'
  [[ -n "$meteoblue_key" ]] || fail "Cle API vide."
  printf 'METEOBLUE_API_KEY = %s\n' "$meteoblue_key" > "$SECRETS"
fi
chmod 600 "$SECRETS"

if [[ -d .git ]] && ! git check-ignore -q "$SECRETS"; then
  fail "$SECRETS n'est pas ignore par Git. Refus de continuer pour eviter de publier la cle."
fi

printf 'Generation du projet Xcode...\n'
xcodegen generate
[[ -d "$PROJECT" ]] || fail "$PROJECT n'a pas ete genere."

printf 'Verification du scheme %s...\n' "$SCHEME"
if ! xcodebuild -list -project "$PROJECT" | grep -q "$SCHEME"; then
  fail "Le scheme $SCHEME n'apparait pas dans le projet genere."
fi

printf '\nDestinations watchOS actuellement vues par Xcode:\n'
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null || true

printf '\nPreparation terminee.\n'
printf '1. Xcode va s ouvrir.\n'
printf '2. Dans Signing & Capabilities, choisis ta Personal Team pour MeteoblueWatch et MeteoblueWatchWidgetExtension.\n'
printf '3. Selectionne ton Apple Watch physique comme destination du scheme MeteoblueWatch.\n'
printf '4. Lance Run.\n\n'

open "$PROJECT"
