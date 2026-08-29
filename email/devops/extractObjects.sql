define git_home = &1

@extractPackageHeader restapi &git_home/dbTwig/email/dba
@preWrapPackageBody restapi &git_home/dbTwig/email/dba

@extractPackageHeader email &git_home/dbTwig/email/dba 
@preWrapPackageBody email &git_home/dbTwig/email/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/dbTwig/email/dba/dbTwigData.sql email

exit
