define git_home = &1

@extractPackageHeader dbtwig_example &git_home/dbTwig/examples/dba
@preWrapPackageBody dbtwig_example &git_home/dbTwig/examples/dba

@extractPackageHeader restapi &git_home/dbTwig/examples/dba
@preWrapPackageBody restapi &git_home/dbTwig/examples/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/dbTwig/examples/dba/dbTwigData.sql dbTwigExample

exit;

