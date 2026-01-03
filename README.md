# Bienvenue à la RÊVERIE 💤
Cliquez pour explorer chez les rêveuses :  
  
## Contributeuses
Voici les chercheuses de rêve avec ses profils GitHub :  
- ZHENG Ting (Paris Nanterre) - https://github.com/ZHENGTING-oss  er
- LEBAIL Emmy (Inalco) - https://github.com/emmylebail  
- ZENG Youjia (Sorbonne Nouvelle) - https://github.com/youjiajuliezeng  

## Description du projet
Le projet est réalisé dans le cadre du cours « La vie multilingue des mots sur le web » et a pour objectif d’étudier à partir de corpus web les usages du mot « rêve », dream en anglais et 梦 en chinois.  

Le travail repose sur une démarche progressive combinant collecte automatique de données, traitement linguistique, et visualisation des résultats.

### Choix du mot & Hypothèse
- Possibilité de recherche
Le choix du mot « rêve » est pris premièrement grâce à son avantage de posséder, dans les trois langues étudiées, un équivalent lexical clair et relativement stable, renvoyant à une notion identifiable et partageable, ce qui en fait un objet particulièrement propice à une analyse comparative.  

- Valeur de comparaison
Par ailleurs, à partir des expressions et des théories liées, on considère la recherche comme pertinente et heuristique, parce que l’étude comparative du mot rêve / dream / 梦 permet non seulement d’analyser des usages lexicaux, mais aussi d’entrevoir des différences culturelles et des systèmes de valeurs distincts, tout en mettant en évidence des préoccupations humaines partagées.
En chinois, le terme « 梦 » apparaît fréquemment dans des expressions à forte portée collective et institutionnelle, telles que « 中国梦 » (le rêve chinois), associée à des enjeux nationaux, historiques et idéologiques.  
En anglais, le mot dream est fortement ancré dans des expressions emblématiques comme the American Dream ou le discours I have a dream, où le rêve renvoie principalement à des aspirations individuelles, à l’accomplissement personnel et à la projection d’un avenir souhaité à l’échelle du sujet.  
Dans le contexte francophone, le mot « rêve » occupe une place centrale dans les discours philosophiques, littéraires et esthétiques, par exemple la conscience et la perception chez Descartes, ainsi que dans les mouvements littéraires et artistiques tels que le surréalisme.

- Hypothèse
À partir de ces observations, nous formulons l’hypothèse que les usages du mot rêve / dream / 梦 varient selon les langues et les contextes culturels :  
Dans les corpus chinois, le terme tendrait à être employé dans des contextes collectifs, macrosociaux ou nationaux.  
Dans les corpus anglophones, il serait plus fréquemment associé à des projets individuels, à la réussite personnelle et à la réalisation de soi.  
Dans les corpus francophones, le mot rêve apparaîtrait davantage dans des contextes réflexifs, philosophiques ou littéraires, liés à l’imaginaire, à la subjectivité et à la pensée abstraite.  

### Constitution du corpus web & Extraction de contextes
À partir de fichiers d’URLs sélectionnées pour chaque langue, le script [script_multi](programmes/script_multi.sh) permet :
- l’aspiration automatique des pages web
- la récupération des codes HTTP et des informations d’encodage
- la sauvegarde des pages HTML originales
- l’extraction du contenu textuel sous forme de dumps nettoyés
Cette étape permet de constituer un corpus exploitable et comparable entre les différentes langues.  
  
Par la suite, le mot étudié (rêve / dream / 梦) est recherché à l’aide d’expressions régulières adaptées aux spécificités de chaque langue :  
- variations morphologiques en français et en anglais (genre (masculin / féminin),  nombre (singulier / pluriel), forme verbale (infinitif, participe))
- absence de frontière de mot en chinois
Pour chaque page, le programme calcule :  
- le nombre d’occurrences du mot cible
- des extraits de contexte dans une fenêtre définie autour de chaque occurrence
À partir de ces contextes, une concordance de type KWIC (contexte gauche / cible / contexte droit) est générée automatiquement, facilitant l'analyse qualitative suivante.

### Analyse quantitative & Visualisation
Dans une étape ultérieure, le projet intègre une analyse PALS par le script [make_pals_corpus](programmes/make_pals_corpus.sh) afin de regrouper et aligner les différentes formes morphologiques du mot, en considérant la segmentation des caractères en mots pour le chinois, ainsi que la normalisation (minuscules) et isolation de la ponctuation pout le français et l'anglais. Le script [analyse_pals.sh](programmes/analyse_pals.sh) regroupe ensuite les formes morphologiques, identifie les cooccurrences significatives et calcule les fréquences et spécificités.  

À partir des données de fréquence et de cooccurrence, des nuages de mots (word clouds) sont générés pour chaque langue par le script [wordcloud](programmes/wordcloud.sh). Ces visualisations offrent une synthèse graphique des environnements lexicaux du mot étudié et facilitent la comparaison entre les corpus.

### Analyse qualitative & Restitution sous forme de site web
À partir des analyses de cooccurrence et des nuages de mots,  **   

L’ensemble des résultats est organisé et présenté sous forme de site web par le script ** , y compris les tableaux récapitulatifs, les résultats des analyses PALS, les nuages de mots associés à chaque langue et les analyses.
 

























