/// 仓库层"当前时间"注入点——测试中注入固定时间戳以获得确定性。
///
/// 与 `data/local/seeder.dart` 的 `SeedClock`、`device_id_store.dart` 的
/// `UuidFactory` 一脉相承：**所有外部不确定性（时间 / 随机数）都应从构造函数
/// 注入**，生产路径用默认值（`DateTime.now`），测试路径用固定 lambda。
typedef RepoClock = DateTime Function();
