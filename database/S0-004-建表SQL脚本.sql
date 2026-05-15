-- =====================================================
-- 神农地球村 S0-004：用户数据表建表脚本
-- 版本：v1.0
-- 日期：2025年12月
-- 目标：Supabase PostgreSQL
-- =====================================================

-- 【第一步】启用必要扩展
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 【第二步】创建基础表：users（被其他表引用，必须先创建）
-- =====================================================

-- 用户主表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    nickname VARCHAR(50) NOT NULL DEFAULT '神农村民',
    phone_encrypted VARCHAR(255),  -- AES-256-GCM加密
    phone_hash VARCHAR(64),         -- 用于登录验证的hash
    wechat_openid VARCHAR(64) UNIQUE,
    wechat_unionid VARCHAR(64),
    avatar_url VARCHAR(512),
    
    -- 注册信息
    register_time TIMESTAMPTZ DEFAULT NOW(),
    last_login_time TIMESTAMPTZ DEFAULT NOW(),
    login_source VARCHAR(20) DEFAULT 'wechat',  -- wechat/phone/email
    
    -- 舌诊相关
    constitution_type VARCHAR(50),  -- 体质类型：平和/气虚/阳虚/阴虚/痰湿/湿热/血瘀/气郁/特禀
    last_diagnosis_time TIMESTAMPTZ,
    
    -- 扩展字段（JSON灵活存储）
    profile JSONB DEFAULT '{}',
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active',  -- active/suspended/banned
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 用户表索引
CREATE INDEX idx_users_phone_hash ON users(phone_hash);
CREATE INDEX idx_users_wechat_openid ON users(wechat_openid);
CREATE INDEX idx_users_constitution ON users(constitution_type);
CREATE INDEX idx_users_register_time ON users(register_time DESC);

-- 自动更新 updated_at 触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 自动填充消费年份
CREATE OR REPLACE FUNCTION fill_consumption_year()
RETURNS TRIGGER AS $$
BEGIN
    NEW.year_of_consumption = EXTRACT(YEAR FROM NEW.consumption_time)::INTEGER;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- consumption_year_fill 触发器移到 consumption_records 建表之后

-- =====================================================
-- 【第三步】创建字典/配置表
-- =====================================================

-- 体质类型字典
CREATE TABLE constitution_types (
    code VARCHAR(30) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    characteristics JSONB,
    dietary_suggestions JSONB,
    lifestyle_suggestions JSONB
);

-- 初始化九种体质
INSERT INTO constitution_types (code, name, description) VALUES
    ('peaceful', '平和质', '健康体质'),
    ('qi_deficiency', '气虚质', '气虚'),
    ('yang_deficiency', '阳虚质', '阳虚'),
    ('yin_deficiency', '阴虚质', '阴虚'),
    ('phlegm_dampness', '痰湿质', '痰湿'),
    ('damp_heat', '湿热质', '湿热'),
    ('blood_stasis', '血瘀质', '血瘀'),
    ('qi_depression', '气郁质', '气郁'),
    ('special_constitution', '特禀质', '特禀');

-- 贡献类型积分规则表
CREATE TABLE contribution_point_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contribution_type VARCHAR(30) NOT NULL,
    base_points INTEGER NOT NULL DEFAULT 5,
    daily_limit INTEGER,               -- 每日上限
    monthly_limit INTEGER,              -- 每月上限
    requires_proof BOOLEAN DEFAULT FALSE,
    description VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 初始化默认规则
INSERT INTO contribution_point_rules (contribution_type, base_points, daily_limit, monthly_limit, description) VALUES
    ('promotion', 10, 30, 100, '分享宣传，每次分享'),
    ('speech', 15, 3, 30, '健康宣讲，每次宣讲'),
    ('help', 5, 10, 50, '邻里互助，每次帮助'),
    ('feedback', 3, 5, 30, '问题反馈，有效反馈'),
    ('knowledge_share', 8, 5, 40, '知识分享，每次分享');

-- 信用分计算规则表
CREATE TABLE credit_change_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reason_code VARCHAR(50) NOT NULL UNIQUE,
    change_value INTEGER NOT NULL,
    change_type VARCHAR(20) NOT NULL,  -- increase/decrease/set
    max_daily_changes INTEGER,
    max_monthly_changes INTEGER,
    description VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 初始化默认规则
INSERT INTO credit_change_rules (reason_code, change_value, change_type, description) VALUES
    ('complete_profile', 10, 'increase', '完善个人资料'),
    ('daily_checkin', 2, 'increase', '每日签到'),
    ('share_content', 5, 'increase', '分享内容'),
    ('helpful_feedback', 10, 'increase', '有效反馈被采纳'),
    ('bad_review', -20, 'decrease', '差评'),
    ('fake_report', -50, 'decrease', '虚假举报'),
    ('violation', -100, 'decrease', '违规行为'),
    ('fake_contribution', -30, 'decrease', '虚假贡献记录');

-- =====================================================
-- 【第四步】创建业务表
-- =====================================================

-- 舌诊记录表
CREATE TABLE tongue_diagnosis_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 图片存储
    tongue_image_url VARCHAR(512) NOT NULL,
    tongue_image_path VARCHAR(512),  -- 本地存储路径
    
    -- 舌象特征
    tongue_color VARCHAR(30),         -- 舌色：淡红/淡白/红/绛/紫/青
    coating_color VARCHAR(30),        -- 苔色：薄白/白/黄/灰/黑/少苔/剥苔
    coating_thickness VARCHAR(20),    -- 苔厚薄：薄/中/厚
    tooth_mark BOOLEAN DEFAULT FALSE,  -- 齿痕
    crack VARCHAR(20),                 -- 裂纹：无/浅/深/网状
    sublingual_vein VARCHAR(20),       -- 舌下络脉：正常/迂曲/怒张
    
    -- AI诊断结果
    constitution_type VARCHAR(50),    -- 判定体质
    constitution_confidence DECIMAL(5,4),  -- 置信度 0.0000-1.0000
    diagnosis_summary TEXT,           -- 诊断建议摘要
    advice_detail JSONB,              -- 详细建议 {diet:[], lifestyle:[], herbs:[]}
    
    -- 舌诊对比（关联上一次记录）
    compare_with_record_id UUID REFERENCES tongue_diagnosis_records(id),
    change_summary TEXT,              -- 变化摘要
    
    -- 元数据
    diagnosis_time TIMESTAMPTZ DEFAULT NOW(),
    diagnosis_source VARCHAR(20) DEFAULT 'ai',  -- ai/manual
    device_info JSONB,                -- {platform, version, model}
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 舌诊记录表索引
CREATE INDEX idx_tongue_user ON tongue_diagnosis_records(user_id);
CREATE INDEX idx_tongue_diagnosis_time ON tongue_diagnosis_records(diagnosis_time DESC);
CREATE INDEX idx_tongue_constitution ON tongue_diagnosis_records(constitution_type);

-- 消费记录表
CREATE TABLE consumption_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 消费信息
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(10) DEFAULT 'CNY',
    consumption_type VARCHAR(30) NOT NULL,  -- product/service/subscription
    
    -- 消费详情
    category VARCHAR(50),              -- 农产品/健康服务/知识付费/...
    product_name VARCHAR(100),
    product_id VARCHAR(64),
    
    -- 订单关联
    order_id VARCHAR(64) UNIQUE,
    payment_method VARCHAR(20),        -- wechat_pay/alipay/card
    
    -- 时间
    consumption_time TIMESTAMPTZ DEFAULT NOW(),
    
    -- 保障计算用（由触发器自动填充）
    year_of_consumption INTEGER,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 消费记录表索引
CREATE INDEX idx_consumption_user ON consumption_records(user_id);
CREATE INDEX idx_consumption_time ON consumption_records(consumption_time DESC);
CREATE INDEX idx_consumption_order ON consumption_records(order_id);
CREATE INDEX idx_consumption_year ON consumption_records(user_id, year_of_consumption);

-- 消费年份自动填充触发器（在建表之后创建）
CREATE TRIGGER consumption_year_fill
    BEFORE INSERT OR UPDATE ON consumption_records
    FOR EACH ROW
    EXECUTE FUNCTION fill_consumption_year();

-- 累计消费年数计算函数
CREATE OR REPLACE FUNCTION calculate_consumption_years(p_user_id UUID)
RETURNS INTEGER AS $$
    SELECT COUNT(DISTINCT EXTRACT(YEAR FROM consumption_time))
    FROM consumption_records
    WHERE user_id = p_user_id;
$$ LANGUAGE sql STABLE;

-- 贡献记录表
CREATE TABLE contribution_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 贡献类型
    contribution_type VARCHAR(30) NOT NULL,  -- promotion/speech/help/feedback/knowledge_share
    contribution_type_desc VARCHAR(50),       -- 详细描述
    
    -- 贡献内容
    content_summary VARCHAR(200) NOT NULL,
    content_detail TEXT,
    evidence_urls JSONB DEFAULT '[]',        -- 证明材料
    
    -- 贡献分值
    points_awarded INTEGER NOT NULL DEFAULT 0,
    
    -- 审核状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/approved/rejected
    reviewer_id UUID REFERENCES users(id),
    review_time TIMESTAMPTZ,
    review_comment TEXT,
    
    -- 时间
    contribution_time TIMESTAMPTZ DEFAULT NOW(),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 贡献记录表索引
CREATE INDEX idx_contribution_user ON contribution_records(user_id);
CREATE INDEX idx_contribution_type ON contribution_records(contribution_type);
CREATE INDEX idx_contribution_time ON contribution_records(contribution_time DESC);
CREATE INDEX idx_contribution_status ON contribution_records(status);

-- 保障状态表
CREATE TABLE guarantee_status (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- 保障比例计算
    guarantee_ratio DECIMAL(5,2) DEFAULT 0,  -- 0.00 - 100.00
    consumption_years INTEGER DEFAULT 0,    -- 累计消费年数
    
    -- 保障状态
    status VARCHAR(20) DEFAULT 'inactive',  -- active/grace_period/stopped/inactive
    status_since TIMESTAMPTZ,               -- 状态开始时间
    grace_period_level INTEGER DEFAULT 0,   -- 宽限期梯度 0/1/2/3
    
    -- 贡献追踪
    last_contribution_time TIMESTAMPTZ,
    contribution_count_30d INTEGER DEFAULT 0,  -- 30天内贡献次数
    
    -- 权益信息
    active_benefits JSONB DEFAULT '[]',     -- 当前生效的权益列表
    accumulated_points INTEGER DEFAULT 0,  -- 累计积分
    
    -- 重新激活
    reactivatable BOOLEAN DEFAULT TRUE,
    deactivation_reason TEXT,
    
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 保障比例计算函数
-- 规则：消费满5年起步10%，每年+10%，15年封顶100%
CREATE OR REPLACE FUNCTION calculate_guarantee_ratio(p_years INTEGER)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    ratio DECIMAL(5,2);
BEGIN
    IF p_years < 5 THEN
        ratio := 0;
    ELSIF p_years >= 15 THEN
        ratio := 100;
    ELSE
        ratio := 10 + (p_years - 5) * 10;
    END IF;
    RETURN ratio;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 保障状态更新触发器
CREATE OR REPLACE FUNCTION update_guarantee_status()
RETURNS TRIGGER AS $$
DECLARE
    v_grace_days INTEGER;
    v_days_since_contribution INTEGER;
BEGIN
    -- 计算距上次贡献天数
    IF NEW.last_contribution_time IS NOT NULL THEN
        v_days_since_contribution := EXTRACT(DAYS FROM NOW() - NEW.last_contribution_time);
    ELSE
        v_days_since_contribution := 999;
    END IF;
    
    -- 梯度宽限期判断
    IF v_days_since_contribution > 90 THEN
        -- 超过90天宽限期，保障停止
        NEW.status := 'stopped';
        NEW.guarantee_ratio := 0;
    ELSIF v_days_since_contribution > 60 THEN
        NEW.status := 'grace_period';
        NEW.guarantee_period_level := 3;
    ELSIF v_days_since_contribution > 30 THEN
        NEW.status := 'grace_period';
        NEW.grace_period_level := 2;
    ELSIF v_days_since_contribution > 0 THEN
        NEW.status := 'grace_period';
        NEW.grace_period_level := 1;
    ELSE
        NEW.status := 'active';
        NEW.guarantee_ratio := calculate_guarantee_ratio(NEW.consumption_years);
    END IF;
    
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER guarantee_status_update
    BEFORE UPDATE ON guarantee_status
    FOR EACH ROW
    EXECUTE FUNCTION update_guarantee_status();

-- 信用分记录表
CREATE TABLE credit_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 变动信息
    change_type VARCHAR(30) NOT NULL,  -- increase/decrease/set
    change_value INTEGER NOT NULL,     -- 变动分值，正负数
    balance_after INTEGER NOT NULL,     -- 变动后余额
    
    -- 变动原因
    reason_code VARCHAR(50) NOT NULL,  -- good_review/bad_review/contribution/...
    reason_detail VARCHAR(200),
    related_record_id UUID,            -- 关联记录ID（舌诊/贡献/投诉等）
    
    -- 审计
    operator_id UUID,                  -- 操作者，NULL表示系统自动
    operator_type VARCHAR(20),         -- system/user/admin
    
    change_time TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 信用分记录表索引
CREATE INDEX idx_credit_user ON credit_records(user_id);
CREATE INDEX idx_credit_time ON credit_records(change_time DESC);
CREATE INDEX idx_credit_reason ON credit_records(reason_code);

-- 信用分基数表
CREATE TABLE user_credit_scores (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_score INTEGER DEFAULT 100 CHECK (current_score >= 0 AND current_score <= 1000),
    level VARCHAR(20) DEFAULT 'C',     -- AAA/AA/A/BBB/BB/B/C/D
    last_change_time TIMESTAMPTZ,
    total_increases INTEGER DEFAULT 0,
    total_decreases INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 信用分等级更新函数
CREATE OR REPLACE FUNCTION update_credit_level(p_score INTEGER)
RETURNS VARCHAR(20) AS $$
BEGIN
    RETURN CASE
        WHEN p_score >= 900 THEN 'AAA'
        WHEN p_score >= 750 THEN 'AA'
        WHEN p_score >= 600 THEN 'A'
        WHEN p_score >= 450 THEN 'BBB'
        WHEN p_score >= 300 THEN 'BB'
        WHEN p_score >= 150 THEN 'B'
        WHEN p_score >= 50 THEN 'C'
        ELSE 'D'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- 【第五步】创建辅助表
-- =====================================================

-- 操作日志表
CREATE TABLE operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    operation_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    operation_details JSONB,
    ip_address INET,
    user_agent TEXT,
    operation_time TIMESTAMPTZ DEFAULT NOW()
);

-- 操作日志表索引
CREATE INDEX idx_oplog_user ON operation_logs(user_id);
CREATE INDEX idx_oplog_time ON operation_logs(operation_time DESC);
CREATE INDEX idx_oplog_type ON operation_logs(operation_type);

-- =====================================================
-- 【第六步】手机号加密函数
-- =====================================================

-- 加密函数（AES-256-GCM）
CREATE OR REPLACE FUNCTION encrypt_phone(phone_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        pgcrypto.gen_salt('bf'),
        'hex'
    ) || ':' || encode(
        pgcrypto.encrypt_aes256(
            encrypt_iv(phone_text::bytea, 
                       current_setting('app.crypto_key')::bytea,
                       gen_random_bytes(16)),
            current_setting('app.crypto_key')::bytea
        ),
        'hex'
    );
END;
$$ LANGUAGE plpgsql;

-- 查询时脱敏函数
CREATE OR REPLACE FUNCTION mask_phone(phone_encrypted TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN '***' || substring(phone_encrypted, length(phone_encrypted)-3, 4);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 【第七步】启用 RLS 行级安全策略
-- =====================================================

-- 启用 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tongue_diagnosis_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE contribution_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE guarantee_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_credit_scores ENABLE ROW LEVEL SECURITY;

-- users 表策略：用户只能查看和修改自己的数据
CREATE POLICY users_select_own ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY users_update_own ON users
    FOR UPDATE USING (auth.uid() = id);

-- tongue_diagnosis_records 表策略
CREATE POLICY tongue_select_own ON tongue_diagnosis_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY tongue_insert_own ON tongue_diagnosis_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY tongue_update_own ON tongue_diagnosis_records
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY tongue_delete_own ON tongue_diagnosis_records
    FOR DELETE USING (auth.uid() = user_id);

-- credit_records 表策略：只能本人查看
CREATE POLICY credit_select_own ON credit_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY credit_insert_own ON credit_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- consumption_records 表策略
CREATE POLICY consumption_select_own ON consumption_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY consumption_insert_own ON consumption_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- contribution_records 表策略
CREATE POLICY contribution_select_own ON contribution_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY contribution_insert_own ON contribution_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- guarantee_status 表策略
CREATE POLICY guarantee_select_own ON guarantee_status
    FOR SELECT USING (auth.uid() = user_id);

-- user_credit_scores 表策略
CREATE POLICY user_credit_select_own ON user_credit_scores
    FOR SELECT USING (auth.uid() = user_id);

-- =====================================================
-- 【第八步】验证脚本（可选执行）
-- =====================================================

-- 查看所有表
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- 查看所有函数
-- SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace;

-- 查看所有触发器
-- SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema = 'public';

-- =====================================================
-- 执行完成！
-- =====================================================
