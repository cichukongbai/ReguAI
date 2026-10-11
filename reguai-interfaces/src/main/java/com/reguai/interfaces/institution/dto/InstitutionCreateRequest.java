package com.reguai.interfaces.institution.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
@Data
public class InstitutionCreateRequest {
    @NotBlank
    @Size(max = 64)
    private String institutionCode;

    @NotBlank
    @Size(max = 255)
    private String institutionName;

    @Size(max = 64)
    private String country;

    @Size(max = 32)
    private String institutionType;
}
