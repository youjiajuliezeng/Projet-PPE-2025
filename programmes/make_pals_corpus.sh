#!/bin/bash

# make_pals.sh
# Usage : ./make_pals.sh <langue> <dossier>
# Exemples :
#   ./make_pals.sh fr dumps-text
#   ./make_pals.sh zh contextes

if [ $# -ne 2 ]; then
    echo "Usage : $0 <langue> <dossier>"
    echo "Exemples :"
    echo "  $0 fr dumps-text    # Pour les dumps en français"
    echo "  $0 zh contextes     # Pour les contextes en chinois"
    echo "  $0 en dumps-text    # Pour les dumps en anglais"
    exit 1
fi

LANG="$1"
DOSSIER="$2"

# Vérifier le dossier
if [ "$DOSSIER" != "dumps-text" ] && [ "$DOSSIER" != "contextes" ]; then
    echo "Erreur : dossier doit être 'dumps-text' ou 'contextes'"
    exit 1
fi

PROGRAMMES_DIR="programmes"
PALS_DIR="pals"
mkdir -p "$PALS_DIR"

# Déterminer le préfixe du fichier de sortie
if [ "$DOSSIER" = "dumps-text" ]; then
    PREFIXE="dumps-text"
else
    PREFIXE="contextes"
fi

OUTPUT_FILE="$PALS_DIR/${PREFIXE}-${LANG}.txt"
> "$OUTPUT_FILE"

# Compter les fichiers traités
compteur=0

# Traiter chaque fichier correspondant à la langue
for fichier in "${DOSSIER}/${LANG}"-*.txt; do
    if [ ! -f "$fichier" ]; then
        continue
    fi

    compteur=$((compteur + 1))
    echo "Traitement de $fichier"

    # Pour le chinois : utiliser tokenization spéciale
    if [ "$LANG" = "zh" ]; then
        # Créer des fichiers temporaires
        TEMP_FILE="/tmp/temp_${LANG}_$$.txt"

        # Tokenisation chinoise
        if [ -f "$PROGRAMMES_DIR/tokenize_chinese.py" ]; then
            python3 "$PROGRAMMES_DIR/tokenize_chinese.py" "$fichier" > "$TEMP_FILE"
        else
            # Fallback simple pour chinois
            sed 's/[。，；：！？、,.!?;:]/ /g' "$fichier" | \
                tr ' ' '\n' | \
                grep -v '^$' > "$TEMP_FILE"
        fi

        # Formater pour PALS
        set -f
        while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && echo "" >> "$OUTPUT_FILE" && continue

            for word in $line; do
                echo "$word" >> "$OUTPUT_FILE"

            # ligne vide a la fin des phrase
                if [[ "$word" =~ ^[。！？.!?]$ ]]; then
                    echo "" >> "$OUTPUT_FILE"
                fi
            done
        done < "$TEMP_FILE"

        rm -f "$TEMP_FILE"

    else
        # Français/Anglais : traitement standard
        while IFS= read -r ligne; do
            # Nettoyer et séparer les mots
            echo "$ligne" | \
                sed 's/[.,!?;:()]/ /g' | \
                tr '[:upper:]' '[:lower:]' | \
                tr ' ' '\n' | \
                grep -v '^$' >> "$OUTPUT_FILE"
        done < "$fichier"
    fi

    # Ajouter une ligne vide entre les fichiers
    echo "" >> "$OUTPUT_FILE"
done

# Vérifier si des fichiers ont été traités
if [ $compteur -eq 0 ]; then
    echo "Aucun fichier trouvé dans ${DOSSIER}/${LANG}-*.txt"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

echo "Terminé !"
echo "Fichier créé : $OUTPUT_FILE"
echo "$compteur fichiers traités"
