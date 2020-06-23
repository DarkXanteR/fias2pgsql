#!/bin/bash
set -e

apt update
apt install postgresql-client pgdbf -yqq

# load latest dbf link from nalog.ru
regex='DBFURL\":\"([^\"]+)\"'
f=$(curl -L https://fias.nalog.ru/DataArchive | grep -oEi $regex | head -n1)
if [[ $f =~ $regex ]]
then
    name="${BASH_REMATCH[1]}"
    echo "${name}"    # concatenate strings
else
    echo "unable to get fias file id"
    exit 1;
fi

# download fias.zip
mkdir -p download
cd download
wget "https://fias-file.nalog.ru/ExportDownloads?file=${name}" -O fias.zip

# unzip files
unzip -j fias.zip "SOCRB*" "ADDROB*"
chmod 644 *.DBF
cd ..

export POSTGRES_DB=fias
export POSTGRES_USER=fias
export POSTGRES_PASSWORD=fias
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export PATH_TO_DBF_FILES=$PWD/download

container=$(docker run --rm -v $PWD/pg_data:/var/lib/postgresql/data -d -e POSTGRES_DB=$POSTGRES_DB -e POSTGRES_USER=$POSTGRES_USER -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -p $POSTGRES_PORT:$POSTGRES_PORT postgres:11)

sleep 5

./index.sh

docker exec $container bash -c 'PGPASSWORD=$POSTGRES_PASSWORD pg_dump --host=localhost --port=$POSTGRES_PORT --dbname=$POSTGRES_DB --username=$POSTGRES_USER' > fias_dump.sql

docker rm -f $container
rm -rf download
rm -rf pg_data
