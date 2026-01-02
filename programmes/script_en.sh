#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo "Il manque au moins deux arguments."
  echo "Utilisation : $0 <fichier_urls> <mot_regex> [contexte_chars]"
  exit 1
fi

fichier_urls="$1"
mot_regex="$2"
ctx_chars="${3:-60}"

mot_regex_bounded="(^|[^[:alpha:]])(${mot_regex})([^[:alpha:]]|$)"

# Dossiers de sortie
mkdir -p aspirations dumps-text contextes concordances tableaux

# Vérification du fichier d'URLs
if [[ ! -f "$fichier_urls" ]]; then
  echo "Erreur : fichier introuvable: $fichier_urls"
  exit 1
fi

# un base du nom du fichier (en.txt -> en)
base="$(basename "$fichier_urls" .txt)"

# Fichiers de sortie principaux
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

  # Requête HTTP : on récupère code HTTP + headers, et on sauve le body
  headers_tmp="$(mktemp)"
  body_tmp="$(mktemp)"
  code_http="$(curl -s -L --max-time 25 -D "$headers_tmp" -o "$body_tmp" -w "%{http_code}" "$url")"
  if [[ -z "$code_http" ]]; then
    code_http="none"
  fi

  # Encodage depuis Content-Type si présent
  encodage="$(cat "$headers_tmp" | tr '\r' '\n' | grep -i '^content-type:' | grep -ioE 'charset=[^;[:space:]]+' | head -n 1 | cut -d= -f2)"
  if [[ -z "$encodage" ]]; then
    encodage="none"
  fi

  # On sauvegarde la page aspirée
  mv "$body_tmp" "$aspiration"
  rm -f "$headers_tmp"

  # Si pas 200 : on écrit une ligne "indisponible"
  if [[ "$code_http" != "200" ]]; then
    echo -e "${numero}\t${url}\t${code_http}\t${encodage}\t0\t0\t${aspiration}\t-\t-\t-" >> "$tsv_out"
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
  lynx -dump -nolist -assume_charset=UTF-8 -display_charset=UTF-8 "$aspiration" > "$dump"

  # Nombre de mots
  nb_mots="$(cat "$dump" | wc -w | tr -d '[:space:]')"
  if [[ -z "$nb_mots" ]]; then
    nb_mots="0"
  fi

  # Occurrences du motif
  occurrences="$(grep -Eoi "$mot_regex_bounded" "$dump" | wc -l | tr -d '[:space:]')"
  if [[ -z "$occurrences" ]]; then
    occurrences="0"
  fi

  # Extraction des contextes (fenêtre en caractères autour du motif)
  grep -Eoi ".{0,${ctx_chars}}${mot_regex_bounded}.{0,${ctx_chars}}" "$dump" > "$contexte"

  # Concordance (gauche / cible / droite)
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
    gauche="$(echo "$ctxline" | sed -E "s/(.*)(${mot_regex})(.*)/\1/I")"
    cible="$(echo "$ctxline" | sed -E "s/(.*)(${mot_regex})(.*)/\3/I")"
    droit="$(echo "$ctxline" | sed -E "s/(.*)(${mot_regex})(.*)/\4/I")"

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

  # Ecriture HTML
  echo "        <tr>
          <td>$numero</td>
          <td><a href=\"$url\" target=\"_blank\">$url</a></td>
          <td>$code_http</td>
          <td>$encodage</td>
          <td>$nb_mots</td>
          <td>$occurrences</td>
          <td><a href=\"$aspiration\" target=\"_blank\">html</a></td>
          <td><a href=\"$dump\" target=\"_blank\">dump</a></td>
          <td><a href=\"$contexte\" target=\"_blank\">ctx</a></td>
          <td><a href=\"$concordance\" target=\"_blank\">kwic</a></td>
        </tr>" >> "$html_out"

done < "$fichier_urls"

# Fermeture HTML
echo "      </table>
    </div>
  </div>
</body>
</html>" >> "$html_out"

echo "OK: $tsv_out et $html_out" >&2
