-- =========================================================================
-- NOSLINK CV - QUERIES DE TESTE E VALIDAÇÃO (VERSÃO CORRIGIDA)
-- =========================================================================

-- QUERY 1: CATÁLOGO GERAL INTER-ILHAS
-- (Valida as relações entre produtos, lojas, subcategorias e categorias)
SELECT 
    c.id AS produto_id,
    c.nome AS nome_produto,
    c.preco AS preco_cve,
    c.stock AS unidades_disponiveis,
    loja.nome AS nome_loja,
    loja.localizacao AS ilha_origem,
    sub.nome AS subcategoria,
    cat.nome AS categoria_principal
FROM marketplace.catalogo c
INNER JOIN marketplace.lojas loja ON c.loja_id = loja.id
INNER JOIN marketplace.subcategorias sub ON c.subcategoria_id = sub.id
INNER JOIN marketplace.categorias cat ON sub.categoria_id = cat.id
ORDER BY ilha_origem ASC, nome_produto ASC;


-- QUERY 2: VALOR TOTAL DE INVENTÁRIO POR ILHA E LOJA
-- (Calcula a quantidade e o valor do stock acumulado por localização)
SELECT 
    loja.localizacao AS ilha,
    loja.nome AS nome_loja,
    COUNT(c.id) AS variedade_produtos,
    COALESCE(SUM(c.stock), 0) AS total_unidades,
    COALESCE(SUM(c.preco * c.stock), 0.00) AS valor_total_stock_cve
FROM marketplace.lojas loja
LEFT JOIN marketplace.catalogo c ON loja.id = c.loja_id
GROUP BY loja.localizacao, loja.nome
ORDER BY valor_total_stock_cve DESC;


-- QUERY 3: ALERTA DE STOCK BAIXO
-- (Filtra todos os produtos que têm menos de 25 unidades disponíveis)
SELECT 
    c.nome AS produto,
    loja.nome AS loja,
    loja.localizacao AS ilha,
    c.stock AS stock_atual
FROM marketplace.catalogo c
INNER JOIN marketplace.lojas loja ON c.loja_id = loja.id
WHERE c.stock < 25
ORDER BY c.stock ASC;