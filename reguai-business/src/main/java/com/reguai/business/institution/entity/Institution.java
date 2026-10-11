package com.reguai.business.institution.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

import lombok.Data;

/**
 * 金融机构/报送机构
 * @TableName institution
 */
@TableName(value ="institution")
@Data
public class Institution implements Serializable {
    /**
     * 内部主键
     */
    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /**
     * 对外安全标识
     */
    @TableField(value = "public_id")
    private UUID publicId;

    /**
     * 机构代码
     */
    @TableField(value = "institution_code")
    private String institutionCode;

    /**
     * 机构名称
     */
    @TableField(value = "institution_name")
    private String institutionName;

    /**
     * 国家/地区
     */
    @TableField(value = "country")
    private String country;

    /**
     * 机构类型
     */
    @TableField(value = "institution_type")
    private String institutionType;

    /**
     * 状态
     */
    @TableField(value = "status")
    private String status;

    /**
     * 
     */
    @TableField(value = "created_at")
    private OffsetDateTime createdAt;

    /**
     * 
     */
    @TableField(value = "updated_at")
    private OffsetDateTime updatedAt;

    @TableField(exist = false)
    private static final long serialVersionUID = 1L;
}