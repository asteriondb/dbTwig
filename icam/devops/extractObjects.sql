define git_home = &1

@extractPackageHeader restapi &git_home/dbTwig/icam/dba
@preWrapPackageBody restapi &git_home/dbTwig/icam/dba

@extractPackageHeader icam &git_home/dbTwig/icam/dba 
@preWrapPackageBody icam &git_home/dbTwig/icam/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/dbTwig/icam/dba/dbTwigData.sql icam

exit
