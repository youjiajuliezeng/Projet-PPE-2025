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
        --context-length 2 \
        --match-mode regex \
        | grep -v -E "^(the|of|and|to|a|in|that|is|are|was|were|be|been|being|have|has|had|having|with|as|by|for|at|on|but|or|not|it|its|it's|he|him|his|she|her|they|them|their|about|we|can|your|my|our|someone|3|1|2|4|5|if|which|into|within|may|using|during|between|such|where|most|while|do|how|does|this|use|down|behind|would|cannot|from|work|these|why|an|because|i|only|whether|now|should|when|really|other|some|ever|often|also|another|see|says|still|just|could)\s" \
        > "$OUTPUT_FILE"

elif [ "$LANG" = "fr" ]; then
    if [ "$DOSSIER" = "dumps-text" ]; then
        OUTPUT_FILE="./pals/analyse-dumps-text-fr.tsv"
    else
        OUTPUT_FILE="./pals/analyse-contextes-fr.tsv"
    fi

    python3 ./programmes/cooccurrents.py --target "[Rr]êv(e|es|er|ant|a|ait|ée|ées|é|és)" "$INPUT_FILE" \
        -N 200 \
        --context-length 2 \
        --match-mode regex \
        | grep -v -E "^(ai|alors|après|au|aux|avoir|bien|car|ce|cela|celui|ces|cette|chez|comment|dans|de|des|deux|dit|donc|dont|du|elle|elles|en|entre|est|et|était|été|eux|fait|faire|il|ils|je|la|le|lequel|les|leur|leurs|lui|ma|mais|mes|moi|mon|ne|non|nos|notre|nous|on|ont|ou|où|par|pas|peu|peut|pendant|plus|plusieurs|pour|pourquoi|qu|que|qui|sa|sans|se|ses|si|sont|sur|ta|tant|tel|ton|tous|tout|travers|tu|un|une|ve|vos|votre|vous|aussi|son|comme|j|n|serait|être|p|ainsi|3|a|ici|devient|5|quand|contenu|souvent|également|mieux|propos|parfois|4|jamais|cas|2|autres|avec|selon|y|même|c|s|d|à|l)\s" \
        > "$OUTPUT_FILE"

elif [ "$LANG" = "zh" ]; then
    if [ "$DOSSIER" = "dumps-text" ]; then
        OUTPUT_FILE="./pals/analyse-dumps-text-zh.tsv"
    else
        OUTPUT_FILE="./pals/analyse-contextes-zh.tsv"
    fi

    python3 ./programmes/cooccurrents.py --target "梦" "$INPUT_FILE" \
        -N 200 \
        --context-length 4 \
        --match-mode regex \
        | grep -v -E '^(的|了|是|在|和|与|中|有|为|对|而|但|也|又|并|这个|那个|一种|一些|会|回|”|“|，|:|《|》|;|(|)|、|。|里|做“|”|虽|如|之|前|场|：|以|一个|自己|《|大|就|一|新|我|都|到|你|不|、|。)\s' \
        > "$OUTPUT_FILE"

else
    echo "Erreur : langue non supportée. Seules 'en', 'fr', 'zh' sont supportées"
    exit 1
fi

echo "Analyse terminée : $OUTPUT_FILE"
