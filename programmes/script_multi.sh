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
is_en=0
if [[ "$base" == "zh" ]]; then
  is_zh=1
fi
if [[ "$base" == "fr" ]]; then
  is_fr=1
fi
if [[ "$base" == "en" ]]; then
  is_en=1
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

# Fonction pour échapper les caractères HTML
escape_html() {
  echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# Fonction améliorée pour détecter l'encodage
detect_encoding() {
    local file="$1"
    local http_encoding="$2"
    
    if [[ -n "$http_encoding" ]] && [[ "$http_encoding" != "none" ]]; then
        echo "$http_encoding"
        return 0
    fi
    
    # 2. Vérifier la balise meta charset
    local meta_enc=$(grep -ioE '<meta[^>]*charset=[^>]*>' "$file" | grep -ioE 'charset=[^"[:space:]>]+' | cut -d'=' -f2 | tr -d '"' | head -n 1)
    if [[ -n "$meta_enc" ]]; then
        echo "$meta_enc"
        return 0
    fi
    
    # 3. Utiliser file -i pour détecter
    local file_enc=$(file -b --mime-encoding "$file")
    if [[ "$file_enc" != "us-ascii" && "$file_enc" != "binary" && -n "$file_enc" ]]; then
        echo "$file_enc"
        return 0
    fi
    
    # 5. Par défaut UTF-8
    echo "UTF-8"
}

# Fonction améliorée pour extraire le texte
extract_text() {
    local input_file="$1"
    local output_file="$2"
    local encoding="$3"
    local url="$4"
    
    # Normaliser l'encodage
    encoding=$(echo "$encoding" | tr '[:lower:]' '[:upper:]')
    case "$encoding" in
        "UTF8"|"UTF-8") encoding="UTF-8" ;;
        "ISO-8859-1"|"ISO8859-1") encoding="ISO-8859-1" ;;
        "WINDOWS-1252"|"CP1252") encoding="WINDOWS-1252" ;;
        "GB2312"|"GBK"|"GB18030") encoding="GB18030" ;;
        "BIG5") encoding="BIG5" ;;
        *) encoding="UTF-8" ;;
    esac
    
    # Méthode 1: Lynx (meilleur pour la plupart des sites)
    if command -v lynx >/dev/null 2>&1; then
        # Essayer avec l'encodage détecté
        lynx -dump -nolist -assume_charset="$encoding" -display_charset=UTF-8 "$input_file" 2>/dev/null > "$output_file"

        # Nettoyer l'encodage
        if [[ -f "$output_file" ]]; then
            iconv -f utf-8 -t utf-8//IGNORE "$output_file" > "${output_file}.tmp" 2>/dev/null && mv "${output_file}.tmp" "$output_file"
        fi
        
        # Si vide ou trop petit, essayer UTF-8
        if [[ ! -s "$output_file" ]] || [[ $(wc -c < "$output_file" 2>/dev/null) -lt 100 ]]; then
            lynx -dump -nolist -assume_charset=UTF-8 -display_charset=UTF-8 "$input_file" 2>/dev/null > "$output_file"
        fi
    fi
    
    # Méthode 2: html2text (alternative)
    if [[ ! -s "$output_file" ]] && command -v html2text >/dev/null 2>&1; then
        if [[ "$encoding" != "UTF-8" ]] && [[ "$encoding" != "utf-8" ]]; then
            iconv -f "$encoding" -t UTF-8//IGNORE "$input_file" 2>/dev/null | html2text -utf8 > "$output_file" 2>/dev/null || true
        else
            html2text -utf8 "$input_file" > "$output_file" 2>/dev/null || true
        fi
    fi
    
    # S'assurer que le fichier existe
    if [[ ! -f "$output_file" ]]; then
        echo "Impossible d'extraire le texte de cette page." > "$output_file"
    fi
    
    # Nettoyer le texte : remplacer les retours à la ligne multiples par un seul espace
    if [[ -f "$output_file" ]]; then
        sed -i 's/\s\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' "$output_file" 2>/dev/null || true
    fi
}

# Fonction pour extraire les contextes de manière fiable
extract_contexts() {
    local dump_file="$1"
    local regex="$2"
    local is_zh="$3"
    local ctx_chars="$4"
    local output_file="$5"
    
    # Vider le fichier de sortie
    > "$output_file"
    
    if [[ ! -f "$dump_file" ]] || [[ ! -s "$dump_file" ]]; then
        return
    fi
    
    # Lire tout le contenu (une seule ligne)
    local content
    content=$(cat "$dump_file" | tr '\n' ' ' | sed 's/\s\+/ /g')
    
    # Créer un fichier temporaire avec le contenu sur une ligne
    local temp_file
    temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    
    # Extraire les contextes
    if [[ "$is_zh" -eq 1 ]]; then
        # Pour le chinois
        grep -oE ".{0,$ctx_chars}${regex}.{0,$ctx_chars}" "$temp_file" 2>/dev/null >> "$output_file"
    else
        # Pour français/anglais (insensible à la casse)
        grep -oiE ".{0,$ctx_chars}${regex}.{0,$ctx_chars}" "$temp_file" 2>/dev/null >> "$output_file"
    fi
    
    # Nettoyer le fichier temporaire
    rm -f "$temp_file"
    
    # Nettoyer les résultats
    if [[ -f "$output_file" ]]; then
        sed -i 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d' "$output_file" 2>/dev/null || true
    fi
}

# En-tête HTML
echo "<!DOCTYPE html>
<html lang=\"$base\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css\">
  <link rel=\"stylesheet\" href=\"../style.css\">
  <title>Tableau $base</title>
</head>
<body>

<nav class=\"navbar is-fixed-top\" role=\"navigation\" aria-label=\"Navigation principale\">
  <div class=\"container\">
    <div class=\"navbar-brand\">
      <a class=\"navbar-item\" href=\"../index.html\">
        <strong>✨ LA RÊVERIE</strong>
      </a>
      <a role=\"button\" class=\"navbar-burger\" aria-label=\"menu\" aria-expanded=\"false\" data-target=\"navbarTable\">
        <span aria-hidden=\"true\"></span>
        <span aria-hidden=\"true\"></span>
        <span aria-hidden=\"true\"></span>
      </a>
    </div>

    <div id=\"navbarTable\" class=\"navbar-menu\">
      <div class=\"navbar-start\">
        <a class=\"navbar-item\" href=\"../index.html\" title=\"Page d'accueil\">Accueil</a>
        
        <div class=\"navbar-item has-dropdown is-hoverable\">
          <a class=\"navbar-link\" title=\"Tableaux de données\">Tableaux</a>
          <div class=\"navbar-dropdown\">
            <a class=\"navbar-item\" href=\"fr.html\" title=\"Tableau français\">Français</a>
            <a class=\"navbar-item\" href=\"en.html\" title=\"Tableau anglais\">Anglais</a>
            <a class=\"navbar-item\" href=\"zh.html\" title=\"Tableau chinois\">Chinois</a>
          </div>
        </div>
        
        <div class=\"navbar-item has-dropdown is-hoverable\">
          <a class=\"navbar-link\" title=\"Analyses par langue\">Analyses</a>
          <div class=\"navbar-dropdown\">
            <a class=\"navbar-item\" href=\"../analyse-fr.html\" title=\"Analyse française\">Français</a>
            <a class=\"navbar-item\" href=\"../analyse-en.html\" title=\"Analyse anglaise\">Anglais</a>
            <a class=\"navbar-item\" href=\"../analyse-zh.html\" title=\"Analyse chinoise\">Chinois</a>
          </div>
        </div>
        
        <a class=\"navbar-item\" href=\"../presentation.html\" title=\"À propos du projet\">À propos</a>
      </div>
    </div>
  </div>
</nav>

<header class=\"hero is-table\" role=\"banner\">
</header>

<main class=\"section\">
  <div class=\"container fade-in\">
    
    <div class=\"columns is-multiline mb-5\">
      
      <div class=\"column is-5\">
        <div class=\"stats-box\">
          <div class=\"stats-title\">Langue :</div>
          <div class=\"stats-value\">" > "$html_out"

# Afficher le nom de la langue
case "$base" in
  "fr") echo "Français" >> "$html_out" ;;
  "en") echo "Anglais" >> "$html_out" ;;
  "zh") echo "Chinois" >> "$html_out" ;;
  *) echo "$base" >> "$html_out" ;;
esac

echo "</div>
        </div>
      </div>
    
      <div class=\"column is-5\">
        <div class=\"stats-box\">
          <div class=\"stats-title\">Mot recherché :</div>
          <div class=\"stats-value\">$mot_regex</div>
        </div>
      </div>
      
    </div>

    <div class=\"table-container\">
      <table class=\"table is-bordered is-hoverable is-striped is-fullwidth\">
        <thead>
          <tr>
            <th>#</th>
            <th>URL</th>
            <th>Code HTTP</th>
            <th>Encodage</th>
            <th>Nb mots</th>
            <th>Occurrences</th>
            <th>Aspiration</th>
            <th>Dump texte</th>
            <th>Contexte</th>
            <th>Concordance</th>
          </tr>
        </thead>
        <tbody>" >> "$html_out"

# Variables pour les statistiques globales
total_urls=0
total_mots=0
total_occurrences=0
urls_success=0

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
  ((total_urls++))
  echo "Traitement $numero : $url" >&2

  aspiration="aspirations/${base}-${numero}.html"
  dump="dumps-text/${base}-${numero}.txt"
  contexte="contextes/${base}-${numero}.ctx.txt"
  concordance="concordances/${base}-${numero}.html"

  # Créer le fichier temporaire pour les headers
  headers_tmp="$(mktemp)"
  
  # Requête HTTP avec gestion d'erreur
  code_http=$(curl -s -L -o "$aspiration" -D "$headers_tmp" -w "%{http_code}" --max-time 30 "$url" 2>/dev/null || echo "000")
  
  # Lire l'encodage depuis les headers
  encodage_from_header="$(cat "$headers_tmp" 2>/dev/null | tr '\r' '\n' | grep -i '^content-type:' | grep -ioE 'charset=[^;[:space:]]+' | head -n 1 | cut -d= -f2 || echo "")"
  
  # Nettoyer le fichier temporaire
  rm -f "$headers_tmp" 2>/dev/null

  # Détection robuste de l'encodage
  detected_encoding="$(detect_encoding "$aspiration" "$encodage_from_header")"
  
  # URL échappée pour HTML
  url_escaped="$(escape_html "$url")"

  # Si pas 200 : on écrit une ligne indisponible dans le HTML
  if [[ "$code_http" != "200" ]]; then
    # Déterminer le tag de statut
    tag_class="tag-danger"
    if [[ "$code_http" =~ ^[45] ]]; then
      tag_class="tag-danger"
    elif [[ "$code_http" =~ ^3 ]]; then
      tag_class="tag-warning"
    else
      tag_class="tag-info"
    fi
    
    echo "        <tr>
          <td>$numero</td>
          <td>
            <a href=\"$url\" target=\"_blank\" title=\"$url_escaped\">
              <span class=\"code-url\">$url_escaped</span>
            </a>
          </td>
          <td><span class=\"tag $tag_class\">$code_http</span></td>
          <td><span class=\"tag tag-info\">$detected_encoding</span></td>
          <td>0</td>
          <td>0</td>
          <td><a class=\"button is-small is-link is-outlined\" href=\"../$aspiration\" target=\"_blank\">HTML</a></td>
          <td>-</td>
          <td>-</td>
          <td>-</td>
        </tr>" >> "$html_out"
    continue
  fi

  # Page avec succès
  ((urls_success++))

  # Extraction du texte avec méthodes multiples
  extract_text "$aspiration" "$dump" "$detected_encoding" "$url"

  # Vérifier si le fichier dump existe
  if [[ ! -f "$dump" ]] || [[ ! -s "$dump" ]]; then
    # Créer un fichier dump vide
    echo "" > "$dump"
    nb_mots="0"
  else
    # Nombre de mots
    nb_mots="$(wc -w < "$dump" 2>/dev/null | tr -d '[:space:]' || echo "0")"
  fi
  
  [[ -z "$nb_mots" ]] && nb_mots="0"
  total_mots=$((total_mots + nb_mots))

  # Occurrences - vérifier si le fichier existe et n'est pas vide
  occurrences="0"
  if [[ -f "$dump" ]] && [[ -s "$dump" ]]; then
    if [[ "$is_zh" -eq 1 ]]; then
      occurrences="$(grep -Eo "$mot_regex_bounded" "$dump" 2>/dev/null | wc -l 2>/dev/null | tr -d '[:space:]' || echo "0")"
    else
      occurrences="$(grep -Eio "$mot_regex_bounded" "$dump" 2>/dev/null | wc -l 2>/dev/null | tr -d '[:space:]' || echo "0")"
    fi
  fi
  [[ -z "$occurrences" ]] && occurrences="0"
  total_occurrences=$((total_occurrences + occurrences))

  # Extraction des contextes avec la nouvelle fonction
  extract_contexts "$dump" "$mot_regex" "$is_zh" "$ctx_chars" "$contexte"

  # Concordance (gauche / cible / droite)
  echo "<!DOCTYPE html>
<html lang=\"$base\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Concordance $base-$numero</title>
  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css\">
  <link rel=\"stylesheet\" href=\"../style.css\">
</head>
<body>
<nav class=\"navbar is-fixed-top\" role=\"navigation\" aria-label=\"Navigation principale\">
  <div class=\"container\">
    <div class=\"navbar-brand\">
      <a class=\"navbar-item\" href=\"../index.html\">
        <strong>✨ LA RÊVERIE</strong>
      </a>
      <a role=\"button\" class=\"navbar-burger\" aria-label=\"menu\" aria-expanded=\"false\" data-target=\"navbarTable\">
        <span aria-hidden=\"true\"></span>
        <span aria-hidden=\"true\"></span>
        <span aria-hidden=\"true\"></span>
      </a>
    </div>

    <div id=\"navbarTable\" class=\"navbar-menu\">
      <div class=\"navbar-start\">
        <a class=\"navbar-item\" href=\"../index.html\" title=\"Page d'accueil\">Accueil</a>
        
        <div class=\"navbar-item has-dropdown is-hoverable\">
          <a class=\"navbar-link\" title=\"Tableaux de données\">Tableaux</a>
          <div class=\"navbar-dropdown\">
            <a class=\"navbar-item\" href=\"../tableaux/fr.html\" title=\"Tableau français\">Français</a>
            <a class=\"navbar-item\" href=\"../tableaux/en.html\" title=\"Tableau anglais\">Anglais</a>
            <a class=\"navbar-item\" href=\"../tableaux/zh.html\" title=\"Tableau chinois\">Chinois</a>
          </div>
        </div>
        
        <div class=\"navbar-item has-dropdown is-hoverable\">
          <a class=\"navbar-link\" title=\"Analyses par langue\">Analyses</a>
          <div class=\"navbar-dropdown\">
            <a class=\"navbar-item\" href=\"../analyse-fr.html\" title=\"Analyse française\">Français</a>
            <a class=\"navbar-item\" href=\"../analyse-en.html\" title=\"Analyse anglaise\">Anglais</a>
            <a class=\"navbar-item\" href=\"../analyse-zh.html\" title=\"Analyse chinoise\">Chinois</a>
          </div>
        </div>
        
        <a class=\"navbar-item\" href=\"../presentation.html\" title=\"À propos du projet\">À propos</a>
      </div>
    </div>
  </div>
</nav>

<header class=\"hero is-table\" role=\"banner\">
</header>

<main class=\"section\">
  <div class=\"container\">
    <h1 class=\"title is-3\">Concordance — $base-$numero</h1>
    <p class=\"subtitle is-6\">URL: <a href=\"$url\" target=\"_blank\">$url_escaped</a></p>
    <p>Occurrences trouvées: <strong>$occurrences</strong></p>
    <div class=\"table-container\">
      <table class=\"table is-bordered is-hoverable is-fullwidth\">
        <thead>
          <tr>
            <th>Contexte gauche</th>
            <th>Cible</th>
            <th>Contexte droit</th>
          </tr>
        </thead>
        <tbody>" > "$concordance"

  if [[ -f "$contexte" ]] && [[ -s "$contexte" ]]; then
   while read -r ctxline; do
      # Échapper les caractères HTML
      ctxline_escaped="$(escape_html "$ctxline")"
      
      if [[ "$is_zh" -eq 1 ]]; then
        # Pour le chinois, chercher le motif exact
        if echo "$ctxline" | grep -qE "$mot_regex"; then
          gauche="$(echo "$ctxline" | sed "s/\(.*\)$mot_regex\(.*\)/\1/" 2>/dev/null || echo "")"
          cible="$(echo "$ctxline" | grep -oE "$mot_regex" 2>/dev/null | head -1 || echo "")"
          droit="$(echo "$ctxline" | sed "s/.*$mot_regex//" 2>/dev/null || echo "")"
        fi
      else
        # Pour français/anglais, insensible à la casse
        if echo "$ctxline" | grep -qiE "$mot_regex"; then
          gauche="$(echo "$ctxline" | sed "s/\(.*\)$mot_regex\(.*\)/\1/i" 2>/dev/null || echo "")"
          cible="$(echo "$ctxline" | grep -oiE "$mot_regex" 2>/dev/null | head -1 || echo "")"
          droit="$(echo "$ctxline" | sed "s/.*$mot_regex//i" 2>/dev/null || echo "")"
        fi
      fi
      
      # Nettoyer les espaces et échapper HTML
      gauche="$(escape_html "$gauche")"
      cible="$(escape_html "$cible")"
      droit="$(escape_html "$droit")"
        
        echo "        <tr>
          <td style=\"text-align: right; width: 40%;\">$gauche</td>
          <td style=\"text-align: center; width: 20%;\"><span class=\"kwic-target\">$cible</span></td>
          <td style=\"text-align: left; width: 40%;\">$droit</td>
        </tr>" >> "$concordance"
    done < "$contexte"
  else
    echo "        <tr>
          <td colspan=\"3\" style=\"text-align: center; color: #999;\">Aucun contexte trouvé</td>
        </tr>" >> "$concordance"
  fi

  echo "        </tbody>
      </table>
    </div>
    <div class=\"mt-4\">
      <a href=\"../tableaux/$base.html\" class=\"button is-black\">← Retour au tableau</a>
    </div>
  </div>
</main>

<footer class=\"footer\" role=\"contentinfo\">
  <div class=\"container has-text-centered\">
    <p>Projet encadré - La vie multilingue des mots sur le web</p>
    <p class=\"is-size-7 mt-2\">© 2025/2026 - Master TAL | Université Paris Cité - INALCO - Université Paris Nanterre</p>
    <p class=\"is-size-7 mt-1\">
      <a href=\"../mentions-legales.html\" style=\"color: var(--lavande); text-decoration: underline;\">Mentions légales</a> | 
      <a href=\"../contact.html\" style=\"color: var(--lavande); text-decoration: underline;\">Contact</a>
    </p>
  </div>
</footer>

<script>
  // Script pour le menu burger
  document.addEventListener('DOMContentLoaded', () => {
    const navbarBurgers = document.querySelectorAll('.navbar-burger');
    
    navbarBurgers.forEach(burger => {
      burger.addEventListener('click', () => {
        const targetId = burger.dataset.target;
        const target = document.getElementById(targetId);
        
        burger.classList.toggle('is-active');
        target.classList.toggle('is-active');
        
        const isExpanded = burger.getAttribute('aria-expanded') === 'true';
        burger.setAttribute('aria-expanded', !isExpanded);
      });
    });
  });
</script>

</body>
</html>" >> "$concordance"

  # Déterminer le tag pour le nombre d'occurrences
  occ_tag_class="tag-info"
  if [[ "$occurrences" -eq 0 ]]; then
    occ_tag_class="tag-warning"
  elif [[ "$occurrences" -gt 10 ]]; then
    occ_tag_class="tag-success"
  fi

  # Déterminer le tag pour le nombre de mots
  mots_tag_class="tag-info"
  if [[ "$nb_mots" -gt 1000 ]]; then
    mots_tag_class="tag-success"
  elif [[ "$nb_mots" -lt 100 ]]; then
    mots_tag_class="tag-warning"
  fi

  # Écriture HTML (tableau principal)
  echo "        <tr>
          <td><strong>$numero</strong></td>
          <td>
            <a href=\"$url\" target=\"_blank\" title=\"$url_escaped\">
              <span class=\"code-url\">$url_escaped</span>
            </a>
          </td>
          <td><span class=\"tag tag-success\">$code_http</span></td>
          <td><span class=\"tag tag-info\">$detected_encoding</span></td>
          <td><span class=\"tag $mots_tag_class\">$nb_mots</span></td>
          <td><span class=\"tag $occ_tag_class\">$occurrences</span></td>
          <td><a class=\"button is-small is-link is-outlined\" href=\"../$aspiration\" target=\"_blank\">HTML</a></td>
          <td><a class=\"button is-small is-info is-outlined\" href=\"../$dump\" target=\"_blank\">TEXTE</a></td>
          <td><a class=\"button is-small is-warning is-outlined\" href=\"../$contexte\" target=\"_blank\">CTX</a></td>
          <td><a class=\"button is-small is-success is-outlined\" href=\"../$concordance\" target=\"_blank\">KWIC</a></td>
        </tr>" >> "$html_out"

done < "$fichier_urls"

# Calculer les moyennes
moy_mots=0
moy_occurrences=0
if [[ $total_urls -gt 0 ]]; then
  moy_mots=$((total_mots / total_urls))
  moy_occurrences=$((total_occurrences / total_urls))
fi

# Taux de succès
taux_success=0
if [[ $total_urls -gt 0 ]]; then
  taux_success=$((urls_success * 100 / total_urls))
fi

# Fermeture du tableau
echo "        </tbody>
      </table>
    </div>
    
    <div class=\"columns is-multiline mt-6\">
      <div class=\"column is-12\">
        <h3 class=\"title is-4\">Résumé statistique</h3>
      </div>
      
      <div class=\"column is-3\">
        <div class=\"notification\" style=\"background-color: var(--rose-bonbon);\">
          <h4 class=\"title is-5\">URLs traitées</h4>
          <p class=\"title is-2 has-text-centered\">$total_urls</p>
        </div>
      </div>
      
      <div class=\"column is-3\">
        <div class=\"notification\" style=\"background-color: #e3f2fd;\">
          <h4 class=\"title is-5\">Pages aspirées</h4>
          <p class=\"title is-2 has-text-centered\">$urls_success <span class=\"subtitle is-6\">($taux_success%)</span></p>
        </div>
      </div>
      
      <div class=\"column is-3\">
        <div class=\"notification\" style=\"background-color: #f1f8e9;\">
          <h4 class=\"title is-5\">Mots total</h4>
          <p class=\"title is-2 has-text-centered\">$total_mots <span class=\"subtitle is-6\">(~$moy_mots/page)</span></p>
        </div>
      </div>
      
      <div class=\"column is-3\">
        <div class=\"notification\" style=\"background-color: #fff3e0;\">
          <h4 class=\"title is-5\">Occurrences</h4>
          <p class=\"title is-2 has-text-centered\">$total_occurrences <span class=\"subtitle is-6\">(~$moy_occurrences/page)</span></p>
        </div>
      </div>
    </div>
    
    <div class=\"notification mt-5\" style=\"background-color: var(--blanc-casse);\">
      <div class=\"content\">
        <h4 class=\"title is-5\">Légende</h4>
        <div class=\"tags\">
          <span class=\"tag tag-success\">Code 200</span>
          <span class=\"tag tag-warning\">Code 3xx/autres</span>
          <span class=\"tag tag-danger\">Code 4xx/5xx</span>
          <span class=\"tag tag-success\">Occurrences > 10</span>
          <span class=\"tag tag-info\">Occurrences 1-10</span>
          <span class=\"tag tag-warning\">Aucune occurrence</span>
        </div>
      </div>
    </div>
    
  </div>
</main>

<footer class=\"footer\" role=\"contentinfo\">
  <div class=\"container has-text-centered\">
    <p>Projet encadré - La vie multilingue des mots sur le web</p>
    <p class=\"is-size-7 mt-2\">© 2025/2026 - Master TAL | Université Paris Cité - INALCO - Université Paris Nanterre</p>
    <p class=\"is-size-7 mt-1\">
      <a href=\"../mentions-legales.html\" style=\"color: var(--lavande); text-decoration: underline;\">Mentions légales</a> | 
      <a href=\"../contact.html\" style=\"color: var(--lavande); text-decoration: underline;\">Contact</a>
    </p>
  </div>
</footer>

<script>
  // Script pour le menu burger
  document.addEventListener('DOMContentLoaded', () => {
    const navbarBurgers = document.querySelectorAll('.navbar-burger');
    
    navbarBurgers.forEach(burger => {
      burger.addEventListener('click', () => {
        const targetId = burger.dataset.target;
        const target = document.getElementById(targetId);
        
        burger.classList.toggle('is-active');
        target.classList.toggle('is-active');
        
        const isExpanded = burger.getAttribute('aria-expanded') === 'true';
        burger.setAttribute('aria-expanded', !isExpanded);
      });
    });
  });
</script>

</body>
</html>" >> "$html_out"

echo "✅ Tableau généré avec succès : $html_out" >&2
echo "📊 Statistiques :" >&2
echo "   - URLs traitées : $total_urls" >&2
echo "   - Pages aspirées (200 OK) : $urls_success ($taux_success%)" >&2
echo "   - Total mots : $total_mots" >&2
echo "   - Total occurrences : $total_occurrences" >&2
