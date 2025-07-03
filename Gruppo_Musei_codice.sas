/* Creazione della libreria mus */
libname mus '/home/u64184487/PROJECT WORK SAS';
libname library '/home/u64184487/PROJECT WORK SAS';
options fmtsearch=(library);

/* Libreria dei formati */
/* Importazione del dataset Istat contenente le informazioni sui musei */
proc import out=musei_full_2022 
		datafile='/home/u64184487/PROJECT WORK SAS/MUSEI_Microdati_2022.txt' replace 
		dbms=dlm;
	delimiter='09'x;
	getnames=yes;
	guessingrows=max;
run;

/* Prime informazioni sul dataset */
proc contents data=musei_full_2022;
run;

/* DATA CLEANING */
/* Nuova tabella con le colonne principali e rinomina */
data musei_clean;
	set musei_full_2022(keep=Regione Provincia Comune Denominazione Catego Tipol1 
		Pubbpriv Totvisit Visitpag Italiani Stranieri Opengg Accesso 
		rename=(Denominazione=Nome Catego=Categoria Tipol1=Tipologia 
		Pubbpriv=Gestione_Pubblica_Privata Totvisit=Visitatori_Totali 
		Visitpag=Visitatori_Paganti Opengg=Giorni_Apertura_Anno 
		Accesso=Gratuito_Pagamento Italiani=Percentuale_Italiani 
		Stranieri=Percentuale_Stranieri));
	Anno=2022;
	Percentuale_Italiani=Percentuale_Italiani / 100;
	Percentuale_Stranieri=Percentuale_Stranieri / 100;

	/* Sistemazione dei formati numerici */
	format Percentuale_Italiani Percentuale_Stranieri percent8.1;
	format Visitatori_Totali Visitatori_Paganti comma15.;
run;

/* Controllo della distribuzione dei missing values */
proc means data=musei_clean nmiss n;
run;

proc contents data=musei_clean;
run;

/* Variabili alfanumeriche: uniformare i missing values ("N.D." as missing) e formattazione */
data musei_cleaned;
	set musei_clean;

	/* Conversione: numerico → carattere delle variabili categoriche che contengono numeri */
	Gestione_Pubblica_Privata_char=strip(put(Gestione_Pubblica_Privata, best.));
	Categoria_char=strip(put(Categoria, best.));
	Tipologia_char=strip(put(Tipologia, best.));
	Gratuito_Pagamento_char=strip(put(Gratuito_Pagamento, best.));
	drop Gestione_Pubblica_Privata Categoria Tipologia Gratuito_Pagamento;
	rename Gestione_Pubblica_Privata_char=Gestione_Pubblica_Privata 
		Categoria_char=Categoria Tipologia_char=Tipologia 
		Gratuito_Pagamento_char=Gratuito_Pagamento;
	array clean (*) _character_;

	do i=1 to dim(clean);

		if clean(i) in (".", "-", "N.D.") then
			clean(i)=" ";
	end;
	drop i;
run;

/* Formattazione colonne alfanumeriche con i valori della proc format */
data mus.musei;
	set musei_cleaned;
	Gestione_Pubblica_Privata=strip(Gestione_Pubblica_Privata);
	Categoria=strip(Categoria);
	Tipologia=strip(Tipologia);
	Gratuito_Pagamento=strip(Gratuito_Pagamento);
	format Gestione_Pubblica_Privata $gest_fmt.
  Categoria $catego_fmt.
  Tipologia $tipol_fmt.
  Gratuito_Pagamento $grt_fmt.;
run;

/* Controllo del risultato del cleaning su una variabile che non conteneva gli "N.D." come missing values */
proc freq data=mus.musei;
	table Nome;
run;

/* INIZIO ANALISI 2022 /*
/* Distribuzione visite: Italia. Esplorazione preliminare sulla tabella musei */
title "Distribuzione Visitatori";
proc univariate data=mus.musei;
	var Visitatori_Totali;
	histogram Visitatori_Totali / normal;
	inset mean median min max;
run;
title;

/* Risultato: il grafico è estremamente asimmetrico a destra --> visualizzazione non molto efficace
poichè l'elevato numero di visite nei maggiori musei d'Italia impatta troppo nella distribuzione.
La trasformazione in scala logaritmica può aiutare a mostrare meglio i valori */
data mus.musei_visite;
	set mus.musei (drop=Gestione_Pubblica_Privata);

	if Visitatori_Totali > 0 then
		Numero_Visitatori_log=log10(Visitatori_Totali);
run;

/* Esplorazione dopo la conversione in scala logaritmica */
title "Distribuzione logaritmica del numero di Visitatori";
proc univariate data=mus.musei_visite;
	var Numero_Visitatori_log;
	histogram Numero_Visitatori_log;
	inset mean median min max;
run;
title;

/* Visualizzazione dei risultati: grafico con valori  */
title 'Percentuale di Musei per numero Visitatori';

proc sgplot data=mus.musei_visite;
	histogram Numero_Visitatori_log / fillattrs=(color=lightblue);
	xaxis label="Numero di visitatori (log)" values=(0 1 2 3 4 5 6 7) valuesdisplay=("0" 
		"10" "100" "1.000" "10.000" "100.000" "1.000.000" "10.000.000");
	yaxis label="Percentuale di musei";
run;

/* Prima analisi: distribuzione dei musei per area geografica */
/* Import del file Istat sulle macro-regioni territoriali per fare il merge con con il dataset sui musei */
FILENAME istat '/home/u64184487/PROJECT WORK SAS/Codici-statistici-e-denominazioni-al-01_01_2025.xlsx';
;
option VALIDVARNAME=any;

proc import datafile=istat dbms=xlsx out=codifiche_istat replace;
run;

proc contents data=codifiche_istat;
run;

/* Rinomina e conservazione delle variabili di nostro interesse */
data macroregioni;
	set codifiche_istat (keep='Denominazione Regione'n 'Ripartizione geografica'n);
	rename 'Denominazione Regione'n=Regione 
		'Ripartizione geografica'n=Macroregione_Nazionale;
run;

/*  Modifica dei nomi incoerenti con il primo dataset per fare il merge */
data macroregioni;
	set macroregioni;

	if Regione="Valle d'Aosta/Vallée d'Aoste" then
		Regione="Valle d'Aosta/Vallee d'Aoste";

	if Regione="Trentino-Alto Adige/Südtirol" then
		Regione="Trentino-Alto Adige";
run;

/* Ordinamento dei due dataset come operazione preliminare necessaria del merge */
proc sort data=macroregioni nodupkey;
	by Regione;
run;

proc sort data=mus.musei;
	by Regione;
run;

/* Merge step */
data mus.musei;
	merge macroregioni mus.musei;
	by Regione;
run;

/* Distribuzione dei musei per macroarea geografica */
proc freq data=mus.musei;
	table Macroregione_Nazionale;
run;

/* Macro per creazione grafici a torta */
%macro pie(variabile, titolo);
	/* Pattern colori per Pie chart */
	pattern1 color=lightsteelblue;
	pattern2 color=mediumseagreen;
	pattern3 color=lightsalmon;
	pattern4 color=goldenrod;
	title "&titolo.";

	proc gchart data=mus.musei;
		pie &variabile. / coutline=gray55 percent=arrow value=none slice=inside 
			discrete noheading;
		run;
	quit;

	title;
%mend;

%pie(Macroregione_Nazionale, Distribuzione musei per Macroregione);
%pie(Gestione_Pubblica_Privata, Distribuzione musei per Gestione Pubblica o Privata);
%pie(Gratuito_Pagamento, Distribuzione musei per Accesso Gratuito o a Pagamento);

/* Distribuzione dei Musei per Regione */
title 'Distribuzione dei Musei per Regione';

proc freq data=mus.musei;
	table Regione;
run;

title;

/* Distribuzione dei Musei per Regione: Grafico */
proc sgplot data=mus.musei;
	title 'Distribuzione Musei per Regione';
	vbar Regione / categoryorder=respdesc stat=freq fillattrs=(color=CXAA4E4E);
	xaxis label="Regione";
	yaxis label="Numero di Musei";
run;

/* Distribuzione dei Visitatori per Regione: Grafico */
proc sgplot data=mus.musei;
	title 'Distribuzione Visitatori per Regione';
	vbar Regione / categoryorder=respdesc response=Visitatori_Totali stat=sum 
		fillattrs=(color=CX7A9272);
	yaxis label="Numero Visitatori";
	xaxis label="Regione";
run;

/* Rapporto Visitatori-Musei per ciascuna Regione */
data mus.musei;
	set mus.musei;

	if missing(Visitatori_Totali) then
		Visitatori_Totali=0;
run;

proc means data=mus.musei noprint;
	class Regione;
	var Visitatori_Totali;
	output out=temp sum=Totale_Visitatori n=Numero_Musei;
run;

data indice_visitatori;
	set temp;

	if _TYPE_=1;
	Visitatori_per_Museo=Totale_Visitatori / Numero_Musei;
run;

proc sgplot data=indice_visitatori;
	title 'Regioni: Distribuzione Visitatori per Museo';
	hbar Regione / categoryorder=respdesc response=Visitatori_per_Museo 
		fillattrs=(color=CX4C78A8);
	xaxis label="Visitatori per Museo";
	yaxis label="Regione";
run;

/* Distribuzione per Comune */
/* Creazione di una tabella di frequenze */
proc freq data=mus.musei;
	tables Comune / out=musei_comuni;
run;

/* Città: Top 10 per numero musei */
data musei_comuni_maggiori;
	set musei_comuni;
	where count >=30;
run;

/* Visualizzazione della distribuzione dei Musei nelle grandi Città */
title 'Città con il maggior numero di Musei';

proc sgplot data=musei_comuni_maggiori;
	title "Top 10 Città per Numero Musei";
	vbar Comune / response=count categoryorder=respdesc fillattrs=(color=CXAA4E4E);
	xaxis label="Città";
	yaxis label="Numero di Musei";
run;

/* Distribuzione dei Visitatori per Città: Grafico */
/* Somma visitatori per Comune */
proc sort data=mus.musei out=mus_sorted;
	by Comune;
run;

data visitatori_per_comune;
	set mus_sorted;
	by Comune;

	if first.Comune then
		TotVisitatori=0;
	TotVisitatori + Visitatori_Totali;

	if last.Comune then
		output;
	keep Comune TotVisitatori;
run;

/* Ordina per TotVisitatori decrescente */
proc sort data=visitatori_per_comune out=visitatori_ordinati;
	by descending TotVisitatori;
run;

/* Città: Top 10 per Numero visitatori */
data top_comuni_visitatori;
	set visitatori_ordinati;

	if _N_ <=10;
run;

proc sgplot data=top_comuni_visitatori;
	title "Top 10 Città per Numero Visitatori";
	vbar Comune / categoryorder=respdesc response=TotVisitatori 
		fillattrs=(color=CX7A9272);
	yaxis label="Visitatori";
	xaxis label="Città";
run;

/* Città: rapporto Visitatori-Numero Musei */
proc means data=mus.musei noprint;
	class Comune;
	var Visitatori_Totali;
	output out=temp_comuni sum=Totale_Visitatori n=Numero_Musei;
run;

data indice_comuni;
	set temp_comuni;

	if _TYPE_=1;

	/* solo aggregazioni per Comune */
	Visitatori_per_Museo=Totale_Visitatori / Numero_Musei;
run;

proc sort data=indice_comuni out=comuni_top;
	by descending Visitatori_per_Museo;
run;

proc sgplot data=comuni_top(obs=10);
	/* Mostra solo le top 10 */
	title "Top 10 Città - Visitatori per Museo";
	hbar Comune / response=Visitatori_per_Museo categoryorder=respdesc 
		fillattrs=(color=CX4C78A8);
	xaxis label="Visitatori per Museo";
	yaxis label="Città";
run;

/* Analisi distribuzione visitatori per Categoria */
/* Calcola il totale dei visitatori per ogni combinazione di Provincia e Categoria */
proc summary data=mus.musei nway;
	class Provincia Categoria;
	var Visitatori_Totali;
	output out=totale_visitatori_provincia (drop=_FREQ_ _TYPE_) 
		sum=Visitatori_Totali;
run;

/* Visualizza la frequenza assoluta per ciascuna categoria */
proc freq data=mus.totale_visitatori_provincia;
	tables Categoria / nocum nopercent;
run;

/* Importa lo shapefile delle province italiane */
proc mapimport 
		datafile="/home/u64184487/PROJECT WORK SAS/ProvCM01012022_g_WGS84.shp" 
		out=province_map;
run;

/* Controlla la struttura del dataset della mappa */
proc contents data=province_map;
run;

/* Rinomina variabile Provincia per merge*/
data mus.province_map;
	set province_map;
	rename DEN_UTS=Provincia;
run;

/* Standardizzazione lunghezza Provincia */
data totale_visitatori_provincia;
	length Provincia $50;
	set totale_visitatori_provincia;
run;

/* Standardizzazione nomi tra i due dataset */
data totale_visitatori_provincia;
	set totale_visitatori_provincia;

	if Provincia='Massa-Carrara' then
		Provincia='Massa Carrara';
	else if Provincia='Bolzano/Bozen' then
		Provincia='Bolzano';
	else if Provincia='Reggio Calabria' then
		Provincia='Reggio di Calabria';
	else if Provincia="Valle d'Aosta/Vallee d'Aoste" then
		Provincia='Aosta';
run;

/* Suddivide il dataset in tre dataset distinti in base alla Categoria:
- 1: Musei
- 2: Parchi archeologici
- 3: Monumenti */
data cat_museo cat_monumento cat_parco_archeologico;
	set totale_visitatori_provincia;

	if Categoria=1 then
		output cat_museo;
	else if Categoria=2 then
		output cat_parco_archeologico;
	else if Categoria=3 then
		output cat_monumento;
run;

/* Creazione macro per la creazione mappe */
%macro mappa(cat, intestazione, fmt=visitfmt);
	data &cat._fmt;
		set &cat.;
		range=put(Visitatori_Totali, &fmt..);
	run;

	/* Definizione dei colori in scala di blu */
	pattern1 v=msolid c=CXDEEBF7;
	pattern2 v=msolid c=CX9ECAE1;
	pattern3 v=msolid c=CX6BAED6;
	pattern4 v=msolid c=CX4292C6;
	pattern5 v=msolid c=CX08306B;
	title "Visitatori per &intestazione.";

	proc gmap data=&cat._fmt map=mus.province_map all;
		id Provincia;
		choro range / discrete;
		run;
	quit;

	title;
%mend;

%mappa(cat_museo, categoria 'Museo, galleria e/o raccolta');
%mappa(cat_parco_archeologico, categoria 'Area/Parco Archeologico');
%mappa(cat_monumento, categoria 'Monumento/Complesso Monumentale');

proc sort data=totale_visitatori_provincia;
	by Provincia descending Visitatori_Totali;
run;

data cat_principale;
	set totale_visitatori_provincia;
	by Provincia;

	if first.Provincia;
run;

/* Definizione dei colori: 1=Museo, 2=Parco, 3=Monumento */
pattern1 v=s c=CXAA4E4E;

/* Museo */
pattern2 v=s c=CX7A9272;

/* Parco archeologico */
pattern3 v=s c=CX4C78A8;

/* Monumento o complesso monumentale */
title "Visitatori per Categoria di museo ";

proc gmap data=cat_principale map=mus.province_map all;
	id Provincia;
	choro Categoria / discrete;
	run;
	title;

	/* Analisi distribuzione visitatori per Tipologia */
proc summary data=mus.musei(where=(Tipologia ne ".")) nway;
	class Provincia Tipologia;
	var Visitatori_Totali;
	output out=totali_visite_2022 (drop=_TYPE_ _FREQ_) sum=Totale_Visitatori;
run;

/* Standardizzazione lunghezza Provincia (ex-ante) */
data totali_visite_2022;
	length Provincia $50;
	set totali_visite_2022;
	rename Totale_Visitatori=Visitatori_Totali;
run;

/* Creazione dataset tiplogia principale*/
proc sort data=totali_visite_2022;
	by Provincia descending Visitatori_Totali;
run;

data best_tipologia;
	set totali_visite_2022;
	by Provincia;

	if first.Provincia;
run;

/* Standardizzazione nomi (ex-ante) */
data best_tipologia;
	set best_tipologia;

	if Provincia='Massa-Carrara' then
		Provincia='Massa Carrara';
	else if Provincia='Bolzano/Bozen' then
		Provincia='Bolzano';
	else if Provincia='Reggio Calabria' then
		Provincia='Reggio di Calabria';
	else if Provincia="Valle d'Aosta/Vallee d'Aoste" then
		Provincia='Aosta';
run;

/* Creazione grafico*/
title "Tipologia di museo principale per Provincia italiana";

proc gmap data=best_tipologia map=mus.province_map all;
	id Provincia;
	choro Tipologia/ discrete;
	run;
	title;

	/* Tipologia più visitate */
proc summary data=mus.musei(where=(Tipologia ne ".")) nway;
	class Tipologia;
	var Visitatori_Totali;
	output out=top_tipologie (drop=_TYPE_ _FREQ_) sum=Totale_Visitatori;
run;

proc sort data=top_tipologie out=top_tipologie_sorted;
	by descending Totale_Visitatori;
run;

data top_tre;
	set top_tipologie_sorted;

	if _N_ <=3;
run;

/* Suddivide il dataset in due dataset distinti in base alla Categoria:
"1" = "Arte: da Medioevo a Ottocento"
"16" = "Chiesa/Edificio a Carattere Religioso"
"14" = "Parco Archeologico" */
data tip_medioevo tip_chiesa tip_parco_archeologico;
	set totali_visite_2022;

	if Tipologia=1 then
		output tip_medioevo;
	else if Tipologia=16 then
		output tip_chiesa;
	else if Tipologia=14 then
		output tip_parco_archeologico;
run;

proc contents data=tip_chiesa;
run;

%mappa(tip_medioevo, tipologia 'Arte: da Medioevo a Ottocento');
%mappa(tip_chiesa, tipologia 'Chiesa/Edificio a Carattere Religioso');
%mappa(tip_parco_archeologico, tipologia 'Parco Archeologico');

/* FINE 2022 */
/* INIZIO ANALISI TEMPORALE /*

/* Macro per importare tutti i dataset disponibili su Musei_istat */
%macro importa_musei(anno);
	proc import out=musei_full_&anno.
		datafile="/home/u64184487/PROJECT WORK SAS/MUSEI_Microdati_&anno..txt" 
			dbms=dlm replace;
		delimiter='09'x;
		getnames=yes;
		guessingrows=max;
	run;

%mend;

/* Importazione dei dataset storici */
%importa_musei(2021);
%importa_musei(2020);
%importa_musei(2019);
%importa_musei(2018);

/* Fase esplorativa dei dataset: visualizzazione di contenuti e variabili condivisibili in una tabella */
%macro contents(anno);
	proc contents data=musei_full_&anno.;
	run;

%mend;

%contents(2021);

/* Manca variabile Comune e Provincia*/
%contents(2020);
%contents(2019);
%contents(2018);

/* DATA CLEANING /*

/* Creazione colonne Comune e Provincia per l'anno 2021 */
/* Creazione variabile PROCOM per avere match con codifiche Istat */
data musei_2021_norm;
	set musei_full_2021;
	PROV_char=put(PROV, z3.);
	COM_char=put(COM, z3.);
	PROCOM=cats(PROV_char, COM_char);
run;

/* Rinomina delle colonne della tabella codifiche Istat di nostro interesse */
data codifiche_comuni;
	set codifiche_istat(rename=('Codice Comune formato alfanumeri'n=PROCOM 
		'Denominazione in italiano'n=Comune) keep='Codice Comune formato alfanumeri'n 
		'Denominazione in italiano'n);
run;

/* Ordinamento pre-merge, sulla colonna PROCOM */
proc sort data=codifiche_comuni nodupkey;
	by PROCOM;
run;

proc sort data=musei_2021_norm;
	by PROCOM;
run;

/* Merge step: mantiene solo righe di musei_2021_norm */
data musei_full_2021;
	merge musei_2021_norm (in=a) codifiche_comuni;
	by PROCOM;

	if a;
run;

/* Risultato del merge: osservazione distribuzione delle frequenze ed evidenza di missing */
proc freq data=musei_full_2021;
	tables Comune / missing;
run;

/* Ricerca informazioni su Comune dai 2 missing: leggendo la Denominazione del Museo, si può risalire */
proc print data=musei_full_2021;
	where Comune is missing;
run;

/* Assegnazione manuale dei 2 Comuni missing per i PROCOM specifici */
data musei_full_2021;
	set musei_full_2021;

	if PROCOM='025002' and missing(Comune) then
		Comune='Alano di Piave';
	else if PROCOM='092036' and missing(Comune) then
		Comune='Mandas';
run;

/* Province: possiamo ricavarle dal dataset 2022 */
/* Conversione in stringa ed estrazione del Codice Provincia (3 caratteri) */
data province_norm;
	length PROCOM_char $6 PROVINCIA_COD $3;
	set musei_full_2022;
	PROCOM_char=put(PROCOM, z6.);
	PROVINCIA_COD=substr(PROCOM_char, 1, 3);
run;

/* Creazione colonna PROVINCIA_COD sul dataset 2021 */
/* Conversione in formato alfanumerico, preservando le 3 cifre necessarie (aggiungere zeri a sinistra se inferiore) */
data musei_full_2021;
	set musei_full_2021;
	length PROVINCIA_COD $3;
	PROVINCIA_COD=put(PROV, z3.);
run;

/* Ordinamento pre-merge */
proc sort data=province_norm nodupkey;
	by PROVINCIA_COD;
run;

proc sort data=musei_full_2021;
	by PROVINCIA_COD;
run;

/* Merge-step sul Codice Provincia */
data musei_full_2021;
	merge musei_full_2021 (in=a) province_norm (keep=PROVINCIA_COD Provincia);
	by PROVINCIA_COD;

	if a;
run;

/* Verifica frequenze ed eventuali missing (nessun rilevamento di valori mancanti) */
proc freq data=musei_full_2021;
	tables Provincia / missing;
run;

/* Creazione dataset storicizzato 2018-2022*/
/* Macro per operazione preliminare (uniformare colonne) a unione dei dataset  */
%macro musei(anno);
	data musei_clean_&anno.;
		set musei_full_&anno.(keep=Regione Provincia Comune denominazione catego 
			tipol1 totvisit pubbpriv rename=(Denominazione=Nome Catego=Categoria 
			Tipol1=Tipologia Pubbpriv=Gestione_Pubblica_Privata 
			Totvisit=Visitatori_Totali));
		Anno="&anno.";

		/* Conversione: numerico → carattere delle variabili categoriche che contengono numeri */
		Gestione_Pubblica_Privata_char=put(Gestione_Pubblica_Privata, best.);
		Categoria_char=put(Categoria, best.);
		Tipologia_char=put(Tipologia, best.);
		drop Gestione_Pubblica_Privata Categoria Tipologia;
		rename Gestione_Pubblica_Privata_char=Gestione_Pubblica_Privata 
			Categoria_char=Categoria Tipologia_char=Tipologia;
	run;

	data musei_&anno.;
		set musei_clean_&anno.;
		array clean (*) _character_;

		do i=1 to dim(clean);

			if clean(i) in (".", "-", "N.D.") then
				clean(i)=" ";
		end;
		drop i;
	run;

%mend;

%musei(2022);
%musei(2021);
%musei(2020);
%musei(2019);
%musei(2018);

/* Creazione dataset storicizzato: pulizia e standard Nomi Musei e applicazione formati */
data musei_storico_clean;
	length Regione $50 Provincia $50 Comune $50;
	set musei_2022 musei_2021 musei_2020 musei_2019 musei_2018;

	/* Pulizia e standard visuale per la colonna con il Nome dei Musei */
	Nome=strip(upcase(Nome));
	Nome=tranwrd(Nome, "’", "'");
	Nome=tranwrd(Nome, "´", "'");
	Nome=tranwrd(Nome, '"', '');
	Gestione_Pubblica_Privata=strip(Gestione_Pubblica_Privata);
	Categoria=strip(Categoria);
	Tipologia=strip(Tipologia);
	format Visitatori_Totali comma15.
  	Gestione_Pubblica_Privata $gest_fmt.
  	Categoria $catego_fmt.
  	Tipologia $tipol_fmt.;
run;

/* Visualizzazione dei contenuti del nuovo dataset */
proc contents data=musei_storico_clean;
run;

/* Controllo standardizzazione nomi Regioni nel dataset (ex-ante) */
proc freq data=musei_storico_clean;
	tables Regione*Anno / norow nocol nopercent;
	title 'Confronto dei nomi delle Regioni per Anno';
run;

/* Standardizzazione nomi Regioni nel dataset */
data musei_storico_std_reg;
	set musei_storico_clean;
	Regione_std=propcase(Regione);

	/* Standardizzazione delle varianti di "Valle d'Aosta" e "Trentino Alto-Adige" */
	if Regione_std in ("Valle D'aosta", "Valle D'aosta/Valle'e D'aost", 
		"Valle D'aosta/Vallee D'aoste", "Valle D'aosta/Valle'e D'aoste") then
			Regione_std="Valle d'Aosta/Vallee d'Aoste";

	if Regione_std="Trentino-Alto Adige/Sudtirol" then
		Regione_std="Trentino-Alto Adige";

	/* Sovrascrizione della variabile originale */
	drop Regione;
	rename Regione_std=Regione;
run;

/* Controllo standardizzazione nomi Regioni nel dataset (ex-post) */
proc freq data=musei_storico_std_reg;
	tables Regione*Anno / norow nocol nopercent;
	title 'Confronto dei nomi delle Regioni per Anno';
run;

/* Controllo standardizzazione nomi Province nel dataset (ex-ante) */
proc freq data=musei_storico_std_reg;
	tables Provincia*Anno / norow nocol nopercent;
	title 'Confronto dei nomi delle Province per Anno';
run;

/* Standardizzazione nomi Province nel dataset */
data musei_storico_std_prov;
	set musei_storico_std_reg;
	Provincia_std=propcase(Provincia);

	/* Gestione varianti riferite a singole Province (standard di riferimento: dataset 2022) */
	if Provincia_std="Bolzano" then
		Provincia_std="Bolzano/Bozen";

	if Provincia_std="Forli-Cesena" then
		Provincia_std="Forli'-Cesena";

	if Provincia_std in ("Pesaro Urbino", "Pesaro E Urbino") then
		Provincia_std="Pesaro e Urbino";

	if Provincia_std="Reggio Di Calabria" then
		Provincia_std="Reggio Calabria";

	if Provincia_std in ("Valle D'aosta/Valle'e D'aost", 
		"Valle D'aosta/Vallee D'aoste") then
			Provincia_std="Valle D'aosta/Vallee d'Aoste";

	/* Correzione di casi specifici per migliore leggibilità */
	Provincia_std=tranwrd(Provincia_std, "L'aquila", "L'Aquila");
	Provincia_std=tranwrd(Provincia_std, "Monza E Della Brianza", 
		"Monza e della Brianza");
	Provincia_std=tranwrd(Provincia_std, "Reggio Nell'emilia", 
		"Reggio nell'Emilia");

	/* Sovrascrizione della variabile originale */
	drop Provincia;
	rename Provincia_std=Provincia;
run;

/* Controllo uniformità nomi Province nel dataset (ex-post) */
proc freq data=musei_storico_std_prov;
	tables Provincia*Anno / norow nocol nopercent;
	title 'Confronto dei nomi delle Province per Anno';
run;

/* Controllo standardizzazione nomi Comuni nel dataset (ex-ante) */
proc freq data=musei_storico_std_prov;
	tables Comune*Anno / norow nocol nopercent;
	title 'Confronto dei nomi dei Comuni per Anno';
run;

/* Standardizzazione a livello macro della colonna Comune: uniformità caratteri e varianti di Bolzano */
data musei_storico_std_com;
	set musei_storico_std_prov;
	Comune_std=propcase(Comune);

	if Comune_std="Bolzano" then
		Comune_std="Bolzano/Bozen";
run;

/* Controllo effetto: ok, ma granularità molto alta per i nostri scopi di indagine */
proc freq data=musei_storico_std_com;
	tables Comune_std*Anno / norow nocol nopercent;
	title 'Confronto dei nomi dei Comuni per Anno';
run;

/* Calcolo della somma di visitatori per Musei in ogni Comune */
proc summary data=musei_storico_std_com nway;
	class Comune_std;
	var Visitatori_Totali;
	output out=comuni_aggregati (drop=_:) sum=Somma_Visitatori_Totali;
run;

/* Filtro dei Comuni con almeno 1 milione di visitatori cumulati nei 5 anni d'indagine */
data comuni_filtrati;
	set comuni_aggregati;

	if Somma_Visitatori_Totali > 1000000;
run;

/* Ordinamento dei Comuni per maggior numero di visitatori nei propri Musei */
proc sort data=comuni_filtrati;
	by descending Somma_Visitatori_Totali;
run;

/* Visualizzazione dei Comuni che contengono al loro interno Musei che nel complesso sono maggiormente visitati */
proc print data=comuni_filtrati;
	title 'Comuni con oltre 1 milione visitatori totali dal 2018 al 2022';
run;

/* Ordinamento preliminare al merge: scopo etichettare nel dataset storico ciascun record nella colonna Comune
Se Comune tra quelli con maggiori visite: mantenere nome. Altrimenti, aggregazione in classe Altri Comuni */
proc sort data=musei_storico_std_com;
	by Comune_std;
run;

proc sort data=comuni_filtrati;
	by Comune_std;
run;

/* Etichetta: Altri Comuni o Comune_std. Comune acquisisce il cleaning preliminare di Comune_std, che possiamo eliminare
Comune acquisisce il cleaning preliminare di Comune_std, che possiamo eliminare */
data mus.musei_storico;
	merge musei_storico_std_com (in=a) comuni_filtrati (in=b keep=Comune_std);
	by Comune_std;

	if a then
		do;

			if b then
				Comune=Comune_std;
			else
				Comune="A.C. (Altri Comuni)";
		end;
	drop Comune_std;
run;

/* Controllo colonna Comuni (ex-post) */
proc freq data=mus.musei_storico;
	tables Comune*Anno / norow nocol nopercent;
	title 'Confronto dei Comuni (etichettati) per Anno';
run;

/* Verifica bontà scelta strategia di suddivisione: quanto pesano i Comuni con maggiori visite rispetto agli Altri Comuni?
Summary e print per avere idea del peso della categoria Altri Comuni rispetto a quelli Top */
proc summary data=mus.musei_storico nway;
	where Comune="A.C. (Altri Comuni)";
	var Visitatori_Totali;
	output out=visitatori_altri_comuni (drop=_:) sum=Totale_Visitatori_AC;
run;

proc print data=visitatori_altri_comuni;
	title 'Totale visitatori Altri Comuni';
run;

/* Peso dei Comuni Top, con maggiori visite in aggregato nel dataset sui 5 anni */
proc summary data=mus.musei_storico nway;
	where Comune ne "A.C. (Altri Comuni)";
	var Visitatori_Totali;
	output out=visitatori_top (drop=_:) sum=Visitatori_Top;
run;

proc print data=visitatori_top;
	title 'Totale visitatori Comuni Top';
run;

/* Analisi storiche */
/* Andamento visitatori in Italia per anno: ordinamento totale visitatori per anno */
proc sort data=mus.musei_storico;
	by Anno;
run;

/* Somma visitatori per anno con utilizzo del retain, conversione missing in 0 e della scala in milioni per leggibilità */
data musei_storico_visitatori (drop=Visitatori_Totali);
	set mus.musei_storico (keep=anno Visitatori_totali);
	format Somma_visitatori comma12. Somma_visitatori_mln 8.2;
	by Anno;
	retain Somma_Visitatori 0;
	Somma_visitatori_mln=Somma_visitatori / 1e6;

	if Visitatori_totali=. then
		Visitatori_totali=0;
	Somma_Visitatori=Somma_Visitatori + Visitatori_totali;

	if last.Anno then
		do;
			output;
			Somma_Visitatori=0;
		end;
run;

/* Grafico andamento visitatori 2018-2022 in Italia */
title "Totale Visitatori nei musei in Italia (2018–2022)";

proc sgplot data=musei_storico_visitatori;
	series x=anno y=Somma_visitatori_mln / markers datalabel lineattrs=(color=blue 
		thickness=2);
	xaxis label="Anno" values=(2018 to 2022 by 1);
	yaxis label="Totale Visitatori in milioni" values=(0 to 160 by 20);
run;

title;

/* Marcato calo visitatori in presenza del 2020 (effetto Covid): deriva maggiormente da domanda interna o estera? */
/* Manca Indicatore Italiani-Stranieri per il 2020: Istat non lo ha calcolato per quell'anno */
%macro perc_stranieri(anno);
	data freq_&anno.;
		set musei_full_&anno. (keep=totvisit italiani stranieri 
			rename=(Totvisit=Visitatori_Totali Italiani=Percentuale_Italiani 
			Stranieri=Percentuale_Stranieri));
		Anno="&anno.";
	run;

	data freq_str_&anno.;
		set freq_&anno. (keep=Visitatori_Totali Percentuale_Stranieri 
			Percentuale_Italiani anno);
		where not missing(Visitatori_Totali) and not missing(Percentuale_Stranieri);
		Numero_Italiani=round(Visitatori_Totali * (Percentuale_Italiani / 100));
		Numero_Stranieri=round(Visitatori_Totali * (Percentuale_Stranieri / 100));
	run;

	data rapporto_stranieri_&anno.;
		set freq_str_&anno. end=ultima;
		retain Somma_Stranieri Somma_Totali 0;
		Somma_Stranieri + Numero_Stranieri;
		Somma_Totali + Visitatori_Totali;

		if ultima then
			do;
				Rapporto=Somma_Stranieri / Somma_Totali;
				output;
			end;
		keep anno Somma_Stranieri Somma_Totali Rapporto;
	run;

	proc print data=rapporto_stranieri_&anno.;
		format Rapporto percent8.2 Somma_: comma15.;
	run;

%mend;

%perc_stranieri(2018);
%perc_stranieri(2019);
%perc_stranieri(2021);
%perc_stranieri(2022);

data storico_stranieri;
	set rapporto_stranieri_2018 rapporto_stranieri_2019 rapporto_stranieri_2021 
		rapporto_stranieri_2022;
run;

title "Andamento percentuale Turisti Stranieri 2018-2022";

proc sgplot data=storico_stranieri;
	vbar anno / response=Rapporto datalabel fillattrs=(color=cx4A90E2);
	yaxis label="Percentuale Visitatori Stranieri" values=(0 to 1 by 0.1);
	xaxis label="Anno";
	format Rapporto percent8.2;
	inset "Dati mancanti per il 2020" / position=topright border;
run;

title;

/* Analisi storica sulla distribuzione geografica di visitatori */
/* ESTRAZIONE PER MAPPA IN PYTHON */
proc sql;
	create table comuni_52 as select Comune, sum(Visitatori_Totali) as 
		Tot_Visitatori from mus.musei_storico where strip(Comune) ne 
		"A.C. (Altri Comuni)" group by Comune;
quit;

/* Export dataset per creazione mappa in python */
proc export data=comuni_52 outfile="C:\xlwings_wd" dbms=csv replace;
run;

/* PER RISULTATO MAPPA IN PYTHON VEDERE CARTELLA DRIVE */

/* Andamento Storico: Visitatori per Regione */
proc summary data=mus.musei_storico nway;
	class Regione Anno;
	var Visitatori_Totali;
	output out=visitatori_regione_anno (drop=_TYPE_ _FREQ_) sum=Visitatori_Tot_Reg;
run;

proc tabulate data=visitatori_regione_anno format=comma12.0 missing;
	class Anno Regione;
	var Visitatori_Tot_Reg;
	table Regione=' ' , Anno=' ' * Visitatori_Tot_Reg=' ' / misstext='0';
	keylabel Sum=' ';
	title "Totale Visitatori per Anno e Regione";
run;

/* Heatmap visitatori per regione 2018-2022 */
proc sgplot data=visitatori_regione_anno;
	heatmap x=Anno y=Regione / colorresponse=Visitatori_Tot_Reg colormodel=(white 
		lightblue blue darkblue);
	gradlegend / title="Visitatori";
	xaxis discreteorder=data label="Anno";
	yaxis label="Regione";
	title "Visitatori per Regione e Anno";
run;

/* Focus su periodo Covid*/
data vis_regione_2020_2021;
	set visitatori_regione_anno;
	where Anno="2020" or Anno="2021";
run;

proc sgplot data=vis_regione_2020_2021;
	heatmap x=Anno y=Regione / colorresponse=Visitatori_Tot_Reg colormodel=(white 
		lightblue blue darkblue);
	gradlegend / title="Visitatori";
	xaxis discreteorder=data label="Anno";
	yaxis label="Regione";
	title "Visitatori per Regione e Anno: focus periodo Covid";
run;

/* Grafico a barre impilate per Regione-visitatori 2018-2022 */
/* Ottenimento dei nomi ordinati delle Regioni per maggior numero di visitatori (ordine decrescente) */
proc summary data=visitatori_regione_anno nway;
    class Regione;
    var Visitatori_Tot_Reg;
    output out=regioni_somma (drop=_TYPE_ _FREQ_) sum=Totale_Visitatori;
run;

proc sort data=regioni_somma;
    by descending Totale_Visitatori;
run;

proc print data=regioni_somma;
run;

/* Creazione della variabile numerica per avere grafici impilati ordinati */
data regione_numerica;
    set visitatori_regione_anno;
    if Regione = "Lazio"      then regio = 1;
    else if Regione = "Toscana" then regio = 2;
    else if Regione = "Campania"  then regio = 3;
    else if Regione = "Veneto"    then regio = 4;
    else if Regione = "Lombardia"   then regio = 5;
    else if Regione = "Piemonte"   then regio = 6;
    else if Regione = "Sicilia"  then regio = 7;
    else if Regione = "Emilia-Romagna"    then regio = 8;
    else if Regione = "Trentino-Alto Adige" then regio = 9;
    else if Regione = "Friuli-Venezia Giulia"   then regio = 10;
    else if Regione = "Sardegna"    then regio = 11;
    else if Regione = "Umbria"   then regio = 12;
    else if Regione = "Marche"  then regio = 13;
    else if Regione = "Liguria"  then regio = 14;
    else if Regione = "Puglia" then regio = 15;
    else if Regione = "Calabria" then regio = 16;
    else if Regione = "Valle d'Aosta/Vallee d'Aoste" then regio = 17;
    else if Regione = "Basilicata"    then regio = 18;
    else if Regione = "Abruzzo"    then regio = 19;
    else if Regione = "Molise" then regio = 20;
run;

title "Visitatori per Regione periodo 2018-2022";
proc sgplot data=regione_numerica;
    styleattrs datacolors=(cx1f77b4 cxff7f0e cx2ca02c cxd62728 cxb998e2); 
    format regio regio_fmt.;
    vbar regio / response=Visitatori_Tot_Reg 
                  group=Anno 
                  groupdisplay=stack;
    xaxis display=(nolabel) fitpolicy=rotate;
    yaxis label="Visitatori totali";
run;
title;

/* Creazione macro grafici regione*/
%macro grafici_regione(anno, colore);
	title "Totale Visitatori per Regione nell'anno &anno.";

	proc sgplot data=visitatori_regione_anno;
		where Anno="&anno.";
		vbar Regione / categoryorder=respdesc response=Visitatori_Tot_Reg
			fillattrs=(color=&colore.);
		xaxis label="Regione";
		yaxis label="Totale Visitatori" grid;
	run;

	title;
%mend;

%grafici_regione(2018, steelblue);
%grafici_regione(2019, mediumseagreen);
%grafici_regione(2020, lightsalmon);
%grafici_regione(2021, goldenrod);
%grafici_regione(2022, lightsteelblue);

/* Distribuzione per Comune */
/* 1. Calcolo totali per Comune e Anno */
proc means data=mus.musei_storico noprint;
	class Anno Comune;
	var Visitatori_Totali;
	output out=visitatori_comune_anno sum=Totale_Visitatori;
run;

proc sort data=visitatori_comune_anno(where=(_TYPE_=3)) out=ordinati;
	by Anno descending Totale_Visitatori;
run;

data top5_per_anno (drop=contatore _type_ _freq_);
	set ordinati;
	where Comune ne "A.C. (Altri Comuni)";
	by Anno;
	retain contatore;

	if first.Anno then
		contatore=1;
	else
		contatore + 1;

	if contatore <=5;
run;

/* Creazione grafico top 5 città per numero visitatori */
%macro grafici_comune(anno, colore);
	title "Top 5 città per visitatori nell'anno &anno.";

	proc sgplot data=top5_per_anno;
		where Anno="&anno.";
		vbar Comune / categoryorder=respdesc response=Totale_Visitatori 
			fillattrs=(color=&colore.);
		xaxis label="Comune";
		yaxis label="Totale Visitatori" grid;
	run;

	title;
%mend;

%grafici_comune(2018, steelblue);
%grafici_comune(2019, mediumseagreen);
%grafici_comune(2020, lightsalmon);
%grafici_comune(2021, goldenrod);
%grafici_comune(2022, lightsteelblue);

/* Categoria */
/* Categoria - Variazioni Assolute */
proc summary data=mus.musei_storico nway;
	class Anno Categoria;
	var Visitatori_Totali;
	output out=totali_visite (drop=_TYPE_ _FREQ_) sum=Totale_Visitatori;
run;

title "Variazione Visitatori per Categoria";
proc sgplot data=totali_visite;
	styleattrs datacolors=(cx4E79A7 cx85A9D4 cxA0CBE8);
	vbar Anno / response=Totale_Visitatori group=Categoria groupdisplay=cluster;
	yaxis label="Totale visitatori" labelattrs=(weight=bold size=10);
	xaxis label="Anno" labelattrs=(weight=bold size=10);
run;
title;

/* Categoria - Variazioni Percentuali  */
proc sort data=totali_visite;
	by Categoria Anno;
run;

data variazioni;
	set totali_visite;
	by Categoria;
	retain Totale_Precedente;

	if first.Categoria then
		do;
			Variazione_Percentuale=.;
		end;
	else
		do;
			Variazione_Percentuale=100 * (Totale_Visitatori - Totale_Precedente) / 
				Totale_Precedente;
		end;
	Totale_Precedente=Totale_Visitatori;
run;

/* Creazione grafico Variazione Percentuale Visitatori per Categoria*/
title "Variazione Percentuale Visitatori per Categoria";
proc sgplot data=variazioni(where=(Variazione_Percentuale ne .));
	styleattrs datacolors=(cx4E79A7 cx85A9D4 cxA0CBE8);
	series x=Anno y=Variazione_Percentuale / group=Categoria markers;
	yaxis label="Variazione %" grid;
	xaxis label="Anno" integer;
run;
title;

/* Tipologia - Variazioni Assolute */
proc summary data=mus.musei_storico(where=(Tipologia ne ".")) nway;
	class Anno Tipologia;
	var Visitatori_Totali;
	output out=totali_visite (drop=_TYPE_ _FREQ_) sum=Totale_Visitatori;
run;

proc sort data=totali_visite;
	by Anno descending Totale_Visitatori;
run;

data top5_per_anno (drop=conta);
	set totali_visite;
	by Anno;

	if first.Anno then
		conta=0;
	conta+1;

	if conta <=5;
run;

/* Creazione grafico top 5 Tipologie per Visitatori per Anno */
title "Top 5 Tipologie per Visitatori per Anno";
proc sgplot data=top5_per_anno;
	styleattrs datacolors=(lightsteelblue goldenrod lightsalmon mediumseagreen steelblue indianred);
	vbar Anno / response=Totale_Visitatori group=Tipologia groupdisplay=cluster;
	yaxis label="Totale Visitatori" labelattrs=(weight=bold size=10);
	xaxis label="Anno" labelattrs=(weight=bold size=10);
run;
title;

/* Tipologia - Variazioni Percentuali  */
proc sort data=totali_visite;
	by Tipologia Anno;
run;

data variazioni;
	set totali_visite;
	by Tipologia;
	retain Totale_Precedente;

	if first.Tipologia then
		Variazione_Percentuale=.;
	else
		Variazione_Percentuale=100*(Totale_Visitatori - Totale_Precedente)/Totale_Precedente;
	Totale_Precedente=Totale_Visitatori;
run;

proc sort data=variazioni
out=variazioni_sorted (drop = Totale_Precedente Totale_Visitatori);
	by Anno descending Variazione_Percentuale ;
run;

data top5_variazioni_per_anno(drop=conta);
	set variazioni_sorted;
	by Anno;

	if first.Anno then
		conta=0;
	conta+1;

	if conta<=5 and Variazione_Percentuale ne .;
run;

data top5_variazioni_per_anno; 
length Tipologia $50.;
set top5_variazioni_per_anno;
run;

/* Creazione grafici per Variazione Percentuale Tipologia negli anni 2019-2022*/
%macro grafici_tipologia(anno, colore);
title "Variazione percentuale di Visitatori per Tipologia nell'anno &anno.";
	proc sgplot data=top5_variazioni_per_anno;
		where Anno="&anno.";
		vbar Tipologia / categoryorder=respdesc response=Variazione_Percentuale 
			fillattrs=(color=&colore.);
		xaxis label="Tipologia" display=(noline) fitpolicy=ROTATEALWAYS;
		yaxis label="Variazione Percentuale di Visitatori" grid;
	run;
title;
%mend;

%grafici_tipologia(2019, lightsteelblue);
%grafici_tipologia(2020, goldenrod);
%grafici_tipologia(2021, lightsalmon);
%grafici_tipologia(2022, mediumseagreen);
