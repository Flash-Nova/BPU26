# 自定义封装模块 `ai_method` 方法说明

将可复用操作封装到了 `ai_method/utils.py` 中，通过 `import ai_method.utils as ai` 进行调用。以下是各方法的作用简述：

| 方法名 | 功能简述 | 输入参数 | 返回值 |
| :--- | :--- | :--- | :--- |
| `pick_file(title)` | 唤起 Windows 原生文件选择器，通过 GUI 交互获取图片路径。 | `title` (窗口标题) | 图片绝对路径 `str`，取消则为空 |
| `get_baidu_client()` | 读取安全配置文件中的密钥，并完成百度 AI 的身份鉴权，创建客户端实例。 | 无 | `AipImageClassify` 对象 |
| `get_file_content(path)` | 读取本地文件。 | `path` (文件路径) | `bytes` 类型的二进制数据 |
| `print_json(data)` | 将 API 返回的数据格式化为易读的 JSON，并防止中文字符转义。 | `data` (字典) | 无 (打印到控制台) |