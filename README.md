# BNEP Cloud Starter Plugin

IntelliJ IDEA 插件，通过 HTTP API 远程操控 IDEA 的 Run/Debug Configuration，配合调试面板实现 SpringBoot 服务的启停管理。

## 功能

插件在 IDEA 启动后自动在 `127.0.0.1:58080` 开启一个轻量 HTTP Server，提供以下接口：

| 接口 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/configs` | GET | 列出当前项目所有 Run Configuration |
| `/run` | POST | 以 Debug 模式启动指定 Configuration |
| `/stop` | POST | 停止指定正在运行的 Configuration |
| `/running` | GET | 列出当前正在运行的进程 |

### 请求示例

```bash
# 列出所有配置
curl http://127.0.0.1:58080/configs

# 启动配置（Debug 模式）
curl -X POST http://127.0.0.1:58080/run -H "Content-Type: application/json" -d "{\"name\":\"MyApplication\"}"

# 停止配置
curl -X POST http://127.0.0.1:58080/stop -H "Content-Type: application/json" -d "{\"name\":\"MyApplication\"}"

# 查看运行中的进程
curl http://127.0.0.1:58080/running
```

## 安装

### 方式一：直接安装 JAR

1. 下载 `dist/bnep-cloud-starter-plugin.jar`
2. IDEA → `Settings` → `Plugins` → `⚙` → `Install Plugin from Disk`
3. 选择 jar 文件，重启 IDEA

### 方式二：从源码构建

```bash
# 修改 build.sh 中的 IDEA_HOME 路径
./build.sh
```

构建产物在 `dist/bnep-cloud-starter-plugin.jar`。

## 自定义端口

在 IDEA 启动时添加 JVM 参数：

```
-Dbnep.debug.port=58080
```

默认端口为 `58080`。

## 项目结构

```
src/main/java/.../BnepCloudPlugin.java   # 插件主类
src/main/resources/META-INF/plugin.xml   # 插件描述文件
build.sh                                  # 构建脚本
dist/                                     # 分发文件
```
