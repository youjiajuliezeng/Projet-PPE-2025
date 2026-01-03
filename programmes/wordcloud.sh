#!/usr/bin/bash
# Script: generate_wordcloud.sh
# Usage: ./generate_wordcloud.sh [fr|en|zh]

BASE_DIR="../wordcloud"
TEXTS_DIR="../dumps-text"
PROGRAMMES_DIR="../programmes"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <fr|en|zh>"
    exit 1
fi

LANG="$1"

case $LANG in
    fr)
        STOPWORDS="$BASE_DIR/stopwords/stopwords_fr.txt"
        OUTPUT="$BASE_DIR/images/wordcloud_fr.png"
        FILES_PATTERN="fr-*.txt"
        FONT="/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf"
        ;;
    en)
        STOPWORDS="$BASE_DIR/stopwords/stopwords_en.txt"
        OUTPUT="$BASE_DIR/images/wordcloud_en.png"
        FILES_PATTERN="en-*.txt"
        FONT="/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf"
        ;;
    zh)
        STOPWORDS="$BASE_DIR/stopwords/stopwords_zh.txt"
        OUTPUT="$BASE_DIR/images/wordcloud_zh.png"
        FILES_PATTERN="zh-*.txt"
        FONT="/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
        ;;
    *)
        echo "Langue non reconnue: $LANG"
        exit 1
        ;;
esac

# Vérifications minimales
if [ ! -f "$STOPWORDS" ]; then
    echo "Fichier stopwords manquant: $STOPWORDS"
    exit 1
fi

if ! command -v wordcloud_cli &> /dev/null; then
    echo "wordcloud_cli non installé. pip install wordcloud"
    exit 1
fi

FILE_COUNT=$(ls -1 "$TEXTS_DIR"/$FILES_PATTERN 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "Aucun fichier $FILES_PATTERN dans $TEXTS_DIR/"
    exit 1
fi

echo "Génération du nuage de mots pour $LANG ($FILE_COUNT fichiers)..."

# Traitement selon la langue
if [ "$LANG" = "zh" ]; then
    # Chinois : utiliser tokenize_chinese.py
    TEMP_COMBINED="/tmp/zh_combined_$$.txt"
    TEMP_TOKENIZED="/tmp/zh_tokenized_$$.txt"

    cat "$TEXTS_DIR"/$FILES_PATTERN > "$TEMP_COMBINED"

    if [ -f "$PROGRAMMES_DIR/tokenize_chinese.py" ]; then
        python3 "$PROGRAMMES_DIR/tokenize_chinese.py" "$TEMP_COMBINED" > "$TEMP_TOKENIZED"
        INPUT="$TEMP_TOKENIZED"
    else
        # Fallback simple
        sed "s/[。，；：！？、,.!?;:'’]/\n/g" "$TEMP_COMBINED" | grep -v '^$' > "$TEMP_TOKENIZED"
        INPUT="$TEMP_TOKENIZED"
    fi

    # Génération
    wordcloud_cli \
        --text "$INPUT" \
        --imagefile "$OUTPUT" \
        --stopwords "$STOPWORDS" \
        --background white \
        --width 1200 \
        --height 800 \
        --contour_width 2 \
        --contour_color "#87CEEB" \
        --mask ../wordcloud/mask.png \
        --margin 0 \
        --fontfile "$FONT" \
        --colormap "plasma"\
        --max_font_size 150 \
        --max_words 200 \
        --min_font_size 10


    rm -f "$TEMP_COMBINED" "$TEMP_TOKENIZED"

else
    # Français/Anglais : traitement simple
    TEXT_CONTENT=$(cat "$TEXTS_DIR"/$FILES_PATTERN | \
        sed "s/[.,!?;:()'’]/ /g" | \
        tr '[:upper:]' '[:lower:]' | \
        tr ' ' '\n' | \
        grep -v '^$')

    # 通过标准输入传递
    echo "$TEXT_CONTENT" | wordcloud_cli \
        --text - \
        --imagefile "$OUTPUT" \
        --stopwords "$STOPWORDS" \
        --background white \
        --width 1200 \
        --height 800 \
        --contour_width 2 \
        --contour_color "#87CEEB" \
        --mask ../wordcloud/mask.png \
        --margin 0 \
        --fontfile "$FONT" \
        --colormap "plasma"\
        --max_font_size 150 \
        --max_words 200 \
        --min_font_size 10
fi

if [ -f "$OUTPUT" ]; then
    echo "✓ Nuage de mots généré: $OUTPUT"
else
    echo "✗ Erreur de génération"
    exit 1
fi
