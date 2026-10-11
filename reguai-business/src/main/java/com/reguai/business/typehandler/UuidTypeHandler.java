package com.reguai.business.typehandler;

import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;
import org.apache.ibatis.type.MappedTypes;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.UUID;

/**
 * PostgreSQL uuid 列 &lt;-&gt; java.util.UUID 的类型处理器。
 *
 * <p>MyBatis 3.5.x 与 MyBatis-Plus 3.5.x 都<strong>没有</strong>内置 UUID 类型处理器，
 * 因此只要实体里出现 UUID 字段，就会踩到两类问题：
 * <ol>
 *   <li>Mapper XML 的 resultMap 中声明了 {@code javaType="java.util.UUID"} 时，
 *       {@code ResultMapping.Builder#validate} 抛
 *       {@code IllegalStateException: No typehandler found for property xxx}，
 *       导致 SqlSessionFactory 创建失败、应用无法启动；</li>
 *   <li>即使绕过 XML，查询结果集自动映射时 MyBatis 会因找不到处理器而
 *       静默跳过该列，UUID 字段恒为 null。</li>
 * </ol>
 *
 * <p>通过 {@code mybatis-plus.type-handlers-package} 扫描注册本类即可同时解决以上两点。
 * 读取统一走 {@link ResultSet#getString}，对各类 JDBC 驱动都安全。
 */
@MappedTypes(UUID.class)
public class UuidTypeHandler extends BaseTypeHandler<UUID> {

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, UUID parameter, JdbcType jdbcType)
            throws SQLException {
        ps.setObject(i, parameter);
    }

    @Override
    public UUID getNullableResult(ResultSet rs, String columnName) throws SQLException {
        return toUuid(rs.getString(columnName));
    }

    @Override
    public UUID getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        return toUuid(rs.getString(columnIndex));
    }

    @Override
    public UUID getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        return toUuid(cs.getString(columnIndex));
    }

    private UUID toUuid(String value) {
        return value == null ? null : UUID.fromString(value);
    }
}
