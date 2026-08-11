-- 1. Extensões, Schemas e Tipos
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Necessário para busca por apelido

-- Criar Schema Privado para dados sensíveis
CREATE SCHEMA IF NOT EXISTS private;

-- Garantir que anon/authenticated não acessem o schema private por padrão
REVOKE ALL ON SCHEMA private FROM anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

-- Tipos para Status de Compra e Entitlement
CREATE TYPE supporter_status AS ENUM ('active', 'pending', 'revoked', 'refunded', 'invalid');
CREATE TYPE entitlement_source AS ENUM ('google_play', 'manual', 'promo');

-- Tipos para Sessões de Jogo
CREATE TYPE session_status AS ENUM ('created', 'completed', 'expired', 'cancelled', 'rejected');

-- Tipos para Desafios
CREATE TYPE challenge_status AS ENUM ('open', 'closed', 'cancelled');
CREATE TYPE challenge_participant_status AS ENUM ('invited', 'accepted', 'completed', 'failed');

-- Tipo para Verificação de Resultados
CREATE TYPE verification_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
