-- Localité | Banco de dados inicial
-- Compatível com MySQL 8.0+
-- Dados fictícios para testes acadêmicos. Não inserir dados reais de usuários.

CREATE DATABASE IF NOT EXISTS localite
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE localite;

CREATE TABLE IF NOT EXISTS usuarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    tipo ENUM('consumidor', 'comerciante', 'administrador') NOT NULL DEFAULT 'consumidor',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categorias (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(80) NOT NULL UNIQUE,
    descricao VARCHAR(255),
    ativa BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS estabelecimentos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_responsavel_id BIGINT UNSIGNED NOT NULL,
    categoria_id BIGINT UNSIGNED NOT NULL,
    nome VARCHAR(140) NOT NULL,
    descricao TEXT,
    telefone VARCHAR(25),
    endereco VARCHAR(180),
    cidade VARCHAR(100) NOT NULL DEFAULT 'São João dos Patos',
    estado CHAR(2) NOT NULL DEFAULT 'MA',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_estabelecimento_usuario
        FOREIGN KEY (usuario_responsavel_id) REFERENCES usuarios(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_estabelecimento_categoria
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_estabelecimentos_nome (nome),
    INDEX idx_estabelecimentos_categoria (categoria_id),
    INDEX idx_estabelecimentos_cidade (cidade, estado)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS itens_catalogo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    estabelecimento_id BIGINT UNSIGNED NOT NULL,
    categoria_id BIGINT UNSIGNED NOT NULL,
    nome VARCHAR(140) NOT NULL,
    descricao TEXT,
    tipo ENUM('produto', 'servico') NOT NULL,
    preco DECIMAL(10,2),
    disponivel BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_item_preco CHECK (preco IS NULL OR preco >= 0),
    CONSTRAINT fk_item_estabelecimento
        FOREIGN KEY (estabelecimento_id) REFERENCES estabelecimentos(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_item_categoria
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_itens_estabelecimento (estabelecimento_id),
    INDEX idx_itens_categoria (categoria_id),
    INDEX idx_itens_nome (nome)
) ENGINE=InnoDB;

-- Carga inicial fictícia para validar o esquema.
INSERT INTO usuarios (nome, email, senha_hash, tipo)
VALUES
('Comerciante Demonstração', 'comerciante.demo@localite.test',
 'HASH_FICTICIO_NAO_UTILIZAR_EM_PRODUCAO', 'comerciante'),
('Consumidor Demonstração', 'consumidor.demo@localite.test',
 'HASH_FICTICIO_NAO_UTILIZAR_EM_PRODUCAO', 'consumidor')
ON DUPLICATE KEY UPDATE nome = VALUES(nome);

INSERT INTO categorias (nome, descricao)
VALUES
('Alimentação', 'Estabelecimentos e serviços de alimentação'),
('Beleza e estética', 'Salões, estética e cuidados pessoais'),
('Vestuário', 'Lojas de roupas e acessórios'),
('Serviços', 'Serviços profissionais diversos')
ON DUPLICATE KEY UPDATE descricao = VALUES(descricao);

-- O INSERT abaixo usa consultas para localizar os IDs, evitando depender
-- de números fixos gerados automaticamente.
INSERT INTO estabelecimentos
    (usuario_responsavel_id, categoria_id, nome, descricao, telefone, endereco)
SELECT u.id, c.id, 'Estabelecimento Exemplo',
       'Registro fictício para validar o banco de dados.',
       '(99) 99999-0000', 'Endereço de demonstração'
FROM usuarios u
JOIN categorias c ON c.nome = 'Serviços'
WHERE u.email = 'comerciante.demo@localite.test'
  AND NOT EXISTS (
      SELECT 1 FROM estabelecimentos e
      WHERE e.nome = 'Estabelecimento Exemplo'
        AND e.usuario_responsavel_id = u.id
  );

INSERT INTO itens_catalogo
    (estabelecimento_id, categoria_id, nome, descricao, tipo, preco)
SELECT e.id, c.id, 'Serviço de demonstração',
       'Item fictício para teste de consultas.',
       'servico', 50.00
FROM estabelecimentos e
JOIN categorias c ON c.nome = 'Serviços'
WHERE e.nome = 'Estabelecimento Exemplo'
  AND NOT EXISTS (
      SELECT 1 FROM itens_catalogo i
      WHERE i.estabelecimento_id = e.id
        AND i.nome = 'Serviço de demonstração'
  );

-- CONSULTAS (READ)
-- 1. Listar estabelecimentos ativos com categoria e responsável.
SELECT e.id, e.nome, c.nome AS categoria, e.telefone,
       e.cidade, u.nome AS responsavel
FROM estabelecimentos e
JOIN categorias c ON c.id = e.categoria_id
JOIN usuarios u ON u.id = e.usuario_responsavel_id
WHERE e.ativo = TRUE
ORDER BY e.nome;

-- 2. Pesquisar produtos e serviços disponíveis.
SELECT i.nome, i.tipo, i.preco, e.nome AS estabelecimento,
       c.nome AS categoria
FROM itens_catalogo i
JOIN estabelecimentos e ON e.id = i.estabelecimento_id
JOIN categorias c ON c.id = i.categoria_id
WHERE i.disponivel = TRUE
ORDER BY e.nome, i.nome;

-- ATUALIZAÇÃO (UPDATE): exemplo de alteração de telefone.
UPDATE estabelecimentos
SET telefone = '(99) 98888-1111'
WHERE nome = 'Estabelecimento Exemplo';

-- REMOÇÃO (DELETE): exemplo seguro usando o registro fictício.
-- A exclusão do estabelecimento remove seus itens de catálogo por CASCADE.
DELETE FROM estabelecimentos
WHERE nome = 'Estabelecimento Exemplo'
  AND endereco = 'Endereço de demonstração';

-- Consultas de conferência após a remoção.
SELECT COUNT(*) AS total_usuarios FROM usuarios;
SELECT COUNT(*) AS total_categorias FROM categorias;
SELECT COUNT(*) AS total_estabelecimentos FROM estabelecimentos;
SELECT COUNT(*) AS total_itens FROM itens_catalogo;

-- Observação: os registros fictícios de usuário e categoria são mantidos
-- para que possam ser reutilizados em novas execuções de teste.
