#!/bin/bash -e

export PGDATABASE=mailertest

echo "Creating database..."
echo "Drop database if exists $PGDATABASE" | psql postgres
echo "Create database $PGDATABASE" | psql postgres
echo

echo "Executing the database scripts..."
cat ../db/* | psql
echo

echo "Adding data..."
echo "\Copy Project (name, fromName, emailAddress, returnURLRoot) from 'project.data';
\Copy Subscriber (projectName, emailAddress, properties) from 'subscriber.data';
\Copy Email (projectName, redirectURL) from 'email.data';
Create temp table TempEmailVariation (subject varchar(1000), plainBody text, hTMLBody text);
\Copy TempEmailVariation from 'emailvariation.data';
Insert into EmailVariation (emailId, subject, plainBody, hTMLBody) select Email.id, TempEmailVariation.* from Email, TempEmailVariation;
Insert into EmailSend (emailId, subscriberId, variationRank) select EmailVariation.emailId, Subscriber.id, EmailVariation.rank from EmailVariation, Subscriber;" | psql
echo