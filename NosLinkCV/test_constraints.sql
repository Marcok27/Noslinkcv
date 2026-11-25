-- =============================================================================
-- AJUSTE LOGÍSTICO TRANSACIONAL (test_constraints.sql)
-- =============================================================================

-- 1. Configurar caminhos automáticos dos schemas
SET search_path TO marketplace, core, public;

-- 2. [LIMPEZA/RESET] Garante que o teste pode ser executado múltiplas vezes
DELETE FROM marketplace.pedidos WHERE id = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
DELETE FROM marketplace.carrinho WHERE cliente_id = '22222222-2222-2222-2222-222222222222';
UPDATE marketplace.catalogo SET stock = 10 WHERE nome = 'SuperPhone X';

-- 3. Simular o "Adicionar ao Carrinho" (2 unidades)
INSERT INTO marketplace.carrinho (cliente_id, produto_id, quantidade)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    (SELECT id FROM marketplace.catalogo WHERE nome = 'SuperPhone X' LIMIT 1),
    2
) ON CONFLICT DO NOTHING;

-- 4. [PRE-CHECK] Visualizar Carrinho antes da compra
SELECT 
    car.cliente_id,
    cat.nome AS produto,
    car.quantidade,
    cat.preco AS preco_unitario,
    (car.quantidade * cat.preco) AS subtotal
FROM marketplace.carrinho car
JOIN marketplace.catalogo cat ON car.produto_id = cat.id
WHERE car.cliente_id = '22222222-2222-2222-2222-222222222222';

-- 5. [TRANSAÇÃO] O Fluxo de Checkout Crítico
BEGIN;

-- Criar o registo do pedido (adicionada a coluna loja_id necessária)
INSERT INTO marketplace.pedidos (id, cliente_id, loja_id, status)
VALUES (
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    '22222222-2222-2222-2222-222222222222',
    (SELECT loja_id FROM marketplace.catalogo WHERE nome = 'SuperPhone X' LIMIT 1),
    'pendente'
);

-- Deduzir o stock (10 - 2 = 8)
UPDATE marketplace.catalogo 
SET stock = stock - 2
WHERE nome = 'SuperPhone X';

-- Esvaziar o carrinho do cliente
DELETE FROM marketplace.carrinho 
WHERE cliente_id = '22222222-2222-2222-2222-222222222222';
COMMIT;
-- 6. Ativar e Forçar o RLS de forma permanente
ALTER TABLE marketplace.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace.pedidos FORCE ROW LEVEL SECURITY;

-- 7. Criar/Substituir a política de isolamento por cliente
DROP POLICY IF EXISTS pedidos_isolation_policy ON marketplace.pedidos;
CREATE POLICY pedidos_isolation_policy ON marketplace.pedidos
    USING (cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::uuid);