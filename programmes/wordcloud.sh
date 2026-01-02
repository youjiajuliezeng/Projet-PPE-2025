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
        STOPWORDS="$BASE_DIR/stopwords_français.txt"
        OUTPUT="$BASE_DIR/wordcloud_français.png"
        FILES_PATTERN="fr-*.txt"  # 法语文件
        FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        ;;
    en)
        STOPWORDS="$BASE_DIR/stopwords_anglais.txt"
        OUTPUT="$BASE_DIR/wordcloud_anglais.png"
        FILES_PATTERN="en-*.txt"   # 英语文件
        FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        ;;
    zh)
        STOPWORDS="$BASE_DIR/stopwords_chinois.txt"
        OUTPUT="$BASE_DIR/wordcloud_chinois.png"
        FILES_PATTERN="zh-*.txt"   # 中文文件
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
        sed 's/[。，；：！？、,.!?;:]/\n/g' "$TEMP_COMBINED" | grep -v '^$' > "$TEMP_TOKENIZED"
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
        --max_words 200 \
        --fontfile "$FONT" \
        --colormap "viridis"

    rm -f "$TEMP_COMBINED" "$TEMP_TOKENIZED"

else
    # Français/Anglais : traitement simple
    TEMP_PROCESSED="/tmp/${LANG}_processed_$$.txt"

    # 使用对应语言的文件
    cat "$TEXTS_DIR"/$FILES_PATTERN | \
        sed 's/[.,!?;:()]/ /g' | \
        tr '[:upper:]' '[:lower:]' | \
        tr ' ' '\n' | \
        grep -v '^$' > "$TEMP_PROCESSED"

    # Génération
    wordcloud_cli \
        --text "$TEMP_PROCESSED" \
        --imagefile "$OUTPUT" \
        --stopwords "$STOPWORDS" \
        --background white \
        --width 1200 \
        --height 800 \
        --max_words 150 \
        --fontfile "$FONT" \
        --colormap "plasma"

    rm -f "$TEMP_PROCESSED"
fi

if [ -f "$OUTPUT" ]; then
    echo "✓ Nuage de mots généré: $OUTPUT"
else
    echo "✗ Erreur de génération"
    exit 1
fi
