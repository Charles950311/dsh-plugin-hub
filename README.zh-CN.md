# dsh-plugin-hub(DSH 插件总控台)

**DeepSeek Harness(dsh)里所有插件与技能的统一入口。**

<p align="center"><img src="docs/demo.gif" alt="30 秒演示:安装、doctor 体检、路由表给出答案" width="880"></p>

DSH 内核刻意做得很薄——"Everything is a Plugin"。几周内社区就产出了对话回退、
长期记忆、技能卡片、失败经验库、Obsidian 桥、浏览器自动化、本地转写、安全扫描……
然后你会遇到真正的问题:

> 7 个插件散落在 profile bundles、技能目录和内置工具里。你记不清哪个干哪件事、
> 哪个现在真的可用、上周到底装过什么。

`dsh-plugin-hub` 就是缺的那个前门:

- **一张触发路由表**(`SKILL.md`)——Agent 回答"X 该用哪个工具"不再靠猜,查一张
  持续维护的表。
- **一条状态命令**(`status.ps1`)——profile 插件、工具文件、服务、技能 Junction
  一次体检。
- **一步安装**(`install.ps1`)——复制 hub 并 Junction 进 `%USERPROFILE%\.dsh\skills`,
  DSH 热加载;技能统一放一个目录,不再往 `.dsh` 里拷文件夹。
- **一份装机清单**(`PROVENANCE.md`)——装了什么、来自哪、什么许可证、怎么验证的。
  路由表只允许声称这份清单确认过的东西。
- **内置安全规则**——第三方技能默认不可信;装前扫描;不装绕过安全策略和
  账号池类插件。

## 两种用法

**1. 作为 dsh bundle(推荐)。** 本仓库现在就是可安装的 DeepSeek Harness bundle:
`package.json` 声明 `dsh.bundle`,`cordis.patch.yml` 注册插件。装完会话里多三个工具:

```powershell
dsh plugin --profile desktop add https://github.com/Charles950311/dsh-plugin-hub
```

| 工具 | 回答什么 |
| --- | --- |
| `hub_plugins` | 这个 profile 里装了什么、什么版本、每个 bundle 是否真的在磁盘上 |
| `hub_check` | 逐项 PASS/WARN/FAIL:profile 清单、第三方 bundle、技能目录、本地服务,每项带修复提示 |
| `hub_route` | "X 该用哪个插件",来自持续维护的路由表,并标明该插件是否已安装 |

三个工具全部**只读**:不安装、不卸载、不打补丁。平台内置包(`@deepseek-ai/*`)标为
`BUILTIN`——它们随 harness 一起发布,`node_modules` 里没有副本是正常的,不是故障。

npm 包名是 `dsh-control-hub`(npm 上 `dsh-plugin-hub` 已被占用),GitHub 仓库保留原名。

**2. 作为技能 + 命令行脚本。** 原方式照旧、不依赖 Node:`install.ps1` 复制 hub 技能并
Junction 到 `%USERPROFILE%\.dsh\skills`;`status.ps1` / `doctor.ps1` / `gen-provenance.ps1`
在 harness 之外直接跑。见下方快速开始。

## 快速开始(技能 + 脚本,Windows,PowerShell 5.1+)

```powershell
git clone https://github.com/<you>/dsh-plugin-hub.git
cd dsh-plugin-hub
powershell -ExecutionPolicy Bypass -File .\install.ps1
# 然后编辑 %USERPROFILE%\.dsh-hub\dsh-plugin-hub\config.ps1
```

重启 DSH(或刷新 Web UI),问一句:

```
装了哪些插件?长期记忆用哪个?
```

## 体检与诊断

`status.ps1` 给清单,`doctor.ps1` 给逐项判定与修复提示,`-Fix` 自动修安全项
(UTF-8 BOM、缺失的 Junction):

<p align="center"><img src="docs/doctor-demo.png" alt="doctor.ps1 输出:逐项 PASS/WARN 与修复提示" width="880"></p>

```
[PASS] config.ps1 present, UTF-8 BOM ok
[PASS] junction points here
[WARN] hindsight DOWN on port 8888
       memory tools will fake-fail; start the service, then re-check.
```

这条 WARN 就是重点:**插件加载成功 ≠ 服务在跑**,总控台会明说,而不是让调用假成功。

## 兼容性

| dsh 版本 | 状态 |
| --- | --- |
| 0.2.0-rc.2(Desktop) | 已实测——生产环境在用 |
| 0.2.1-rc.2(Desktop) | 已实测——含 turn-rewind 0.3.10 兼容修复 |

Windows 优先(Junction、PowerShell)。欢迎提交其他平台的 PR。

## 它不做什么

- 不是插件管理器(`dsh plugin add/remove` 仍然是正解)——它是插件之上的
  发现、调度与"保真"层。
- 不收集、不上传任何数据。所有路径来自本地 `config.ps1`(已 git-ignore)。

## Roadmap

- [x] 30 秒演示 GIF(`docs/demo.gif`,由 `docs/make-demo-gif.py` 从沙盒真实运行渲染;路径前缀展示为 `C:\Users\you`)
- [x] `doctor` 模式:逐项 PASS/WARN/FAIL 并给修复提示(`doctor.ps1`,`-Fix` 修安全项)
- [x] 清单生成器:从 `dsh plugin list` 自动起草 PROVENANCE(`gen-provenance.ps1`,`-Online` 用 npm 补全)
- [ ] 社区路由表预设(安全、媒体、办公工作流)

---

MIT 许可,按"现状"提供;安装任何第三方插件前请自行审查。
