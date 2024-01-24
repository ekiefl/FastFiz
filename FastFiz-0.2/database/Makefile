include config.mk

WWWDIR=../www/
TEMPLATES=$(wildcard *.tmpl)
OUTPUTS=$(addprefix $(DATABASE).,$(basename $(TEMPLATES)))
SUDO=sudo -u postgres 

all: database pool-schema.sql docs install 

pool-schema.sql: init-db.sql database
	env PGUSER=${USER} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} pg_dump -sOx ${DATABASE} > $@
	env PGUSER=${USER} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} pg_dump -aOx -t balls -t ballstates -t decisions -t end_reasons -t gametypes -t pockets -t rules -t turntypes -t noisetypes ${DATABASE} >> $@
	cat init-db.sql >> $@

backup: ${DATABASE}.sql.gz
	cp $< ${DATABASE}-`date +%Y%m%d`-backup.sql.gz

${DATABASE}.sql.gz: database
	env PGUSER=${USER} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} pg_dump ${DATABASE} | gzip > $@

$(OUTPUTS): database postgresql_autodoc $(TEMPLATES)
	./postgresql_autodoc -l . -d ${DATABASE} -h localhost -u ${USER} --password=${PASSWORD}

%.png: %.dot
	dot -Tpng < $< > $@

docs: ${DATABASE}.png ${DATABASE}.html

${WWWDIR}/database.png: ${DATABASE}.png
	cp $< $@

${WWWDIR}/database.html: ${DATABASE}.html 
	cp $< $@

install: ${WWWDIR}/database.png ${WWWDIR}/database.html

database:
	if env PGUSER=${USER} PGDATABASE=${DATABASE} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} psql -c ''; then echo "Error: Database Already Exists!"; exit 1; fi
	$(SUDO) createuser -SDRl ${USER}
	$(SUDO) psql -c "ALTER ROLE ${USER} PASSWORD '${PASSWORD}';"
	$(SUDO) createdb -O ${USER} ${DATABASE}
	env PGUSER=${USER} PGDATABASE=${DATABASE} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} psql < pool-schema.sql
	touch database

dropdb:
	-sudo -u postgres dropdb ${DATABASE}
	-sudo -u postgres dropuser ${USER}
	-rm database

clean:
	if env PGUSER=${USER} PGDATABASE=${DATABASE} PGHOSTADDR=127.0.0.1 PGPASSWORD=${PASSWORD} psql -c ''; then touch database; else rm database; fi
	-rm $(OUTPUTS) $(DATABASE).png *~ 
	
clean_all: clean
	-rm $(DATABASE).sql.gz
