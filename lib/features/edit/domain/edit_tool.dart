/// 编辑工具。
enum EditTool {
  brush('画笔'),
  fill('填充'),
  picker('吸管');

  const EditTool(this.label);

  final String label;
}
