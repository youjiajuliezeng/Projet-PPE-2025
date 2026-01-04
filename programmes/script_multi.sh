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

# En-tête HTML (même que précédemment, mais je raccourcis pour la lisibilité)
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
<div>
</div>
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
          <div class=\"stats-value\">"$mot_regex"</div>
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

  # Créer les fichiers temporaires
  headers_tmp="$(mktemp)"
  body_tmp="$(mktemp)"
  
  # Requête HTTP avec gestion d'erreur
  code_http="$(curl -s -L --max-time 30 -D "$headers_tmp" -o "$body_tmp" -w "%{http_code}" "$url" 2>/dev/null || echo "000")"
  
  # Lire l'encodage AVANT de supprimer le fichier headers_tmp
  encodage="$(cat "$headers_tmp" | tr '\r' '\n' | grep -i '^content-type:' | grep -ioE 'charset=[^;[:space:]]+' | head -n 1 | cut -d= -f2)"
  rm -f "$headers_tmp"
  if [ -z "$encodage" ]
  then
    encodage=$(grep -E -o "charset=[^\"'> ]*" "$body_tmp" | head -1 | tr -d "/>" | cut -d= -f2)
  fi
  
  [[ -z "$encodage" ]] && encodage="none"

  # Sauvegarder la page aspirée seulement si le fichier temporaire existe
  if [[ -f "$body_tmp" ]] && [[ -s "$body_tmp" ]]; then
    mv "$body_tmp" "$aspiration"
  else
    # Créer un fichier vide si le téléchargement a échoué
    echo "<!-- Échec du téléchargement -->" > "$aspiration"
    rm -f "$body_tmp" 2>/dev/null
  fi

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
          <td><span class=\"tag tag-info\">$encodage</span></td>
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

  # Dump texte (lynx) - Forcer la sortie UTF-8
    # Essayer de convertir l'encodage d'abord
    if [[ "$encodage" != "none" ]] && [[ "$encodage" != "UTF-8" ]] && [[ "$encodage" != "utf-8" ]]; then
        # Traitement spécial pour GB2312/GBK
        if [[ "$encodage" == "gb2312" ]] || [[ "$encodage" == "gbk" ]] || [[ "$encodage" == "GB2312" ]] || [[ "$encodage" == "GBK" ]]; then
            iconv -f GBK -t UTF-8//IGNORE "$aspiration" 2>/dev/null | lynx -dump -nolist -stdin 2>/dev/null > "$dump" || true
        else
            # Essayer de convertir d'autres encodages
            iconv -f "$encodage" -t UTF-8//IGNORE "$aspiration" 2>/dev/null | lynx -dump -nolist -stdin 2>/dev/null > "$dump" || true
        fi
    fi

    # Si la méthode ci-dessus échoue ou si la conversion n'est pas nécessaire, utiliser la méthode par défaut
    if [[ ! -s "$dump" ]]; then
        lynx -dump -nolist -assume_charset=UTF-8 -display_charset=UTF-8 "$aspiration" 2>/dev/null > "$dump" || true
    fi

    # Finalement, s'assurer que le fichier est en UTF-8
    if command -v uconv &> /dev/null; then
        # Utiliser uconv (si disponible) pour une conversion plus sûre
        uconv -f UTF-8 -t UTF-8//IGNORE "$dump" -o "$dump.tmp" 2>/dev/null && mv "$dump.tmp" "$dump"
    elif command -v iconv &> /dev/null; then
        # Utiliser iconv
        iconv -f UTF-8 -t UTF-8//IGNORE "$dump" -o "$dump.tmp" 2>/dev/null && mv "$dump.tmp" "$dump"
    fi

  # Dump texte (lynx) - avec gestion d'erreur
  if [[ "$encodage" != "none" ]] && [[ "$encodage" != "UTF-8" ]] && [[ "$encodage" != "utf-8" ]]; then
    if [[ -f "$aspiration" ]]; then
      lynx -dump -nolist -assume_charset="$encodage" -display_charset=UTF-8 "$aspiration" 2>/dev/null > "$dump" || true
    fi
  else
    if [[ -f "$aspiration" ]]; then
      lynx -dump -nolist -assume_charset=UTF-8 -display_charset=UTF-8 "$aspiration" 2>/dev/null > "$dump" || true
    fi

  fi

  # Nombre de mots - vérifier si le fichier existe
  if [[ -f "$dump" ]]; then
    nb_mots="$(wc -w < "$dump" 2>/dev/null | tr -d '[:space:]' || echo "0")"
  else
    nb_mots="0"
    # Créer un fichier dump vide
    echo "" > "$dump"
  fi
  [[ -z "$nb_mots" ]] && nb_mots="0"
  total_mots=$((total_mots + nb_mots))

  # Occurrences - vérifier si le fichier existe et n'est pas vide
  occurrences="0"
  if [[ -f "$dump" ]] && [[ -s "$dump" ]]; then
    if [[ "$is_zh" -eq 1 ]]; then
      occurrences="$(grep -Eo "$mot_regex_bounded" "$dump" 2>/dev/null | wc -l 2>/dev/null | tr -d '[:space:]' || echo "0")"
    else
      occurrences="$(grep -Eoi "$mot_regex_bounded" "$dump" 2>/dev/null | wc -l 2>/dev/null | tr -d '[:space:]' || echo "0")"
    fi
  fi
  [[ -z "$occurrences" ]] && occurrences="0"
  total_occurrences=$((total_occurrences + occurrences))

  # Extraction des contextes
  if [[ -f "$dump" ]] && [[ -s "$dump" ]]; then
    if [[ "$is_zh" -eq 1 ]]; then
      grep -Eo ".{0,${ctx_chars}}${mot_regex}.{0,${ctx_chars}}" "$dump" 2>/dev/null > "$contexte" || true
    else
      grep -Eio ".{0,${ctx_chars}}${mot_regex}.{0,${ctx_chars}}" "$dump" 2>/dev/null > "$contexte" || true
    fi
  else
    echo "" > "$contexte"
  fi

  # Concordance (gauche / cible / droite) - version simplifiée
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
<body>

  <div>
  </div>
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
      ctxline="$(echo "$ctxline" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
      
      if [[ "$is_zh" -eq 1 ]]; then
        gauche="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, 1, RSTART-1); }' 2>/dev/null || echo "")"
        cible="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, RSTART, RLENGTH); }' 2>/dev/null || echo "")"
        droit="$(echo "$ctxline" | awk -v re="$mot_regex" '{ if (match($0, re)) print substr($0, RSTART+RLENGTH); }' 2>/dev/null || echo "")"
      else
        gauche="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, 1, RSTART-1); }' 2>/dev/null || echo "")"
        cible="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, RSTART, RLENGTH); }' 2>/dev/null || echo "")"
        droit="$(echo "$ctxline" | awk -v re="$mot_regex" 'BEGIN{IGNORECASE=1} { if (match($0, re)) print substr($0, RSTART+RLENGTH); }' 2>/dev/null || echo "")"
      fi
      
      # Échapper les résultats
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

  # Ecriture HTML (tableau principal)
  echo "        <tr>
          <td><strong>$numero</strong></td>
          <td>
            <a href=\"$url\" target=\"_blank\" title=\"$url_escaped\">
              <span class=\"code-url\">$url_escaped</span>
            </a>
          </td>
          <td><span class=\"tag tag-success\">$code_http</span></td>
          <td><span class=\"tag tag-info\">$encodage</span></td>
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

# Fermeture du tableau (même que précédemment)
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
