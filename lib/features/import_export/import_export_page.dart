import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_ext.dart';

/// 导入 / 导出 hub 页（Step 13.1 + 13.3）。
///
/// 当前承载两个入口：
/// - 导出（Step 13.1 / 13.2）：CSV / JSON / `.bbbak` 三种格式可选；
/// - 导入（Step 13.3）：JSON / CSV / `.bbbak` 通过文件选择器导入；
///   第三方模板（钱迹 / 微信 / 支付宝）等候 Step 13.4 上线。
///
/// hub 页本身刻意保持极简——配置项都收敛在子页里，避免 hub 承担两份不同形态的表单。
class ImportExportPage extends StatelessWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importExportTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(context.l10n.importExportExport),
            subtitle: Text(context.l10n.importExportExportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import-export/export'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(context.l10n.importExportImport),
            subtitle: Text(context.l10n.importExportImportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import-export/import'),
          ),
        ],
      ),
    );
  }
}
