FROM oraclelinux:7
  
ENV DBTWIG_USER
ENV DBTWIG_PASSWORD
ENV DBTWIG_DATABASE_NAME

RUN yum install -y oracle-instantclient-release-el7 oracle-nodejs-release-el7 \
 && yum install -y oracle-instantclient-basic oracle-instantclient-tools oracle-instantclient-sqlplus \
    nodejs node-oracledb-node14 make gcc-c++ \
 && yum update -y

WORKDIR /app

COPY ./middleTier/* /app/

RUn npm install

CMD [ "bash" ]

