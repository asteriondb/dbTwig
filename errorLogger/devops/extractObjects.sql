define git_home = &1

@extractPackageHeader error_logger &git_home/dbTwig/errorLogger/dba 
@preWrapPackageBody error_logger &git_home/dbTwig/errorLogger/dba

exit
