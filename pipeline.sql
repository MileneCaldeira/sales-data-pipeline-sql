-- ============================================================
-- PIPELINE: Carga e Validação de Dados de Vendas
-- Autor: Milene Caldeira
-- ============================================================
-- Etapas do pipeline:
--   1. Staging  → carga bruta sem transformações
--   2. Validação → checagem de regras de qualidade
--   3. Quarentena → isolamento de registros com problemas
--   4. Carga final → apenas dados aprovados vão para produção
--   5. Log de execução → rastreabilidade de cada carga
-- ============================================================


-- ============================================================
-- ETAPA 0: SETUP DAS TABELAS
-- ============================================================

-- Tabela de staging: recebe os dados brutos sem qualquer filtro
DROP TABLE IF EXISTS stg_vendas;
CREATE TABLE stg_vendas (
    id_venda        VARCHAR(10),
    data_venda      VARCHAR(20),    -- VARCHAR para aceitar qualquer formato
    id_cliente      VARCHAR(10),
    produto         VARCHAR(100),
    categoria       VARCHAR(50),
    quantidade      VARCHAR(10),    -- VARCHAR para capturar valores inválidos
    preco_unitario  VARCHAR(20),
    desconto_pct    VARCHAR(10),
    status          VARCHAR(30),
    regiao          VARCHAR(30),
    dt_carga        DATETIME DEFAULT GETDATE(),
    lote_carga      VARCHAR(20)
);

-- Tabela de quarentena: registros que falharam na validação
DROP TABLE IF EXISTS quarentena_vendas;
CREATE TABLE quarentena_vendas (
    id_registro     INT IDENTITY(1,1) PRIMARY KEY,
    id_venda        VARCHAR(10),
    motivo_rejeicao VARCHAR(500),
    regra_violada   VARCHAR(100),
    severidade      VARCHAR(10),    -- CRITICO | AVISO
    dt_quarentena   DATETIME DEFAULT GETDATE(),
    lote_carga      VARCHAR(20)
);

-- Tabela de log de execução
DROP TABLE IF EXISTS log_pipeline;
CREATE TABLE log_pipeline (
    id_log          INT IDENTITY(1,1) PRIMARY KEY,
    lote_carga      VARCHAR(20),
    etapa           VARCHAR(50),
    registros_in    INT,
    registros_ok    INT,
    registros_rejeitados INT,
    status_etapa    VARCHAR(20),
    mensagem        VARCHAR(500),
    dt_execucao     DATETIME DEFAULT GETDATE()
);

-- Tabela de produção: apenas dados validados
DROP TABLE IF EXISTS fato_vendas;
CREATE TABLE fato_vendas (
    id_venda        VARCHAR(10) PRIMARY KEY,
    data_venda      DATE NOT NULL,
    id_cliente      VARCHAR(10) NOT NULL,
    produto         VARCHAR(100),
    categoria       VARCHAR(50),
    quantidade      INT NOT NULL,
    preco_unitario  DECIMAL(10,2) NOT NULL,
    desconto_pct    INT DEFAULT 0,
    valor_liquido   DECIMAL(10,2),
    status          VARCHAR(20),
    regiao          VARCHAR(30),
    dt_carga        DATETIME DEFAULT GETDATE(),
    lote_carga      VARCHAR(20)
);


-- ============================================================
-- ETAPA 1: STORED PROCEDURE — CARGA NO STAGING
-- ============================================================

DROP PROCEDURE IF EXISTS sp_carga_staging;
GO

CREATE PROCEDURE sp_carga_staging
    @lote_carga VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @registros_inseridos INT = 0;
    DECLARE @msg VARCHAR(500);

    BEGIN TRY
        -- Marca o início da etapa no log
        INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                                  registros_rejeitados, status_etapa, mensagem)
        VALUES (@lote_carga, 'STAGING_INICIO', 0, 0, 0, 'EXECUTANDO',
                'Iniciando carga no staging para o lote ' + @lote_carga);

        -- Limpa registros anteriores do mesmo lote (idempotência)
        DELETE FROM stg_vendas WHERE lote_carga = @lote_carga;

        -- Em produção, aqui viria um BULK INSERT ou INSERT via ETL
        -- Para este projeto, simulamos com INSERT direto dos dados raw
        INSERT INTO stg_vendas (id_venda, data_venda, id_cliente, produto, categoria,
                                quantidade, preco_unitario, desconto_pct, status,
                                regiao, lote_carga)
        VALUES
        ('V001','2024-03-01','C001','Notebook Dell','Eletrônicos','1','3200.00','0','Concluída','Sudeste',@lote_carga),
        ('V002','2024-03-02','C002','Mouse Logitech','Periféricos','2','150.00','5','Concluída','Sudeste',@lote_carga),
        ('V003','2024-03-03',NULL,'Teclado Mecânico','Periféricos','1','380.00','0','Concluída','Sudeste',@lote_carga),   -- id_cliente NULL
        ('V004','2024-03-04','C004','Monitor LG','Eletrônicos','-1','1800.00','10','Concluída','Sudeste',@lote_carga),   -- quantidade negativa
        ('V005','2024-03-05','C005','Headset Gamer','Periféricos','3','250.00','0','Cancelada','Sul',@lote_carga),
        ('V006','2024-03-06','C006','SSD 1TB','Armazenamento','2','420.00','0','Concluída','Nordeste',@lote_carga),
        ('V007','2024-03-07','C007','Webcam HD','Periféricos','1','320.00','5','Concluída','Sudeste',@lote_carga),
        ('V008','2024-03-08','C008','Notebook Lenovo','Eletrônicos','1','2900.00','0','Concluída','Nordeste',@lote_carga),
        ('V009','2024-03-09','C009','HD Externo 2TB','Armazenamento','1','550.00','0','Pendente','Sul',@lote_carga),
        ('V010','2024-03-10','C010','Impressora HP','Outros','1','890.00','10','Concluída','Sudeste',@lote_carga),
        ('V011','2024-03-11','C001','Mouse Logitech','Periféricos','1','150.00','0','Concluída','Sudeste',@lote_carga),
        ('V012','2024-03-12','C002','Notebook Dell','Eletrônicos','1','3200.00','0','Cancelada','Sudeste',@lote_carga),
        ('V013','2024-03-13','C011','SSD 512GB','Armazenamento','3','280.00','5','Concluída','Centro-Oeste',@lote_carga),
        ('V014','2024-03-14','C012','Monitor Samsung','Eletrônicos','2','1500.00','0','Concluída','Sudeste',@lote_carga),
        ('V015','2024-03-15','C013','Teclado Sem Fio','Periféricos','1','220.00','0','Concluída','Norte',@lote_carga),
        ('V016','2024-03-16','C014','Webcam 4K','Periféricos','1','680.00','15','Concluída','Sudeste',@lote_carga),
        ('V017','2024-03-17','C015','Notebook Acer','Eletrônicos','1','2600.00','0','Concluída','Sudeste',@lote_carga),
        ('V018','2024-03-18','C016','HD Externo 1TB','Armazenamento','2','380.00','0','Concluída','Sudeste',@lote_carga),
        ('V019','2024-03-19','C017','Headset Sony','Periféricos','1','450.00','5','Concluída','Sudeste',@lote_carga),
        ('V020','2024-03-20','C018','Impressora Epson','Outros','1','1200.00','0','Pendente','Sul',@lote_carga),
        ('V021','2024-03-21','C019','Notebook Dell','Eletrônicos','2','3200.00','10','Concluída','Sudeste',@lote_carga),
        ('V022','2024-03-22','C020','Mouse Sem Fio','Periféricos','4','120.00','0','Concluída','Nordeste',@lote_carga),
        ('V023','2024-03-23','C001','SSD 2TB','Armazenamento','1','780.00','0','Concluída','Sudeste',@lote_carga),
        ('V024','2024-03-24','C003','Teclado Mecânico','Periféricos','2','380.00','5','Concluída','Sudeste',@lote_carga),
        ('V025','2024-03-25','C004','Monitor Samsung','Eletrônicos','3','1500.00','0','Concluída','Sudeste',@lote_carga),
        ('V026','2024-03-26','C007','Notebook Dell','Eletrônicos','1','3200.00','0','Concluída','Sudeste',@lote_carga),
        ('V027','2024-03-27','C009','SSD 2TB','Armazenamento','1','780.00','0','Cancelada','Sul',@lote_carga),
        ('V028','2024-03-28','C001','Headset Gamer','Periféricos','1','250.00','0','Concluída','Sudeste',@lote_carga),
        ('V029','2024-03-29','C002','Webcam HD','Periféricos','2','320.00','5','Concluída','Sudeste',@lote_carga),
        ('V030','2024-03-30','C003','Monitor Samsung','Eletrônicos','1','1500.00','0','Concluída','Sudeste',@lote_carga),
        ('V031','2024-03-31','C001','Notebook Dell','Eletrônicos','1','3200.00','0','Concluída','Sudeste',@lote_carga),
        ('V032','2024-04-01','C005','SSD 1TB','Armazenamento','2','420.00','0','Concluída','Sul',@lote_carga),
        ('V033','2024-04-01','C005','SSD 1TB','Armazenamento','2','420.00','0','Concluída','Sul',@lote_carga),           -- duplicata de V032
        ('V034','2024-04-02','C010','Monitor LG','Eletrônicos','1','99999.00','0','Concluída','Sudeste',@lote_carga),   -- preço outlier
        ('V035','2024-04-03','C012','Headset Gamer','Periféricos','1','250.00','110','Concluída','Sudeste',@lote_carga), -- desconto > 100%
        ('V036','2024-04-04','C014','Notebook Dell','Eletrônicos','1','3200.00','0','Aprovada','Sudeste',@lote_carga),  -- status inválido
        ('V037','2024-04-05','C007','Mouse Logitech','Periféricos','0','150.00','0','Concluída','Sudeste',@lote_carga), -- quantidade zero
        ('V038','2024-04-06','C019','Webcam HD','Periféricos','1','320.00','5','Concluída','Sudeste',@lote_carga),
        ('V039','2024-04-07','C001','SSD 512GB','Armazenamento','2','280.00','0','Concluída','Sudeste',@lote_carga),
        ('V040','2024-04-08','C003','Monitor Samsung','Eletrônicos','1','1500.00','0','Concluída','Sudeste',@lote_carga);

        SET @registros_inseridos = @@ROWCOUNT;

        -- Registra sucesso no log
        INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                                  registros_rejeitados, status_etapa, mensagem)
        VALUES (@lote_carga, 'STAGING_FIM', @registros_inseridos, @registros_inseridos,
                0, 'SUCESSO', CAST(@registros_inseridos AS VARCHAR) + ' registros carregados no staging.');

    END TRY
    BEGIN CATCH
        INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                                  registros_rejeitados, status_etapa, mensagem)
        VALUES (@lote_carga, 'STAGING_ERRO', 0, 0, 0, 'ERRO',
                'Erro: ' + ERROR_MESSAGE());
        THROW;
    END CATCH
END;
GO


-- ============================================================
-- ETAPA 2: STORED PROCEDURE — VALIDAÇÃO DE QUALIDADE
-- ============================================================

DROP PROCEDURE IF EXISTS sp_validacao_qualidade;
GO

CREATE PROCEDURE sp_validacao_qualidade
    @lote_carga VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @total INT, @rejeitados INT;
    SELECT @total = COUNT(*) FROM stg_vendas WHERE lote_carga = @lote_carga;

    -- Limpa quarentena anterior do mesmo lote
    DELETE FROM quarentena_vendas WHERE lote_carga = @lote_carga;

    -- --------------------------------------------------------
    -- REGRA 1 [CRÍTICO]: id_cliente nulo ou vazio
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Campo id_cliente está nulo ou vazio — venda não pode ser atribuída a nenhum cliente.',
           'REG-01: id_cliente NOT NULL',
           'CRITICO',
           @lote_carga
    FROM stg_vendas
    WHERE lote_carga = @lote_carga
      AND (id_cliente IS NULL OR TRIM(id_cliente) = '');

    -- --------------------------------------------------------
    -- REGRA 2 [CRÍTICO]: quantidade zero ou negativa
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Quantidade inválida: ' + quantidade + '. Deve ser maior que zero.',
           'REG-02: quantidade > 0',
           'CRITICO',
           @lote_carga
    FROM stg_vendas
    WHERE lote_carga = @lote_carga
      AND TRY_CAST(quantidade AS INT) IS NOT NULL
      AND CAST(quantidade AS INT) <= 0;

    -- --------------------------------------------------------
    -- REGRA 3 [CRÍTICO]: desconto acima de 100%
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Desconto inválido: ' + desconto_pct + '%. Valor não pode exceder 100%.',
           'REG-03: desconto_pct BETWEEN 0 AND 100',
           'CRITICO',
           @lote_carga
    FROM stg_vendas
    WHERE lote_carga = @lote_carga
      AND TRY_CAST(desconto_pct AS INT) IS NOT NULL
      AND CAST(desconto_pct AS INT) > 100;

    -- --------------------------------------------------------
    -- REGRA 4 [CRÍTICO]: status fora do domínio permitido
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Status "' + status + '" não é um valor aceito. Valores válidos: Concluída, Cancelada, Pendente.',
           'REG-04: status IN (Concluída, Cancelada, Pendente)',
           'CRITICO',
           @lote_carga
    FROM stg_vendas
    WHERE lote_carga = @lote_carga
      AND status NOT IN ('Concluída', 'Cancelada', 'Pendente');

    -- --------------------------------------------------------
    -- REGRA 5 [CRÍTICO]: registros duplicados no mesmo lote
    -- (mesmo id_cliente + produto + data_venda + quantidade)
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Possível duplicata detectada: mesma combinação de cliente, produto, data e quantidade já existe no lote.',
           'REG-05: sem duplicatas por (id_cliente, produto, data_venda, quantidade)',
           'CRITICO',
           @lote_carga
    FROM (
        SELECT id_venda,
               ROW_NUMBER() OVER (
                   PARTITION BY id_cliente, produto, data_venda, quantidade
                   ORDER BY id_venda
               ) AS rn
        FROM stg_vendas
        WHERE lote_carga = @lote_carga
    ) AS dup
    WHERE rn > 1;

    -- --------------------------------------------------------
    -- REGRA 6 [AVISO]: preço unitário fora do intervalo esperado
    -- Outlier acima de R$ 10.000 — sinaliza para revisão manual
    -- --------------------------------------------------------
    INSERT INTO quarentena_vendas (id_venda, motivo_rejeicao, regra_violada, severidade, lote_carga)
    SELECT id_venda,
           'Preço unitário de R$ ' + preco_unitario + ' está acima do limite de alerta (R$ 10.000). Verificar se é erro de digitação.',
           'REG-06: preco_unitario <= 10000 (AVISO)',
           'AVISO',
           @lote_carga
    FROM stg_vendas
    WHERE lote_carga = @lote_carga
      AND TRY_CAST(preco_unitario AS DECIMAL(10,2)) IS NOT NULL
      AND CAST(preco_unitario AS DECIMAL(10,2)) > 10000;

    -- Registra resultado da validação no log
    SELECT @rejeitados = COUNT(DISTINCT id_venda)
    FROM quarentena_vendas
    WHERE lote_carga = @lote_carga AND severidade = 'CRITICO';

    INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                              registros_rejeitados, status_etapa, mensagem)
    VALUES (@lote_carga, 'VALIDACAO', @total, @total - @rejeitados, @rejeitados,
            CASE WHEN @rejeitados = 0 THEN 'SUCESSO' ELSE 'SUCESSO_COM_REJEICOES' END,
            CAST(@rejeitados AS VARCHAR) + ' registro(s) crítico(s) enviados à quarentena de ' +
            CAST(@total AS VARCHAR) + ' registros validados.');
END;
GO


-- ============================================================
-- ETAPA 3: STORED PROCEDURE — CARGA NA TABELA DE PRODUÇÃO
-- Apenas registros sem erros críticos são promovidos
-- ============================================================

DROP PROCEDURE IF EXISTS sp_carga_producao;
GO

CREATE PROCEDURE sp_carga_producao
    @lote_carga VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @registros_carregados INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Remove registros anteriores do mesmo lote (reprocessamento seguro)
        DELETE FROM fato_vendas WHERE lote_carga = @lote_carga;

        -- Insere apenas registros sem erros críticos na quarentena
        INSERT INTO fato_vendas (id_venda, data_venda, id_cliente, produto, categoria,
                                 quantidade, preco_unitario, desconto_pct, valor_liquido,
                                 status, regiao, lote_carga)
        SELECT
            s.id_venda,
            CAST(s.data_venda AS DATE),
            s.id_cliente,
            s.produto,
            s.categoria,
            CAST(s.quantidade AS INT),
            CAST(s.preco_unitario AS DECIMAL(10,2)),
            CAST(s.desconto_pct AS INT),
            -- Calcula valor líquido já na carga
            ROUND(
                CAST(s.preco_unitario AS DECIMAL(10,2))
                * CAST(s.quantidade AS INT)
                * (1 - CAST(s.desconto_pct AS DECIMAL(5,2)) / 100)
            , 2),
            s.status,
            s.regiao,
            s.lote_carga
        FROM stg_vendas s
        WHERE s.lote_carga = @lote_carga
          -- Exclui todos os registros que tiveram erros críticos
          AND s.id_venda NOT IN (
              SELECT DISTINCT id_venda
              FROM quarentena_vendas
              WHERE lote_carga = @lote_carga
                AND severidade = 'CRITICO'
          );

        SET @registros_carregados = @@ROWCOUNT;

        COMMIT TRANSACTION;

        INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                                  registros_rejeitados, status_etapa, mensagem)
        VALUES (@lote_carga, 'CARGA_PRODUCAO',
                (SELECT COUNT(*) FROM stg_vendas WHERE lote_carga = @lote_carga),
                @registros_carregados,
                (SELECT COUNT(*) FROM stg_vendas WHERE lote_carga = @lote_carga) - @registros_carregados,
                'SUCESSO',
                CAST(@registros_carregados AS VARCHAR) + ' registros promovidos para produção.');

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        INSERT INTO log_pipeline (lote_carga, etapa, registros_in, registros_ok,
                                  registros_rejeitados, status_etapa, mensagem)
        VALUES (@lote_carga, 'CARGA_PRODUCAO_ERRO', 0, 0, 0, 'ERRO',
                'Erro na carga para produção: ' + ERROR_MESSAGE());
        THROW;
    END CATCH
END;
GO


-- ============================================================
-- ETAPA 4: EXECUÇÃO COMPLETA DO PIPELINE
-- ============================================================

DECLARE @lote VARCHAR(20) = 'LOTE_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmm');

-- Executa as três etapas em sequência
EXEC sp_carga_staging     @lote_carga = @lote;
EXEC sp_validacao_qualidade @lote_carga = @lote;
EXEC sp_carga_producao    @lote_carga = @lote;


-- ============================================================
-- ETAPA 5: RELATÓRIO DE EXECUÇÃO
-- ============================================================

-- Resumo do pipeline
SELECT
    lote_carga,
    etapa,
    registros_in,
    registros_ok,
    registros_rejeitados,
    status_etapa,
    mensagem,
    dt_execucao
FROM log_pipeline
ORDER BY dt_execucao;


-- Registros em quarentena com detalhes
SELECT
    q.id_venda,
    q.severidade,
    q.regra_violada,
    q.motivo_rejeicao,
    s.id_cliente,
    s.produto,
    s.quantidade,
    s.preco_unitario,
    s.desconto_pct,
    s.status
FROM quarentena_vendas q
LEFT JOIN stg_vendas s ON q.id_venda = s.id_venda
                       AND q.lote_carga = s.lote_carga
ORDER BY q.severidade, q.id_venda;


-- Resumo: quantos registros aprovados vs rejeitados
SELECT
    'Aprovados para produção'       AS situacao,
    COUNT(*)                        AS registros
FROM fato_vendas
UNION ALL
SELECT
    'Críticos em quarentena',
    COUNT(DISTINCT id_venda)
FROM quarentena_vendas
WHERE severidade = 'CRITICO'
UNION ALL
SELECT
    'Avisos (aguardando revisão)',
    COUNT(DISTINCT id_venda)
FROM quarentena_vendas
WHERE severidade = 'AVISO';
