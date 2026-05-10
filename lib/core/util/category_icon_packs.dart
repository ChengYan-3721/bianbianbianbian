// Step 15.3：分类图标包定义 + 运行时解析。
//
// 两套内置图标包：
// - [BianBianIconPack.sticker]：手绘贴纸风（emoji 表现力强、色彩丰富，自 Step 1.7
//   起即作为默认图标集存在于 `DefaultSeeder.categoriesByParent`）。
// - [BianBianIconPack.flat]：扁平简约风（emoji 更简洁、符号化）。
//
// **运行时解析策略**：`category.icon` 存储的可能是 pack 默认值或用户自定义值。
// [resolveCategoryIcon] 在展示时判断：若存储值匹配任一 pack 的默认值 → 视为
// "pack 默认"，返回当前激活 pack 的对应值；否则 → 视为用户自定义，原样返回。
// 这使得切换 pack 后所有非自定义图标即时更新，无需批量写 DB / 产生 sync_op。

/// 两套内置分类图标包。
enum BianBianIconPack {
  sticker('sticker', '✏️ 手绘贴纸'),
  flat('flat', '📝 扁平简约');

  const BianBianIconPack(this.key, this.label);

  /// 持久化 key（存入 `user_pref.icon_pack`）。
  final String key;

  /// 展示用标签（emoji + 中文名）。
  final String label;

  /// 从持久化 key 解析枚举；未知值 / null 回退 [sticker]。
  static BianBianIconPack fromKey(String? key) {
    return switch (key) {
      'sticker' => BianBianIconPack.sticker,
      'flat' => BianBianIconPack.flat,
      _ => BianBianIconPack.sticker,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 手绘贴纸 pack——与 DefaultSeeder.categoriesByParent 完全一致的 emoji。
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _stickerIcons = {
  'income': {
    '工资': '💰',
    '奖金': '🎉',
    '兼职': '👔',
    '投资收益': '📈',
    '理财收益': '💹',
    '报销': '🧾',
    '红包': '🧧',
    '退款': '↩️',
    '礼金': '💝',
    '其他收入': '💵',
  },
  'food': {
    '早餐': '🥣',
    '午餐': '🍱',
    '晚餐': '🍲',
    '零食': '🍿',
    '饮料': '🧋',
  },
  'shopping': {
    '日用品': '🧻',
    '服饰': '👕',
    '数码': '📱',
    '家居': '🛋️',
    '其他购物': '🛒',
  },
  'transport': {
    '地铁公交': '🚇',
    '打车': '🚕',
    '加油': '⛽',
    '停车': '🅿️',
    '火车机票': '✈️',
  },
  'education': {
    '书籍': '📚',
    '课程': '🧑‍🏫',
    '考试报名': '📝',
    '文具': '✏️',
    '其他教育': '🎒',
  },
  'entertainment': {
    '电影': '🎬',
    '游戏': '🎮',
    '聚会': '🍻',
    '旅行娱乐': '🏖️',
    '其他娱乐': '🎉',
  },
  'social': {
    '礼物': '🎁',
    '请客': '🍽️',
    '红包支出': '🧧',
    '随礼': '💌',
    '其他人情': '🤝',
  },
  'housing': {
    '房租': '🏠',
    '水费': '🚿',
    '电费': '💡',
    '燃气': '🔥',
    '物业': '🧾',
  },
  'medical': {
    '门诊': '🏥',
    '购药': '💊',
    '体检': '🩺',
    '治疗': '🛌',
    '其他医药': '🧪',
  },
  'investment': {
    '基金': '📊',
    '股票': '📉',
    '债券': '🧾',
    '黄金': '🪙',
    '其他投资': '💼',
  },
  'other': {
    '杂项': '🧩',
    '手续费': '💳',
    '捐赠': '🙏',
    '订阅': '🗂️',
    '其他': '💸',
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// 扁平简约 pack——更简洁、符号化的 emoji 替代方案。
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _flatIcons = {
  'income': {
    '工资': '💵',
    '奖金': '🏅',
    '兼职': '💼',
    '投资收益': '📊',
    '理财收益': '💹',
    '报销': '🧾',
    '红包': '🧧',
    '退款': '🔄',
    '礼金': '🎁',
    '其他收入': '💲',
  },
  'food': {
    '早餐': '🍚',
    '午餐': '🍜',
    '晚餐': '🍲',
    '零食': '🍪',
    '饮料': '☕',
  },
  'shopping': {
    '日用品': '🧴',
    '服饰': '👔',
    '数码': '💻',
    '家居': '🛏️',
    '其他购物': '🛍️',
  },
  'transport': {
    '地铁公交': '🚃',
    '打车': '🚖',
    '加油': '⛽',
    '停车': '🅿️',
    '火车机票': '🚄',
  },
  'education': {
    '书籍': '📖',
    '课程': '🎓',
    '考试报名': '📋',
    '文具': '✏️',
    '其他教育': '🎒',
  },
  'entertainment': {
    '电影': '🎥',
    '游戏': '🕹️',
    '聚会': '🥂',
    '旅行娱乐': '🗺️',
    '其他娱乐': '🎭',
  },
  'social': {
    '礼物': '🎀',
    '请客': '🍴',
    '红包支出': '🧧',
    '随礼': '💌',
    '其他人情': '🤲',
  },
  'housing': {
    '房租': '🏘️',
    '水费': '💧',
    '电费': '⚡',
    '燃气': '🔥',
    '物业': '📜',
  },
  'medical': {
    '门诊': '🏥',
    '购药': '💊',
    '体检': '📋',
    '治疗': '🩹',
    '其他医药': '🔬',
  },
  'investment': {
    '基金': '📈',
    '股票': '📉',
    '债券': '📃',
    '黄金': '🪙',
    '其他投资': '💼',
  },
  'other': {
    '杂项': '📌',
    '手续费': '💳',
    '捐赠': '🙏',
    '订阅': '📰',
    '其他': '💲',
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// 运行时解析
// ─────────────────────────────────────────────────────────────────────────────

/// 返回指定 pack 对 `(parentKey, name)` 的默认 emoji；无映射返回 null。
String? packDefaultIcon(BianBianIconPack pack, String parentKey, String name) {
  final map = pack == BianBianIconPack.sticker ? _stickerIcons : _flatIcons;
  return map[parentKey]?[name];
}

/// 解析分类的有效展示图标。
///
/// 判定逻辑：
/// 1. `storedIcon == null` → 使用当前 pack 默认值，无则 [fallback]。
/// 2. `storedIcon` 匹配任一 pack 对 `(parentKey, name)` 的默认值 → 视为 pack 默认，
///    返回当前 pack 的默认值（切换 pack 后自动更新）。
/// 3. `storedIcon` 不匹配任何 pack 默认 → 视为用户自定义，原样返回。
String resolveCategoryIcon(
  String? storedIcon,
  String parentKey,
  String name,
  BianBianIconPack pack, [
  String fallback = '📁',
]) {
  if (storedIcon == null) {
    return packDefaultIcon(pack, parentKey, name) ?? fallback;
  }
  // 检查是否匹配任一 pack 默认值
  final stickerDefault = _stickerIcons[parentKey]?[name];
  final flatDefault = _flatIcons[parentKey]?[name];
  if (storedIcon == stickerDefault || storedIcon == flatDefault) {
    return packDefaultIcon(pack, parentKey, name) ?? storedIcon;
  }
  // 用户自定义
  return storedIcon;
}

/// 返回指定 pack 下所有默认分类的样本图标（用于设置页预览）。
///
/// 从每个一级分类各取第一个二级分类的 emoji，最多 11 个。
List<String> samplePackIcons(BianBianIconPack pack) {
  final map = pack == BianBianIconPack.sticker ? _stickerIcons : _flatIcons;
  return [
    for (final entry in map.entries)
      if (entry.value.isNotEmpty) entry.value.values.first,
  ];
}
