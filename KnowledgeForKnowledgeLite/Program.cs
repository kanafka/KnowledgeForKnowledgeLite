using KnowledgeForKnowledgeLite.Models;
using KnowledgeForKnowledgeLite.Services;
using Microsoft.AspNetCore.Mvc;
using BCrypt.Net;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddScoped<DatabaseService>();
builder.Services.AddLogging();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "KnowledgeForKnowledgeLite API", Version = "v1" });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Простая аутентификация через header X-User-ID (для демонстрации)
// В реальном приложении используйте JWT токены

app.MapPost("/api/accounts/register", async (
    [FromBody] CreateAccountRequest request,
    DatabaseService db) =>
{
    try
    {
        var accountId = await db.CreateAccountAsync(request);
        return Results.Created($"/api/accounts/{accountId}", new { AccountID = accountId });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("RegisterAccount")
.WithTags("Accounts")
.WithSummary("Регистрация нового пользователя")
.WithDescription("Создает новую учетную запись и профиль пользователя. Пароль хешируется с помощью BCrypt.")
.Produces(201)
.Produces(400);

app.MapPost("/api/accounts/login", async (
    [FromBody] LoginRequest request,
    DatabaseService db) =>
{
    try
    {
        var account = await db.GetAccountByLoginAsync(request.Login);
        if (account == null)
        {
            return Results.Unauthorized();
        }

        var passwordHash = await db.GetPasswordHashAsync(request.Login);
        if (passwordHash == null || !BCrypt.Net.BCrypt.Verify(request.Password, passwordHash))
        {
            return Results.Unauthorized();
        }

        await db.UpdateLastLoginAsync(account.AccountID);

        return Results.Ok(new LoginResponse(
            account.AccountID,
            account.Login,
            account.IsAdmin
        ));
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("Login")
.WithTags("Accounts")
.WithSummary("Вход в систему")
.WithDescription("Аутентификация пользователя по логину и паролю. Обновляет время последнего входа.")
.Produces<LoginResponse>()
.Produces(401);

app.MapDelete("/api/accounts/{accountId}", async (
    long accountId,
    DatabaseService db) =>
{
    try
    {
        await db.SoftDeleteAccountAsync(accountId);
        return Results.NoContent();
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("DeleteAccount")
.WithTags("Accounts")
.WithSummary("Мягкое удаление аккаунта")
.WithDescription("Выполняет мягкое удаление аккаунта (soft delete). Деактивирует профиль и закрывает все активные посты пользователя.")
.Produces(204)
.Produces(400);

app.MapGet("/api/users/{accountId}/profile", async (
    long accountId,
    DatabaseService db) =>
{
    try
    {
        var profile = await db.GetUserProfileAsync(accountId);
        if (profile == null)
        {
            return Results.NotFound();
        }
        return Results.Ok(profile);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetUserProfile")
.WithTags("UserProfiles")
.WithSummary("Получить профиль пользователя")
.WithDescription("Возвращает информацию о профиле пользователя по его AccountID.")
.Produces<UserProfileDto>()
.Produces(404);

app.MapPut("/api/users/{accountId}/profile", async (
    long accountId,
    [FromBody] UpdateUserProfileRequest request,
    DatabaseService db) =>
{
    try
    {
        await db.UpdateUserProfileAsync(accountId, request);
        await db.UpdateLastSeenOnlineAsync(accountId);
        return Results.NoContent();
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("UpdateUserProfile")
.WithTags("UserProfiles")
.WithSummary("Обновить профиль пользователя")
.WithDescription("Обновляет информацию профиля пользователя и время последнего визита.")
.Produces(204)
.Produces(400);

app.MapPost("/api/users/{accountId}/contacts", async (
    long accountId,
    [FromBody] CreateUserContactRequest request,
    DatabaseService db) =>
{
    try
    {
        var contactId = await db.CreateUserContactAsync(accountId, request);
        return Results.Created($"/api/contacts/{contactId}", new { ContactID = contactId });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("CreateUserContact")
.WithTags("UserContacts")
.WithSummary("Добавить контакт пользователя")
.WithDescription("Добавляет новый контакт для пользователя (email, телефон, Telegram и т.д.) с настройкой публичности.")
.Produces(201)
.Produces(400);

app.MapGet("/api/users/{accountId}/contacts", async (
    long accountId,
    bool publicOnly,
    DatabaseService db) =>
{
    try
    {
        var contacts = await db.GetUserContactsAsync(accountId, publicOnly);
        return Results.Ok(contacts);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetUserContacts")
.WithTags("UserContacts")
.WithSummary("Получить контакты пользователя")
.WithDescription("Возвращает список контактов пользователя. Параметр publicOnly позволяет получить только публичные контакты.")
.Produces<List<UserContactDto>>();

app.MapGet("/api/skills/categories", async (DatabaseService db) =>
{
    try
    {
        var categories = await db.GetSkillCategoriesAsync();
        return Results.Ok(categories);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetSkillCategories")
.WithTags("Skills")
.WithSummary("Получить категории навыков")
.WithDescription("Возвращает список всех категорий навыков (Mathematics, Programming, Languages и т.д.).")
.Produces<List<SkillCategoryDto>>();

app.MapGet("/api/skills/levels", async (DatabaseService db) =>
{
    try
    {
        var levels = await db.GetSkillLevelsAsync();
        return Results.Ok(levels);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetSkillLevels")
.WithTags("Skills")
.WithSummary("Получить уровни навыков")
.WithDescription("Возвращает список уровней владения навыком (Beginner, Intermediate, Advanced, Expert).")
.Produces<List<SkillLevelDto>>();

app.MapGet("/api/skills", async (long? categoryId, DatabaseService db) =>
{
    try
    {
        var skills = await db.GetSkillsByCategoryAsync(categoryId);
        return Results.Ok(skills);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetSkills")
.WithTags("Skills")
.WithSummary("Получить список навыков")
.WithDescription("Возвращает список навыков из каталога. Опционально фильтрует по categoryId.")
.Produces<List<SkillCatalogDto>>();

app.MapPost("/api/users/{accountId}/skills", async (
    long accountId,
    [FromBody] CreateUserSkillRequest request,
    DatabaseService db) =>
{
    try
    {
        await db.AddUserSkillAsync(accountId, request);
        return Results.Created($"/api/users/{accountId}/skills", new { });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("AddUserSkill")
.WithTags("Skills")
.WithSummary("Добавить навык пользователю")
.WithDescription("Добавляет навык пользователю с указанием уровня владения и опыта. Если навык уже существует, обновляет его.")
.Produces(201)
.Produces(400);

app.MapGet("/api/users/{accountId}/skills", async (
    long accountId,
    DatabaseService db) =>
{
    try
    {
        var skills = await db.GetUserSkillsAsync(accountId);
        return Results.Ok(skills);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetUserSkills")
.WithTags("Skills")
.WithSummary("Получить навыки пользователя")
.WithDescription("Возвращает список всех навыков пользователя с информацией о категориях и уровнях владения.")
.Produces<List<UserSkillDto>>();

app.MapGet("/api/skills/{skillName}/users", async (
    string skillName,
    int? minLevelRank,
    DatabaseService db) =>
{
    try
    {
        var users = await db.SearchUsersBySkillAsync(skillName, minLevelRank);
        return Results.Ok(users);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("SearchUsersBySkill")
.WithTags("Skills")
.WithSummary("Поиск пользователей по навыку")
.WithDescription("Ищет всех пользователей, владеющих указанным навыком. Опционально фильтрует по минимальному уровню (minLevelRank).")
.Produces<List<UserProfileDto>>();

app.MapPost("/api/users/{accountId}/education", async (
    long accountId,
    [FromBody] CreateEducationRequest request,
    DatabaseService db) =>
{
    try
    {
        var educationId = await db.CreateEducationAsync(accountId, request);
        return Results.Created($"/api/education/{educationId}", new { EducationID = educationId });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("CreateEducation")
.WithTags("Education")
.WithSummary("Добавить информацию об образовании")
.WithDescription("Добавляет запись об образовании пользователя (учебное заведение, специальность, годы обучения и т.д.).")
.Produces(201)
.Produces(400);

app.MapGet("/api/users/{accountId}/education", async (
    long accountId,
    DatabaseService db) =>
{
    try
    {
        var education = await db.GetUserEducationAsync(accountId);
        return Results.Ok(education);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetUserEducation")
.WithTags("Education")
.WithSummary("Получить образование пользователя")
.WithDescription("Возвращает список всех записей об образовании пользователя.")
.Produces<List<EducationDto>>();

app.MapPost("/api/users/{accountId}/proofs", async (
    long accountId,
    [FromBody] CreateProofRequest request,
    DatabaseService db) =>
{
    try
    {
        var proofId = await db.CreateProofAsync(accountId, request);
        return Results.Created($"/api/proofs/{proofId}", new { ProofID = proofId });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("CreateProof")
.WithTags("Proofs")
.WithSummary("Загрузить подтверждающий документ")
.WithDescription("Загружает документ, подтверждающий навык или образование пользователя. Создает запрос на верификацию.")
.Produces(201)
.Produces(400);

app.MapGet("/api/users/{accountId}/proofs", async (
    long accountId,
    DatabaseService db) =>
{
    try
    {
        var proofs = await db.GetUserProofsAsync(accountId);
        return Results.Ok(proofs);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetUserProofs")
.WithTags("Proofs")
.WithSummary("Получить документы пользователя")
.WithDescription("Возвращает список всех загруженных документов пользователя с их статусами верификации.")
.Produces<List<ProofDto>>();

app.MapPost("/api/proofs/{proofId}/verify", async (
    long proofId,
    [FromBody] VerifyProofRequest request,
    [FromHeader(Name = "X-Admin-ID")] long? adminId,
    DatabaseService db) =>
{
    try
    {
        if (!adminId.HasValue)
        {
            return Results.Unauthorized();
        }

        await db.VerifyProofAsync(proofId, adminId.Value, request);
        return Results.NoContent();
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("VerifyProof")
.WithTags("Proofs")
.WithSummary("Верифицировать документ")
.WithDescription("Верифицирует документ администратором. Требуется заголовок X-Admin-ID. Обновляет статус навыка при одобрении.")
.Produces(204)
.Produces(400)
.Produces(401);

app.MapPost("/api/users/{accountId}/posts", async (
    long accountId,
    [FromBody] CreateSkillPostRequest request,
    DatabaseService db) =>
{
    try
    {
        var postId = await db.CreateSkillPostAsync(accountId, request);
        return Results.Created($"/api/posts/{postId}", new { PostID = postId });
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("CreateSkillPost")
.WithTags("SkillPosts")
.WithSummary("Создать пост о навыке")
.WithDescription("Создает пост с предложением помощи (Offer) или запросом помощи (Request) по определенному навыку.")
.Produces(201)
.Produces(400);

app.MapGet("/api/posts", async (
    long? skillId,
    string? postType,
    string? status,
    DatabaseService db) =>
{
    try
    {
        var posts = await db.GetSkillPostsAsync(skillId, postType, status);
        return Results.Ok(posts);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetSkillPosts")
.WithTags("SkillPosts")
.WithSummary("Получить список постов")
.WithDescription("Возвращает список постов о навыках. Можно фильтровать по skillId, postType (Offer/Request) и status (Active/Closed и т.д.).")
.Produces<List<SkillPostDto>>();

app.MapGet("/api/posts/{postId}", async (
    long postId,
    DatabaseService db) =>
{
    try
    {
        var posts = await db.GetSkillPostsAsync();
        var post = posts.FirstOrDefault(p => p.PostID == postId);
        
        if (post == null)
        {
            return Results.NotFound();
        }

        await db.IncrementPostViewsAsync(postId);
        
        // Обновляем ViewsCount в ответе
        var updatedPost = post with { ViewsCount = post.ViewsCount + 1 };
        return Results.Ok(updatedPost);
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("GetSkillPostById")
.WithTags("SkillPosts")
.WithSummary("Получить пост по ID")
.WithDescription("Возвращает пост по его ID и автоматически увеличивает счетчик просмотров.")
.Produces<SkillPostDto>()
.Produces(404);

app.MapPut("/api/posts/{postId}/status", async (
    long postId,
    [FromBody] UpdateSkillPostStatusRequest request,
    DatabaseService db) =>
{
    try
    {
        await db.UpdateSkillPostStatusAsync(postId, request.Status);
        return Results.NoContent();
    }
    catch (Exception ex)
    {
        var errorMessage = ex.Message;
        if (ex.InnerException != null)
        {
            errorMessage += " | Inner: " + ex.InnerException.Message;
        }
        return Results.BadRequest(new { error = errorMessage, stackTrace = ex.StackTrace });
    }
})
.WithName("UpdateSkillPostStatus")
.WithTags("SkillPosts")
.WithSummary("Изменить статус поста")
.WithDescription("Изменяет статус поста (Active, Closed, Cancelled, Expired).")
.Produces(204)
.Produces(400);


app.Run();
