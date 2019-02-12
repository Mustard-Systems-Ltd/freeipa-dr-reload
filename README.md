# freeipa-dr-reload
FreeIPA DR recover by LDIF import


Skeleton scripts for building a new FreeIPA intrastructure from an LDIF export of the old one starting with a legacy version and schema. 


Script | Purpose
--- | ---
r1-4272.sh | FreeIPA v4.2 package install on  Centos 7.2 catering for the poor packaging and YUM dependency reolver
r2.sh | Vanilla install of FreeIPA 4.2 
r3.sh | LDIF import and cleanse of legacy server references


You will also need a server.inc file, see server.inc.sample

