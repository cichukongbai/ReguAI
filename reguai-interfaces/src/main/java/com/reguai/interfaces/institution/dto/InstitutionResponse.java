package com.reguai.interfaces.institution.dto;
import com.reguai.business.institution.entity.Institution;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

@Data
public class InstitutionResponse {
    private UUID publicId;
    private String institutionCode;
    private String institutionName;
    private String country;
    private String institutionType;
    private String status;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;

    public static InstitutionResponse from(Institution entity) {
        InstitutionResponse response = new InstitutionResponse();
        response.setPublicId(entity.getPublicId());
        response.setInstitutionCode(entity.getInstitutionCode());
        response.setInstitutionName(entity.getInstitutionName());
        response.setCountry(entity.getCountry());
        response.setInstitutionType(entity.getInstitutionType());
        response.setStatus(entity.getStatus());
        response.setCreatedAt(entity.getCreatedAt());
        response.setUpdatedAt(entity.getUpdatedAt());
        return response;
    }
}
