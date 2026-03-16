# 🔧 Sales Data Pipeline — Carga e Validação de Qualidade

![SQL](https://img.shields.io/badge/SQL-Server-blue?style=flat-square&logo=microsoftsqlserver)
![Tema](https://img.shields.io/badge/tema-data%20quality%20·%20pipeline-orange?style=flat-square)
![Técnica](https://img.shields.io/badge/técnica-stored%20procedures%20·%20staging-9cf?style=flat-square)

> Pipeline de carga e validação de dados de vendas construído em SQL Server — com staging, regras de qualidade, quarentena de registros problemáticos e log de rastreabilidade. Do arquivo bruto à tabela de produção com controle total do que entra.

---

## 🔎 Principais Achados

### 7 dos 40 registros do lote falharam na validação
Na execução simulada com dados reais de entrada, **7 registros (17,5% do lote)** foram interceptados antes de chegar à produção — um número alto que em ambiente real justificaria revisão do processo de geração dos dados na origem.

### Os erros mais comuns são evitáveis com validação na origem
Os problemas encontrados no lote — campo de cliente nulo, quantidade zero, desconto acima de 100%, status fora do domínio — são todos erros de formulário ou integração que deveriam ser bloqueados antes do envio. O pipeline funciona como última linha de defesa, mas a solução definitiva é upstream.

### Duplicatas representam risco silencioso de inflação de receita
O registro duplicado (V032/V033) chegou com dados idênticos e não seria detectado por uma carga simples sem controle de duplicidade. Em pipelines de vendas, duplicatas não detectadas inflariam KPIs e comprometeriam decisões baseadas em receita.

### O log de execução permite rastrear qualquer carga retroativamente
Cada execução do pipeline gera um lote identificado com timestamp e registra — etapa por etapa — quantos registros entraram, quantos foram aprovados e quantos foram rejeitados. Isso viabiliza auditoria, reprocessamento e SLA de qualidade.

---

## 🎯 Contexto

Dados de vendas chegam de múltiplas origens — ERPs, formulários, integrações — e raramente chegam limpos. Este projeto implementa um pipeline em SQL Server que trata os dados como não confiáveis por padrão: tudo passa por staging e validação antes de ir para produção. Nenhum registro problemático contamina a tabela final.

---

## ⚙️ Arquitetura do Pipeline

```
[Dados Brutos]
      │
      ▼
┌─────────────────┐
│  stg_vendas     │  ← Carga bruta sem filtros (sp_carga_staging)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Validação      │  ← 6 regras de qualidade (sp_validacao_qualidade)
└──────┬──────┬───┘
       │      │
  Aprovado  Rejeitado
       │      │
       ▼      ▼
┌──────────┐ ┌──────────────────┐
│fato_vendas│ │quarentena_vendas │
└──────────┘ └──────────────────┘
       │
       ▼
┌─────────────────┐
│  log_pipeline   │  ← Rastreabilidade de cada execução
└─────────────────┘
```

---

## 📋 Regras de Validação Implementadas

| Código | Regra | Severidade | Impacto se violada |
|--------|-------|------------|-------------------|
| REG-01 | `id_cliente` não pode ser nulo | 🔴 CRÍTICO | Venda sem dono — não pode ser analisada |
| REG-02 | `quantidade` deve ser > 0 | 🔴 CRÍTICO | Receita negativa ou zerada |
| REG-03 | `desconto_pct` entre 0 e 100 | 🔴 CRÍTICO | Valor líquido negativo ou inválido |
| REG-04 | `status` apenas valores do domínio | 🔴 CRÍTICO | Quebra de categorização e filtros |
| REG-05 | Sem duplicatas por cliente+produto+data | 🔴 CRÍTICO | Inflação de receita nos KPIs |
| REG-06 | `preco_unitario` ≤ R$ 10.000 | 🟡 AVISO | Possível erro de digitação — revisão manual |

---

## 🗂️ Estrutura do Repositório

```
sales-data-pipeline-sql/
│
├── data/
│   └── vendas_raw.csv          # Arquivo de entrada com problemas intencionais
│
├── scripts/
│   └── pipeline.sql            # Pipeline completo: setup + 3 SPs + execução + relatório
│
└── README.md
```

---

## 💡 Destaques Técnicos

**Stored Procedure com tratamento de erro e log:**
```sql
BEGIN TRY
    BEGIN TRANSACTION;
    -- lógica de carga
    COMMIT TRANSACTION;
    INSERT INTO log_pipeline (...) VALUES (..., 'SUCESSO', ...);
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    INSERT INTO log_pipeline (...) VALUES (..., 'ERRO', ERROR_MESSAGE());
    THROW;
END CATCH
```

**Detecção de duplicatas com ROW_NUMBER() na quarentena:**
```sql
SELECT id_venda,
       ROW_NUMBER() OVER (
           PARTITION BY id_cliente, produto, data_venda, quantidade
           ORDER BY id_venda
       ) AS rn
FROM stg_vendas
WHERE rn > 1  -- apenas a segunda ocorrência em diante vai para quarentena
```

**Carga final exclui críticos via NOT IN na subconsulta:**
```sql
WHERE id_venda NOT IN (
    SELECT DISTINCT id_venda
    FROM quarentena_vendas
    WHERE severidade = 'CRITICO'
)
```

---

## 🚀 Como Executar

```bash
git clone https://github.com/MileneCaldeira/sales-data-pipeline-sql.git
```

No SSMS ou Azure Data Studio:
1. Execute `scripts/pipeline.sql` completo — ele cria as tabelas, as SPs e executa o pipeline
2. Verifique os resultados nas queries do **Relatório de Execução** ao final do script

Compatível com **SQL Server 2016+** (requer `TRY_CAST`, `FORMAT` e `ROW_NUMBER`).

---

## 📅 Série: 28 Dias de Dados

| Dia | Projeto | Foco Analítico |
|-----|---------|----------------|
| ✅ 01 | [sql-consultas-basicas](https://github.com/MileneCaldeira/sql-consultas-basicas) | Filtragem e exploração |
| ✅ 02 | [ecommerce-b2b-sql-analysis](https://github.com/MileneCaldeira/ecommerce-b2b-sql-analysis) | Modelo relacional |
| ✅ 03 | [commercial-kpis-by-dimension](https://github.com/MileneCaldeira/commercial-kpis-by-dimension) | KPIs por dimensão |
| ✅ 04 | [customer-churn-retention-sql](https://github.com/MileneCaldeira/customer-churn-retention-sql) | Churn e retenção |
| ✅ 05 | [repurchase-behavior-sql](https://github.com/MileneCaldeira/repurchase-behavior-sql) | Ciclo de recompra e RFV |
| ✅ 06 | [sales-data-pipeline-sql](.) | Pipeline de carga e validação |
| 🔜 07 | Em breve | Case de análise completo |
| 🔜 ... | ... | ... |

---

## 👩‍💻 Sobre

**Milene Caldeira** — BI Analyst com foco em dados comerciais, SQL, Power BI e cloud.

[![GitHub](https://img.shields.io/badge/GitHub-MileneCaldeira-black?style=flat-square&logo=github)](https://github.com/MileneCaldeira)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Conectar-blue?style=flat-square&logo=linkedin)](https://linkedin.com/in/milenecaldeira)
