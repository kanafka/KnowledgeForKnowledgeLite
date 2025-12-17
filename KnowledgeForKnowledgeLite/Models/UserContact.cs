namespace KnowledgeForKnowledgeLite.Models;

public record UserContactDto(
    long ContactID,
    long AccountID,
    string ContactType,
    string ContactValue,
    bool IsPublic,
    int DisplayOrder
);

public record CreateUserContactRequest(
    string ContactType,
    string ContactValue,
    bool IsPublic,
    int DisplayOrder
);


