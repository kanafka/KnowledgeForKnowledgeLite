using KnowledgeForKnowledgeLite.Models;
using KnowledgeForKnowledgeLite.Services;
using Microsoft.AspNetCore.Mvc;
using BCrypt.Net;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddScoped<DatabaseService>();
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

#region Accounts Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("RegisterAccount")
.WithTags("Accounts")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("Login")
.WithTags("Accounts")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("DeleteAccount")
.WithTags("Accounts")
.Produces(204)
.Produces(400);

#endregion

#region UserProfiles Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetUserProfile")
.WithTags("UserProfiles")
.Produces<UserProfileDto>();

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("UpdateUserProfile")
.WithTags("UserProfiles")
.Produces(204)
.Produces(400);

#endregion

#region UserContacts Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("CreateUserContact")
.WithTags("UserContacts")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetUserContacts")
.WithTags("UserContacts")
.Produces<List<UserContactDto>>();

#endregion

#region Skills Endpoints

app.MapGet("/api/skills/categories", async (DatabaseService db) =>
{
    try
    {
        var categories = await db.GetSkillCategoriesAsync();
        return Results.Ok(categories);
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetSkillCategories")
.WithTags("Skills")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetSkillLevels")
.WithTags("Skills")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetSkills")
.WithTags("Skills")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("AddUserSkill")
.WithTags("Skills")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetUserSkills")
.WithTags("Skills")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("SearchUsersBySkill")
.WithTags("Skills")
.Produces<List<UserProfileDto>>();

#endregion

#region Education Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("CreateEducation")
.WithTags("Education")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetUserEducation")
.WithTags("Education")
.Produces<List<EducationDto>>();

#endregion

#region Proofs Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("CreateProof")
.WithTags("Proofs")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetUserProofs")
.WithTags("Proofs")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("VerifyProof")
.WithTags("Proofs")
.Produces(204)
.Produces(400)
.Produces(401);

#endregion

#region SkillPosts Endpoints

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("CreateSkillPost")
.WithTags("SkillPosts")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetSkillPosts")
.WithTags("SkillPosts")
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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("GetSkillPostById")
.WithTags("SkillPosts")
.Produces<SkillPostDto>();

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
        return Results.BadRequest(new { error = ex.Message });
    }
})
.WithName("UpdateSkillPostStatus")
.WithTags("SkillPosts")
.Produces(204)
.Produces(400);

#endregion

app.Run();
