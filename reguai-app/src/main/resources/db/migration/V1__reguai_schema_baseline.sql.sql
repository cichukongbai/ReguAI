-- ============================================================
-- ReguAI PostgreSQL Schema
-- Regulatory Reporting & AI Assistant Platform
-- PostgreSQL 15+
--
-- Domain model:
--   regulatory_business -> A01 / A02 definitions
--   business_instance   -> common lifecycle/reference
--   a01_business        -> A01 physical business data
--   a02_business        -> A02 physical business data
--   validation_*        -> validation history
--   submission_*        -> submission workflow/history
--
-- Important:
--   1. A01/A02 business data is NOT stored in one giant generic table.
--   2. business_instance.business_id is an application-level polymorphic
--      reference; PostgreSQL cannot create a normal FK to multiple tables.
--   3. Regulatory/audit history should normally be retained rather than
--      physically deleted.
-- ============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. institution
-- 机构
-- ============================================================
CREATE TABLE institution (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id           UUID NOT NULL DEFAULT gen_random_uuid(),
    institution_code    VARCHAR(64) NOT NULL,
    institution_name    VARCHAR(255) NOT NULL,
    country             VARCHAR(64),
    institution_type    VARCHAR(32),
    status              VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_institution_public_id UNIQUE (public_id),
    CONSTRAINT uk_institution_code UNIQUE (institution_code),
    CONSTRAINT ck_institution_status
        CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

COMMENT ON TABLE institution IS '金融机构/报送机构';
COMMENT ON COLUMN institution.id IS '内部主键';
COMMENT ON COLUMN institution.public_id IS '对外安全标识';
COMMENT ON COLUMN institution.institution_code IS '机构代码';
COMMENT ON COLUMN institution.institution_name IS '机构名称';
COMMENT ON COLUMN institution.country IS '国家/地区';
COMMENT ON COLUMN institution.institution_type IS '机构类型';
COMMENT ON COLUMN institution.status IS '状态';

-- ============================================================
-- 2. regulatory_business
-- 监管业务定义，例如 A01 / A02
-- ============================================================
CREATE TABLE regulatory_business (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_code       VARCHAR(32) NOT NULL,
    business_name       VARCHAR(255) NOT NULL,
    description         TEXT,
    physical_table_name VARCHAR(128) NOT NULL,
    status              VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_regulatory_business_code UNIQUE (business_code),
    CONSTRAINT ck_regulatory_business_status
        CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

COMMENT ON TABLE regulatory_business IS '监管业务定义，不保存具体业务实例';
COMMENT ON COLUMN regulatory_business.business_code IS '业务代码，例如 A01/A02';
COMMENT ON COLUMN regulatory_business.business_name IS '业务名称';
COMMENT ON COLUMN regulatory_business.physical_table_name IS '业务数据对应的物理表名';

-- ============================================================
-- 3. regulatory_field
-- 监管字段定义 / 上游字段映射
-- ============================================================
CREATE TABLE regulatory_field (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    regulatory_business_id BIGINT NOT NULL,
    field_code          VARCHAR(64) NOT NULL,
    field_name          VARCHAR(255) NOT NULL,
    data_type           VARCHAR(32) NOT NULL,
    source_field        VARCHAR(128),
    required            BOOLEAN NOT NULL DEFAULT FALSE,
    description         TEXT,
    status              VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_regulatory_field_business
        FOREIGN KEY (regulatory_business_id)
        REFERENCES regulatory_business(id),

    CONSTRAINT uk_regulatory_field_business_code
        UNIQUE (regulatory_business_id, field_code),

    CONSTRAINT ck_regulatory_field_status
        CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

COMMENT ON TABLE regulatory_field IS '监管字段元数据与上游字段映射';
COMMENT ON COLUMN regulatory_field.field_code IS '监管字段代码';
COMMENT ON COLUMN regulatory_field.field_name IS '监管字段名称';
COMMENT ON COLUMN regulatory_field.data_type IS '数据类型';
COMMENT ON COLUMN regulatory_field.source_field IS '上游来源字段';
COMMENT ON COLUMN regulatory_field.required IS '是否必填';

CREATE INDEX idx_regulatory_field_business
    ON regulatory_field (regulatory_business_id);

-- ============================================================
-- 4. reporting_rule
-- 报送规则 / 截止时间规则
-- ============================================================
CREATE TABLE reporting_rule (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    regulatory_business_id BIGINT NOT NULL,
    rule_code           VARCHAR(64) NOT NULL,
    trigger_type        VARCHAR(32) NOT NULL,
    deadline_type       VARCHAR(32) NOT NULL,
    deadline_value      INTEGER NOT NULL,
    description         TEXT,
    status              VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reporting_rule_business
        FOREIGN KEY (regulatory_business_id)
        REFERENCES regulatory_business(id),

    CONSTRAINT uk_reporting_rule_code UNIQUE (rule_code),

    CONSTRAINT ck_reporting_rule_trigger
        CHECK (trigger_type IN ('BUSINESS_TIME', 'MONTH_START')),

    CONSTRAINT ck_reporting_rule_deadline_type
        CHECK (deadline_type IN ('CALENDAR_DAYS', 'WORKING_DAYS')),

    CONSTRAINT ck_reporting_rule_deadline_value
        CHECK (deadline_value > 0),

    CONSTRAINT ck_reporting_rule_status
        CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

COMMENT ON TABLE reporting_rule IS '监管业务报送时限规则';
COMMENT ON COLUMN reporting_rule.trigger_type IS '计时起点类型：业务发生时间/月初';
COMMENT ON COLUMN reporting_rule.deadline_type IS '日历日/工作日';
COMMENT ON COLUMN reporting_rule.deadline_value IS '期限数量';

CREATE INDEX idx_reporting_rule_business_status
    ON reporting_rule (regulatory_business_id, status);

-- ============================================================
-- 5. business_instance
-- 所有业务实例的公共生命周期/来源信息
-- ============================================================
CREATE TABLE business_instance (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id           UUID NOT NULL DEFAULT gen_random_uuid(),
    regulatory_business_id BIGINT NOT NULL,
    institution_id      BIGINT,
    source_system       VARCHAR(64),
    source_business_id  VARCHAR(128),
    business_time       TIMESTAMPTZ,
    status              VARCHAR(32) NOT NULL DEFAULT 'RECEIVED',
    operator_id         VARCHAR(128),
    validation_time     TIMESTAMPTZ,
    deadline_at         TIMESTAMPTZ,
    reported_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_business_instance_public_id UNIQUE (public_id),

    CONSTRAINT fk_business_instance_business
        FOREIGN KEY (regulatory_business_id)
        REFERENCES regulatory_business(id),

    CONSTRAINT fk_business_instance_institution
        FOREIGN KEY (institution_id)
        REFERENCES institution(id),

    CONSTRAINT uk_business_instance_source
        UNIQUE (regulatory_business_id, source_system, source_business_id),

    CONSTRAINT ck_business_instance_status
        CHECK (
            status IN (
                'RECEIVED',
                'VALIDATING',
                'VALIDATION_FAILED',
                'VALIDATED',
                'WAITING_SUBMISSION',
                'SUBMITTING',
                'SUBMITTED',
                'SUBMISSION_FAILED',
                'RETRYING',
                'REJECTED'
            )
        )
);

COMMENT ON TABLE business_instance IS '业务实例公共信息及生命周期';
COMMENT ON COLUMN business_instance.public_id IS '业务实例对外标识';
COMMENT ON COLUMN business_instance.regulatory_business_id IS '业务类型';
COMMENT ON COLUMN business_instance.source_system IS '上游系统';
COMMENT ON COLUMN business_instance.source_business_id IS '上游业务唯一标识';
COMMENT ON COLUMN business_instance.business_time IS '业务发生时间（若由上游提供）';
COMMENT ON COLUMN business_instance.status IS '业务生命周期状态';
COMMENT ON COLUMN business_instance.operator_id IS '当前操作人，自动报送可使用 SYSTEM';
COMMENT ON COLUMN business_instance.deadline_at IS '计算出的报送截止时间';

CREATE INDEX idx_business_instance_business_status
    ON business_instance (regulatory_business_id, status);

CREATE INDEX idx_business_instance_institution
    ON business_instance (institution_id);

CREATE INDEX idx_business_instance_deadline
    ON business_instance (status, deadline_at);

CREATE INDEX idx_business_instance_source
    ON business_instance (source_system, source_business_id);

-- ============================================================
-- 6. a01_business
-- A01 业务专属数据
-- ============================================================
CREATE TABLE a01_business (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_instance_id BIGINT NOT NULL,
    customer_id         VARCHAR(128),
    amount              NUMERIC(20, 4),
    currency            VARCHAR(16),
    business_time       TIMESTAMPTZ,

    CONSTRAINT uk_a01_business_instance UNIQUE (business_instance_id),

    CONSTRAINT fk_a01_business_instance
        FOREIGN KEY (business_instance_id)
        REFERENCES business_instance(id),

    CONSTRAINT ck_a01_amount
        CHECK (amount IS NULL OR amount >= 0)
);

COMMENT ON TABLE a01_business IS 'A01 业务专属数据表（示例字段）';
COMMENT ON COLUMN a01_business.business_instance_id IS '对应公共业务实例';
COMMENT ON COLUMN a01_business.customer_id IS '客户编号';
COMMENT ON COLUMN a01_business.amount IS '业务金额';
COMMENT ON COLUMN a01_business.currency IS '币种';
COMMENT ON COLUMN a01_business.business_time IS '业务发生时间';

CREATE INDEX idx_a01_customer
    ON a01_business (customer_id);

CREATE INDEX idx_a01_business_time
    ON a01_business (business_time);

-- ============================================================
-- 7. a02_business
-- A02 业务专属数据
-- ============================================================
CREATE TABLE a02_business (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_instance_id BIGINT NOT NULL,
    institution_code    VARCHAR(64),
    balance             NUMERIC(20, 4),
    currency            VARCHAR(16),
    business_month      DATE,

    CONSTRAINT uk_a02_business_instance UNIQUE (business_instance_id),

    CONSTRAINT fk_a02_business_instance
        FOREIGN KEY (business_instance_id)
        REFERENCES business_instance(id),

    CONSTRAINT ck_a02_balance
        CHECK (balance IS NULL OR balance >= 0)
);

COMMENT ON TABLE a02_business IS 'A02 业务专属数据表（示例字段）';
COMMENT ON COLUMN a02_business.business_instance_id IS '对应公共业务实例';
COMMENT ON COLUMN a02_business.institution_code IS '监管业务中的机构代码';
COMMENT ON COLUMN a02_business.balance IS '余额';
COMMENT ON COLUMN a02_business.currency IS '币种';
COMMENT ON COLUMN a02_business.business_month IS '业务月份';

CREATE INDEX idx_a02_institution_code
    ON a02_business (institution_code);

CREATE INDEX idx_a02_business_month
    ON a02_business (business_month);

-- ============================================================
-- 8. validation_rule
-- 校验规则
-- ============================================================
CREATE TABLE validation_rule (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    regulatory_business_id BIGINT NOT NULL,
    rule_code           VARCHAR(64) NOT NULL,
    rule_name           VARCHAR(255) NOT NULL,
    expression          TEXT NOT NULL,
    severity            VARCHAR(32) NOT NULL DEFAULT 'ERROR',
    version             INTEGER NOT NULL DEFAULT 1,
    enabled             BOOLEAN NOT NULL DEFAULT TRUE,
    description         TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_validation_rule_business
        FOREIGN KEY (regulatory_business_id)
        REFERENCES regulatory_business(id),

    CONSTRAINT uk_validation_rule_code_version
        UNIQUE (rule_code, version),

    CONSTRAINT ck_validation_rule_severity
        CHECK (severity IN ('INFO', 'WARNING', 'ERROR')),

    CONSTRAINT ck_validation_rule_version
        CHECK (version > 0)
);

COMMENT ON TABLE validation_rule IS '业务校验规则定义';
COMMENT ON COLUMN validation_rule.expression IS '由应用层规则引擎解释的表达式';
COMMENT ON COLUMN validation_rule.version IS '规则版本';

CREATE INDEX idx_validation_rule_business_enabled
    ON validation_rule (regulatory_business_id, enabled);

-- ============================================================
-- 9. validation_result
-- 一次业务校验执行结果
-- ============================================================
CREATE TABLE validation_result (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_instance_id BIGINT NOT NULL,
    validation_version  INTEGER NOT NULL DEFAULT 1,
    status              VARCHAR(32) NOT NULL,
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    error_count         INTEGER NOT NULL DEFAULT 0,
    warning_count       INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_validation_result_business
        FOREIGN KEY (business_instance_id)
        REFERENCES business_instance(id),

    CONSTRAINT ck_validation_result_status
        CHECK (status IN ('RUNNING', 'PASSED', 'FAILED')),

    CONSTRAINT ck_validation_result_error_count
        CHECK (error_count >= 0),

    CONSTRAINT ck_validation_result_warning_count
        CHECK (warning_count >= 0)
);

COMMENT ON TABLE validation_result IS '业务实例的一次完整校验执行结果';

CREATE INDEX idx_validation_result_business
    ON validation_result (business_instance_id, created_at DESC);

-- ============================================================
-- 10. validation_error
-- 单条校验错误
-- ============================================================
CREATE TABLE validation_error (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    validation_result_id BIGINT NOT NULL,
    validation_rule_id  BIGINT,
    field_code          VARCHAR(64),
    severity            VARCHAR(32) NOT NULL,
    error_code          VARCHAR(64) NOT NULL,
    error_message       TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_validation_error_result
        FOREIGN KEY (validation_result_id)
        REFERENCES validation_result(id),

    CONSTRAINT fk_validation_error_rule
        FOREIGN KEY (validation_rule_id)
        REFERENCES validation_rule(id),

    CONSTRAINT ck_validation_error_severity
        CHECK (severity IN ('INFO', 'WARNING', 'ERROR'))
);

COMMENT ON TABLE validation_error IS '具体校验错误明细';

CREATE INDEX idx_validation_error_result
    ON validation_error (validation_result_id);

CREATE INDEX idx_validation_error_code
    ON validation_error (error_code);

-- ============================================================
-- 11. submission
-- 一次业务报送逻辑记录
-- ============================================================
CREATE TABLE submission (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id           UUID NOT NULL DEFAULT gen_random_uuid(),
    business_instance_id BIGINT NOT NULL,
    submission_version  INTEGER NOT NULL DEFAULT 1,
    submission_method   VARCHAR(32) NOT NULL,
    status              VARCHAR(32) NOT NULL DEFAULT 'WAITING',
    deadline_at         TIMESTAMPTZ,
    idempotency_key     VARCHAR(255) NOT NULL,
    operator_id         VARCHAR(128),
    submitted_at        TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    regulator_request_id VARCHAR(128),
    regulator_response_id VARCHAR(128),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_submission_public_id UNIQUE (public_id),

    CONSTRAINT fk_submission_business
        FOREIGN KEY (business_instance_id)
        REFERENCES business_instance(id),

    CONSTRAINT uk_submission_business_version
        UNIQUE (business_instance_id, submission_version),

    CONSTRAINT uk_submission_idempotency
        UNIQUE (idempotency_key),

    CONSTRAINT ck_submission_version
        CHECK (submission_version > 0),

    CONSTRAINT ck_submission_method
        CHECK (submission_method IN ('AUTO', 'MANUAL')),

    CONSTRAINT ck_submission_status
        CHECK (
            status IN (
                'WAITING',
                'SUBMITTING',
                'SUCCESS',
                'FAILED',
                'REJECTED',
                'CANCELLED'
            )
        )
);

COMMENT ON TABLE submission IS '一次业务报送记录';
COMMENT ON COLUMN submission.submission_version IS '同一业务实例的第几次报送版本';
COMMENT ON COLUMN submission.submission_method IS '自动 Quartz / 手工点击';
COMMENT ON COLUMN submission.idempotency_key IS '防重复提交幂等键';

CREATE INDEX idx_submission_business_status
    ON submission (business_instance_id, status);

CREATE INDEX idx_submission_status_deadline
    ON submission (status, deadline_at);

CREATE INDEX idx_submission_regulator_request
    ON submission (regulator_request_id);

-- ============================================================
-- 12. submission_attempt
-- 一次具体的 HTTP/API/消息提交尝试
-- ============================================================
CREATE TABLE submission_attempt (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    submission_id       BIGINT NOT NULL,
    attempt_no          INTEGER NOT NULL,
    status              VARCHAR(32) NOT NULL,
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    response_code       VARCHAR(64),
    response_message    TEXT,
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_submission_attempt_submission
        FOREIGN KEY (submission_id)
        REFERENCES submission(id),

    CONSTRAINT uk_submission_attempt_no
        UNIQUE (submission_id, attempt_no),

    CONSTRAINT ck_submission_attempt_no
        CHECK (attempt_no > 0),

    CONSTRAINT ck_submission_attempt_status
        CHECK (
            status IN (
                'RUNNING',
                'SUCCESS',
                'FAILED',
                'TIMEOUT',
                'REJECTED'
            )
        )
);

COMMENT ON TABLE submission_attempt IS '一次实际报送尝试，用于重试历史追踪';

CREATE INDEX idx_submission_attempt_submission
    ON submission_attempt (submission_id, attempt_no DESC);

-- ============================================================
-- 13. idempotency_record
-- API / MQ / Submission 幂等记录
-- ============================================================
CREATE TABLE idempotency_record (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key     VARCHAR(255) NOT NULL,
    request_type        VARCHAR(64) NOT NULL,
    request_hash        VARCHAR(128),
    status              VARCHAR(32) NOT NULL,
    response_body       JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at          TIMESTAMPTZ,

    CONSTRAINT uk_idempotency_key UNIQUE (idempotency_key),

    CONSTRAINT ck_idempotency_status
        CHECK (status IN ('PROCESSING', 'SUCCESS', 'FAILED'))
);

COMMENT ON TABLE idempotency_record IS '幂等请求记录，防止重复提交/重复消费';

CREATE INDEX idx_idempotency_expires
    ON idempotency_record (expires_at);

-- ============================================================
-- 14. outbox_event
-- Transactional Outbox
-- ============================================================
CREATE TABLE outbox_event (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id            UUID NOT NULL DEFAULT gen_random_uuid(),
    aggregate_type      VARCHAR(64) NOT NULL,
    aggregate_id        BIGINT NOT NULL,
    event_type          VARCHAR(128) NOT NULL,
    payload             JSONB NOT NULL,
    status              VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    retry_count         INTEGER NOT NULL DEFAULT 0,
    next_retry_at       TIMESTAMPTZ,
    published_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_outbox_event_id UNIQUE (event_id),

    CONSTRAINT ck_outbox_status
        CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),

    CONSTRAINT ck_outbox_retry_count
        CHECK (retry_count >= 0)
);

COMMENT ON TABLE outbox_event IS '本地事务消息表，保证数据库事务与 Kafka 发布最终一致';

CREATE INDEX idx_outbox_status_retry
    ON outbox_event (status, next_retry_at);

CREATE INDEX idx_outbox_aggregate
    ON outbox_event (aggregate_type, aggregate_id);

-- ============================================================
-- 15. processed_event
-- Kafka Consumer 幂等消费记录
-- ============================================================
CREATE TABLE processed_event (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id            UUID NOT NULL,
    consumer_name       VARCHAR(128) NOT NULL,
    processed_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_processed_event_consumer
        UNIQUE (event_id, consumer_name)
);

COMMENT ON TABLE processed_event IS 'Kafka 消费者幂等记录，防止重复消费';

CREATE INDEX idx_processed_event_time
    ON processed_event (processed_at);

-- ============================================================
-- 16. job_execution
-- Quartz / 定时任务执行记录
-- ============================================================
CREATE TABLE job_execution (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_name            VARCHAR(128) NOT NULL,
    execution_id        UUID NOT NULL DEFAULT gen_random_uuid(),
    status              VARCHAR(32) NOT NULL,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMPTZ,
    total_count         INTEGER NOT NULL DEFAULT 0,
    success_count       INTEGER NOT NULL DEFAULT 0,
    failed_count        INTEGER NOT NULL DEFAULT 0,
    error_message       TEXT,

    CONSTRAINT uk_job_execution_id UNIQUE (execution_id),

    CONSTRAINT ck_job_execution_status
        CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),

    CONSTRAINT ck_job_execution_counts
        CHECK (
            total_count >= 0
            AND success_count >= 0
            AND failed_count >= 0
        )
);

COMMENT ON TABLE job_execution IS 'Quartz 等定时任务的执行历史';

CREATE INDEX idx_job_execution_name_time
    ON job_execution (job_name, started_at DESC);

-- ============================================================
-- 17. notification
-- 通知记录
-- ============================================================
CREATE TABLE notification (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_instance_id BIGINT,
    submission_id       BIGINT,
    notification_type   VARCHAR(64) NOT NULL,
    recipient           VARCHAR(255) NOT NULL,
    title               VARCHAR(255),
    content             TEXT NOT NULL,
    status              VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    sent_at             TIMESTAMPTZ,
    retry_count         INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_business
        FOREIGN KEY (business_instance_id)
        REFERENCES business_instance(id),

    CONSTRAINT fk_notification_submission
        FOREIGN KEY (submission_id)
        REFERENCES submission(id),

    CONSTRAINT ck_notification_status
        CHECK (status IN ('PENDING', 'SENT', 'FAILED')),

    CONSTRAINT ck_notification_retry_count
        CHECK (retry_count >= 0)
);

COMMENT ON TABLE notification IS '报送失败、校验失败等通知记录';

CREATE INDEX idx_notification_status
    ON notification (status, created_at);

CREATE INDEX idx_notification_business
    ON notification (business_instance_id);

-- ============================================================
-- 18. audit_log
-- 审计日志
-- ============================================================
CREATE TABLE audit_log (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operator_id         VARCHAR(128),
    action              VARCHAR(128) NOT NULL,
    resource_type       VARCHAR(64) NOT NULL,
    resource_id         VARCHAR(128) NOT NULL,
    request_id          VARCHAR(128),
    detail              JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE audit_log IS '系统审计日志，不用于普通业务查询';

CREATE INDEX idx_audit_log_resource
    ON audit_log (resource_type, resource_id, created_at DESC);

CREATE INDEX idx_audit_log_operator
    ON audit_log (operator_id, created_at DESC);

CREATE INDEX idx_audit_log_request
    ON audit_log (request_id);

-- ============================================================
-- 19. system_config
-- 系统参数 / 配置
-- ============================================================
CREATE TABLE system_config (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    config_key          VARCHAR(128) NOT NULL,
    config_value        TEXT NOT NULL,
    value_type          VARCHAR(32) NOT NULL DEFAULT 'STRING',
    description         TEXT,
    environment         VARCHAR(32) NOT NULL DEFAULT 'LOCAL',
    version             INTEGER NOT NULL DEFAULT 1,
    enabled             BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_system_config_key_env
        UNIQUE (config_key, environment),

    CONSTRAINT ck_system_config_type
        CHECK (value_type IN ('STRING', 'INTEGER', 'LONG', 'BOOLEAN', 'JSON')),

    CONSTRAINT ck_system_config_version
        CHECK (version > 0)
);

COMMENT ON TABLE system_config IS '系统运行参数，如重试次数、超时、批大小等';

-- ============================================================
-- 20. workday_calendar
-- 工作日历，用于 A02 等工作日截止规则
-- ============================================================
CREATE TABLE workday_calendar (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code        VARCHAR(16) NOT NULL,
    calendar_date       DATE NOT NULL,
    is_workday          BOOLEAN NOT NULL,
    holiday_name       VARCHAR(255),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_workday_calendar_country_date
        UNIQUE (country_code, calendar_date)
);

COMMENT ON TABLE workday_calendar IS '工作日/节假日日历，用于工作日报送截止时间计算';

CREATE INDEX idx_workday_calendar_date
    ON workday_calendar (calendar_date, country_code);

-- ============================================================
-- Seed data
-- 注意：A01/A02 字段和规则是本项目的模拟监管数据，
-- 不是任何真实监管机构的正式报表定义。
-- ============================================================

-- 机构
INSERT INTO institution (
    institution_code,
    institution_name,
    country,
    institution_type,
    status
) VALUES (
    'DEMO_BANK',
    'ReguAI Demo Bank',
    'CN',
    'BANK',
    'ACTIVE'
);

-- 监管业务
INSERT INTO regulatory_business (
    business_code,
    business_name,
    description,
    physical_table_name,
    status
) VALUES
(
    'A01',
    'A01业务',
    '示例：发生业务后按规定期限报送',
    'a01_business',
    'ACTIVE'
),
(
    'A02',
    'A02业务',
    '示例：按月度工作日窗口报送',
    'a02_business',
    'ACTIVE'
);

-- 监管字段
INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'CUSTOMER_ID', '客户编号', 'STRING', 'customer_id', TRUE, '上游客户编号'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'AMOUNT', '业务金额', 'DECIMAL', 'amount', TRUE, '业务金额'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'CURRENCY', '币种', 'STRING', 'currency', TRUE, '币种代码'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'BUSINESS_TIME', '业务发生时间', 'TIMESTAMP', 'business_time', TRUE, '业务发生时间'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'INSTITUTION_CODE', '机构代码', 'STRING', 'institution_code', TRUE, '业务中的机构代码'
FROM regulatory_business WHERE business_code = 'A02';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'BALANCE', '余额', 'DECIMAL', 'balance', TRUE, '业务余额'
FROM regulatory_business WHERE business_code = 'A02';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'CURRENCY', '币种', 'STRING', 'currency', TRUE, '币种代码'
FROM regulatory_business WHERE business_code = 'A02';

INSERT INTO regulatory_field (
    regulatory_business_id,
    field_code,
    field_name,
    data_type,
    source_field,
    required,
    description
)
SELECT id, 'BUSINESS_MONTH', '业务月份', 'DATE', 'business_month', TRUE, '业务月份'
FROM regulatory_business WHERE business_code = 'A02';

-- 报送规则
-- A01：业务发生后 3 个日历日内
INSERT INTO reporting_rule (
    regulatory_business_id,
    rule_code,
    trigger_type,
    deadline_type,
    deadline_value,
    description
)
SELECT
    id,
    'A01_3_CALENDAR_DAYS',
    'BUSINESS_TIME',
    'CALENDAR_DAYS',
    3,
    'A01：从业务发生时间起 3 个日历日内完成报送'
FROM regulatory_business
WHERE business_code = 'A01';

-- A02：每月前 3 个工作日
INSERT INTO reporting_rule (
    regulatory_business_id,
    rule_code,
    trigger_type,
    deadline_type,
    deadline_value,
    description
)
SELECT
    id,
    'A02_FIRST_3_WORKING_DAYS',
    'MONTH_START',
    'WORKING_DAYS',
    3,
    'A02：每月前 3 个工作日内完成报送'
FROM regulatory_business
WHERE business_code = 'A02';

-- 校验规则
INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A01_AMOUNT_NON_NEGATIVE', 'A01金额不能为负',
       'amount >= 0', 'ERROR', 1, TRUE,
       'A01 amount 必须大于等于 0'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A01_CURRENCY_REQUIRED', 'A01币种不能为空',
       'currency IS NOT NULL', 'ERROR', 1, TRUE,
       'A01 currency 为必填字段'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A01_BUSINESS_TIME_REQUIRED', 'A01业务时间不能为空',
       'business_time IS NOT NULL', 'ERROR', 1, TRUE,
       'A01 business_time 为必填字段'
FROM regulatory_business WHERE business_code = 'A01';

INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A02_BALANCE_NON_NEGATIVE', 'A02余额不能为负',
       'balance >= 0', 'ERROR', 1, TRUE,
       'A02 balance 必须大于等于 0'
FROM regulatory_business WHERE business_code = 'A02';

INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A02_CURRENCY_REQUIRED', 'A02币种不能为空',
       'currency IS NOT NULL', 'ERROR', 1, TRUE,
       'A02 currency 为必填字段'
FROM regulatory_business WHERE business_code = 'A02';

INSERT INTO validation_rule (
    regulatory_business_id,
    rule_code,
    rule_name,
    expression,
    severity,
    version,
    enabled,
    description
)
SELECT id, 'A02_BUSINESS_MONTH_REQUIRED', 'A02业务月份不能为空',
       'business_month IS NOT NULL', 'ERROR', 1, TRUE,
       'A02 business_month 为必填字段'
FROM regulatory_business WHERE business_code = 'A02';

-- 系统配置
INSERT INTO system_config
    (config_key, config_value, value_type, description, environment)
VALUES
    ('submission.retry.max', '3', 'INTEGER',
     '报送最大重试次数', 'LOCAL'),
    ('submission.timeout.ms', '5000', 'INTEGER',
     '报送请求超时时间', 'LOCAL'),
    ('scheduler.scan.interval.seconds', '300', 'INTEGER',
     'Quartz 扫描待报送业务的间隔', 'LOCAL'),
    ('validation.batch.size', '500', 'INTEGER',
     '批量校验批次大小', 'LOCAL'),
    ('kafka.report.topic', 'regu.business.submission', 'STRING',
     '业务报送 Kafka Topic', 'LOCAL'),
    ('cache.business.ttl.seconds', '300', 'INTEGER',
     '业务缓存 TTL', 'LOCAL');

COMMIT;

-- ============================================================
-- Basic verification queries
-- ============================================================

-- 查看业务定义
-- SELECT * FROM regulatory_business ORDER BY id;

-- 查看 A01/A02 字段
-- SELECT rb.business_code, rf.field_code, rf.field_name, rf.data_type
-- FROM regulatory_business rb
-- JOIN regulatory_field rf
--   ON rf.regulatory_business_id = rb.id
-- ORDER BY rb.business_code, rf.id;

-- 查看报送规则
-- SELECT rb.business_code, rr.rule_code, rr.trigger_type,
--        rr.deadline_type, rr.deadline_value
-- FROM regulatory_business rb
-- JOIN reporting_rule rr
--   ON rr.regulatory_business_id = rb.id;

-- 查看校验规则
-- SELECT rb.business_code, vr.rule_code, vr.expression
-- FROM regulatory_business rb
-- JOIN validation_rule vr
--   ON vr.regulatory_business_id = rb.id
-- ORDER BY rb.business_code, vr.id;
