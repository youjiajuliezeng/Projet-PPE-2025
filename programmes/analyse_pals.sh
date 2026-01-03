#!/bin/bash

# analyse_pals.sh
# Usage : ./analyse_pals.sh <langue> <dossier>
# Exemples :
#   ./analyse_pals.sh en dumps-text
#   ./analyse_pals.sh fr contextes
#   ./analyse_pals.sh zh dumps-text

if [ $# -ne 2 ]; then
    echo "Usage : $0 <langue> <dossier>"
    echo "Exemples :"
    echo "  $0 en dumps-text"
    echo "  $0 fr contextes"
    echo "  $0 zh dumps-text"
    exit 1
fi

LANG="$1"
DOSSIER="$2"

# Vérifier le dossier
if [ "$DOSSIER" != "dumps-text" ] && [ "$DOSSIER" != "contextes" ]; then
    echo "Erreur : dossier doit être 'dumps-text' ou 'contextes'"
    exit 1
fi

PALS_DIR="pals"

# Déterminer le fichier d'entrée
if [ "$DOSSIER" = "dumps-text" ]; then
    INPUT_FILE="$PALS_DIR/dumps-text-${LANG}.txt"
else
    INPUT_FILE="$PALS_DIR/contextes-${LANG}.txt"
fi

# Vérifier si le fichier d'entrée existe
if [ ! -f "$INPUT_FILE" ]; then
    echo "Erreur : fichier $INPUT_FILE introuvable"
    exit 1
fi

# Exécuter l'analyse selon la langue
if [ "$LANG" = "en" ]; then
    if [ "$DOSSIER" = "dumps-text" ]; then
        OUTPUT_FILE="./pals/analyse-dumps-text-en.tsv"
    else
        OUTPUT_FILE="./pals/analyse-contextes-en.tsv"
    fi

    python3 ./programmes/cooccurrents.py --target "[Dd]ream(s|ed|ing|t)?" "$INPUT_FILE" \
        -N 200 \
        --min-cofrequency 5 \
        --min-frequency 10 \
        --match-mode regex \
        | grep -v -E "^(the|of|and|to|a|in|that|is|are|was|were|be|been|being|have|has|had|having|with|as|by|for|at|on|but|or|not|it|its|it's|he|him|his|she|her|they|them|their|about|we|can)\s" \
        > "$OUTPUT_FILE"

elif [ "$LANG" = "fr" ]; then
    if [ "$DOSSIER" = "dumps-text" ]; then
        OUTPUT_FILE="./pals/analyse-dumps-text-fr.tsv"
    else
        OUTPUT_FILE="./pals/analyse-contextes-fr.tsv"
    fi

    python3 ./programmes/cooccurrents.py --target "[Rr]êv(e|es|er|ant|a|ait|ée|ées|é|és)" "$INPUT_FILE" \
        -N 200 \
        --min-cofrequency 5 \
        --min-frequency 10 \
        --match-mode regex \
        | grep -v -E "^(le|la|les|de|des|du|et|à|en|que|qui|dans|pour|sur|avec|par|est|son|ses|ces|cette|pas|plus|comme|mais|ou|où|si|ne|se|ce|il|elle|ils|elles|lui|leur|eux|je|tu|nous|vous|on|un|une|moi|sont|leurs|leur|notre|votre|ma|mon|ta|ton|sa|)\s" \
        > "$OUTPUT_FILE"

elif [ "$LANG" = "zh" ]; then
    if [ "$DOSSIER" = "dumps-text" ]; then
        OUTPUT_FILE="./pals/analyse-dumps-text-zh.tsv"
    else
        OUTPUT_FILE="./pals/analyse-contextes-zh.tsv"
    fi

    python3 ./programmes/cooccurrents.py --target "梦" "$INPUT_FILE" \
        -N 200 \
        --min-cofrequency 5 \
        --min-frequency 10 \
        --match-mode regex \
        | grep -v -E '^(的|了|是|在|和|与|中|有|为|对|而|但|也|又|并|这个|那个|一种|一些|会|回|"|"|，|里|做)\s' \
        > "$OUTPUT_FILE"

else
    echo "Erreur : langue non supportée. Seules 'en', 'fr', 'zh' sont supportées"
    exit 1
fi

echo "Analyse terminée : $OUTPUT_FILE"
