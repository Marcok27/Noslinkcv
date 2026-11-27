# 🇨🇻 NôsLinkCV — Infraestrutura Digital do Comércio e Logística Inter-Ilhas

![Status](https://img.shields.io/badge/Status-MVP%20Funcional%20Ativo-success?style=for-the-badge)
![Cobertura](https://marcok27.github.io/Noslinkcv/)
![Stack](https://img.shields.io/badge/Stack-React%20%7C%20Node.js%20%7C%20PostgreSQL%20%7C%20Supabase-informational?style=for-the-badge)

> **"Nove ilhas. Um mercado. Uma só economia digital."**

A **NôsLinkCV** é uma plataforma ecossistémica que integra **Marketplace B2B/B2C, Orquestração Logística Multimodal Inter-Ilhas, Rastreabilidade em Tempo Real e Custódia Segura de Pagamentos (Escrow + OTP)** em Cabo Verde. O sistema resolve a fragmentação geográfica e logística do arquipélago, ligando produtores, lojas, transportadores e consumidores finais num único fluxo digital.

---

## 🎯 O Problema que Resolvemos

Em Cabo Verde, mais de **81,8% do PIB** concentra-se em apenas três ilhas (Santiago, São Vicente e Sal), deixando as restantes seis ilhas com acesso limitado a canais de escoamento e abastecimento. O comércio inter-ilhas enfrenta quatro gargalos críticos:
- **Fragmentação Logística:** Operadores marítimos e aéreos sem integração digital unificada e porões com capacidade subutilizada.
- **Cegueira Operacional:** Ausência de rastreamento em tempo real e fretes pouco transparentes.
- **Desconfiança nos Pagamentos:** Risco elevado em transferências antecipadas devido ao receio de extravios ou atrasos.
- **Processos Manuais:** Gestão informal de pedidos e inventários por mensagens diretas ou registos em papel.

---

## 🚀 Principais Funcionalidades

### 1. Identificação e Registo Único (`NLCV`)
- Registo de **Contas Pessoais** (Nome, CNI e WhatsApp) e **Empresariais** (Razão Social e NIF).
- Geração imediata de **ID Logístico Único** (`NLCV-PES-XXXXX` / `NLCV-EMP-XXXXX`) para acesso ao ecossistema.

### 2. Marketplace & Serviço Concierge
- **Catálogo Express:** Compra direta de artigos de lojas e produtores validados em diferentes ilhas.
- **Serviço Concierge (*"Compramos & Recolhemos por Ti"*):** Recolha presencial em qualquer estabelecimento físico na ilha de origem para artigos fora do catálogo online.

### 3. Inteligência Logística & Calculadora Multimodal
- Roteamento integrado entre transporte **Marítimo** (CV Interilhas), **Aéreo Expresso** (CVA / Cargo) e **Transportadoras Privadas Locais**.
- **Controlo Físico Inteligente (Massa vs. Volume):** Validação automática da capacidade dos navios em peso (`kg`) e volume (`m³`) através de funções SQL dedicadas (`fnc_alocar_viagem_pedido`), impedindo sobrelotação.
- **Mapa Dinâmico Interativo:** Visualização geolocalizada de portos, hubs logísticos, transportadoras e lojas parceiras.

### 4. Rastreabilidade Ponta a Ponta (`NL-XXXXXX`)
- Emissão de código de rastreio exclusivo por encomenda com consulta pública em tempo real.
- Máquina de estados automatizada: `aguardando_alocacao` → `alocado` → `pago` → `em_transito` → `disponivel_para_recolha` → `entregue`.

### 5. Custódia Financeira (Escrow Vinti4) & Validação OTP
- O pagamento (via Vinti4 / Transferência Bancária, Pagamento Móvel ou Cartão) fica retido em **conta de custódia segura**.
- Os fundos só são libertados ao vendedor e à transportadora após a confirmação física da entrega pelo comprador através de um **código OTP (One-Time Password)**.
- Três níveis de proteção configuráveis: **Básico**, **Standard** e **Premium**.

### 6. Atendimento Inteligente & Automação
- Assistente virtual integrado ao **WhatsApp** com processamento de linguagem natural (IA) para extração de intenções, consulta de rastreio e abertura de pedidos.
- Sincronização automatizada via **Webhooks** entre a base de dados, planilhas operacionais de controlo e liquidações financeiras.

---

## 🛠️ Arquitetura e Tecnologias Utilizadas

A arquitetura do projeto divide-se em camadas desacopladas para garantir integridade transacional, segurança de dados e escalabilidade:

### **Frontend & Aplicação Web**
- **React & HTML5 / CSS3 / JavaScript (ES6+):** Interface responsiva de single-page application (SPA), carrinho inter-ilhas, calculadora dinâmica de fretes e painel de rastreio.
- **Mapas & Geolocalização:** Integração com mapas interativos (CartoDB Voyager) para hubs portuários e lojas parceiras.

### **Backend, Base de Dados & Segurança**
- **Node.js & TypeScript:** Serviços de API, regras de negócio e testes automatizados de segurança (`security.test.ts`).
- **PostgreSQL & Supabase:** Base de dados relacional com 9 entidades principais (`ilhas`, `portos`, `transportadoras`, `clientes`, `navios`, `viagens`, `pedidos`, `sessoes_atendimento`, `mensagens_whatsapp`).
- **Segurança & Integridade:** Políticas de **Row-Level Security (RLS)** no Supabase para isolamento multi-tenant, *Triggers* de atualização automática e restrições de capacidade física (`CHECK` constraints).

### **Automação, IA & Integrações**
- **Make.com (Webhooks & Routers):** Orquestração de fluxos assíncronos, notificações de mudança de estado e registo de liquidações financeiras.
- **Inteligência Artificial (OpenAI / Google Gemini):** Classificação de intenções de mensagens e extração estruturada de códigos de rastreio.
- **WhatsApp Business API / Meta:** Canal conversacional para notificações ativas e suporte ao cliente.
- **Google Workspace (Google Sheets):** Painéis espelho para operação portuária e controlo de repasses (payouts).

---

## 🗄️ Modelo de Dados Relacional

```text
[Ilhas] 1 ──── * [Portos]
                    │
[Transportadoras] 1 ──── * [Navios] 1 ──── * [Viagens] 1 ──── * [Pedidos] * ──── 1 [Clientes]
                                                                    │
                                                       [Sessões Atendimento] 1 ──── * [Mensagens WhatsApp]
