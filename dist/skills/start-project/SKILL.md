---
name: start-project
description: >
  在 IDEA 中以 Debug 模式启动 BNEP Cloud 微服务模块，或初始化本地开发环境。
  当用户说"启动项目"、"帮我启动"、"初始化开发环境"、"配置项目"、"setup"、
  提到任何模块中文名（网关、IOT平台、事件中心、流程引擎、数智档案、大气管控、
  水环境管控等）或英文模块名时触发。也用于查看模块列表、停止服务。
  这是一个多模块微服务项目的开发环境管理工具，支持一键初始化和模块启停。
---

## 行为规则

### 1. 初始化意图（最高优先级）

当用户说"初始化开发环境"、"配置项目"、"setup"、"第一次用"、"帮我装插件"时，按顺序执行以下步骤。**做完所有步骤后再统一提示重启，不要中途打断。**

**Step 1 — 配置 Nacos 命名空间**

问用户："你的 Nacos 命名空间 ID 是什么？（如 `dplinger`，可在 http://121.5.102.46:8849/nacos 查看，若还没有请先去创建）"

拿到命名空间 ID 后设置环境变量：

```powershell
[Environment]::SetEnvironmentVariable('NACOS_NAMESPACE', '用户给的ID', 'User')
```

**Step 2 — 安装 IDEA 插件**

将 `assets/bnep-cloud-starter-plugin.jar` 拷贝到 IDEA 插件目录：

```powershell
$plugins = "$env:APPDATA\JetBrains\IntelliJIdea*\plugins"
if (Test-Path $plugins) {
    Copy-Item "assets\bnep-cloud-starter-plugin.jar" (Resolve-Path $plugins).Path -Force
}
```

**Step 3 — 扫描项目生成模块数据**

```powershell
scripts\update-modules.ps1 -ProjectPath "当前项目根目录"
```

**Step 4 — 配置 dynamic.classpath**

检查 `.idea\workspace.xml` 是否包含 `"dynamic.classpath": "true"`，若没有则添加：

将以下命令中的 `<PROJECT_ROOT>` 替换为当前项目根目录的绝对路径后执行：

```powershell
$ws = "<PROJECT_ROOT>\.idea\workspace.xml"
if (Test-Path $ws) {
    $c = Get-Content $ws -Raw -Encoding UTF8
    if ($c -notmatch '"dynamic\.classpath"') {
        $c = $c -replace '("keyToString"\s*:\s*\{)', ('$1' + "`r`n    `"dynamic.classpath`": `"true`",")
        $c | Set-Content $ws -Encoding UTF8 -NoNewline
    }
}
```

项目根目录就是 Step 3 `update-modules.ps1` 用的 `-ProjectPath` 参数值。

**Step 5 — 完成**

所有步骤做完后，统一告诉用户：

> "初始化完成！命名空间已设为 `xxx`、插件已安装、模块数据已生成。请重启 IDEA，然后说'启动项目'即可。"

---

### 2. 启动意图

当用户说"启动项目"、"帮我启动服务"、"运行起来"时：

1. 先检查插件是否在线：`scripts/start-modules.ps1 -Action health`
   - 若失败，提示用户"插件未响应，请确认 IDEA 已启动并重启过。如果还没初始化，说'初始化开发环境'。"
2. 插件在线则执行 `scripts/start-modules.ps1 -Action start-all`
3. 脚本自动按顺序启动 **GatewayServerApplication → BaseServerApplication**，间隔 10 秒
4. 脚本自动输出模块分类表格，**不需要再执行 -Action table**
5. 问用户：**"核心模块已启动，还需要启动哪些？说中文名或模块名即可。"**

---

### 3. 指定模块名意图

当用户说出具体模块时，直接执行：

```
scripts/start-modules.ps1 -Action start -Name "用户说的名称"
```

脚本内置中文名→英文映射，支持：IOT平台、源清单、运维中心、大气管控、水环境管控、事件中心、非现场监管、专项管控、排查工具、通知中心、流程引擎、数智档案、数据转接入、通用服务、副通用服务、绩效分析、大屏、减污降碳、AI基础设施、数智答、应用监控中心等。

---

### 4. 查看 / 停止 / 健康检查

```
scripts/start-modules.ps1 -Action table          # 查看模块表
scripts/start-modules.ps1 -Action stop -Name "X" # 停止
scripts/start-modules.ps1 -Action health         # 健康检查
```

---

### 5. 更新模块

当用户说"更新模块"、"刷新模块列表"、"新增了模块"时：

```
scripts/update-modules.ps1 -ProjectPath "当前项目根目录"
```

完成后自动执行 `-Action table` 让用户确认。

---

### 6. 手动安装方式（可选）

如果用户不想通过对话初始化，可以手动运行分发包中的一键脚本。告诉用户：

> 打开 PowerShell，进入分发包 `dist/` 目录，执行：
> ```
> .\setup.ps1 -ProjectPath "你的项目路径"
> ```
> 该脚本会自动完成：Run Configurations 生成 → dynamic.classpath 配置 → Skill 安装 → IDEA 插件安装。完成后重启 IDEA 即可。

---

## 注意事项

- 中文名解析全在 PS1 脚本中，透传即可
- Gateway 和 Base 必须最先启动
- 本 skill 目录完全自包含，可拷贝到任意项目的 `.claude/skills/start-project/` 使用
