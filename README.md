# 神农地球村健康协议 (Shennong Health Protocol)

> **使命**：让每个人有价值地活着

神农地球村是一个全球健康保障共同体，通过消费即保障、神农舌象识体质、健康积分永不过期的方式，为每个人提供温暖的健康保障服务。

## 🌿 核心理念

### 宪法层·人间温度
1. **第0条：尊重人是基本原则** — 系统服务人，制度须善良有道德
2. **第0.1条：系统不会让任何人受委屈** — 每条规则过检验
3. **第0.2条：善意的分寸** — 帮人不居高临下，不让人亏欠
4. **第0.3条：你的身体你做主** — 系统帮你看见，不替你决定
5. **第0.4条：不过期的人生** — 积分不过期，保障不缩水，身份不丢失
6. **第0.5条：善良的闭环** — 看见→懂了→行动→积累→回报→传承
7. **第0.6条：制度的镜子** — 冷冰冰vs有温度的对比

### 十六字家训
> 认真吃饭，好好睡觉，对人善良，对己克制

### 品牌理念
- **品牌**：华未堂（治未病）
- **核心理念**：价值感是最好的药，财富是健康的外显，健康是价值的外显
- **家训**：有饭送给饥人，有话送给知人（姥爷）/ 醒来不是病，焦虑才是病（妈妈）

## 📂 项目结构

```
shennong-health-protocol/
├── README.md              # 项目总览
├── CHANGELOG.md           # 更新日志
├── DEPLOY.md              # 部署指南
├── LICENSE                # AGPL v3
├── website/               # 官网代码
│   └── index.html
├── miniprogram-wechat/    # 微信小程序（君兰健康）
│   ├── app.js/json/wxss
│   ├── pages/
│   │   ├── index/         # 首页
│   │   ├── guarantee/     # 保障页
│   │   ├── points/        # 积分页
│   │   ├── tongue/        # 舌象页
│   │   └── profile/       # 个人页
│   ├── services/          # 服务层
│   └── utils/             # 工具函数
├── miniprogram-douyin/    # 抖音小程序（華未堂健康生活）
│   └── ...
├── database/              # 数据库脚本
│   └── schema.sql
├── docs/                  # 文档
│   ├── 宪法层-人间温度.md
│   ├── 盈利规划.md
│   └── ...
└── .gitignore
```

## 🛠️ 技术栈

### 前端
- **网站**：HTML5, CSS3 (响应式设计), Vanilla JavaScript
- **微信小程序**：WXML, WXSS, JavaScript (ES6+)
- **抖音小程序**：TTML, TTSS, JavaScript

### 后端
- **数据库**：PostgreSQL (Supabase)
- **API**：RESTful API

### AI能力
- **舌诊**：基于AI的舌象分析，辨识九种体质

## 🚀 快速开始

### 网站部署
```bash
# 将 index.html 上传到 Web 服务器
scp website/index.html user@server:/var/www/
```

### 小程序开发
```bash
# 微信小程序
1. 下载微信开发者工具
2. 导入 miniprogram-wechat 目录
3. 配置 AppID
4. 开始开发

# 抖音小程序
1. 下载字节开发者工具
2. 导入 miniprogram-douyin 目录
3. 配置 AppID
4. 开始开发
```

### 数据库初始化
```bash
# 执行数据库脚本
psql -h <host> -U <user> -d <database> -f database/schema.sql
```

## 📜 开源协议

本项目采用 **AGPL v3 (GNU Affero General Public License v3)** 开源协议。

详细内容请参阅 [LICENSE](LICENSE) 文件。

## 🤝 贡献

我们欢迎所有形式的贡献！请参阅 [贡献指南](CONTRIBUTING.md)（如有）。

## 📞 联系方式

- **品牌**：华未堂
- **使命**：让每个人有价值地活着
- **网站**：https://sndqc.cn

---

*价值感是最好的药，认真吃饭、好好睡觉、对人善良、对己克制。*
