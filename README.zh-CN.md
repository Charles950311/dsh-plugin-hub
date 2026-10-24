# dsh-plugin-hub(DSH 插件总控台)

**DeepSeek Harness(dsh)里所有插件与技能的统一入口。**

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

## 快速开始(Windows,PowerShell 5.1+)

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

- [ ] 30 秒演示 GIF
- [ ] `doctor` 模式:对常见故障给出修复建议
- [ ] 社区路由表预设(安全、媒体、办公工作流)
- [ ] 清单生成器:从 `dsh plugin list` 自动起草 PROVENANCE

---

MIT 许可,按"现状"提供;安装任何第三方插件前请自行审查。
