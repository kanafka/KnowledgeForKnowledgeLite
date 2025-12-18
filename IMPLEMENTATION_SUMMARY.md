# Сводка по реализации проекта KnowledgeForKnowledgeLite

## Реализованные требования

### ✅ Функциональные требования

#### Управление пользователями
- ✅ FR-1: Регистрация новых пользователей (`POST /api/accounts/register`)
- ✅ FR-2: Аутентификация пользователей (`POST /api/accounts/login`)
- ✅ FR-4: Мягкое удаление пользователей (`DELETE /api/accounts/{accountId}`)
- ✅ FR-5: Отслеживание времени последнего входа (автоматически при логине)

#### Управление профилями
- ✅ FR-6: Создание и редактирование профиля (`GET/PUT /api/users/{accountId}/profile`)
- ✅ FR-7: Настройка видимости контактной информации (`POST /api/users/{accountId}/contacts` с параметром IsPublic)
- ✅ FR-8: Отслеживание времени последнего визита (`PUT /api/users/{accountId}/profile` обновляет LastSeenOnline)

#### Управление навыками
- ✅ FR-9: Каталог навыков по категориям (`GET /api/skills/categories`, `GET /api/skills`)
- ✅ FR-10: Добавление навыков пользователю (`POST /api/users/{accountId}/skills`)
- ✅ FR-11: Уровни владения навыком (`GET /api/skills/levels`)
- ✅ FR-12: Опыт работы со навыком в годах (параметр ExperienceYears)
- ✅ FR-13: Связь многие-ко-многим пользователей и навыков

#### Верификация навыков
- ✅ FR-15: Загрузка подтверждающих документов (`POST /api/users/{accountId}/proofs`)
- ✅ FR-16: Верификация документов администраторами (`POST /api/proofs/{proofId}/verify`)
- ✅ FR-17: Информация о верификаторе (хранится в таблице Proofs)
- ✅ FR-18: Статусы документов (Pending, Approved, Rejected, Expired)

#### Образование
- ✅ FR-20: Добавление информации об образовании (`POST /api/users/{accountId}/education`)

#### Публикация предложений и запросов
- ✅ FR-21: Публикация предложений (`POST /api/users/{accountId}/posts` с PostType='Offer')
- ✅ FR-22: Публикация запросов (`POST /api/users/{accountId}/posts` с PostType='Request')
- ✅ FR-23: Поиск предложений и запросов по навыкам (`GET /api/posts?skillId={id}`)
- ✅ FR-24: Статусы постов (Active, Closed, Cancelled, Expired)
- ✅ FR-25: Мягкое удаление постов (поле DeletedAt)
- ✅ FR-26: Счетчик просмотров (ViewsCount, увеличивается при GET /api/posts/{postId})
- ✅ FR-27: Связь поста с пользователем и навыком

#### Поиск и фильтрация
- ✅ FR-28: Поиск пользователей по навыку (`GET /api/skills/{skillName}/users`)
- ✅ FR-29: Фильтрация по уровню владения (`GET /api/skills/{skillName}/users?minLevelRank={rank}`)
- ✅ FR-30: Поиск активных предложений и запросов (`GET /api/posts?status=Active`)

#### Аудит
- ✅ FR-31: Логирование действий (таблица AuditLog, логируется регистрация, добавление навыков, верификация и т.д.)

### ✅ Техническая реализация

1. **Минимальный API (Minimal API)**: Все endpoints реализованы через Minimal API в `Program.cs`

2. **Swagger/OpenAPI**: Настроен Swagger для документации API (`/swagger`)

3. **Голые SQL запросы**: Все запросы к БД выполняются напрямую через `MySqlCommand` в `DatabaseService.cs` без использования ORM

4. **Транзакции**: Критичные операции (регистрация, добавление навыка с документом, верификация, удаление аккаунта) выполняются в транзакциях

5. **Модели данных**: Созданы DTOs для всех сущностей в папке `Models/`

6. **SQL DDL скрипт**: Создан полный скрипт инициализации БД в `Scripts/init_database.sql`

## Структура проекта

```
KnowledgeForKnowledgeLite/
├── Models/                      # DTOs
│   ├── Account.cs
│   ├── UserProfile.cs
│   ├── UserContact.cs
│   ├── Skill.cs
│   ├── Education.cs
│   ├── Proof.cs
│   └── SkillPost.cs
├── Services/
│   └── DatabaseService.cs       # Сервис с SQL запросами
├── Scripts/
│   └── init_database.sql        # SQL DDL скрипт
├── Program.cs                   # Minimal API endpoints
├── appsettings.json             # Конфигурация
└── README.md                    # Документация
```

## Используемые технологии

- **.NET 9.0** - платформа
- **Minimal API** - для создания API endpoints
- **Swagger/OpenAPI** - для документации API
- **MySql.Data** - для работы с MySQL
- **BCrypt.Net-Next** - для хеширования паролей

## Примеры использования

Все примеры использования API находятся в файле `README.md`.

## Запуск проекта

1. Настройте connection string в `appsettings.json`
2. Выполните SQL скрипт `Scripts/init_database.sql`
3. Запустите: `dotnet run`
4. Откройте Swagger UI: `https://localhost:5001/swagger`

## Особенности реализации

- ✅ Все SQL запросы написаны "голыми" (raw SQL), без ORM
- ✅ Использование транзакций для атомарности операций
- ✅ Мягкое удаление (soft delete) для аккаунтов и постов
- ✅ Полное логирование действий в AuditLog
- ✅ Верификация документов с поддержкой статусов
- ✅ Гибкая система поиска пользователей по навыкам




