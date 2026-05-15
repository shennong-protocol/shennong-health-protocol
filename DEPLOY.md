# 部署指南

## 网站部署

### 腾讯云部署
```bash
# 1. 上传 index.html
sshpass -p '密码' scp -o StrictHostKeyChecking=no website/index.html ubuntu@服务器IP:/tmp/index.html

# 2. 移动到网站目录
sshpass -p '密码' ssh -o StrictHostKeyChecking=no ubuntu@服务器IP \
  'sudo cp /tmp/index.html /var/www/sndqc.cn/index.html && \
   sudo chown www-data:www-data /var/www/sndqc.cn/index.html'
```

### 环境要求
- Web 服务器 (Nginx/Apache)
- HTTPS 支持（可选但推荐）

## 微信小程序部署

1. 在微信公众平台注册小程序账号
2. 下载微信开发者工具
3. 导入 `miniprogram-wechat` 目录
4. 配置 AppID 和服务器域名
5. 上传代码并提交审核

## 抖音小程序部署

1. 在抖音开放平台注册应用
2. 下载字节开发者工具
3. 导入 `miniprogram-douyin` 目录
4. 配置 AppID 和服务器域名
5. 上传代码并提交审核

## 数据库部署

### Supabase
1. 创建 Supabase 项目
2. 执行 `database/schema.sql` 中的建表语句
3. 配置 RLS 策略
4. 获取 API Keys 并配置到小程序

### 环境变量
```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```
