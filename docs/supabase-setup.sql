-- =============================================================================
-- 边边记账（bianbianbianbian）· Supabase 初始化脚本
-- =============================================================================
-- 用途：仅当用户选择 Supabase 作为云同步 backend 时，在自己的 Supabase 项目
--       里跑一次的初始化脚本。其他 3 个 backend（iCloud / WebDAV / S3）无需
--       任何后端配置。
--
-- 覆盖：
--   1. 账本快照备份 bucket（bbbb-backups，Phase 10 已上线；V2 后仅未升级旧 App 使用）
--   2. 附件本体 bucket（attachments，Phase 11 新增；V2 仍在用，附件继续走对象存储）
--   3. 上述两个 bucket 的 SELECT / INSERT / UPDATE / DELETE 共 8 条 RLS 策略
--   4. **V2 增量同步业务表（Phase 17 新增）**：ledger / category / account /
--      transaction_entry / budget 共 5 张 Postgres 表 + 6 个索引 + 20 条 RLS 策略
--   5. 验证查询：用两个测试账户跑一遍，确认跨用户访问被挡（bucket + 业务表都验）
--   6. 回滚段（DROP POLICY + DROP TABLE + DELETE FROM storage.buckets）
--
-- V1 → V2 升级提示：
--   - 旧 App（V1 快照模式）只读写 bbbb-backups bucket，本脚本保留该段不动；
--   - 新 App（V2 增量模式）只读写下面 5 张业务表 + attachments bucket，不再碰
--     bbbb-backups；
--   - 升级用户必须**重新跑一次本脚本**，确保 V2 段（业务表 + RLS）已创建；
--     脚本幂等，重复跑不会破坏现有数据。
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

-- insert into storage.buckets (id, name, public)
-- values ('bbbb-backups', 'bbbb-backups', false)
-- on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do update set public = excluded.public;


-- -----------------------------------------------------------------------------
-- 2. RLS 启用（storage.objects 默认已启用，此处显式声明便于审计）
-- -----------------------------------------------------------------------------
-- alter table storage.objects enable row level security;


-- -----------------------------------------------------------------------------
-- 3. RLS 策略 · bbbb-backups（账本快照）
-- -----------------------------------------------------------------------------
-- 设计原则：
--   - 只读自己的对象（folder[2] == auth.uid()）；
--   - 写入路径必须以 `users/<uid>/` 开头（INSERT 的 WITH CHECK）；
--   - UPDATE 同时校验 USING（旧行）+ WITH CHECK（新行），防止把别人对象改名到自己路径下；
--   - DELETE 只能删自己的。

-- 3.1 SELECT
-- drop policy if exists "backups: owner can read" on storage.objects;
-- create policy "backups: owner can read"
--   on storage.objects
--   for select
--   to authenticated
--   using (
--     bucket_id = 'bbbb-backups'
--     and (storage.foldername(name))[1] = 'users'
--     and (storage.foldername(name))[2] = (auth.uid())::text
--   );

-- 3.2 INSERT
-- drop policy if exists "backups: owner can insert" on storage.objects;
-- create policy "backups: owner can insert"
--   on storage.objects
--   for insert
--   to authenticated
--   with check (
--     bucket_id = 'bbbb-backups'
--     and (storage.foldername(name))[1] = 'users'
--     and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 3.3 UPDATE
-- drop policy if exists "backups: owner can update" on storage.objects;
-- create policy "backups: owner can update"
--   on storage.objects
--   for update
--   to authenticated
--   using (
--     bucket_id = 'bbbb-backups'
--     and (storage.foldername(name))[1] = 'users'
--     and (storage.foldername(name))[2] = (auth.uid())::text
--   )
--   with check (
--     bucket_id = 'bbbb-backups'
--     and (storage.foldername(name))[1] = 'users'
--     and (storage.foldername(name))[2] = (auth.uid())::text
  );

-- 3.4 DELETE
-- drop policy if exists "backups: owner can delete" on storage.objects;
-- create policy "backups: owner can delete"
--   on storage.objects
--   for delete
--   to authenticated
--   using (
--     bucket_id = 'bbbb-backups'
--     and (storage.foldername(name))[1] = 'users'
--     and (storage.foldername(name))[2] = (auth.uid())::text
--   );


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
-- 5. V2 增量同步业务表（Phase 17 新增）
-- =============================================================================
-- 设计要点：
--   - 字段以本地 drift 表为真值源（lib/data/local/tables/*.dart）；新增本地列
--     时必须同步在此追加 ALTER TABLE 段。
--   - id 列类型 = text（与本地 TextColumn 一致；不用 uuid，避免 PostgREST 把
--     uuid 列包装成对象，简化 push/pull 序列化）。
--   - user_id 列类型 = uuid（对接 auth.users.id），是 RLS 隔离的唯一依据。
--   - 时间戳列（updated_at / occurred_at / created_at / start_date /
--     last_settled_at）= bigint（epoch ms，与本地 IntColumn 一致）。
--   - note_encrypted / attachments_encrypted = text 存 base64 字符串
--     （本地 BLOB 通过 toJson 已经 base64 化，roundtrip 不需要 PostgREST bytea
--     编码，简化数倍）。
--   - bool 字段（archived / is_favorite / include_in_total / carry_over）= integer
--     0/1，与本地 drift IntColumn 0/1 对齐；客户端推送时由 entity_mappers 把
--     Dart bool 在 entity↔row 层归一化，再由 _entityJsonToCloudRow 把 entity
--     bool 转成 int 0/1 上推。**不**用 boolean 列——PostgREST 不会自动 bool↔int
--     归一化，列类型若是 boolean 而客户端发 int 0/1 会报 22P02。统一用
--     integer 让 client 不需要切换发送类型。
--   - 5 张表均无外键 references，仅靠应用层维护引用一致性。理由：多设备同步时
--     pull 顺序无法保证（先拉到 transaction，后才拉到 ledger），FK CASCADE 会
--     导致 INSERT 失败或意外清空数据。
--   - 索引：(user_id, updated_at) 是增量 pull 的 hot path（where user_id =
--     ? and updated_at > ?）；transaction_entry 额外补 (user_id, ledger_id,
--     occurred_at desc) 给后续 server-side 查询用。
-- -----------------------------------------------------------------------------

-- 5.1 ledger（账本）
create table if not exists public.ledger (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  cover_emoji text,
  cover_svg text,
  default_currency text default 'CNY',
  archived integer default 0,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  device_id text not null
);
create index if not exists ledger_user_updated_idx on public.ledger(user_id, updated_at);

-- 5.2 category（分类，全局共享，跨账本可见）
create table if not exists public.category (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  icon text,
  icon_svg text,
  color text,
  parent_key text not null,
  sort_order int default 0,
  is_favorite integer default 0,
  updated_at bigint not null,
  deleted_at bigint,
  device_id text not null
);
create index if not exists category_user_updated_idx on public.category(user_id, updated_at);

-- 5.3 account（资产账户，全局共享）
create table if not exists public.account (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null,
  icon text,
  icon_svg text,
  color text,
  include_in_total integer default 1,
  currency text default 'CNY',
  billing_day int,
  repayment_day int,
  updated_at bigint not null,
  deleted_at bigint,
  device_id text not null
);
create index if not exists account_user_updated_idx on public.account(user_id, updated_at);

-- 5.4 transaction_entry（流水，按 ledger_id 软引用，无 FK）
create table if not exists public.transaction_entry (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ledger_id text not null,
  type text not null,
  amount double precision not null,
  currency text not null,
  fx_rate double precision default 1.0,
  category_id text,
  account_id text,
  to_account_id text,
  occurred_at bigint not null,
  note_encrypted text,
  attachments_encrypted text,
  tags text,
  content_hash text,
  updated_at bigint not null,
  deleted_at bigint,
  device_id text not null
);
create index if not exists tx_user_updated_idx on public.transaction_entry(user_id, updated_at);
create index if not exists tx_user_ledger_occurred_idx on public.transaction_entry(user_id, ledger_id, occurred_at desc);

-- 5.5 budget（预算）
create table if not exists public.budget (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ledger_id text not null,
  period text not null,
  category_id text,
  amount double precision not null,
  carry_over integer default 0,
  carry_balance double precision default 0,
  last_settled_at bigint,
  start_date bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  device_id text not null
);
create index if not exists budget_user_updated_idx on public.budget(user_id, updated_at);


-- -----------------------------------------------------------------------------
-- 6. V2 业务表 RLS：5 张表 × 4 op = 20 条策略
-- -----------------------------------------------------------------------------
-- 与 Storage RLS 不同，业务表的 RLS 走 user_id = auth.uid() 直接判定。
-- - SELECT / DELETE：USING 子句校验旧行 user_id == auth.uid()；
-- - INSERT：WITH CHECK 子句校验新行 user_id == auth.uid()，禁止伪造 user_id；
-- - UPDATE：USING（旧行）+ WITH CHECK（新行）双校验，防止把别人的行改成自己的。
--
-- 客户端 push 路径必须显式把 user_id 设为 auth.uid()——见
-- packages/flutter_cloud_sync_supabase 的 upsertBatch 实现：调用方注入 user_id，
-- 或由该方法读取 auth.currentUser.id 自动注入。

alter table public.ledger enable row level security;
alter table public.category enable row level security;
alter table public.account enable row level security;
alter table public.transaction_entry enable row level security;
alter table public.budget enable row level security;

-- 6.1 ledger
drop policy if exists "ledger: owner can read"   on public.ledger;
create policy "ledger: owner can read"   on public.ledger for select to authenticated using       (user_id = auth.uid());
drop policy if exists "ledger: owner can insert" on public.ledger;
create policy "ledger: owner can insert" on public.ledger for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "ledger: owner can update" on public.ledger;
create policy "ledger: owner can update" on public.ledger for update to authenticated using       (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "ledger: owner can delete" on public.ledger;
create policy "ledger: owner can delete" on public.ledger for delete to authenticated using       (user_id = auth.uid());

-- 6.2 category
drop policy if exists "category: owner can read"   on public.category;
create policy "category: owner can read"   on public.category for select to authenticated using       (user_id = auth.uid());
drop policy if exists "category: owner can insert" on public.category;
create policy "category: owner can insert" on public.category for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "category: owner can update" on public.category;
create policy "category: owner can update" on public.category for update to authenticated using       (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "category: owner can delete" on public.category;
create policy "category: owner can delete" on public.category for delete to authenticated using       (user_id = auth.uid());

-- 6.3 account
drop policy if exists "account: owner can read"   on public.account;
create policy "account: owner can read"   on public.account for select to authenticated using       (user_id = auth.uid());
drop policy if exists "account: owner can insert" on public.account;
create policy "account: owner can insert" on public.account for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "account: owner can update" on public.account;
create policy "account: owner can update" on public.account for update to authenticated using       (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "account: owner can delete" on public.account;
create policy "account: owner can delete" on public.account for delete to authenticated using       (user_id = auth.uid());

-- 6.4 transaction_entry
drop policy if exists "transaction_entry: owner can read"   on public.transaction_entry;
create policy "transaction_entry: owner can read"   on public.transaction_entry for select to authenticated using       (user_id = auth.uid());
drop policy if exists "transaction_entry: owner can insert" on public.transaction_entry;
create policy "transaction_entry: owner can insert" on public.transaction_entry for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "transaction_entry: owner can update" on public.transaction_entry;
create policy "transaction_entry: owner can update" on public.transaction_entry for update to authenticated using       (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "transaction_entry: owner can delete" on public.transaction_entry;
create policy "transaction_entry: owner can delete" on public.transaction_entry for delete to authenticated using       (user_id = auth.uid());

-- 6.5 budget
drop policy if exists "budget: owner can read"   on public.budget;
create policy "budget: owner can read"   on public.budget for select to authenticated using       (user_id = auth.uid());
drop policy if exists "budget: owner can insert" on public.budget;
create policy "budget: owner can insert" on public.budget for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "budget: owner can update" on public.budget;
create policy "budget: owner can update" on public.budget for update to authenticated using       (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "budget: owner can delete" on public.budget;
create policy "budget: owner can delete" on public.budget for delete to authenticated using       (user_id = auth.uid());


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
-- where bucket_id in ('bbbb-backups', 'attachments')
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

-- V5. 列出 V2 业务表的 RLS 策略，确认全部 20 条已生效
select schemaname, tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('ledger', 'category', 'account', 'transaction_entry', 'budget')
order by tablename, policyname;
-- 期望返回 20 行：5 张表 × (read/insert/update/delete) 各 4 条。

-- V6. 列出 V2 业务表本身 + 索引，确认全部 5 张表 + 6 个索引已创建
select tablename from pg_tables
where schemaname = 'public'
  and tablename in ('ledger', 'category', 'account', 'transaction_entry', 'budget')
order by tablename;
-- 期望返回 5 行

select indexname, tablename from pg_indexes
where schemaname = 'public'
  and tablename in ('ledger', 'category', 'account', 'transaction_entry', 'budget')
  and indexname not like '%_pkey'
order by tablename, indexname;
-- 期望返回 6 行（不含主键索引）：
--   account_user_updated_idx           on account
--   budget_user_updated_idx            on budget
--   category_user_updated_idx          on category
--   ledger_user_updated_idx            on ledger
--   tx_user_ledger_occurred_idx        on transaction_entry
--   tx_user_updated_idx                on transaction_entry
-- 4 张表各 1 个 (user_id, updated_at) + transaction_entry 多 1 个
-- (user_id, ledger_id, occurred_at desc) = 共 6 个。

-- V7. 验业务表 RLS：模拟跨用户访问被挡
-- 准备：用 SQL Editor 顶部的 "Run as" 选 a@test.local（或在客户端用 a 的 token）。
-- 先以 a 身份插一行 ledger：
-- insert into public.ledger
--   (id, user_id, name, default_currency, created_at, updated_at, device_id)
-- values
--   ('test-ledger-a', auth.uid(), '测试账本A', 'CNY',
--    extract(epoch from now())::bigint * 1000,
--    extract(epoch from now())::bigint * 1000, 'test-device-a');
-- 期望：成功插入。
--
-- 然后切到 b@test.local 身份查询：
-- select * from public.ledger where id = 'test-ledger-a';
-- 期望：返回 0 行（RLS 挡住）。
--
-- 仍以 b 身份尝试伪造 user_id = a.uid 插入：
-- insert into public.ledger
--   (id, user_id, name, default_currency, created_at, updated_at, device_id)
-- values
--   ('test-ledger-fake', '<UID_A>'::uuid, '伪造账本', 'CNY', 0, 0, 'b');
-- 期望：报 "new row violates row-level security policy for table 'ledger'"。
--
-- 清理：以 a 身份 delete from public.ledger where id = 'test-ledger-a';


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
-- delete from storage.objects where bucket_id in ('bbbb-backups', 'attachments');
-- delete from storage.buckets where id in ('bbbb-backups', 'attachments');
--
-- -- 3. 删 V2 业务表的 RLS 策略（按表分组，共 20 条）
-- drop policy if exists "ledger: owner can read"            on public.ledger;
-- drop policy if exists "ledger: owner can insert"          on public.ledger;
-- drop policy if exists "ledger: owner can update"          on public.ledger;
-- drop policy if exists "ledger: owner can delete"          on public.ledger;
-- drop policy if exists "category: owner can read"          on public.category;
-- drop policy if exists "category: owner can insert"        on public.category;
-- drop policy if exists "category: owner can update"        on public.category;
-- drop policy if exists "category: owner can delete"        on public.category;
-- drop policy if exists "account: owner can read"           on public.account;
-- drop policy if exists "account: owner can insert"         on public.account;
-- drop policy if exists "account: owner can update"         on public.account;
-- drop policy if exists "account: owner can delete"         on public.account;
-- drop policy if exists "transaction_entry: owner can read"   on public.transaction_entry;
-- drop policy if exists "transaction_entry: owner can insert" on public.transaction_entry;
-- drop policy if exists "transaction_entry: owner can update" on public.transaction_entry;
-- drop policy if exists "transaction_entry: owner can delete" on public.transaction_entry;
-- drop policy if exists "budget: owner can read"            on public.budget;
-- drop policy if exists "budget: owner can insert"          on public.budget;
-- drop policy if exists "budget: owner can update"          on public.budget;
-- drop policy if exists "budget: owner can delete"          on public.budget;
--
-- -- 4. 删 V2 业务表（CASCADE 会自动连带索引；如有其他对象依赖请先排查）
-- drop table if exists public.transaction_entry cascade;
-- drop table if exists public.budget cascade;
-- drop table if exists public.category cascade;
-- drop table if exists public.account cascade;
-- drop table if exists public.ledger cascade;
