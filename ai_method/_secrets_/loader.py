# secrets/loader.py
import json
from pathlib import Path

def load_config(service_name: str) -> dict:
    """
    读取并返回指定服务的配置字典。
    用法: cfg = load_config("baidu")
    """
    secret_path = Path(__file__).parent / "secret.json"
    if not secret_path.exists():
        raise FileNotFoundError(f"未找到 {secret_path}，请先创建配置文件。")
    
    with open(secret_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        return data.get(service_name, {})