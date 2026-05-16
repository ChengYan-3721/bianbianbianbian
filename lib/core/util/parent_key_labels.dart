/// 一级分类(`category.parent_key`)与中文标签的双向映射。
///
/// 单一真值源——`quick_text_parser.dart` / `export_service.dart` /
/// `csv/parsers/*.dart` 等均从本文件取常量,避免双副本飘移。
///
/// 11 个固定 key 必须与 `category_table.dart::customConstraints` 中
/// CHECK 约束完全对齐。
// i18n-exempt: needs refactoring for l10n
const Map<String, String> kParentKeyToLabel = {
  'income': '收入',
  'food': '饮食',
  'shopping': '购物',
  'transport': '出行',
  'education': '教育',
  'entertainment': '娱乐',
  'social': '人情',
  'housing': '住房',
  'medical': '医药',
  'investment': '投资',
  'other': '其他',
};

/// 反向映射——CSV 导入时把「饮食」reverse map 到 `food`。
// i18n-exempt: needs refactoring for l10n
const Map<String, String> kLabelToParentKey = {
  '收入': 'income',
  '饮食': 'food',
  '购物': 'shopping',
  '出行': 'transport',
  '教育': 'education',
  '娱乐': 'entertainment',
  '人情': 'social',
  '住房': 'housing',
  '医药': 'medical',
  '投资': 'investment',
  '其他': 'other',
};

/// 已知 `parentKey` 返回中文标签;未知返回 null。
String? parentKeyToChineseLabel(String parentKey) => kParentKeyToLabel[parentKey];

/// 已知中文标签返回 `parentKey`(trim 后查表);未知返回 null。
String? chineseLabelToParentKey(String label) => kLabelToParentKey[label.trim()];
