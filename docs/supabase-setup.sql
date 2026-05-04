-- =============================================================================
-- 边边记账（bianbianbianbian）· Supabase 初始化脚本
-- =============================================================================
-- 用途：仅当用户选择 Supabase 作为云同步 backend 时，在自己的 Supabase 项目
--       里跑一次的初始化脚本。其他 3 个 backend（iCloud / WebDAV / S3）无需
--       任何后端配置。
--
-- 覆盖：
--   1. 账本快照备份 bucket（beecount-backups，Phase 10 已上线）
--   2. 附件本体 bucket（attachments，Phase 11 新增）
--   3. 上述两个 bucket 的 SELECT / INSERT / UPDATE / DELETE 共 8 条 RLS 策略
--   4. 验证查询：用两个测试账户跑一遍，确认跨用户访问被挡
--   5. 回滚段（DROP POLICY + DELETE FROM storage.buckets）
--
-- 加密说明：
--   本脚本与 App 均**不做云端加密**。账本快照是明文 JSON、附件是原始格式
--   （.jpg / .png / .heic / .pdf 等）明文存放。原因：用户的 Supabase 项目
--   是用户自有空间，RLS 已隔离不同 user_id；明文存放允许用户通过 Supabase
--   Dashboard 直接预览附件，运维友好。如果未来要加密，作为独立 Phase 重新
--   评估，本脚本不需改。
--
--   ⚠️ 用户的 Supabase 账户被攻破或凭据泄露 = 全部数据可读。
--      请确保使用受信任的 Supabase 实例 + 强密码 + 必要时启用 MFA。
--
-- 执行方式：
--   - 推荐在 Supabase Dashboard → SQL Editor 中按段执行（每段一次 Run），
--     而不是整个文件一次跑——便于看清每段的影响。
--   - 也可在本地用 supabase CLI：`supabase db execute --file docs/supabase-setup.sql`
--   - 脚本是幂等的：所有 CREATE/INSERT 都用 IF NOT EXISTS / ON CONFLICT；
--     所有 POLICY 用 DROP IF EXISTS 后再 CREATE。
--   - **App 内不自动执行**——避免持有 service_role key，也避免误改用户其他
--     业务表。手动一次性配置即可。
--
-- 依赖前提：
--   - Supabase 项目已创建，auth schema 已就绪（开箱默认）。
--   - 用户走 Email + Password 走 supabase.auth.signUp / signIn 拿到 auth.uid()。
--   - 客户端写入路径必须是 `users/<auth.uid()>/...`，否则 INSERT 会被 RLS 拒绝。
--
-- 路径约定（与 lib/features/sync/sync_service.dart 保持一致）：
--   - 备份：users/<uid>/ledgers/<ledgerId>.json
--   - 附件：users/<uid>/attachments/<txId>/<sha256><ext>
--           (<ext> 是原始扩展名，如 .jpg / .png / .heic / .pdf；不追加 .enc)
-- 两者 RLS 检查共用 `(storage.foldername(name))[2] = auth.uid()::text`。
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Bucket 创建（私有，禁止公网读取）
-- -----------------------------------------------------------------------------
-- public = false：必须经过 RLS 才能访问，匿名 anon key 无能力越过。
-- file_size_limit / allowed_mime_types 留空 = 不限制（应用层做约束）。
--   - 附件单文件 ≤ 10MB（客户端 AttachmentUploader 强制；超出转 JPEG q=85）。
--     如要进一步收紧，改 file_size_limit。
--   - allowed_mime_types 不限制——客户端可上传 image/* + application/pdf 等
--     原始格式；服务端不重复约束便于未来调整。

insert into storage.buckets (id, name, public)
values ('beecount-backups', 'beecount-backups', false)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do update set public = excluded.public;


-- -----------------------------------------------------------------------------
-- 2. RLS 启用（storage.objects 默认已启用，此处显式声明便于审计）
-- -----------------------------------------------------------------------------
alter table storage.objects enable row level security;


-- -----------------------------------------------------------------------------
-- 3. RLS 策略 · beecount-backups（账本快照）
-- -----------------------------------------------------------------------------
-- 设计原则：
--   - 只读自己的对象（folder[2] == auth.uid()）；
--   - 写入路径必须以 `users/<uid>/` 开头（INSERT 的 WITH CHECK）；
--   - UPDATE 同时校验 USING（旧行）+ WITH CHECK（新行），防止把别人对象改名到自己路径下；
--   - DELETE 只能删自己的。

-- 3.1 SELECT
drop policy if exists "backups: owner can read" on storage.objects;
create policy "backups: owner can read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'beecount-backups'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 3.2 INSERT
drop policy if exists "backups: owner can insert" on storage.objects;
create policy "backups: owner can insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'beecount-backups'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 3.3 UPDATE
drop policy if exists "backups: owner can update" on storage.objects;
create policy "backups: owner can update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'beecount-backups'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  )
  with check (
    bucket_id = 'beecount-backups'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 3.4 DELETE
drop policy if exists "backups: owner can delete" on storage.objects;
create policy "backups: owner can delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'beecount-backups'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );


-- -----------------------------------------------------------------------------
-- 4. RLS 策略 · attachments（附件本体明文，Phase 11 新增）
-- -----------------------------------------------------------------------------
-- 与 backups 同模式，只换 bucket_id。
-- 路径：users/<uid>/attachments/<txId>/<sha256><ext>
--   folder[1] = 'users'    ← RLS 校验
--   folder[2] = uid        ← RLS 校验
--   folder[3] = 'attachments' ← 不参与 RLS（应用层强制）
--   folder[4] = txId       ← 不参与 RLS
--   文件名 = <sha256><ext>  ← 不参与 RLS

-- 4.1 SELECT
drop policy if exists "attachments: owner can read" on storage.objects;
create policy "attachments: owner can read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 4.2 INSERT
drop policy if exists "attachments: owner can insert" on storage.objects;
create policy "attachments: owner can insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 4.3 UPDATE
drop policy if exists "attachments: owner can update" on storage.objects;
create policy "attachments: owner can update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 4.4 DELETE
drop policy if exists "attachments: owner can delete" on storage.objects;
create policy "attachments: owner can delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'users'
    and (storage.foldername(name))[2] = (auth.uid())::text
  );


-- =============================================================================
-- 验证段 · 跑这些查询确认 RLS 真的挡住了跨用户访问
-- =============================================================================
-- 准备工作：
--   1. 在 Supabase Dashboard → Authentication → Users 里新建两个测试账户：
--      a@test.local / b@test.local（密码任意，记住 uid，下面叫 UID_A / UID_B）。
--   2. 在 Dashboard → SQL Editor 顶部的「Run as」下拉选 a@test.local；
--      或在客户端用 supabase.auth.signInWithPassword 拿到 a 的 access_token，
--      用该 token 访问 REST/Storage API。
--
-- 期望结果：
--   - A 能读/写 `users/<UID_A>/...` 路径下的对象。
--   - A 尝试读/写 `users/<UID_B>/...` 路径，返回 0 行或 403/RLS error。
--   - anon（未登录）任何操作都返回 0 行或 401。
-- -----------------------------------------------------------------------------

-- V1. 列出当前登录用户能看到的对象（应只看到自己的）
-- select name, bucket_id, owner from storage.objects
-- where bucket_id in ('beecount-backups', 'attachments')
-- order by created_at desc
-- limit 20;

-- V2. 模拟 A 写入自己路径（应成功）
-- 注意：直接 INSERT INTO storage.objects 通常被 service_role 限制；
--       推荐用客户端 supabase.storage.from('attachments').uploadBinary 测试。
-- 但在 SQL Editor 内可以用以下方式模拟（需要 owner 字段对齐）：
-- insert into storage.objects (bucket_id, name, owner, metadata)
-- values (
--   'attachments',
--   'users/' || (auth.uid())::text || '/attachments/test-tx/0000.jpg',
--   auth.uid(),
--   '{"size": 0}'::jsonb
-- );

-- V3. 模拟 A 写入 B 的路径（应被 RLS 拒绝，报 new row violates row-level security policy）
-- insert into storage.objects (bucket_id, name, owner, metadata)
-- values (
--   'attachments',
--   'users/<UID_B>/attachments/foo/bar.jpg',
--   auth.uid(),
--   '{"size": 0}'::jsonb
-- );
-- 期望错误：new row violates row-level security policy for table "objects"

-- V4. 列出策略本身，确认全部 8 条已生效
select schemaname, tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and (policyname like 'backups:%' or policyname like 'attachments:%')
order by policyname;
-- 期望返回 8 行：backups SELECT/INSERT/UPDATE/DELETE + attachments 同上。


-- =============================================================================
-- 客户端测试脚本（与 SQL 配套，仅作记录，不在此文件执行）
-- =============================================================================
-- 在 test/integration/supabase_rls_test.dart 中（Phase 11 落地时新增）：
--
-- ```dart
-- final clientA = SupabaseClient(url, anonKey);
-- await clientA.auth.signInWithPassword(email: 'a@test.local', password: ...);
-- final uidA = clientA.auth.currentUser!.id;
--
-- // ✓ A 写自己路径：成功
-- await clientA.storage.from('attachments').uploadBinary(
--   'users/$uidA/attachments/tx-1/sha-aaa.jpg',
--   Uint8List.fromList([1, 2, 3]),
-- );
--
-- // ✗ A 写 B 路径：抛 StorageException(statusCode: 403)
-- expect(
--   () => clientA.storage.from('attachments').uploadBinary(
--     'users/$uidB/attachments/tx-1/sha-bbb.jpg',
--     Uint8List.fromList([1, 2, 3]),
--   ),
--   throwsA(isA<StorageException>()),
-- );
--
-- // ✗ A 读 B 路径：返回空字节或抛异常（取决于 SDK 版本）
-- expect(
--   () => clientA.storage.from('attachments').download('users/$uidB/attachments/tx-1/sha-bbb.jpg'),
--   throwsA(isA<StorageException>()),
-- );
-- ```


-- =============================================================================
-- 回滚段（仅在确认要清理时执行；危险，会删除所有用户的数据）
-- =============================================================================
-- 注释默认留着，避免误执行。需要回滚时把整段取消注释后跑。
--
-- -- 1. 删策略
-- drop policy if exists "backups: owner can read" on storage.objects;
-- drop policy if exists "backups: owner can insert" on storage.objects;
-- drop policy if exists "backups: owner can update" on storage.objects;
-- drop policy if exists "backups: owner can delete" on storage.objects;
-- drop policy if exists "attachments: owner can read" on storage.objects;
-- drop policy if exists "attachments: owner can insert" on storage.objects;
-- drop policy if exists "attachments: owner can update" on storage.objects;
-- drop policy if exists "attachments: owner can delete" on storage.objects;
--
-- -- 2. 删 bucket（必须先清空对象，否则报错）
-- delete from storage.objects where bucket_id in ('beecount-backups', 'attachments');
-- delete from storage.buckets where id in ('beecount-backups', 'attachments');
