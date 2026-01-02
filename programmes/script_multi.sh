#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo "Il manque au moins deux arguments."
  echo "Utilisation : $0 <fichier_urls> <mot_regex> [contexte_chars]"
  exit 1
fi

fichier_urls="$1"
mot_regex="$2"
ctx_chars="${3:-60}"

# base du nom du fichier (en.txt -> en, fr.txt -> fr, zh.txt -> zh)
base="$(basename "$fichier_urls" .txt)"

# Détection simple de la langue à partir du nom du fichier
is_zh=0
is_fr=0
if [[ "$base" == "zh" ]]; then
  is_zh=1
fi
if [[ "$base" == "fr" ]]; then
  is_fr=1
fi

# Pour en/fr : on veut éviter de matcher à l'intérieur des mots
# Pour zh : pas de notion de frontière de mot, et donc on garde le motif tel quel
if [[ "$is_zh" -eq 1 ]]; then
  mot_regex_bounded="$mot_regex"
else
  mot_regex_bounded="(^|[^[:alpha:]])(${mot_regex})([^[:alpha:]]|$)"
fi

# Dossiers de sortie
mkdir -p aspirations dumps-text contextes concordances tableaux

# Vérification du fichier d'URLs
if [[ ! -f "$fichier_urls" ]]; then
  echo "Erreur : fichier introuvable: $fichier_urls"
  exit 1
fi

# Fichier HTML principal
html_out="tableaux/${base}.html"

# En-tête HTML
echo "<!DOCTYPE html>
<html>
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css\">
  <title>Tableau $base</title>
</head>
<body>
  <div class=\"container\">
    <h1 class=\"title\">Tableau — $base</h1>
    <p>Mot (regex) : <code>$mot_regex</code> — Contexte : $ctx_chars caractères</p>
    <div class=\"table-container\">
      <table class=\"table is-bordered is-hoverable is-striped is-fullwidth\">
        <tr>
          <th>Numero</th>
          <th>URL</th>
          <th>Code HTTP</th>
          <th>Encodage</th>
          <th>Nb mots</th>
          <th>Occurrences</th>
          <th>Aspiration</th>
          <th>Dump</th>
          <th>Contexte</th>
          <th>Concordance</th>
        </tr>" > "$html_out"

numero=0
while read -r line; do
  # Nettoyage simple d'URLs
  line="$(echo "$line" | tr -d '\r')"
  line="$(echo "$line" | sed 's/^\xef\xbb\xbf//')"
  line="$(echo "$line" | sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//')"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue

  # Normalisation URL
  url="$line"
  if ! echo "$url" | grep -qE '^https?://'; then
    url="https://$url"
  fi

  ((numero++))
  echo "Traitement $numero : $url" >&2

  aspiration="aspirations/${base}-${numero}.html"
  dump="dumps-text/${base}-${numero}.txt"
  contexte="contextes/${base}-${numero}.ctx.txt"
  concordance="concordances/${base}-${numero}.html"

  # Requête HTTP : code HTTP + headers, body dans un fichier temporaire
  headers_tmp="$(mktemp)"
  body_tmp="$(mktemp)"
  code_http="$(curl -s -L --max-time 25 -D "$headers_tmp" -o "$body_tmp" -w "%{http_code}" "$url")"
  [[ -z "$code_http" ]] && code_http="none"

  # Encodage depuis Content-Type si présent
  encodage="$(cat "$headers_tmp" | tr '\r' '\n' | grep -i '^content-type:' | grep -ioE 'charset=[^;[:space:]]+' | head -n 1 | cut -d= -f2)"
  [[ -z "$encodage" ]] && encodage="none"

  # On sauvegarde la page aspirée
  mv "$body_tmp" "$aspiration"
  rm -f "$headers_tmp"

  # Si pas 200 : on écrit une ligne indisponible dans le HTML
  if [[ "$code_http" != "200" ]]; then
    echo "        <tr>
          <td>$numero</td>
          <td><a href=\"$url\" target=\"_blank\">$url</a></td>
          <td>$code_http</td>
          <td>$encodage</td>
          <td>0</td>
          <td>0</td>
          <td><a href=\"$aspiration\" target=\"_blank\">html</a></td>
          <td>-</td>
          <td>-</td>
          <td>-</td>
        </tr>" >> "$html_out"
    continue
  fi

  # Dump texte (lynx)
  # Pour zh : si l'encodage est inconnu, on peut essayer UTF-8 (souvent) ; sinon encodage des headers
  if [[ "$encodage" != "none" ]]; then
    lynx -dump -nolist -assume_charset="$encodage" -display_charset=UTF-8 "$aspiration" > "$dump"
  else
    lynx -dump -nolist -assume_charset=UTF-8 -display_charset=UTF-8 "$aspiration" > "$dump"
  fi

  # Nombre de mots (ok pour en/fr ; pour zh, c'est indicatif)
  nb_mots="$(cat "$dump" | wc -w | tr -d '[:space:]')"
  [[ -z "$nb_mots" ]] && nb_mots="0"

  # Occurrences
  # en/fr : insensible à la casse, et avec frontières
  # zh : pas de -i, pas de frontières
  if [[ "$is_zh" -eq 1 ]]; then
    occurrences="$(grep -Eo "$mot_regex_bounded" "$dump" | wc -l | tr -d '[:space:]')"
  else
    occurrences="$(grep -Eoi "$mot_regex_bounded" "$dump" | wc -l | tr -d '[:space:]')"
  fi
  [[ -z "$occurrences" ]] && occurrences="0"

  # Extraction des contextes (fenêtre en caractères autour du motif)
  # Important : ici on utilise mot_regex (simple), sinon les ^/$ du bounded peuvent gêner l'extraction
  if [[ "$is_zh" -eq 1 ]]; then
    grep -Eo ".{0,${ctx_chars}}${mot_regex}.{0,${ctx_chars}}" "$dump" > "$contexte"
  else
    grep -Eio ".{0,${ctx_chars}}${mot_regex}.{0,${ctx_chars}}" "$dump" > "$contexte"
  fi

  # Concordance (gauche / cible / droite) : on évite les problèmes de groupes avec awk match()
  echo "<!DOCTYPE html>
<html>
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css\">
  <title>Concordance $base-$numero</title>
</head>
<body>
  <div class=\"container\">
    <h1 class=\"title\">Concordance — $base-$numero</h1>
    <div class=\"table-container\">
      <table class=\"table is-bordered is-hoverable is-striped is-fullwidth\">
        <tr>
          <th>Contexte gauche</th>
          <th>Cible</th>
          <th>Contexte droit</th>
        </tr>" > "$concordance"

  while read -r ctxline; do
    ctxline="$(echo "$ctxline" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"

    if [[ "$is_zh" -eq 1 ]]; then
      gauche="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, 1, RSTART-1); }')"
      cible="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, RSTART, RLENGTH); }')"
      droit="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, RSTART+RLENGTH); }')"
    else
      gauche="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, 1, RSTART-1); }')"
      cible="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, RSTART, RLENGTH); }')"
      droit="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, RSTART+RLENGTH); }')"
    fi

    echo "        <tr>
          <td>$gauche</td>
          <td><strong>$cible</strong></td>
          <td>$droit</td>
        </tr>" >> "$concordance"
  done < "$contexte"

  echo "      </table>
    </div>
  </div>
</body>
</html>" >> "$concordance"

  # Ecriture HTML (tableau principal)
  echo "        <tr>
          <td>$numero</td>
          <td><a href=\"$url\" target=\"_blank\">$url</a></td>
          <td>$code_http</td>
          <td>$encodage</td>
          <td>$nb_mots</td>
          <td>$occurrences</td>
          <td><a href=\"../$aspiration\" target=\"_blank\">html</a></td>
          <td><a href=\"../$dump\" target=\"_blank\">dump</a></td>
          <td><a href=\"../$contexte\" target=\"_blank\">ctx</a></td>
          <td><a href=\"../$concordance\" target=\"_blank\">kwic</a></td>
        </tr>" >> "$html_out"

done < "$fichier_urls"

# Fermeture HTML
echo "      </table>
    </div>
  </div>
</body>
</html>" >> "$html_out"

echo "OK: $html_out" >&2
