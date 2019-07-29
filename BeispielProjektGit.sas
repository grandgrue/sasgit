/* ---------------------------------- */
/* MACRO: enterpriseguide             */
/* PURPOSE: define a macro variable   */
/*   that contains the file system    */
/*   path of the WORK library on the  */
/*   server.  Note that different     */
/*   logic is needed depending on the */
/*   server type.                     */
/* ---------------------------------- */
%macro enterpriseguide;
%global sasworklocation;
%local tempdsn unique_dsn path;

%if &sysscp=OS %then %do; /* MVS Server */
	%if %sysfunc(getoption(filesystem))=MVS %then %do;
        /* By default, physical file name will be considered a classic MVS data set. */
	    /* Construct dsn that will be unique for each concurrent session under a particular account: */
		filename egtemp '&egtemp' disp=(new,delete); /* create a temporary data set */
 		%let tempdsn=%sysfunc(pathname(egtemp)); /* get dsn */
		filename egtemp clear; /* get rid of data set - we only wanted its name */
		%let unique_dsn=".EGTEMP.%substr(&tempdsn, 1, 16).PDSE"; 
		filename egtmpdir &unique_dsn
			disp=(new,delete,delete) space=(cyl,(5,5,50))
			dsorg=po dsntype=library recfm=vb
			lrecl=8000 blksize=8004 ;
		options fileext=ignore ;
	%end; 
 	%else %do; 
        /* 
		By default, physical file name will be considered an HFS 
		(hierarchical file system) file. 
		*/
		%if "%sysfunc(getoption(filetempdir))"="" %then %do;
			filename egtmpdir '/tmp';
		%end;
		%else %do;
			filename egtmpdir "%sysfunc(getoption(filetempdir))";
		%end;
	%end; 
	%let path=%sysfunc(pathname(egtmpdir));
    %let sasworklocation=%sysfunc(quote(&path));  
%end; /* MVS Server */
%else %do;
	%let sasworklocation = "%sysfunc(getoption(work))/";
%end;
%if &sysscp=VMS_AXP %then %do; /* Alpha VMS server */
	%let sasworklocation = "%sysfunc(getoption(work))";                         
%end;
%if &sysscp=CMS %then %do; 
	%let path = %sysfunc(getoption(work));                         
	%let sasworklocation = "%substr(&path, %index(&path,%str( )))";
%end;
%mend enterpriseguide;

%enterpriseguide


/* Conditionally delete set of tables or views, if they exists          */
/* If the member does not exist, then no action is performed   */
%macro _eg_conditional_dropds /parmbuff;
	
   	%local num;
   	%local stepneeded;
   	%local stepstarted;
   	%local dsname;
	%local name;

   	%let num=1;
	/* flags to determine whether a PROC SQL step is needed */
	/* or even started yet                                  */
	%let stepneeded=0;
	%let stepstarted=0;
   	%let dsname= %qscan(&syspbuff,&num,',()');
	%do %while(&dsname ne);	
		%let name = %sysfunc(left(&dsname));
		%if %qsysfunc(exist(&name)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;

			%end;
				drop table &name;
		%end;

		%if %sysfunc(exist(&name,view)) %then %do;
			%let stepneeded=1;
			%if (&stepstarted eq 0) %then %do;
				proc sql;
				%let stepstarted=1;
			%end;
				drop view &name;
		%end;
		%let num=%eval(&num+1);
      	%let dsname=%qscan(&syspbuff,&num,',()');
	%end;
	%if &stepstarted %then %do;
		quit;
	%end;
%mend _eg_conditional_dropds;


/* save the current settings of XPIXELS and YPIXELS */
/* so that they can be restored later               */
%macro _sas_pushchartsize(new_xsize, new_ysize);
	%global _savedxpixels _savedypixels;
	options nonotes;
	proc sql noprint;
	select setting into :_savedxpixels
	from sashelp.vgopt
	where optname eq "XPIXELS";
	select setting into :_savedypixels
	from sashelp.vgopt
	where optname eq "YPIXELS";
	quit;
	options notes;
	GOPTIONS XPIXELS=&new_xsize YPIXELS=&new_ysize;
%mend _sas_pushchartsize;

/* restore the previous values for XPIXELS and YPIXELS */
%macro _sas_popchartsize;
	%if %symexist(_savedxpixels) %then %do;
		GOPTIONS XPIXELS=&_savedxpixels YPIXELS=&_savedypixels;
		%symdel _savedxpixels / nowarn;
		%symdel _savedypixels / nowarn;
	%end;
%mend _sas_popchartsize;


ODS PROCTITLE;
OPTIONS DEV=PNG;
GOPTIONS XPIXELS=0 YPIXELS=0;
FILENAME EGSRX TEMP;
ODS tagsets.sasreport13(ID=EGSRX) FILE=EGSRX
    STYLE=HTMLBlue
    STYLESHEET=(URL="file:///C:/Program%20Files/SASHome/SASEnterpriseGuide/7.1/Styles/HTMLBlue.css")
    NOGTITLE
    NOGFOOTNOTE
    GPATH=&sasworklocation
    ENCODING=UTF8
    options(rolap="on")
;
%LET _CLIENTTASKLABEL='SAS Information Map importieren';
%LET _CLIENTPROCESSFLOWNAME='Prozessfluss';
%LET _CLIENTPROJECTPATH='\\szh.loc\ssz\users\sszgrm\Dokumente\GitHub\sasgit\BeispielProjektGit.egp';
%LET _CLIENTPROJECTPATHHOST='ZRHV0A8A';
%LET _CLIENTPROJECTNAME='BeispielProjektGit.egp';

GOPTIONS ACCESSIBLE;
/* assign the library using the INFOMAPS library engine */

sysecho "Zuweisen der Bibliothek für den Zugriff auf Information Map";
%macro SetDisplayOrder;
%if %sysevalf(&sysver>=9.4) %then displayorder=folder;
%mend SetDisplayOrder;

libname _egimle sasioime
	 mappath="/InformationMaps/Bevoelkerung/BVS Bevoelkerungsbestand int."
	 aggregate=yes
	 metacredentials=no
	 PRESERVE_MAP_NAMES=YES
	 %SetDisplayOrder;
/* NOTE: when using this LIBNAME statement in a batch environment,  */
/* you might need to add metadata host and credentials information. */


data WORK.BEVBESTNAT (label='Ausgewählte Daten von BVS Bevoelkerungsbestand int.');
	sysecho "Extrahieren von Daten aus der Information Map";
	length 
		ExportVersionCd $ 200
		StichtagDatMM 8
		StichtagDatJahr 8
		NationLang $ 200
		AnzBestWir 8
		;
	label 
		ExportVersionCd="Exportversion (Code)"  /* Exportversion (Code) */
		StichtagDatMM="Daten gültig per MM"  /* Daten gültig per MM */
		StichtagDatJahr="Daten gültig per Jahr"  /* Daten gültig per Jahr */
		NationLang="Staatsangehörigkeit (lang)"  /* Staatsangehörigkeit (lang) */
		AnzBestWir="wirtschaftliche Bevölkerung"  /* wirtschaftliche Bevölkerung */
		;
	
	set _egimle."BVS Bevoelkerungsbestand int."n 
		(keep=
			ExportVersionCd
			StichtagDatMM
			StichtagDatJahr
			NationLang
			AnzBestWir 
		 /* default EXPCOLUMNLEN is 32 */ 
		 filter=(NOT (ExportVersionCd = "A") AND (StichtagDatMM = 12)) 
		 
		 );
	
run;

/* clear the libname when complete */
libname _egimle clear;





GOPTIONS NOACCESSIBLE;
%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROCESSFLOWNAME=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTPATHHOST=;
%LET _CLIENTPROJECTNAME=;

%LET SYSLAST=WORK.BEVBESTNAT;
%LET _CLIENTTASKLABEL='filter-nat';
%LET _CLIENTPROCESSFLOWNAME='Prozessfluss';
%LET _CLIENTPROJECTPATH='\\szh.loc\ssz\users\sszgrm\Dokumente\GitHub\sasgit\BeispielProjektGit.egp';
%LET _CLIENTPROJECTPATHHOST='ZRHV0A8A';
%LET _CLIENTPROJECTNAME='BeispielProjektGit.egp';
%LET _SASPROGRAMFILE='\\szh.loc\ssz\users\sszgrm\Dokumente\GitHub\sasgit\code\filter-nat.sas';
%LET _SASPROGRAMFILEHOST='ZRHV0A8A';

GOPTIONS ACCESSIBLE;
/* Ausgewählte karibische Destinationen filtern */

data work.bevisland;
  set work.bevbestnat;
  if NationLang in ('Kuba', 'Dominikanische Republik', 'Haiti', 'Jamaika');
  drop ExportVersionCd StichtagDatMM;
run;

/* Sortieren der Tabelle nach Nation und Jahr */
proc sort data=work.bevisland;
  by NationLang StichtagDatJahr;
run;


GOPTIONS NOACCESSIBLE;
%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROCESSFLOWNAME=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTPATHHOST=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;
%LET _SASPROGRAMFILEHOST=;


GOPTIONS ACCESSIBLE;
/* Einfache Grafik ausgeben */ 

PROC GPLOT DATA=work.BEVISLAND;
  PLOT AnzBestWir * StichtagDatJahr = NationLang; 
run;


GOPTIONS NOACCESSIBLE;
%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROCESSFLOWNAME=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTPATHHOST=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;
%LET _SASPROGRAMFILEHOST=;

;*';*";*/;quit;run;
ODS _ALL_ CLOSE;
