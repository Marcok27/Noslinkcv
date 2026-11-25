-- =============================================================================
-- SCRIPT DE TESTE TRANSACIONAL CORRIGIDO (testes.sql)
-- =============================================================================

SET search_path TO marketplace, core, public;

-- 1. LIMPEZA DE TESTES ANTERIORES
DELETE FROM marketplace.pedidos WHERE id = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
DELETE FROM marketplace.carrinho WHERE usuario_id = '22222222-2222-2222-2222-222222222222';
UPDATE marketplace.catalogo SET stock = 10 WHERE nome = 'SuperPhone X';

-- 2. CRIAR O COMPRADOR (Se não existir)
INSERT INTO core.usuarios (id, email, password_hash) 
VALUES ('22222222-2222-2222-2222-222222222222', 'cliente.praia@gmail.com', 'hash_comprador_xyz')
ON CONFLICT (id) DO NOTHING;

-- 3. ADICIONAR AO CARRINHO
INSERT INTO marketplace.carrinho (usuario_id, produto_id, quantidade)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    (SELECT id FROM marketplace.catalogo WHERE nome = 'SuperPhone X' LIMIT 1),
    2
);

-- 4. VISUALIZAR CARRINHO (Usando nome_comercial)
SELECT 
    u.email AS cliente,
    cat.nome AS produto,
    l.nome_comercial AS loja,
    car.quantidade,
    cat.preco AS preco_unitario,
    (car.quantidade * cat.preco) AS subtotal
FROM marketplace.carrinho car
JOIN core.usuarios u ON car.usuario_id = u.id
JOIN marketplace.catalogo cat ON car.produto_id = cat.id
JOIN marketplace.lojas l ON cat.loja_id = l.id
WHERE car.usuario_id = '22222222-2222-2222-2222-222222222222';

-- 5. TRANSAÇÃO DE CHECKOUT
BEGIN;

INSERT INTO marketplace.pedidos (id, usuario_comprador_id, total, status)
VALUES (
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    '22222222-2222-2222-2222-222222222222',
    90000.00,
    'pendente'
);

UPDATE marketplace.catalogo 
SET stock = stock - 2
WHERE nome = 'SuperPhone X';

DELETE FROM marketplace.carrinho 
WHERE usuario_id = '22222222-2222-2222-2222-222222222222';

COMMIT;

-- 6. AUDITORIA FINAL
SELECT nome, stock AS stock_atual_deve_ser_8 FROM marketplace.catalogo WHERE nome = 'SuperPhone X';
SELECT COUNT(*) AS total_itens_no_carrinho_deve_ser_0 FROM marketplace.carrinho WHERE usuario_id = '22222222-2222-2222-2222-222222222222';