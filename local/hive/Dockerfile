# Hive Metastore com o driver JDBC do Postgres, que a imagem oficial não inclui.
FROM apache/hive:4.0.1

ADD --chown=hive:hive --chmod=644 \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar \
    /opt/hive/lib/postgresql-42.7.4.jar
