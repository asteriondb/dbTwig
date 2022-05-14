define git_home = &1

@extractPackageHeader db_twig &git_home/dbTwig/dba 
@preWrapPackageBody db_twig &git_home/dbTwig/dba

exit;

