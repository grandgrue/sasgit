data work.bevisland;
  set work.bevbestnat;
  if NationLang in ('Kuba');
  drop ExportVersionCd StichtagDatMM;
run;