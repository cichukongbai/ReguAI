package com.reguai.business.institution.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.reguai.business.institution.entity.Institution;
import com.reguai.business.institution.service.InstitutionService;
import com.reguai.business.institution.mapper.InstitutionMapper;
import org.springframework.stereotype.Service;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
* @author axuer
* @description 针对表【institution(金融机构/报送机构)】的数据库操作Service实现
* @createDate 2026-10-09 15:10:24
*/
@Service
@RequiredArgsConstructor
public class InstitutionServiceImpl extends ServiceImpl<InstitutionMapper, Institution>
    implements InstitutionService{

    private final InstitutionMapper institutionMapper;

    @Override
    @Transactional
//    让一次创建操作在事务范围内执行。
    public Institution create(
            String institutionCode,
            String institutionName,
            String country,
            String institutionType) {

        // 先检查机构代码是否已经存在
        Long count = institutionMapper.selectCount(
                new LambdaQueryWrapper<Institution>()
                        .eq(Institution::getInstitutionCode,
                                institutionCode)
        );

        if (count != null && count > 0) {
            throw new IllegalArgumentException(
                    "Institution code already exists: "
                            + institutionCode);
        }

        Institution institution = new Institution();
        institution.setInstitutionCode(institutionCode);
        institution.setInstitutionName(institutionName);
        institution.setCountry(country);
        institution.setInstitutionType(institutionType);

        // status、publicId、createdAt、updatedAt
        // 使用数据库默认值
        institutionMapper.insert(institution);

        // PostgreSQL + MyBatis-Plus 通常会回填生成的主键。
        // 为确保返回数据库默认生成的字段，插入后再查询一次。
        return institutionMapper.selectById(institution.getId());
    }
}




