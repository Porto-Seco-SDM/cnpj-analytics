-- ============================================================================
-- 05_materialized_views.sql — agregações para dashboards (refresh mensal)
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_ativas_por_municipio_cnae;
CREATE MATERIALIZED VIEW analytics.mv_ativas_por_municipio_cnae AS
SELECT e.uf, e.municipio_cod, e.cnae_fiscal_principal, count(*) AS qtd
FROM analytics.estabelecimento e
WHERE e.situacao_cadastral = 2
GROUP BY 1, 2, 3;
CREATE UNIQUE INDEX ux_mv_ativas_mun_cnae
    ON analytics.mv_ativas_por_municipio_cnae (uf, municipio_cod, cnae_fiscal_principal);

DROP MATERIALIZED VIEW IF EXISTS analytics.mv_capital_por_natureza;
CREATE MATERIALIZED VIEW analytics.mv_capital_por_natureza AS
SELECT em.natureza_juridica_cod,
       count(*)              AS empresas,
       sum(em.capital_social) AS capital_total
FROM analytics.empresa em
GROUP BY 1;
CREATE UNIQUE INDEX ux_mv_capital_natureza
    ON analytics.mv_capital_por_natureza (natureza_juridica_cod);

-- Atualiza todas as MVs (chamar após cada carga mensal)
CREATE OR REPLACE FUNCTION analytics.refresh_mvs() RETURNS void
    LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_ativas_por_municipio_cnae;
    REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_capital_por_natureza;
END;
$$;
