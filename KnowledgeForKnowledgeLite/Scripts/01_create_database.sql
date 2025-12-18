-- ============================================
-- Скрипт создания базы данных
-- KnowledgeForKnowledgeLite
-- 
-- Описание: Этот скрипт создает базу данных и все необходимые таблицы
-- для системы обмена знаниями.
-- 
-- Использование:
-- mysql -u root -p < 01_create_database.sql
-- ============================================

-- Создание базы данных
CREATE DATABASE IF NOT EXISTS KnowledgeForKnowledgeLite CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Использование созданной базы данных
USE KnowledgeForKnowledgeLite;

-- Примечание: Полный DDL скрипт с созданием всех таблиц находится в файле init_database.sql
-- Этот файл служит для первичной инициализации БД

