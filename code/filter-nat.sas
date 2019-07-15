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
