/* Ausgewählte karibische Destinationen filtern */

data work.bevisland;
  set work.bevbestnat;
  if NationLang in ('Kuba', 'Dominikanische Republik', 'Haiti', 'Jamaika');
  drop ExportVersionCd StichtagDatMM;
run;

