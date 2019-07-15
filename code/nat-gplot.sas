/* Einfache Grafik ausgeben */ 

PROC GPLOT DATA=work.BEVISLAND;
  PLOT AnzBestWir * StichtagDatJahr = NationLang; 
run;
