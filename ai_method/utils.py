# ai_method/utils.py
import json
from aip import AipImageClassify
from ai_method._secrets_.loader import load_config

def get_baidu_client() -> AipImageClassify:
    """获取百度 AI 图像识别客户端"""
    cfg = load_config("baidu")
    return AipImageClassify(
        cfg["app_id"],
        cfg["api_key"],
        cfg["secret_key"],
    )

def pick_file(title: str = "选择文件") -> str:
    """弹出系统原生文件选择器，返回路径"""
    import tkinter as tk
    from tkinter import filedialog
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.askopenfilename(
        title=title,
        filetypes=[
            ("图片文件", "*.jpg *.jpeg *.png *.bmp *.gif *.webp"),
            ("所有文件", "*.*"),
        ],
    )
    root.destroy()
    return path

def get_file_content(file_path: str) -> bytes:
    """读取文件二进制内容"""
    with open(file_path, "rb") as fp:
        return fp.read()

def print_json(data: dict):
    """格式化、中文化地打印字典数据"""
    print(json.dumps(data, ensure_ascii=False, indent=2))