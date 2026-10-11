package com.reguai.business.institution.mapper;

import com.reguai.business.institution.entity.Institution;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

/**
* @author axuer
* @description 针对表【institution(金融机构/报送机构)】的数据库操作Mapper
* @createDate 2026-10-09 15:10:24
* @Entity com.reguai.business.institution.Entity.Institution
*/
@Mapper
public interface InstitutionMapper extends BaseMapper<Institution> {

}




