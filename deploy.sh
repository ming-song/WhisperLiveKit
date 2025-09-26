#!/bin/bash

# WhisperLiveKit 部署脚本
# 作者: Songm
# 用于在新拉取的仓库中进行自动化部署

echo "=================================="
echo "WhisperLiveKit 自动部署脚本"
echo "=================================="

# 设置脚本在出错时退出
set -e

# 获取项目根目录
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$PROJECT_ROOT"

echo "当前工作目录: $PROJECT_ROOT"

# 步骤1: 创建 venv 虚拟环境
echo ""
echo "[步骤 1/6] 创建 Python 虚拟环境..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ 虚拟环境创建成功"
else
    echo "✓ 虚拟环境已存在，跳过创建"
fi

# 步骤2: 激活 venv 环境
echo ""
echo "[步骤 2/6] 激活虚拟环境..."
source venv/bin/activate
echo "✓ 虚拟环境已激活"
echo "Python 路径: $(which python)"
echo "Python 版本: $(python --version)"

# 步骤3: 安装 PyTorch 依赖
echo ""
echo "[步骤 3/6] 安装 PyTorch 和 torchaudio..."
echo "开始下载依赖，请耐心等待..."
pip install torch torchaudio
echo "✓ PyTorch 依赖安装完成"

# 步骤4: 下载 VAD 模型
echo ""
echo "[步骤 4/6] 下载 VAD 模型..."
if [ -f "download_vad_model.py" ]; then
    echo "执行 VAD 模型下载，请耐心等待..."
    python download_vad_model.py
    echo "✓ VAD 模型下载完成"
else
    echo "⚠ 警告: download_vad_model.py 文件不存在，跳过模型下载"
fi

# 步骤5: 构建基础镜像和启动服务
echo ""
echo "[步骤 5/6] 构建基础镜像和启动服务..."
echo "首先构建基础镜像..."
docker compose --profile build-only up --build wlk-base
echo "启动应用服务（后台模式）..."
docker compose up -d wlk-auto wlk-cn
echo "✓ Docker 服务启动命令执行完成"

# 步骤6: 监控服务启动状态
echo ""
echo "[步骤 6/6] 监控服务启动状态..."
echo "等待服务完全启动..."
echo "监控容器日志，等待两个服务都显示 'Uvicorn running on http://0.0.0.0:8000'"
echo "按 Ctrl+C 可停止日志监控"
echo ""

# 监控函数
monitor_services() {
    local timeout=300  # 5分钟超时
    local elapsed=0
    local wlk_auto_ready=false
    local wlk_cn_ready=false
    
    echo "开始监控服务启动状态..."
    
    while [ $elapsed -lt $timeout ]; do
        # 检查 wlk-auto 服务
        if ! $wlk_auto_ready; then
            if docker compose logs wlk-auto 2>/dev/null | grep -q "Uvicorn running on http://0.0.0.0:8000"; then
                echo "✓ wlk-auto 服务已启动 (端口: 8764)"
                wlk_auto_ready=true
            fi
        fi
        
        # 检查 wlk-cn 服务
        if ! $wlk_cn_ready; then
            if docker compose logs wlk-cn 2>/dev/null | grep -q "Uvicorn running on http://0.0.0.0:8000"; then
                echo "✓ wlk-cn 服务已启动 (端口: 8763)"
                wlk_cn_ready=true
            fi
        fi
        
        # 如果两个服务都启动了，退出监控
        if $wlk_auto_ready && $wlk_cn_ready; then
            echo ""
            echo "🎉 所有服务启动完成！"
            echo "   - wlk-auto (自动语言检测): http://localhost:8764"
            echo "   - wlk-cn (中文专用): http://localhost:8763"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
        
        # 每10秒显示一次进度
        if [ $((elapsed % 10)) -eq 0 ]; then
            echo "等待服务启动中... (${elapsed}s/${timeout}s)"
        fi
    done
    
    echo "⚠ 警告: 监控超时，请手动检查服务状态"
    return 1
}

# 执行监控
monitor_services

echo ""
echo "=================================="
echo "部署完成！"
echo "=================================="
echo ""
echo "服务状态检查:"
docker compose ps

echo ""
echo "可用命令:"
echo "  查看实时日志: docker compose logs -f"
echo "  停止服务:     docker compose down"
echo "  重启服务:     docker compose restart"
echo ""
echo "如需查看完整日志输出，请运行:"
echo "  docker compose logs -f"