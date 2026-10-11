# ReguAI v0.1 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the auditable A01/A02 regulatory-reporting MVP: configuration, manual/API data intake, validation, compulsory compliance review, guarded submission, and traceable operations.

**Architecture:** Retain the existing Java 17 / Spring Boot 3 multi-module backend and add a versioned PostgreSQL schema, domain services, REST contracts, Quartz jobs and audit trail. Add a standalone Vue 3 + TypeScript + Vite web application under `frontend/`; it talks only to `/api/v1` through one typed HTTP client and mirrors the backend state-machine gates rather than implementing independent business rules.

**Tech Stack:** Java 17, Spring Boot 3.5, MyBatis-Plus, PostgreSQL, Flyway, Quartz, Spring Security, JUnit 5, Testcontainers, Vue 3, TypeScript, Vite, Vue Router, Pinia, Element Plus, Vitest, Playwright.

---

## Scope, sequencing, and delivery slices

The repository currently contains only an institution-create vertical slice; there is no checked-in frontend, authentication model, migration system, reporting domain, or API contract. Implement the MVP in the following independently testable slices, in order:

1. Platform conventions and database baseline.
2. Institution and configuration/version publication.
3. Reporting-instance intake and dynamic data editing.
4. Validation, compulsory compliance review, and submission state machine.
5. Logs, notifications, scheduling and resilient submission.
6. Frontend shell, then configuration and reporting UI.
7. End-to-end acceptance coverage and release hardening.

Do not implement real bank/regulator integrations, batch import/export, external notification channels, AI features, or a standalone operations role. Use a deterministic stub submission adapter in the MVP; keep its interface ready for a later real channel.

## Planned file structure

| Area | Files / responsibility |
| --- | --- |
| Application platform | `reguai-app/pom.xml`, `reguai-app/src/main/java/com/reguai/config/*`, `reguai-app/src/main/resources/db/migration/*`, `reguai-app/src/main/resources/application.yml` — runtime dependencies, migration, request ID, error responses and Quartz wiring. |
| Business domain | `reguai-business/src/main/java/com/reguai/business/{config,reporting,validation,review,submission,audit,notification}/**` — entities, mappers, state transitions and service tests. |
| REST boundary | `reguai-interfaces/src/main/java/com/reguai/interfaces/{common,auth,institution,config,reporting,admin}/**` — controllers, request/response DTOs and global exception translation. |
| Frontend foundation | `frontend/{package.json,vite.config.ts,src/main.ts,src/router/**,src/stores/**,src/services/**}` — app bootstrap, session, route guards and typed API client. |
| Frontend features | `frontend/src/{views,features,components}/**` — workbench, reporting workspaces, admin, notifications and tests. |
| Quality | `reguai-app/src/test/**`, `reguai-business/src/test/**`, `reguai-interfaces/src/test/**`, `frontend/src/**/*.spec.ts`, `frontend/e2e/**` — unit, integration, component and E2E coverage. |

## API and domain rules that must not drift

- Public API identifiers are UUID `publicId` values; never expose database `id` values in paths or responses.
- A created instance locks its business-type, field-schema, validation-rule and deadline-rule versions. Publishing a later version changes new instances only.
- Any data edit invalidates prior validation and compliance decisions. First edit of an API-received instance snapshots the received original before mutation.
- `ERROR` blocks review and submission; `WARNING` requires a handling statement; every instance requires an approve-or-return compliance decision.
- Manual and Quartz submissions call the same service method. Only `APPROVED_PENDING_SUBMISSION` may enter `SUBMITTING`; a failed/rejected attempt may first return to that status only when its current approval and validation decisions remain valid. `SUBMITTED` is terminal and may never be submitted or retried again.
- All privileged configuration changes and every data mutation/transition write an audit record with actor, request ID, before/after data and timestamp.

### Task 1: Establish platform conventions and repeatable database tests

**Files:**
- Modify: `pom.xml`, `reguai-app/pom.xml`, `reguai-system/pom.xml`, `reguai-interfaces/pom.xml`, `reguai-app/src/main/resources/application.yml`
- Create: `reguai-app/src/main/java/com/reguai/config/RequestIdFilter.java`
- Create: `reguai-system/src/main/java/com/reguai/system/security/{Role,CurrentActor,RoleAccessService,JwtService}.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/auth/SessionController.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/auth/dto/{LoginRequest,TokenRefreshRequest,SessionResponse}.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/common/ApiError.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/common/GlobalExceptionHandler.java`
- Create: `reguai-app/src/test/java/com/reguai/ApiErrorContractTest.java`

- [ ] **Step 1: Write the failing MVC tests for a generated request ID, validation error shape, `X-Request-Id` echo, and local-development `login`, `refresh`, and `me` session contract.**

- [ ] **Step 2: Run `./mvnw -pl reguai-app test -Dtest=ApiErrorContractTest` and verify it fails because the filter and error contract are absent.**

- [ ] **Step 3: Add Flyway, Quartz, Spring Security, Testcontainers PostgreSQL and direct `reguai-interfaces → reguai-system` compile dependencies. Add a request-ID filter and a single structured error response (`code`, `message`, `fieldErrors`, `requestId`). Implement a signed-JWT development session contract backed by environment-configured local users/roles; expose `POST /api/v1/session/login`, `POST /api/v1/session/refresh`, and `GET /api/v1/session/me`. This is the MVP Gateway contract and is intentionally replaceable by a later IdP adapter.**

- [ ] **Step 4: Re-run the targeted test and then `./mvnw test`; verify both pass.**

- [ ] **Step 5: Commit `build: establish platform error, request-id and test conventions`.**

### Task 2: Add the versioned reporting schema and reference data migrations

**Files:**
- Create: `reguai-app/src/main/resources/db/migration/V001__baseline_institution.sql`
- Create: `reguai-app/src/main/resources/db/migration/V002__business_configuration.sql`
- Create: `reguai-app/src/main/resources/db/migration/V003__reporting_instance.sql`
- Create: `reguai-app/src/main/resources/db/migration/V004__workflow_audit_and_notification.sql`
- Create: `reguai-app/src/test/java/com/reguai/SchemaMigrationTest.java`

- [ ] **Step 1: Write a Testcontainers PostgreSQL test that starts Flyway and asserts all four migration versions plus required unique/index constraints.**

- [ ] **Step 2: Run `./mvnw -pl reguai-app test -Dtest=SchemaMigrationTest` and verify it fails before the migrations exist.**

- [ ] **Step 3: Create normalized tables for institutions; business types; versioned field schemas and options; versioned validation/deadline rules; report instances with all four locked version references; JSON field data; validation results; reviews; submission attempts; source snapshots; process/audit/system logs; and notifications. Add unique constraints for public IDs, version numbers and submission idempotency keys.**

- [ ] **Step 4: Re-run the migration test and inspect PostgreSQL constraint names in the failure-free result.**

- [ ] **Step 5: Commit `feat: add versioned regulatory reporting schema`.**

### Task 3: Complete institution lifecycle and RBAC baseline

**Files:**
- Modify: `reguai-business/src/main/java/com/reguai/business/institution/{service/InstitutionService.java,service/impl/InstitutionServiceImpl.java,mapper/InstitutionMapper.java}`
- Modify: `reguai-interfaces/src/main/java/com/reguai/interfaces/institution/InstitutionController.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/institution/dto/{InstitutionUpdateRequest,InstitutionListResponse}.java`
- Create: `reguai-system/src/main/java/com/reguai/system/security/{Role.java,CurrentActor.java,RoleAccessService.java}`
- Create: `reguai-interfaces/src/test/java/com/reguai/interfaces/institution/InstitutionControllerIT.java`

- [ ] **Step 1: Add failing integration tests for code uniqueness, paged search, update, enable/disable confirmation and role-restricted write operations.**

- [ ] **Step 2: Run the institution integration test and verify existing create-only behavior is insufficient.**

- [ ] **Step 3: Implement list/update/status endpoints and a minimal role resolver for `REPORTING_OFFICER`, `COMPLIANCE_OFFICER` and `SYSTEM_ADMIN`; apply method-level authorization while keeping the authentication provider configurable.**

- [ ] **Step 4: Run `./mvnw -pl reguai-interfaces test -Dtest=InstitutionControllerIT` and then the reactor test suite.**

- [ ] **Step 5: Commit `feat: complete institution lifecycle and role baseline`.**

### Task 4: Implement business-type configuration and immutable publishing

**Files:**
- Create: `reguai-business/src/main/java/com/reguai/business/config/{entity,mapper,service}/**`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/config/{BusinessTypeController,FieldSchemaController,ValidationRuleController,DeadlineRuleController}.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/config/dto/**`
- Create: `reguai-business/src/test/java/com/reguai/business/config/ConfigurationPublicationServiceTest.java`

- [ ] **Step 1: Write failing service tests for draft-only editing, field metadata validation, publish-time version increments and no mutation of published versions.**

- [ ] **Step 2: Run the targeted configuration test and verify publication services do not exist.**

- [ ] **Step 3: Implement configuration aggregates and REST endpoints. Validate the MVP field types (`TEXT`, `INTEGER`, `DECIMAL`, `DATE`, `DATETIME`, `BOOLEAN`, `SINGLE_SELECT`) and their metadata. Publish field schema, validation rules and deadline rules atomically with an impact summary and audit entry; each validation-rule publication produces an immutable version.**

- [ ] **Step 4: Run the focused tests and `./mvnw test`; verify an already published version rejects update.**

- [ ] **Step 5: Commit `feat: add versioned reporting configuration publication`.**

### Task 5: Build report-instance creation, API receipt and auditable data edits

**Files:**
- Create: `reguai-business/src/main/java/com/reguai/business/reporting/{entity,mapper,service}/**`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/reporting/{ReportingInstanceController,ApiReceiptController}.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/reporting/dto/{CreateManualInstanceRequest,ReceiveApiInstanceRequest,UpdateInstanceDataRequest,ReportingInstanceResponse}.java`
- Create: `reguai-business/src/test/java/com/reguai/business/reporting/ReportingInstanceServiceTest.java`

- [ ] **Step 1: Write failing tests for manual creation requiring institution/business type/business date; deadline and published-version locking; API receipt; and first-edit immutable source snapshot behavior.**

- [ ] **Step 2: Run the reporting service test and verify it fails before the reporting domain exists.**

- [ ] **Step 3: Implement instance list/detail/create/update services. Persist field values as a validated JSON document keyed by frozen schema fields, lock the currently published business type, field-schema, validation-rule and deadline-rule versions, derive the deadline from the frozen rule, and write source snapshots to the configured directory only before the first API-data mutation. Emit field-level audit records with request ID.**

- [ ] **Step 4: Run service and controller integration tests; verify API edits do not create a second instance and edits clear prior workflow decisions.**

- [ ] **Step 5: Commit `feat: add reporting intake, frozen schemas and audited edits`.**

### Task 6: Implement validation, mandatory compliance review and state transitions

**Files:**
- Create: `reguai-business/src/main/java/com/reguai/business/{validation,review,workflow}/**`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/reporting/{ValidationController,ComplianceReviewController}.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/reporting/dto/{ValidationResultResponse,ReviewDecisionRequest}.java`
- Create: `reguai-business/src/test/java/com/reguai/business/workflow/ReportingWorkflowServiceTest.java`

- [ ] **Step 1: Write a parameterized failing test matrix for valid/invalid state transitions, `ERROR` blocking, `WARNING` treatment statements, required review approval, and required return reason.**

- [ ] **Step 2: Run `./mvnw -pl reguai-business test -Dtest=ReportingWorkflowServiceTest` and verify transitions are missing.**

- [ ] **Step 3: Implement a single transition service and rule evaluation adapter that selects the instance's locked validation-rule version. Persist each validation run/result and review decision; authorize only reporting officers to run validation and only compliance officers to approve/return. Every instance must enter review before submission eligibility.**

- [ ] **Step 4: Re-run the matrix and add controller tests for 409 business-state errors and forbidden roles.**

- [ ] **Step 5: Commit `feat: enforce validation and mandatory compliance workflow`.**

### Task 7: Add guarded submission, Quartz processing, notifications and logs

**Files:**
- Create: `reguai-business/src/main/java/com/reguai/business/submission/{SubmissionService,SubmissionGateway,StubSubmissionGateway,SubmissionScheduler}.java`
- Create: `reguai-business/src/main/java/com/reguai/business/{audit,notification}/**`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/reporting/SubmissionController.java`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/admin/{AuditLogController,OperationsController,NotificationController,SystemLogController}.java`
- Create: `reguai-business/src/test/java/com/reguai/business/submission/SubmissionServiceTest.java`

- [ ] **Step 1: Write failing tests proving only approved-pending instances can submit, duplicate idempotency keys create one attempt, submitted instances never resubmit, and a failed/rejected attempt can retry only by transitioning back to `APPROVED_PENDING_SUBMISSION` when its same frozen validation version and approval decision remain valid.**

- [ ] **Step 2: Run the focused submission test and verify the gateway/scheduler are absent.**

- [ ] **Step 3: Implement one submission service shared by the manual endpoint and Quartz job. Record attempt/receipt/failure and process/audit/system logs; expose instance process history at `GET /api/v1/reporting-instances/{publicId}/process-logs` and administrator system logs at `GET /api/v1/admin/system-logs`; use the stub gateway for repeatable tests. Generate in-app notifications for validation failure, return, approaching deadline, submission failure/rejection and retry exhaustion.**

- [ ] **Step 4: Run tests including concurrent submit simulation; verify the terminal `SUBMITTED` transition remains immutable.**

- [ ] **Step 5: Commit `feat: add guarded submission scheduling and observability`.**

### Task 8: Publish and test the backend contract

**Files:**
- Modify: `reguai-app/pom.xml`
- Create: `reguai-interfaces/src/main/java/com/reguai/interfaces/common/OpenApiConfiguration.java`
- Create: `docs/api/reguai-v01-contract.md`
- Create: `reguai-interfaces/src/test/java/com/reguai/interfaces/ApiContractSmokeTest.java`

- [ ] **Step 1: Write a failing smoke test that starts the app and verifies OpenAPI exposes all v0.1 endpoints and error schemas.**

- [ ] **Step 2: Run the test and verify the generated contract is unavailable.**

- [ ] **Step 3: Add OpenAPI generation, standardized pagination and explicit status/error examples. Document the mocked submission adapter, original-snapshot directory property, concrete local JWT session contract, request-ID propagation and the later-IdP replacement boundary.**

- [ ] **Step 4: Run `./mvnw test` and manually inspect `/v3/api-docs` for no database IDs or stack traces.**

- [ ] **Step 5: Commit `docs: publish ReguAI v0.1 backend contract`.**

### Task 9: Scaffold the Vue application shell and access controls

**Files:**
- Create: `frontend/{package.json,tsconfig.json,vite.config.ts,index.html}`
- Create: `frontend/src/{main.ts,App.vue,styles/tokens.css,styles/base.css}`
- Create: `frontend/src/router/{index.ts,guards.ts}`
- Create: `frontend/src/stores/{session.ts,ui.ts}`
- Create: `frontend/src/services/{http.ts,apiError.ts,types.ts}`
- Create: `frontend/src/views/{LoginView.vue,ForbiddenView.vue,NotFoundView.vue}`
- Create: `frontend/src/router/guards.spec.ts`

- [ ] **Step 1: Write failing Vitest tests for unauthenticated redirect, role menu visibility and request-ID/error normalization.**

- [ ] **Step 2: Run `npm --prefix frontend test -- --run` and verify the test fails before the application exists.**

- [ ] **Step 3: Create the Vite application with Vue Router, Pinia and Element Plus. Implement token/session lifecycle, guarded routes, a single HTTP client and the approved navy/stone/blue design tokens. Do not duplicate backend business gates in the client.**

- [ ] **Step 4: Run `npm --prefix frontend run lint`, `npm --prefix frontend test -- --run`, and `npm --prefix frontend run build`.**

- [ ] **Step 5: Commit `feat(frontend): scaffold ReguAI shell and access controls`.**

### Task 10: Implement reporting workbench, list and three-tab instance workspace

**Files:**
- Create: `frontend/src/features/reporting/{api.ts,store.ts,types.ts}/**`
- Create: `frontend/src/views/{WorkbenchView,ReportingListView,ReportingInstanceView}.vue`
- Create: `frontend/src/features/reporting/components/{InstanceStatus,DeadlineBadge,DynamicDataForm,ValidationReviewPanel,SubmissionPanel}.vue`
- Create: `frontend/src/features/reporting/components/**/*.spec.ts`
- Create: `frontend/e2e/reporting-workflow.spec.ts`

- [ ] **Step 1: Write component and Playwright tests for risk-order workbench tasks, manual-create prerequisites, schema-versioned form rendering, edit invalidation, validation-to-review routing and disabled submission before approval.**

- [ ] **Step 2: Run the targeted tests and verify the reporting pages are missing.**

- [ ] **Step 3: Implement `/workbench`, `/reporting` and `/reporting/:businessType/:instanceId`. Keep the three tabs fixed: 数据新增, 校验与合规复核, 提交记录. Display API source/snapshot reference, preserve field errors, and render a second confirmation only for eligible manual submission.**

- [ ] **Step 4: Run Vitest and Playwright against the stub backend; verify completed instances render receipt/history but no submit or retry action.**

- [ ] **Step 5: Commit `feat(frontend): add reporting workflow workspace`.**

### Task 11: Implement institution, notifications and system-management UI

**Files:**
- Create: `frontend/src/views/{InstitutionListView,NotificationCenterView,AdminBusinessTypesView,AdminFieldSchemasView,AdminValidationRulesView,AdminDeadlineRulesView,AdminOperationsView,AdminAuditLogsView,AdminSystemLogsView}.vue`
- Create: `frontend/src/features/{institutions,notifications,admin}/**`
- Create: `frontend/src/features/admin/**/*.spec.ts`
- Create: `frontend/e2e/admin-and-notification.spec.ts`

- [ ] **Step 1: Write failing tests for role-scoped navigation, configuration publish confirmation, immutable-version display, notification read state and audit/system-log access restrictions.**

- [ ] **Step 2: Run the targeted test suite and verify the administration pages are absent.**

- [ ] **Step 3: Implement the configuration, operations, log and notification pages from the accepted prototype. Ensure high-risk configuration/disable actions require confirmation and all mobile layouts collapse to the specified card/drawer patterns.**

- [ ] **Step 4: Run unit and E2E tests at desktop and mobile viewport sizes; perform keyboard-only checks for drawers, dialogs and tabs.**

- [ ] **Step 5: Commit `feat(frontend): add configuration and observability pages`.**

### Task 12: Harden release acceptance and operational documentation

**Files:**
- Create: `docs/runbooks/{local-development,original-snapshot-storage,submission-failure-recovery}.md`
- Create: `docs/acceptance/reguai-v01-acceptance.md`
- Modify: `README.md`
- Create: `frontend/e2e/accessibility.spec.ts`
- Create: `reguai-app/src/test/java/com/reguai/EndToEndWorkflowIT.java`

- [ ] **Step 1: Write the end-to-end acceptance cases listed in the approved frontend specification, including duplicate submission and API-source edit traceability.**

- [ ] **Step 2: Run backend integration, frontend E2E and accessibility tests; record the initially failing gaps.**

- [ ] **Step 3: Fix only acceptance failures, document local bootstrap, snapshot-directory backup/recovery, Quartz failure handling and the stub-channel limitation.**

- [ ] **Step 4: Run `./mvnw test`, `npm --prefix frontend run lint`, `npm --prefix frontend test -- --run`, and `npm --prefix frontend exec playwright test`; verify all pass.**

- [ ] **Step 5: Commit `docs: complete ReguAI v0.1 release acceptance`.**

## Jira backlog mapping

Create one Epic and the following stories in dependency order. Estimates are sizing inputs for sprint planning, not delivery commitments.

| Order | Suggested summary | Depends on | Estimate |
| --- | --- | --- | --- |
| 1 | 平台基础、请求追踪与数据库迁移 | — | 5 SP |
| 2 | 机构全生命周期与角色权限基线 | 1 | 5 SP |
| 3 | 业务类型、字段、规则与时限配置版本 | 1 | 8 SP |
| 4 | 报送实例创建、API 接收与原始快照审计 | 2, 3 | 8 SP |
| 5 | 校验、强制合规复核与状态机 | 4 | 8 SP |
| 6 | 受控提交、Quartz、回执、日志与通知 | 5 | 8 SP |
| 7 | 后端 API 合同与联调环境 | 2–6 | 3 SP |
| 8 | 前端框架、会话、路由与权限 | 7 | 5 SP |
| 9 | 前端工作台、报送列表与实例三页签 | 8, 7 | 8 SP |
| 10 | 前端机构、通知与系统管理 | 8, 7 | 8 SP |
| 11 | 集成验收、可访问性与运行手册 | 6, 9, 10 | 5 SP |

## Definition of Done

- Code and migrations are reviewed, formatted and committed in the order above.
- Unit, integration, UI and E2E tests cover the six acceptance scenarios in the specification.
- No completed report can be submitted again through UI, REST or Quartz.
- Audit records correlate every mutation to an actor and request ID; API-source originals remain retrievable after edits.
- The frontend matches the approved information architecture and supports the stated role, keyboard and responsive requirements.
