"""
study.py - 调用百度 AI 通用物体识别
用法: python study.py [图片路径]
    不带参数时会弹出系统文件选择器
"""

import json
import os
import sys
from pathlib import Path
from aip import AipImageClassify


def find_secret():
    p = Path(__file__).resolve().parent
    while True:
        s = p / "secret.json"
        if s.exists():
            return s
        if p == p.parent:
            raise FileNotFoundError("未找到 secret.json，请参考 secret.example.json 在仓库根目录创建")
        p = p.parent


def load_baidu_config():
    with open(find_secret(), "r", encoding = "utf-8") as f:
        return json.load(f)["baidu"]


def pick_file():
    # 弹出系统原生文件选择器
    import tkinter as tk
    from tkinter import filedialog
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.askopenfilename(
        title = "选择要识别的图片",
        filetypes = [
            ("图片文件", "*.jpg *.jpeg *.png *.bmp *.gif *.webp"),
            ("所有文件", "*.*"),
        ],
    )
    root.destroy()
    return path


def get_file_content(file_path):
    with open(file_path, "rb") as fp:
        return fp.read()


def main():
    # 有命令行参数就用参数，否则弹出一个选择器
    if len(sys.argv) >= 2:
        img_path = sys.argv[1]
    else:
        img_path = pick_file()
        if not img_path:
            print("已取消。")
            sys.exit(0)

    if not os.path.exists(img_path):
        print(f"[错误] 图片不存在: {img_path}")
        sys.exit(1)

    cfg = load_baidu_config()
    client = AipImageClassify(
        cfg["app_id"],
        cfg["api_key"],
        cfg["secret_key"],
    )

    image = get_file_content(img_path)
    result = client.advancedGeneral(image)
    print(json.dumps(result, ensure_ascii = False, indent = 2))


if __name__ == "__main__":
    main()