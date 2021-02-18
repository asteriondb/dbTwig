FROM oraclelinux:7
  
# Environment Variables
# DBTWIG_USER
# DBTWIG_PASSWORD
# DBTWIG_DATABASE_NAME


RUN yum install -y oracle-instantclient-release-el7 oracle-nodejs-release-el7 \
 && yum install -y oracle-instantclient-basic oracle-instantclient-tools oracle-instantclient-sqlplus \
                   nodejs node-oracledb-node14 make gcc-c++ \
 && yum update -y

# ** Uncomment the following (replacing above) to Leverage Later Release of make and gcc-c++ 
#RUN yum install -y oracle-instantclient-release-el7 oracle-nodejs-release-el7 \
# && yum install -y oracle-instantclient-basic oracle-instantclient-tools oracle-instantclient-sqlplus \
#                   nodejs node-oracledb-node14 \
# && yum install -y oracle-softwarecollection-release-el7 scl-utils \
# && yum install -y yum install devtoolset-6-gcc-c++ devtoolset-6-make \
# && yum update -y

WORKDIR /app

COPY ./middleTier/* /app/

RUN npm install
# ** Uncomment the following (replacing above) to Leverage Later Release of make and gcc-c++ 
#RUN scl enable devtoolset-6 -- npm install

CMD [ "bash" ]

