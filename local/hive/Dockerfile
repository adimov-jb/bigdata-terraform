# Hive Metastore com o driver JDBC do Postgres, que a imagem oficial não inclui.
FROM apache/hive:4.2.1

# O checksum faz o build falhar se o arquivo baixado não for exatamente o esperado.
# Para trocar a versão, confira o .sha1 publicado no Maven Central e recalcule o sha256.
ADD --chown=hive:hive --chmod=644 \
    --checksum=sha256:188976721ead8e8627eb6d8389d500dccc0c9bebd885268a3047180274a6031e \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar \
    /opt/hive/lib/postgresql-42.7.4.jar
