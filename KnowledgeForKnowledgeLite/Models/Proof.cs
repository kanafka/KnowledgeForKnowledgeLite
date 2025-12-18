namespace KnowledgeForKnowledgeLite.Models;

public record ProofDto(
    long ProofID,
    long AccountID,
    long? SkillID,
    long? EducationID,
    string FileURL,
    string? FileName,
    long? FileSize,
    string? MimeType,
    string Status,
    long? VerifiedBy,
    DateTime? VerifiedAt,
    string? RejectionReason,
    DateTime? ExpiresAt,
    DateTime CreatedAt
);

public record CreateProofRequest(
    long? SkillID,
    long? EducationID,
    string FileURL,
    string? FileName,
    long? FileSize,
    string? MimeType
);

public record VerifyProofRequest(
    string Status,
    string? ReviewNotes,
    string? RejectionReason
);





