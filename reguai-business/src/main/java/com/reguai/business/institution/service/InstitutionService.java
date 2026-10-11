package com.reguai.business.institution.service;

import com.reguai.business.institution.entity.Institution;
import com.baomidou.mybatisplus.extension.service.IService;

/**
* @author axuer
* @description 针对表【institution(金融机构/报送机构)】的数据库操作Service
* @createDate 2026-10-09 15:10:24
*/
public interface InstitutionService extends IService<Institution> {
    Institution create(
            String institutionCode,
            String institutionName,
            String country,
            String institutionType);
}
