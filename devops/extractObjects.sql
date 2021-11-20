define git_home = &1
define tutorial_user = &2
define tutorial_pass = &3
define db_name = &4

@extractPackageHeader db_twig &git_home/dbTwig/dba 
@preWrapPackageBody db_twig &git_home/dbTwig/dba

connect &tutorial_user/&tutorial_pass@&db_name

@extractPackageHeader react_example &git_home/dbTwig/examples/react/dba
@preWrapPackageBody react_example &git_home/dbTwig/examples/react/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/dbTwig/examples/react/dba/dbTwigData.sql reactExample

exit;

