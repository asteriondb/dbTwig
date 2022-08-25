define git_home = &1

@extractPackageHeader react_example &git_home/dbTwig/examples/react/dba
@preWrapPackageBody react_example &git_home/dbTwig/examples/react/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/dbTwig/examples/react/dba/dbTwigData.sql reactExample

exit;

