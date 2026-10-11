package com.reguai.interfaces.institution;

import com.reguai.business.institution.entity.Institution;
import com.reguai.business.institution.service.InstitutionService;
import com.reguai.interfaces.institution.dto.InstitutionCreateRequest;
import com.reguai.interfaces.institution.dto.InstitutionResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/institutions")
@RequiredArgsConstructor
public class InstitutionController {

        private final InstitutionService institutionService;

        @PostMapping
        @ResponseStatus(HttpStatus.CREATED)
        public InstitutionResponse create(
                @Valid @RequestBody InstitutionCreateRequest request) {

            Institution institution = institutionService.create(
                    request.getInstitutionCode(),
                    request.getInstitutionName(),
                    request.getCountry(),
                    request.getInstitutionType()
            );

            return InstitutionResponse.from(institution);
        }
}
