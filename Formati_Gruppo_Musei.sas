libname library "/home/u64184487/PROJECT WORK SAS";

/* Decodifica dei valori assegnati nel dataset per migliore leggibilità */
proc format library = library;
    
  value $gest_fmt
    "1" = "Pubblico"
    "2" = "Privato";
    
  value $tipol_fmt
    "1" = "Arte: da Medioevo a Ottocento"
    "2" = "Arte: Moderna e Contemporanea" 
    "3" = "Religione e Culto"
    "4" = "Archeologia"
    "5" = "Storia"
    "6" = "Storia Naturale e Scienze Naturali"
    "7" = "Scienza e Tecnica"
    "8" = "Etnografia e Antropologia"
    "9" = "Tematico e/o Specializzato"
    "10" = "Industriale e/o d'Impresa"
    "11" = "Casa Museo/Casa della Memoria"
    "12" = "Altro Tipo (Museo)"
    "13" = "Area Archeologica"
    "14" = "Parco Archeologico"
    "15" = "Altro Tipo (Area Archeologica)"
    "16" = "Chiesa/Edificio a Carattere Religioso"
    "17" = "Villa-Palazzo di interesse Storico-Artistico"
    "18" = "Parco-Giardino di interesse Storico-Artistico"
    "19" = "Architettura Fortificata/Militare"
    "20" = "Architettura Civile di interesse Storico-Artistico"
    "21" = "Manufatto Archeologico"
    "22" = "Manufatto di  Archeologia Industriale"
    "23" = "Altro Tipo (Monumento)"
    "24" = "Istituto che espone viventi animali/vegetali"
    "25" = "Istituto che organizza esposizioni/mostre temporanee"
    "26" = "Istituto non destinato a pubblica fruizione"
    "27" = "Istituto con attività non prettamente espositive"
    "28" = "Istituto con attività prevalentemente commerciale"
    "29" = "Istituto privo di modalità organizzata di visita";
  
  value $catego_fmt  
    "1" = "Museo, galleria e/o raccolta"
    "2" = "Area/Parco Archeologico" 
    "3" = "Monumento/Complesso Monumentale"
    "4" = "Ecomuseo";
    
  value $grt_fmt
    "1" = "Accesso completamente gratuito"
    "2" = "Previste forme di pagamento"; 
    
  value visitfmt
    low - <10001 = '1: 0-10k'
    10001 - <50001 = '2: 10k-50k'
    50001 - <100001 = '3: 50k-100k'
    100001 - <500001 = '4: 100k-500k'
    500001 - high = '5: >500k';
    
   value pochivisitfmt
    low - <1001 = '1: 0-1k'
    1001 - <5001 = '2: 1k-5k'
    5001 - <10001 = '3: 5k-10k'
    10001 - <50001 = '4: 10k-50k'
    50001 - high = '5: >50k';

    value regio_fmt
        1 = "Lazio"
        2 = "Toscana"
        3 = "Campania"
        4 = "Veneto"
        5 = "Lombardia"
        6 = "Piemonte"
        7 = "Sicilia"
        8 = "Emilia-Romagna"
        9 = "Trentino-Alto Adige"
        10 = "Friuli-Venezia Giulia"
        11 = "Sardegna"
        12 = "Umbria"
        13 = "Marche"
        14 = "Liguria"
        15 = "Puglia"
        16 = "Calabria"
        17 = "Valle d'Aosta"
        18 = "Basilicata"
        19 = "Abruzzo"
        20 = "Molise";

run;