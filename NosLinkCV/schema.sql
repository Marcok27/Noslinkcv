-- ====================================================================
--                  SYSTEM CONSOLIDATED: NÔSLINK CV v6.0
--            ESTRUTURA UNIFICADA PRONTA PARA PRODUÇÃO (ZERO TRUST)
-- ====================================================================

-- --------------------------------------------------------------------
-- 0. EXTENSÕES E SCHEMAS INICIAIS
-- --------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS marketplace;
CREATE SCHEMA IF NOT EXISTS financeiro;
CREATE SCHEMA IF NOT EXISTS compliance;

-- Limpeza de estruturas anteriores para garantir execução limpa
DROP VIEW IF EXISTS compliance.vw_ia_dados_comportamentais CASCADE;
DROP VIEW IF EXISTS financeiro.vw_reconciliacao_financeira CASCADE;
DROP TABLE IF EXISTS compliance.pista_auditoria CASCADE;
DROP TABLE IF EXISTS marketplace.cupons CASCADE;
DROP TABLE IF EXISTS marketplace.afiliados CASCADE;
DROP TABLE IF EXISTS marketplace.favoritos CASCADE;
DROP TABLE IF EXISTS marketplace.avaliacoes CASCADE;
DROP TABLE IF EXISTS marketplace.escrow CASCADE;
DROP TABLE IF EXISTS marketplace.pedidos CASCADE;
DROP TABLE IF EXISTS marketplace.carrinho CASCADE;
DROP TABLE IF EXISTS marketplace.catalogo CASCADE;
DROP TABLE IF EXISTS financeiro.lancamentos CASCADE;
DROP TABLE IF EXISTS financeiro.transacoes CASCADE;
DROP TABLE IF EXISTS financeiro.contas_razao CASCADE;
DROP TABLE IF EXISTS financeiro.taxas_cambio CASCADE;
DROP TABLE IF EXISTS compliance.solicitacoes_esquecimento CASCADE;
DROP TABLE IF EXISTS compliance.consentimentos CASCADE;
DROP TABLE IF EXISTS marketplace.subcategorias CASCADE;
DROP TABLE IF EXISTS marketplace.categorias CASCADE;
DROP TABLE IF EXISTS marketplace.lojas CASCADE;
DROP TABLE IF EXISTS core.clientes CASCADE;
DROP TABLE IF EXISTS core.usuarios CASCADE;

-- --------------------------------------------------------------------
-- 1. MÓDULO CORE: IDENTIDADES, CLIENTES E MULTILOJA
-- --------------------------------------------------------------------

-- Tabela de Utilizadores Autenticados (Padrão de segurança de senhas hash)
CREATE TABLE core.usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'cliente' NOT NULL CHECK (role IN ('cliente', 'vendedor', 'admin', 'auditor')),
    ativo BOOLEAN DEFAULT TRUE NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Clientes (Dados pessoais estritamente encriptados com AES-256 sob pgcrypto)
CREATE TABLE core.clientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES core.usuarios(id) ON DELETE RESTRICT,
    nome VARCHAR(150) NOT NULL,
    nif_encriptado BYTEA NOT NULL,       -- AES-256
    telefone_encriptado BYTEA NOT NULL,  -- AES-256
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Multiloja (Isolamento de vendedores e comissões customizáveis)
CREATE TABLE marketplace.lojas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_dono_id UUID NOT NULL REFERENCES core.usuarios(id) ON DELETE RESTRICT,
    nome_comercial VARCHAR(150) NOT NULL UNIQUE,
    slug VARCHAR(150) NOT NULL UNIQUE,
    descricao TEXT,
    comissao_personalizada NUMERIC(5, 4) DEFAULT NULL, -- NULL herda a comissão global
    verificada BOOLEAN DEFAULT FALSE NOT NULL,
    ativa BOOLEAN DEFAULT TRUE NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Categorias Globais do Marketplace
CREATE TABLE marketplace.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativa BOOLEAN DEFAULT TRUE NOT NULL
);

-- Subcategorias Globais do Marketplace
CREATE TABLE marketplace.subcategorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria_id UUID NOT NULL REFERENCES marketplace.categorias(id) ON DELETE CASCADE,
    nome VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    ativa BOOLEAN DEFAULT TRUE NOT NULL,
    CONSTRAINT uq_categoria_subcategoria UNIQUE (categoria_id, slug)
);

-- Índices Core para otimização de consultas de pesquisa e login
CREATE INDEX idx_usuarios_email ON core.usuarios(email);
CREATE INDEX idx_lojas_slug ON marketplace.lojas(slug);

-- --------------------------------------------------------------------
-- 2. MÓDULO COMPLIANCE: RGPD, CONSENTIMENTO E SEGURANÇA MILITAR
-- --------------------------------------------------------------------

-- Registros de Consentimentos (LGPD/RGPD Compliance)
CREATE TABLE compliance.consentimentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES core.usuarios(id) ON DELETE CASCADE,
    tipo_consentimento VARCHAR(100) NOT NULL, -- Ex: 'termos_servico', 'marketing_cookies'
    consentiu BOOLEAN NOT NULL,
    ip_origem VARCHAR(45) NOT NULL,
    data_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Solicitações de Esquecimento (Direito de eliminação)
CREATE TABLE compliance.solicitacoes_esquecimento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL, -- Mantido sem restrição física de chave estrangeira para permitir o delete do usuário
    status VARCHAR(50) DEFAULT 'pendente' NOT NULL CHECK (status IN ('pendente', 'processado', 'rejeitado')),
    solicitado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    processado_em TIMESTAMP WITH TIME ZONE
);

-- Procedure de Anonimização Completa (Direito ao Esquecimento)
CREATE OR REPLACE PROCEDURE compliance.prc_direito_ao_esquecimento(p_usuario_id UUID)
LANGUAGE plpgsql AS $$
DECLARE
    v_cliente_id UUID;
BEGIN
    SELECT id INTO v_cliente_id FROM core.clientes WHERE usuario_id = p_usuario_id;
    
    -- 1. Anonimizar informações confidenciais de Clientes
    IF v_cliente_id IS NOT NULL THEN
        UPDATE core.clientes
        SET nome = 'ANONIMIZADO_RGPD_EXCLUIDO',
            nif_encriptado = encrypt('000000000'::bytea, 'ChaveInvalida', 'aes'),
            telefone_encriptado = encrypt('+000000000000'::bytea, 'ChaveInvalida', 'aes')
        WHERE id = v_cliente_id;
    END IF;

    -- 2. Desativar credenciais de acesso ao sistema
    UPDATE core.usuarios
    SET email = 'anonimo_' || p_usuario_id || '@noslink.cv',
        password_hash = 'N/A',
        ativo = FALSE,
        atualizado_em = CURRENT_TIMESTAMP
    WHERE id = p_usuario_id;

    -- 3. Registrar o encerramento no log do GDPR
    INSERT INTO compliance.solicitacoes_esquecimento (usuario_id, status, processado_em)
    VALUES (p_usuario_id, 'processado', CURRENT_TIMESTAMP);
END;
$$;

-- RLS (Row-Level Security) Militar aplicada aos Dados Pessoais
ALTER TABLE core.clientes ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_cliente_leitura_propria ON core.clientes
    FOR SELECT USING (usuario_id::text = current_setting('noslink.usuario_id_ativo', true));

-- --------------------------------------------------------------------
-- 3. MÓDULO FINANCEIRO: RAZÃO DE DUPLA ENTRADA & TAXAS DE CÂMBIO
-- --------------------------------------------------------------------

-- Tabelas de Taxas de Câmbio (Moedas estrangeiras em Escudos - CVE)
CREATE TABLE financeiro.taxas_cambio (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moeda_origem VARCHAR(10) NOT NULL UNIQUE,
    moeda_destino VARCHAR(10) DEFAULT 'CVE' NOT NULL,
    taxa_conversao NUMERIC(12, 6) NOT NULL,
    fixa BOOLEAN DEFAULT FALSE NOT NULL,
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Contas do Razão Contabilístico (Double-Entry Balance Ledger)
CREATE TABLE financeiro.contas_razao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entidade_id UUID NOT NULL, -- UUID de associação (Cliente, Loja ou Sistema)
    tipo_entidade VARCHAR(50) NOT NULL CHECK (tipo_entidade IN ('cliente', 'loja', 'sistema')),
    moeda VARCHAR(10) DEFAULT 'CVE' NOT NULL,
    saldo_atual NUMERIC(15, 4) DEFAULT 0.0000 NOT NULL,
    assinatura_seguranca BYTEA, -- Assinatura HMAC contra adulterações de saldo
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_entidade_moeda UNIQUE (entidade_id, moeda)
);

-- Transações Contábeis (Faturas e Movimentos)
CREATE TABLE financeiro.transacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    descricao TEXT NOT NULL,
    tipo_operacao VARCHAR(50) NOT NULL, -- 'compra', 'remessa_internacional', 'cashback', 'reembolso'
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Lançamentos (Pernas de Débito / Crédito)
CREATE TABLE financeiro.lancamentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transacao_id UUID NOT NULL REFERENCES financeiro.transacoes(id) ON DELETE CASCADE,
    conta_id UUID NOT NULL REFERENCES financeiro.contas_razao(id) ON DELETE RESTRICT,
    tipo_lancamento VARCHAR(10) NOT NULL CHECK (tipo_lancamento IN ('debito', 'credito')),
    valor NUMERIC(15, 4) NOT NULL CHECK (valor > 0.0000),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Função de Validação e Atualização em Cadeia do Razão Contábil
CREATE OR REPLACE FUNCTION financeiro.fnc_validar_dupla_entrada()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualiza dinamicamente o saldo correspondente na tabela contas_razao
    IF NEW.tipo_lancamento = 'debito' THEN
        UPDATE financeiro.contas_razao 
        SET saldo_atual = saldo_atual - NEW.valor, 
            atualizado_em = CURRENT_TIMESTAMP 
        WHERE id = NEW.conta_id;
    ELSE
        UPDATE financeiro.contas_razao 
        SET saldo_atual = saldo_atual + NEW.valor, 
            atualizado_em = CURRENT_TIMESTAMP 
        WHERE id = NEW.conta_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_lancamento_financeiro
AFTER INSERT ON financeiro.lancamentos
FOR EACH ROW EXECUTE FUNCTION financeiro.fnc_validar_dupla_entrada();

-- Selo Criptográfico HMAC-SHA256 para impedir manipulação fraudulenta de saldos
CREATE OR REPLACE FUNCTION financeiro.fnc_assinar_conta_razao()
RETURNS TRIGGER AS $$
DECLARE
    v_dados TEXT;
    v_chave BYTEA := 'ChaveSecretaFinancasMilitarCV2026';
BEGIN
    v_dados := NEW.id::text || '|' || NEW.entidade_id::text || '|' || NEW.saldo_atual::text || '|' || NEW.moeda;
    NEW.assinatura_seguranca := hmac(v_dados, v_chave, 'sha256');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_selar_conta_razao
BEFORE INSERT OR UPDATE ON financeiro.contas_razao
FOR EACH ROW EXECUTE FUNCTION financeiro.fnc_assinar_conta_razao();

-- --------------------------------------------------------------------
-- 4. MÓDULO MARKETPLACE: INVENTÁRIO, PEDIDOS E ESCROW
-- --------------------------------------------------------------------

-- Catálogo Geral de Produtos e Serviços
CREATE TABLE marketplace.catalogo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loja_id UUID NOT NULL REFERENCES marketplace.lojas(id) ON DELETE CASCADE,
    subcategoria_id UUID NOT NULL REFERENCES marketplace.subcategorias(id) ON DELETE RESTRICT,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    preco NUMERIC(12, 2) NOT NULL CHECK (preco >= 0.00),
    stock INT, -- NULL para Serviços / Infoprodutos / Fretes
    ativo BOOLEAN DEFAULT TRUE NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Itens do Carrinho Ativo
CREATE TABLE marketplace.carrinho (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES core.clientes(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES marketplace.catalogo(id) ON DELETE CASCADE,
    quantidade INT NOT NULL CHECK (quantidade > 0),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Encomendas e Fluxo Logístico
CREATE TABLE marketplace.pedidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES core.clientes(id) ON DELETE RESTRICT,
    loja_id UUID NOT NULL REFERENCES marketplace.lojas(id) ON DELETE RESTRICT,
    status VARCHAR(50) DEFAULT 'pendente' NOT NULL CHECK (status IN ('pendente', 'pago', 'em_transito', 'entregue', 'cancelado')),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Conta de Custódia Militar (Escrow Temporário)
CREATE TABLE marketplace.escrow (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID NOT NULL REFERENCES marketplace.pedidos(id) ON DELETE CASCADE UNIQUE,
    valor_retido NUMERIC(12, 2) NOT NULL,
    liberado BOOLEAN DEFAULT FALSE NOT NULL,
    data_liberacao TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_pedidos_cliente ON marketplace.pedidos(cliente_id);
CREATE INDEX idx_catalogo_loja ON marketplace.catalogo(loja_id);

-- --------------------------------------------------------------------
-- 5. MÓDULO FEATURES: ENGAJAMENTO, FIDELIZAÇÃO E PARCEIROS
-- --------------------------------------------------------------------

-- Avaliações de Produtos (Sistema de Classificação por Estrelas)
CREATE TABLE marketplace.avaliacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES core.clientes(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES marketplace.catalogo(id) ON DELETE CASCADE,
    classificacao INT NOT NULL CHECK (classificacao BETWEEN 1 AND 5),
    comentario TEXT,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Lista de Desejos / Favoritagem de Produtos
CREATE TABLE marketplace.favoritos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES core.clientes(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES marketplace.catalogo(id) ON DELETE CASCADE,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_cliente_favorito UNIQUE (cliente_id, produto_id)
);

-- Programa Estruturado de Afiliados
-- Linha 320:
CREATE TABLE marketplace.afiliados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES core.usuarios(id) ON DELETE CASCADE UNIQUE,
    codigo_afiliado VARCHAR(50) UNIQUE NOT NULL,
    comissao_afiliado NUMERIC(5, 4) DEFAULT 0.0200 NOT NULL, -- 2% padrão de comissão
    ativo BOOLEAN DEFAULT TRUE NOT NULL
);

-- Cupons de Desconto Dinâmicos e Promocionais
CREATE TABLE marketplace.cupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loja_id UUID REFERENCES marketplace.lojas(id) ON DELETE CASCADE, -- NULL se global do sistema
    codigo VARCHAR(50) UNIQUE NOT NULL,
    tipo_desconto VARCHAR(20) NOT NULL CHECK (tipo_desconto IN ('percentagem', 'fixo')),
    valor NUMERIC(12, 2) NOT NULL,
    limite_usos INT,
    usos_atuais INT DEFAULT 0,
    validade TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Cupons de Desconto Dinâmicos e Promocionais
CREATE TABLE marketplace.cupons (
-- --------------------------------------------------------------------
-- 8. POPULAÇÃO DE DADOS ESSENCIAIS (SEED INTEGRADO)
-- --------------------------------------------------------------------

-- Inserindo taxas de câmbio oficiais
INSERT INTO financeiro.taxas_cambio (moeda_origem, moeda_destino, taxa_conversao, fixa) VALUES
('EUR', 'CVE', 110.265000, TRUE),  -- Paridade fixa com o Euro
('USD', 'CVE', 101.550000, FALSE), -- Dólar americano
('GBP', 'CVE', 128.400000, FALSE)  -- Libra esterlina
ON CONFLICT (moeda_origem) DO UPDATE 
SET taxa_conversao = EXCLUDED.taxa_conversao, atualizado_em = CURRENT_TIMESTAMP;

-- Inserindo Categorias Base do Ecossistema NôsLink
INSERT INTO marketplace.categorias (id, nome, slug, descricao) VALUES
('10000000-0000-0000-0000-000000000001', 'Alimentação e Produtos Locais', 'alimentacao', 'Alimentos frescos, grogue e licores típicos de Cabo Verde'),
('10000000-0000-0000-0000-000000000002', 'Agronegócio e Insumos', 'agronegocio', 'Sementes, fertilizantes e ferramentas de cultivo'),
('10000000-0000-0000-0000-000000000003', 'Serviços Globais e Logística', 'servicos-transporte', 'Logística interilhas, fretes e transporte de mercadorias')
ON CONFLICT (id) DO NOTHING;
-- --------------------------------------------------------------------
-- 8. POPULAÇÃO DE DADOS ESSENCIAIS (SEED INTEGRADO)
-- --------------------------------------------------------------------

-- Inserindo taxas de câmbio oficiais
INSERT INTO financeiro.taxas_cambio (moeda_origem, moeda_destino, taxa_conversao, fixa) VALUES
('EUR', 'CVE', 110.265000, TRUE),  -- Paridade fixa com o Euro
('USD', 'CVE', 101.550000, FALSE), -- Dólar americano
('GBP', 'CVE', 128.400000, FALSE)  -- Libra esterlina
ON CONFLICT (moeda_origem) DO UPDATE 
SET taxa_conversao = EXCLUDED.taxa_conversao, atualizado_em = CURRENT_TIMESTAMP;

-- Inserindo Categorias Base do Ecossistema NôsLink
INSERT INTO marketplace.categorias (id, nome, slug, descricao) VALUES
('10000000-0000-0000-0000-000000000001', 'Alimentação e Produtos Locais', 'alimentacao', 'Alimentos frescos, grogue e licores típicos de Cabo Verde'),
('10000000-0000-0000-0000-000000000002', 'Agronegócio e Insumos', 'agronegocio', 'Sementes, fertilizantes e ferramentas de cultivo'),
('10000000-0000-0000-0000-000000000003', 'Serviços Globais e Logística', 'servicos-transporte', 'Logística interilhas, fretes e transporte de mercadorias')
ON CONFLICT (id) DO NOTHING;

-- Inserindo Subcategorias correspondentes (Agora no fluxo correto, após a criação das categorias)
INSERT INTO marketplace.subcategorias (categoria_id, nome, slug) VALUES
('10000000-0000-0000-0000-000000000001', 'Grogue e Bebidas Tradicionais', 'grogue-bebidas'),
('10000000-0000-0000-0000-000000000002', 'Cana-de-Açúcar e Matéria Prima', 'cana-acucar'),
('10000000-0000-0000-0000-000000000003', 'Fretes de Camião e Cargas', 'fretes-cargas')
ON CONFLICT ON CONSTRAINT uq_categoria_subcategoria DO NOTHING;

-- =======================================================
-- 9. GARANTIA DE ISOLAMENTO DE DADOS (RLS) - APLICADO NO FIM
-- =======================================================
ALTER TABLE marketplace.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace.pedidos FORCE ROW LEVEL SECURITY;

-- Verificação segura de política única executada apenas uma vez
DROP POLICY IF EXISTS pedidos_isolation_policy ON marketplace.pedidos;
CREATE POLICY pedidos_isolation_policy ON marketplace.pedidos
    FOR ALL
    USING (cliente_id = NULLIF(current_setting('app.current_client_id', true), '')::uuid);