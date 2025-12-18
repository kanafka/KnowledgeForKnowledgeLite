namespace KnowledgeForKnowledgeLite.Models;

public record AccountDto(
    long AccountID,
    string Login,
    bool IsAdmin,
    bool EmailConfirmed,
    DateTime? LastLoginAt,
    DateTime CreatedAt
);

public record CreateAccountRequest(
    string Login,
    string Password
);

public record LoginRequest(
    string Login,
    string Password
);

public record LoginResponse(
    long AccountID,
    string Login,
    bool IsAdmin
);




