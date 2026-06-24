#!/usr/bin/env bash
# ============================================================================
# load.sh — popula o schema analytics a partir dos zips em ./data
#
# Estratégia: streaming `unzip -p <zip> | psql \copy ... FROM STDIN` direto para
# dentro do container postgres. Não extrai CSV em disco nem precisa montar ./data
# no container (que só monta ./data/postgres).
#
# Uso (a partir da raiz do repo):   bash analytics/load.sh
# Pré-requisitos: docker compose up -d postgres ; unzip no PATH do host.
# ============================================================================
set -euo pipefail

DATA_DIR="${DATA_DIR:-./data}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# psql dentro do container; -T = sem TTY (essencial para pipe via STDIN)
PSQL=(docker compose exec -T postgres psql -U cnpj -d cnpj -v ON_ERROR_STOP=1)
COPY_OPTS="(FORMAT csv, DELIMITER ';', QUOTE '\"', ENCODING 'LATIN9')"

run_sql_file() { echo ">> aplicando $1"; "${PSQL[@]}" < "$1"; }

# Faz \copy de todos os zips que casam com o glob para a tabela informada.
copy_zips() {
    local table="$1"; shift
    local glob="$1"; shift
    shopt -s nullglob
    local files=( $DATA_DIR/$glob )
    shopt -u nullglob
    if [ ${#files[@]} -eq 0 ]; then
        echo "!! nenhum arquivo para $glob — pulando $table"; return
    fi
    for z in "${files[@]}"; do
        echo ">> COPY $(basename "$z") -> staging.$table"
        unzip -p "$z" | "${PSQL[@]}" -c "\copy staging.$table FROM STDIN $COPY_OPTS"
    done
}

echo "== [1/5] schema =="
run_sql_file "$HERE/01_schema.sql"

echo "== [2/5] staging =="
run_sql_file "$HERE/02_staging.sql"

echo "== [3/5] COPY bruto dos CSVs =="
copy_zips empresas         'Empresas*.zip'
copy_zips estabelecimentos 'Estabelecimentos*.zip'
copy_zips socios           'Socios*.zip'
copy_zips simples          'Simples.zip'
copy_zips cnaes            'Cnaes.zip'
copy_zips naturezas        'Naturezas.zip'
copy_zips qualificacoes    'Qualificacoes.zip'
copy_zips paises           'Paises.zip'
copy_zips motivos          'Motivos.zip'
copy_zips municipios       'Municipios.zip'

echo "== [4/5] transform (staging -> analytics) =="
run_sql_file "$HERE/03_transform.sql"

echo "== [5/5] índices + materialized views =="
run_sql_file "$HERE/04_indexes.sql"
run_sql_file "$HERE/05_materialized_views.sql"

echo "== concluído =="
"${PSQL[@]}" -c "SELECT 'empresa' t, count(*) FROM analytics.empresa
UNION ALL SELECT 'estabelecimento', count(*) FROM analytics.estabelecimento
UNION ALL SELECT 'socio', count(*) FROM analytics.socio
UNION ALL SELECT 'simples', count(*) FROM analytics.simples;"
