# KnowledgeForKnowledgeLite API

Система обмена знаниями для студентов с использованием Minimal API, Swagger и голых SQL запросов.

## Требования

- .NET 9.0
- PostgreSQL 12+
- Visual Studio / Rider / VS Code

## Установка и настройка

### 1. Настройка базы данных PostgreSQL

**Рекомендуется использовать PostgreSQL** (текущая версия проекта).

1. Установите PostgreSQL: https://www.postgresql.org/download/

2. Создайте базу данных:

```sql
CREATE DATABASE KnowledgeForKnowledgeLite;
```

3. Выполните SQL скрипт для создания таблиц:

```bash
# Подключитесь к PostgreSQL и выполните скрипт
psql -U postgres -d KnowledgeForKnowledgeLite -f Scripts/00_init_database_postgresql.sql
```

Или через pgAdmin:
- Откройте Query Tool
- Выполните содержимое файла `Scripts/00_init_database_postgresql.sql`

**Описание SQL файлов:**
- `00_init_database_postgresql.sql` - Полный DDL скрипт для PostgreSQL (создание всех таблиц, индексов и справочных данных)
- `02_dml_queries_postgresql.sql` - DML запросы для всех функциональных требований
- `03_transactions_postgresql.sql` - Транзакции для критичных операций

**Примечание:** SQL запросы в DML и транзакциях совместимы с PostgreSQL (используется стандартный SQL синтаксис).

### 2. Настройка connection string

Отредактируйте `appsettings.json` и укажите правильный connection string для PostgreSQL:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=KnowledgeForKnowledgeLite;Username=postgres;Password=ВАШ_ПАРОЛЬ;"
  }
```

### 3. Восстановление пакетов

```bash
dotnet restore
```

### 4. Запуск приложения

```bash
dotnet run
```

Приложение будет доступно по адресу:
- HTTP: `http://localhost:5232`
- HTTPS: `https://localhost:7134`
- Swagger UI: `http://localhost:5232/swagger`

## API Endpoints

### Accounts (Аккаунты)

- `POST /api/accounts/register` - Регистрация нового пользователя
- `POST /api/accounts/login` - Вход в систему
- `DELETE /api/accounts/{accountId}` - Мягкое удаление аккаунта

### User Profiles (Профили пользователей)

- `GET /api/users/{accountId}/profile` - Получить профиль пользователя
- `PUT /api/users/{accountId}/profile` - Обновить профиль пользователя

### User Contacts (Контакты)

- `POST /api/users/{accountId}/contacts` - Добавить контакт
- `GET /api/users/{accountId}/contacts?publicOnly={bool}` - Получить контакты пользователя

### Skills (Навыки)

- `GET /api/skills/categories` - Получить категории навыков
- `GET /api/skills/levels` - Получить уровни навыков
- `GET /api/skills?categoryId={id}` - Получить навыки (опционально по категории)
- `POST /api/users/{accountId}/skills` - Добавить навык пользователю
- `GET /api/users/{accountId}/skills` - Получить навыки пользователя
- `GET /api/skills/{skillName}/users?minLevelRank={rank}` - Поиск пользователей по навыку

### Education (Образование)

- `POST /api/users/{accountId}/education` - Добавить запись об образовании
- `GET /api/users/{accountId}/education` - Получить образование пользователя

### Proofs (Документы)

- `POST /api/users/{accountId}/proofs` - Загрузить документ
- `GET /api/users/{accountId}/proofs` - Получить документы пользователя
- `POST /api/proofs/{proofId}/verify` - Верифицировать документ (требуется заголовок X-Admin-ID)

### Skill Posts (Посты)

- `POST /api/users/{accountId}/posts` - Создать пост (предложение/запрос)
- `GET /api/posts?skillId={id}&postType={type}&status={status}` - Получить посты
- `GET /api/posts/{postId}` - Получить пост по ID (увеличивает счетчик просмотров)
- `PUT /api/posts/{postId}/status` - Изменить статус поста

## Примеры использования

### Регистрация пользователя

```bash
curl -X POST "http://localhost:5232/api/accounts/register" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "student@university.edu",
    "password": "secure_password"
  }'
```

### Вход в систему

```bash
curl -X POST "http://localhost:5232/api/accounts/login" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "student@university.edu",
    "password": "secure_password"
  }'
```

### Добавление навыка пользователю

```bash
curl -X POST "http://localhost:5232/api/users/1/skills" \
  -H "Content-Type: application/json" \
  -d '{
    "skillId": 3,
    "skillLevelId": 2,
    "experienceYears": 2.5
  }'
```

### Создание поста (предложение помощи)

```bash
curl -X POST "http://localhost:5232/api/users/1/posts" \
  -H "Content-Type: application/json" \
  -d '{
    "skillId": 1,
    "postType": "Offer",
    "title": "Помощь с линейной алгеброй",
    "details": "Готов помочь с решением задач по линейной алгебре.",
    "contactPreference": "Telegram",
    "expiresAt": "2024-12-31T23:59:59"
  }'
```

### Создание поста (запрос помощи)

```bash
curl -X POST "https://localhost:5001/api/users/2/posts" \
  -H "Content-Type: application/json" \
  -d '{
    "skillId": 2,
    "postType": "Request",
    "title": "Нужна помощь с математическим анализом",
    "details": "Ищу помощь с подготовкой к экзамену по матанализу.",
    "contactPreference": "Email",
    "expiresAt": "2024-12-31T23:59:59"
  }'
```

## Архитектура

Проект использует:

- **Minimal API** - для создания HTTP endpoints
- **Swagger/OpenAPI** - для документации API
- **Npgsql** - для прямого выполнения SQL запросов к PostgreSQL (без ORM)
- **BCrypt.Net-Next** - для хеширования паролей
- **Транзакции** - для обеспечения атомарности операций

## Структура проекта

```
KnowledgeForKnowledgeLite/
├── Models/              # DTOs и модели данных
│   ├── Account.cs
│   ├── UserProfile.cs
│   ├── UserContact.cs
│   ├── Skill.cs
│   ├── Education.cs
│   ├── Proof.cs
│   └── SkillPost.cs
├── Services/            # Сервисы для работы с БД
│   └── DatabaseService.cs
├── Scripts/             # SQL скрипты
│   └── init_database.sql
├── Program.cs           # Точка входа и настройка API
└── appsettings.json     # Конфигурация
```

## Особенности реализации

1. **Голые SQL запросы**: Все запросы к БД выполняются напрямую через ADO.NET без использования ORM
2. **Транзакции**: Критичные операции выполняются в транзакциях для обеспечения целостности данных
3. **Мягкое удаление**: Аккаунты и посты не удаляются физически, помечаются как удаленные
4. **Аудит**: Все значимые действия логируются в таблицу AuditLog
5. **Верификация**: Документы могут быть верифицированы администраторами

## Примечания

- Для продакшена необходимо добавить полноценную аутентификацию (JWT токены)
- Добавить валидацию входных данных
- Реализовать обработку ошибок и логирование
- Добавить rate limiting для защиты от злоупотреблений
- Настроить CORS политики




