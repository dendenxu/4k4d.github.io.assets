#!/bin/bash

# 检查参数数量
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [github-repo-url] [destination-dir]"
    exit 1
fi

REPO_URL=$1
DEST_DIR=$2

# 从 GitHub URL 中提取用户名和仓库名
REPO=$(echo "$REPO_URL" | awk -F'/' '{print $4"/"$5}' | sed 's/.git$//')

# 使用 GitHub API 获取仓库的文件结构
FILES_JSON=$(curl -s "https://api.github.com/repos/$REPO/git/trees/HEAD?recursive=1")

# 使用 jq 解析文件结构并获取每个文件的路径和哈希值
FILES=$(echo "$FILES_JSON" | jq -r '.tree[] | select(.type == "blob") | "\(.path)|\(.sha)"')

echo "$FILES" | while IFS="|" read -r FILE HASH; do
    FILE_PATH="$DEST_DIR/$FILE"
    FILE_URL="https://raw.githubusercontent.com/$REPO/master/$FILE"

    # 如果文件路径已经是一个目录，我们跳过它
    if [ -d "$FILE_PATH" ]; then
        echo "Warning: Skipping file as the path is a directory: $FILE_PATH"
        continue
    fi

    # 如果文件存在，计算其哈希值
    if [ -f "$FILE_PATH" ]; then
        LOCAL_HASH=$(git hash-object "$FILE_PATH")

        # 如果哈希值匹配，跳过下载
        if [ "$LOCAL_HASH" == "$HASH" ]; then
            echo "File is up-to-date, skipping: $FILE"
            continue
        fi
    fi

    # 创建目录结构
    mkdir -p "$(dirname "$FILE_PATH")"

    # 打印要下载的文件名
    echo "Downloading: $FILE"

    # 下载文件
    curl -# -L -o "$FILE_PATH" "$FILE_URL"
done

echo "Sync completed!"
