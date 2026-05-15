-- =====================================================
-- 神农地球村 S0-005：积分数据表增量脚本
-- 版本：v1.0
-- 日期：2025年12月
-- 目标：Supabase PostgreSQL
-- 说明：在S0-004基础上新增积分相关表、触发器、视图
-- =====================================================

-- =====================================================
-- 【第一步】创建积分规则配置表（可动态配置）
-- =====================================================

-- 积分规则配置表
CREATE TABLE IF NOT EXISTS point_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 规则类型
    rule_type VARCHAR(30) NOT NULL,  -- consumption/contribution/activity/redemption
    action_code VARCHAR(50) NOT NULL UNIQUE,  -- 唯一操作代码
    
    -- 规则内容
    points_value INTEGER NOT NULL,    -- 积分数值（正数为获得，负数为消耗）
    points_type VARCHAR(20) DEFAULT 'earning',  -- earning/consume/locked
    
    -- 限制配置
    daily_limit INTEGER,              -- 每日上限
    monthly_limit INTEGER,            -- 每月上限
    total_limit INTEGER,              -- 终身上限
    
    -- 规则描述
    description VARCHAR(200),
    description_zh VARCHAR(200),      -- 中文描述
    
    -- 状态与有效期
    is_active BOOLEAN DEFAULT TRUE,
    start_date DATE,                  -- 生效日期
    end_date DATE,                    -- 失效日期
    
    -- 合规标记
    compliance_tags JSONB DEFAULT '[]',  -- ['no_cash_out', 'no_fission']
    
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id)
);

-- 积分规则表索引
CREATE INDEX IF NOT EXISTS idx_point_rules_type ON point_rules(rule_type);
CREATE INDEX IF NOT EXISTS idx_point_rules_action ON point_rules(action_code);
CREATE INDEX IF NOT EXISTS idx_point_rules_active ON point_rules(is_active);

-- 自动更新 updated_at
CREATE OR REPLACE FUNCTION update_point_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER point_rules_updated_at
    BEFORE UPDATE ON point_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_point_rules_updated_at();

-- 初始化默认积分规则
INSERT INTO point_rules (rule_type, action_code, points_value, points_type, daily_limit, monthly_limit, description, description_zh, compliance_tags) VALUES
    -- 消费积分规则
    ('consumption', 'consume_purchase', 1, 'earning', NULL, NULL, '每消费1元获得1积分', '消费积分', '["no_cash_out"]'),
    
    -- 贡献积分规则（从contribution_point_rules同步，但作为独立积分规则）
    ('contribution', 'promotion', 10, 'earning', 30, 100, '分享宣传，每次10分', '宣传积分', '["no_cash_out", "no_fission"]'),
    ('contribution', 'speech', 15, 'earning', 3, 30, '健康宣讲，每次15分', '宣讲积分', '["no_cash_out", "no_fission"]'),
    ('contribution', 'help', 5, 'earning', 10, 50, '邻里互助，每次5分', '互助积分', '["no_cash_out", "no_fission"]'),
    ('contribution', 'feedback', 3, 'earning', 5, 30, '问题反馈，每次3分', '反馈积分', '["no_cash_out", "no_fission"]'),
    ('contribution', 'knowledge_share', 8, 'earning', 5, 40, '知识分享，每次8分', '知识分享积分', '["no_cash_out", "no_fission"]'),
    
    -- 活跃积分规则
    ('activity', 'daily_checkin', 2, 'earning', 1, NULL, '每日签到，2分', '签到积分', '["no_cash_out"]'),
    ('activity', 'complete_profile', 10, 'earning', 1, NULL, '完善个人资料，10分（仅一次）', '完善资料积分', '["no_cash_out"]'),
    
    -- 积分兑换规则（占位，具体兑换比例由兑换记录定义）
    ('redemption', 'redeem_service', -1, 'consume', NULL, NULL, '兑换健康服务', '服务兑换', '["no_cash_out"]'),
    ('redemption', 'redeem_product', -1, 'consume', NULL, NULL, '兑换产品', '产品兑换', '["no_cash_out"]')
ON CONFLICT (action_code) DO NOTHING;

-- =====================================================
-- 【第二步】创建积分账户表
-- =====================================================

-- 积分账户表（每个用户一个积分账户）
CREATE TABLE IF NOT EXISTS point_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- 积分余额（核心）
    current_balance INTEGER NOT NULL DEFAULT 0 CHECK (current_balance >= 0),  -- 不可为负
    
    -- 累计统计
    total_earned INTEGER NOT NULL DEFAULT 0,     -- 累计获得
    total_consumed INTEGER NOT NULL DEFAULT 0,   -- 累计消耗
    total_expired INTEGER NOT NULL DEFAULT 0,    -- 累计过期（目前不使用，永不过期）
    
    -- 冻结积分（提现冻结等，合规场景）
    frozen_balance INTEGER NOT NULL DEFAULT 0,    -- 冻结积分
    
    -- 分类统计
    consumption_points INTEGER NOT NULL DEFAULT 0,  -- 消费积分余额
    contribution_points INTEGER NOT NULL DEFAULT 0, -- 贡献积分余额
    activity_points INTEGER NOT NULL DEFAULT 0,     -- 活跃积分余额
    
    -- 统计日期
    last_earned_at TIMESTAMPTZ,          -- 最后获得时间
    last_consumed_at TIMESTAMPTZ,        -- 最后消耗时间
    last_activity_at TIMESTAMPTZ,        -- 最后活跃时间
    
    -- 有效期配置（目前永不过期）
    expiry_days INTEGER DEFAULT 0,       -- 0表示永不过期
    
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 积分账户表索引
CREATE INDEX IF NOT EXISTS idx_point_accounts_user ON point_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_point_accounts_balance ON point_accounts(current_balance DESC);

-- 自动更新 updated_at
CREATE OR REPLACE FUNCTION update_point_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER point_accounts_updated_at
    BEFORE UPDATE ON point_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_point_accounts_updated_at();

-- 创建用户时自动创建积分账户
CREATE OR REPLACE FUNCTION create_point_account_for_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO point_accounts (user_id, current_balance, total_earned, total_consumed)
    VALUES (NEW.id, 0, 0, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_user_create_point_account
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_point_account_for_user();

-- =====================================================
-- 【第三步】创建积分流水表
-- =====================================================

-- 积分流水表（每笔积分变动的详细记录）
CREATE TABLE IF NOT EXISTS point_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 用户
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 变动信息
    change_type VARCHAR(20) NOT NULL,   -- earn/consume/lock/unlock/adjust
    points_amount INTEGER NOT NULL,     -- 变动积分数（正数）
    points_balance_before INTEGER NOT NULL,  -- 变动前余额
    points_balance_after INTEGER NOT NULL,   -- 变动后余额
    
    -- 积分类型
    points_category VARCHAR(30) NOT NULL,  -- consumption/contribution/activity
    
    -- 规则关联
    rule_id UUID REFERENCES point_rules(id),
    action_code VARCHAR(50),            -- 操作代码
    
    -- 来源信息
    source_type VARCHAR(30),            -- consumption/contribution/activity/redemption/manual
    source_id UUID,                     -- 关联业务ID（消费记录ID/贡献记录ID等）
    
    -- 描述
    description VARCHAR(200),            -- 变动描述
    description_zh VARCHAR(200),       -- 中文描述
    
    -- 合规标记
    compliance_verified BOOLEAN DEFAULT TRUE,  -- 合规验证通过
    
    -- 审计
    operator_id UUID,                    -- 操作者，NULL表示系统
    operator_type VARCHAR(20) DEFAULT 'system',  -- system/user/admin
    transaction_time TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 积分流水表索引
CREATE INDEX IF NOT EXISTS idx_point_txn_user ON point_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_txn_time ON point_transactions(transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_point_txn_type ON point_transactions(change_type);
CREATE INDEX IF NOT EXISTS idx_point_txn_category ON point_transactions(points_category);
CREATE INDEX IF NOT EXISTS idx_point_txn_source ON point_transactions(source_type, source_id);

-- =====================================================
-- 【第四步】创建积分兑换记录表
-- =====================================================

-- 积分兑换记录表
CREATE TABLE IF NOT EXISTS point_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 用户
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 兑换类型
    redemption_type VARCHAR(30) NOT NULL,  -- service/product/voucher
    category VARCHAR(50),                   -- 兑换分类：health_service/food/supplement等
    
    -- 兑换物品信息
    item_id VARCHAR(64),                   -- 物品ID
    item_name VARCHAR(100) NOT NULL,       -- 物品名称
    item_description TEXT,                 -- 物品描述
    item_image_url VARCHAR(512),            -- 物品图片
    
    -- 积分消耗
    points_cost INTEGER NOT NULL CHECK (points_cost > 0),  -- 消耗积分
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending',  -- pending/approved/completed/cancelled/rejected
    approval_comment TEXT,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    
    -- 履约信息
    fulfillment_type VARCHAR(20),          -- immediate/scheduled/pickup/delivery
    delivery_address TEXT,
    delivery_status VARCHAR(20),          -- not_applicable/pending/shipped/delivered
    tracking_number VARCHAR(100),
    
    -- 关联积分流水
    point_transaction_id UUID REFERENCES point_transactions(id),
    
    -- 审计
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 积分兑换记录表索引
CREATE INDEX IF NOT EXISTS idx_point_redeem_user ON point_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_redeem_status ON point_redemptions(status);
CREATE INDEX IF NOT EXISTS idx_point_redeem_type ON point_redemptions(redemption_type);
CREATE INDEX IF NOT EXISTS idx_point_redeem_time ON point_redemptions(requested_at DESC);

-- =====================================================
-- 【第五步】创建商品/服务兑换配置表
-- =====================================================

-- 可兑换物品配置表
CREATE TABLE IF NOT EXISTS redeemable_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 物品类型
    item_type VARCHAR(30) NOT NULL,        -- service/product/voucher
    category VARCHAR(50) NOT NULL,         -- health_service/food/supplement/consultation
    
    -- 物品信息
    name VARCHAR(100) NOT NULL,             -- 物品名称
    description TEXT,                      -- 物品描述
    image_url VARCHAR(512),                -- 物品图片
    
    -- 积分配置
    points_required INTEGER NOT NULL,      -- 所需积分
    stock_quantity INTEGER,                -- 库存，NULL表示无限
    max_per_user INTEGER DEFAULT 1,        -- 每个用户最大兑换次数
    
    -- 有效期
    validity_days INTEGER DEFAULT 365,     -- 兑换后有效期（天）
    
    -- 状态
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,     -- 是否推荐展示
    
    -- 排序与分组
    display_order INTEGER DEFAULT 0,
    tags JSONB DEFAULT '[]',               -- 标签：["热门","新品"]
    
    -- 审计
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 可兑换物品表索引
CREATE INDEX IF NOT EXISTS idx_redeemable_type ON redeemable_items(item_type);
CREATE INDEX IF NOT EXISTS idx_redeemable_category ON redeemable_items(category);
CREATE INDEX IF NOT EXISTS idx_redeemable_active ON redeemable_items(is_active);
CREATE INDEX IF NOT EXISTS idx_redeemable_points ON redeemable_items(points_required);

-- 自动更新 updated_at
CREATE OR REPLACE FUNCTION update_redeemable_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER redeemable_items_updated_at
    BEFORE UPDATE ON redeemable_items
    FOR EACH ROW
    EXECUTE FUNCTION update_redeemable_items_updated_at();

-- =====================================================
-- 【第六步】创建辅助函数
-- =====================================================

-- 检查积分规则是否有效的函数
CREATE OR REPLACE FUNCTION check_point_rule_active(p_action_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_rule point_rules%ROWTYPE;
    v_today DATE := CURRENT_DATE;
BEGIN
    SELECT * INTO v_rule
    FROM point_rules
    WHERE action_code = p_action_code
      AND is_active = TRUE
      AND (start_date IS NULL OR start_date <= v_today)
      AND (end_date IS NULL OR end_date >= v_today);
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql STABLE;

-- 检查每日上限函数
CREATE OR REPLACE FUNCTION check_daily_limit(p_user_id UUID, p_action_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_daily_limit INTEGER;
    v_today_count INTEGER;
BEGIN
    -- 获取规则配置的每日上限
    SELECT daily_limit INTO v_daily_limit
    FROM point_rules
    WHERE action_code = p_action_code;
    
    -- 如果没有上限，直接返回TRUE
    IF v_daily_limit IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- 统计今日已使用次数
    SELECT COALESCE(SUM(ABS(points_amount)), 0)::INTEGER INTO v_today_count
    FROM point_transactions
    WHERE user_id = p_user_id
      AND action_code = p_action_code
      AND change_type = 'earn'
      AND transaction_time >= (CURRENT_DATE || ' 00:00:00')::TIMESTAMPTZ
      AND transaction_time < (CURRENT_DATE + 1 || ' 00:00:00')::TIMESTAMPTZ;
    
    RETURN v_today_count < v_daily_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- 检查每月上限函数
CREATE OR REPLACE FUNCTION check_monthly_limit(p_user_id UUID, p_action_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_monthly_limit INTEGER;
    v_month_count INTEGER;
BEGIN
    -- 获取规则配置的每月上限
    SELECT monthly_limit INTO v_monthly_limit
    FROM point_rules
    WHERE action_code = p_action_code;
    
    -- 如果没有上限，直接返回TRUE
    IF v_monthly_limit IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- 统计本月已使用次数
    SELECT COALESCE(SUM(ABS(points_amount)), 0)::INTEGER INTO v_month_count
    FROM point_transactions
    WHERE user_id = p_user_id
      AND action_code = p_action_code
      AND change_type = 'earn'
      AND transaction_time >= (DATE_TRUNC('month', CURRENT_DATE))::TIMESTAMPTZ
      AND transaction_time < (DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month'))::TIMESTAMPTZ;
    
    RETURN v_month_count < v_monthly_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- 添加积分的核心函数
CREATE OR REPLACE FUNCTION add_points(
    p_user_id UUID,
    p_action_code VARCHAR,
    p_source_type VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description VARCHAR DEFAULT NULL,
    p_description_zh VARCHAR DEFAULT NULL,
    p_override_limit BOOLEAN DEFAULT FALSE  -- 是否绕过限制（管理员操作）
)
RETURNS TABLE(success BOOLEAN, points_added INTEGER, message TEXT) AS $$
DECLARE
    v_rule point_rules%ROWTYPE;
    v_points INTEGER;
    v_balance_before INTEGER;
    v_balance_after INTEGER;
    v_account point_accounts%ROWTYPE;
BEGIN
    -- 检查规则是否存在且有效
    IF NOT check_point_rule_active(p_action_code) THEN
        RETURN QUERY SELECT FALSE, 0, '积分规则不存在或已失效';
        RETURN;
    END IF;
    
    -- 获取规则
    SELECT * INTO v_rule FROM point_rules WHERE action_code = p_action_code;
    
    -- 检查限制（非管理员操作时）
    IF NOT p_override_limit THEN
        IF NOT check_daily_limit(p_user_id, p_action_code) THEN
            RETURN QUERY SELECT FALSE, 0, '已达每日上限';
            RETURN;
        END IF;
        
        IF NOT check_monthly_limit(p_user_id, p_action_code) THEN
            RETURN QUERY SELECT FALSE, 0, '已达每月上限';
            RETURN;
        END IF;
    END IF;
    
    -- 获取当前余额
    SELECT * INTO v_account FROM point_accounts WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0, '积分账户不存在';
        RETURN;
    END IF;
    
    v_points := v_rule.points_value;
    v_balance_before := v_account.current_balance;
    v_balance_after := v_balance_before + v_points;
    
    -- 更新积分账户
    UPDATE point_accounts SET
        current_balance = v_balance_after,
        total_earned = total_earned + v_points,
        last_earned_at = NOW(),
        last_activity_at = NOW(),
        consumption_points = CASE 
            WHEN v_rule.rule_type = 'consumption' THEN consumption_points + v_points 
            ELSE consumption_points 
        END,
        contribution_points = CASE 
            WHEN v_rule.rule_type = 'contribution' THEN contribution_points + v_points 
            ELSE contribution_points 
        END,
        activity_points = CASE 
            WHEN v_rule.rule_type = 'activity' THEN activity_points + v_points 
            ELSE activity_points 
        END
    WHERE user_id = p_user_id;
    
    -- 插入积分流水
    INSERT INTO point_transactions (
        user_id, change_type, points_amount, points_balance_before, points_balance_after,
        points_category, rule_id, action_code, source_type, source_id,
        description, description_zh, operator_type
    ) VALUES (
        p_user_id, 'earn', v_points, v_balance_before, v_balance_after,
        v_rule.rule_type, v_rule.id, p_action_code, p_source_type, p_source_id,
        COALESCE(p_description, v_rule.description),
        COALESCE(p_description_zh, v_rule.description_zh),
        CASE WHEN p_override_limit THEN 'admin' ELSE 'system' END
    );
    
    -- 同步更新guarantee_status中的accumulated_points
    UPDATE guarantee_status SET
        accumulated_points = accumulated_points + v_points
    WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT TRUE, v_points, '积分添加成功';
END;
$$ LANGUAGE plpgsql;

-- 消费积分的核心函数
CREATE OR REPLACE FUNCTION consume_points(
    p_user_id UUID,
    p_points INTEGER,
    p_source_type VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description VARCHAR DEFAULT NULL,
    p_description_zh VARCHAR DEFAULT NULL,
    p_points_category VARCHAR DEFAULT 'consumption'  -- 消耗哪类积分
)
RETURNS TABLE(success BOOLEAN, message TEXT, points_remaining INTEGER) AS $$
DECLARE
    v_balance_before INTEGER;
    v_balance_after INTEGER;
    v_available INTEGER;
    v_txn_id UUID;
BEGIN
    -- 获取当前可用余额
    SELECT current_balance INTO v_available
    FROM point_accounts
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, '积分账户不存在', 0;
        RETURN;
    END IF;
    
    -- 检查余额是否足够
    IF v_available < p_points THEN
        RETURN QUERY SELECT FALSE, '积分不足', v_available;
        RETURN;
    END IF;
    
    v_balance_before := v_available;
    v_balance_after := v_available - p_points;
    
    -- 扣除积分
    UPDATE point_accounts SET
        current_balance = v_balance_after,
        total_consumed = total_consumed + p_points,
        last_consumed_at = NOW(),
        last_activity_at = NOW()
    WHERE user_id = p_user_id;
    
    -- 插入积分流水
    INSERT INTO point_transactions (
        user_id, change_type, points_amount, points_balance_before, points_balance_after,
        points_category, source_type, source_id,
        description, description_zh, operator_type
    ) VALUES (
        p_user_id, 'consume', p_points, v_balance_before, v_balance_after,
        p_points_category, p_source_type, p_source_id,
        COALESCE(p_description, '积分兑换'),
        COALESCE(p_description_zh, '积分兑换'),
        'user'
    ) RETURNING id INTO v_txn_id;
    
    RETURN QUERY SELECT TRUE, '积分消费成功', v_balance_after;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 【第七步】创建触发器（自动积分计算）
-- =====================================================

-- 触发器1：消费记录审核通过后自动添加积分
CREATE OR REPLACE FUNCTION trigger_add_points_on_consumption()
RETURNS TRIGGER AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- 只在插入新消费记录时处理
    -- 注意：消费积分由支付系统回调触发，这里仅记录
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 触发器2：贡献审核通过后自动添加积分
CREATE OR REPLACE FUNCTION trigger_add_points_on_contribution_approved()
RETURNS TRIGGER AS $$
DECLARE
    v_action_code VARCHAR(50);
    v_points INTEGER;
BEGIN
    -- 当贡献记录状态从非approved变为approved时
    IF OLD.status != 'approved' AND NEW.status = 'approved' THEN
        -- 根据贡献类型确定action_code
        v_action_code := NEW.contribution_type;
        
        -- 调用添加积分函数
        PERFORM add_points(
            NEW.user_id,
            v_action_code,
            'contribution',
            NEW.id,
            '贡献审核通过获得积分：' || NEW.content_summary,
            NEW.contribution_type_desc || '贡献奖励'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 贡献审核通过触发器
CREATE TRIGGER contribution_approved_add_points
    AFTER UPDATE OF status ON contribution_records
    FOR EACH ROW
    EXECUTE FUNCTION trigger_add_points_on_contribution_approved();

-- 触发器3：签到时自动添加积分（由应用层调用）
-- 此触发器在用户每日首次签到记录插入时触发
CREATE TABLE IF NOT EXISTS checkin_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    checkin_date DATE NOT NULL,
    checkin_time TIMESTAMPTZ DEFAULT NOW(),
    points_earned INTEGER DEFAULT 0,
    is_first_checkin_today BOOLEAN DEFAULT FALSE,  -- 是否当日首次签到
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, checkin_date)  -- 每个用户每天只能签到一次
);

-- 签到记录表索引
CREATE INDEX IF NOT EXISTS idx_checkin_user ON checkin_records(user_id);
CREATE INDEX IF NOT EXISTS idx_checkin_date ON checkin_records(checkin_date DESC);

-- 签到后自动添加积分触发器
CREATE OR REPLACE FUNCTION trigger_add_points_on_checkin()
RETURNS TRIGGER AS $$
BEGIN
    -- 只在首次签到时添加积分
    IF NEW.is_first_checkin_today = TRUE THEN
        PERFORM add_points(
            NEW.user_id,
            'daily_checkin',
            'activity',
            NEW.id,
            '每日签到',
            '签到积分'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkin_add_points
    AFTER INSERT ON checkin_records
    FOR EACH ROW
    EXECUTE FUNCTION trigger_add_points_on_checkin();

-- 触发器4：用户资料完善后添加积分（一次性）
CREATE OR REPLACE FUNCTION trigger_add_points_on_profile_complete()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_completed BOOLEAN;
    v_previously_completed BOOLEAN;
BEGIN
    -- 检查profile字段是否包含必要的完善信息
    -- 这里简化处理，实际应检查具体字段
    v_profile_completed := (NEW.profile IS NOT NULL) AND 
                           (NEW.profile ? 'phone') AND 
                           (NEW.profile ? 'name');
    
    -- 检查之前是否已完善（通过检查是否有对应的积分流水）
    SELECT EXISTS(
        SELECT 1 FROM point_transactions 
        WHERE user_id = NEW.id 
          AND action_code = 'complete_profile'
    ) INTO v_previously_completed;
    
    -- 如果刚完成资料完善且之前未获得过积分
    IF v_profile_completed AND NOT v_previously_completed THEN
        PERFORM add_points(
            NEW.id,
            'complete_profile',
            'activity',
            NEW.id,
            '完善个人资料',
            '完善资料积分'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profile_complete_add_points
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION trigger_add_points_on_profile_complete();

-- =====================================================
-- 【第八步】创建用户积分总览视图
-- =====================================================

-- 用户积分总览视图
CREATE OR REPLACE VIEW v_user_points_summary AS
SELECT 
    pa.user_id,
    u.nickname,
    u.avatar_url,
    
    -- 积分余额
    pa.current_balance AS total_points,
    pa.frozen_balance,
    pa.current_balance - pa.frozen_balance AS available_points,
    
    -- 分类积分
    pa.consumption_points,
    pa.contribution_points,
    pa.activity_points,
    
    -- 累计统计
    pa.total_earned,
    pa.total_consumed,
    
    -- 活跃信息
    pa.last_activity_at,
    pa.last_earned_at,
    pa.last_consumed_at,
    
    -- 保障关联
    gs.guarantee_ratio,
    gs.consumption_years,
    gs.accumulated_points AS guarantee_accumulated_points,
    gs.status AS guarantee_status,
    
    -- 近期积分变动（最近10笔）
    (
        SELECT json_agg(json_build_object(
            'id', pt.id,
            'change_type', pt.change_type,
            'points_amount', pt.points_amount,
            'description_zh', pt.description_zh,
            'transaction_time', pt.transaction_time
        ) ORDER BY pt.transaction_time DESC)
        FROM point_transactions pt
        WHERE pt.user_id = pa.user_id
        LIMIT 10
    ) AS recent_transactions,
    
    -- 近期兑换（最近5笔）
    (
        SELECT json_agg(json_build_object(
            'id', pr.id,
            'item_name', pr.item_name,
            'points_cost', pr.points_cost,
            'status', pr.status,
            'requested_at', pr.requested_at
        ) ORDER BY pr.requested_at DESC)
        FROM point_redemptions pr
        WHERE pr.user_id = pa.user_id
        LIMIT 5
    ) AS recent_redemptions,
    
    -- 今日获得积分
    (
        SELECT COALESCE(SUM(ABS(points_amount)), 0)::INTEGER
        FROM point_transactions
        WHERE user_id = pa.user_id
          AND change_type = 'earn'
          AND transaction_time >= (CURRENT_DATE || ' 00:00:00')::TIMESTAMPTZ
    ) AS today_earned,
    
    -- 本月获得积分
    (
        SELECT COALESCE(SUM(ABS(points_amount)), 0)::INTEGER
        FROM point_transactions
        WHERE user_id = pa.user_id
          AND change_type = 'earn'
          AND transaction_time >= (DATE_TRUNC('month', CURRENT_DATE))::TIMESTAMPTZ
    ) AS month_earned

FROM point_accounts pa
LEFT JOIN users u ON u.id = pa.user_id
LEFT JOIN guarantee_status gs ON gs.user_id = pa.user_id;

-- 积分来源统计视图
CREATE OR REPLACE VIEW v_point_sources_summary AS
SELECT 
    user_id,
    points_category,
    COUNT(*) AS transaction_count,
    SUM(ABS(points_amount)) AS total_points,
    MIN(transaction_time) AS first_transaction,
    MAX(transaction_time) AS last_transaction
FROM point_transactions
WHERE change_type = 'earn'
GROUP BY user_id, points_category;

-- 积分兑换统计视图
CREATE OR REPLACE VIEW v_redemption_summary AS
SELECT 
    user_id,
    redemption_type,
    COUNT(*) AS redemption_count,
    SUM(points_cost) AS total_points_spent,
    MIN(requested_at) AS first_redemption,
    MAX(requested_at) AS last_redemption
FROM point_redemptions
WHERE status IN ('completed', 'approved')
GROUP BY user_id, redemption_type;

-- =====================================================
-- 【第九步】启用 RLS 行级安全策略
-- =====================================================

-- 启用 RLS
ALTER TABLE point_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE redeemable_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkin_records ENABLE ROW LEVEL SECURITY;

-- point_accounts 表策略：用户只能查看自己的积分账户
CREATE POLICY point_accounts_select_own ON point_accounts
    FOR SELECT USING (auth.uid() = user_id);

-- point_transactions 表策略：用户只能查看自己的积分流水
CREATE POLICY point_transactions_select_own ON point_transactions
    FOR SELECT USING (auth.uid() = user_id);

-- point_transactions 表策略：系统可插入（通过函数）
-- 注意：应用层通过函数添加积分，不直接插入流水表

-- point_redemptions 表策略：用户只能查看自己的兑换记录
CREATE POLICY point_redemptions_select_own ON point_redemptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY point_redemptions_insert_own ON point_redemptions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY point_redemptions_update_own ON point_redemptions
    FOR UPDATE USING (auth.uid() = user_id OR approved_by = auth.uid());

-- point_rules 表策略：所有人可查看规则
CREATE POLICY point_rules_select_all ON point_rules
    FOR SELECT USING (TRUE);

-- 只有管理员可修改规则（通过RLS实现）
-- 需要在Supabase后台配置管理员角色

-- redeemable_items 表策略：所有人可查看可兑换物品
CREATE POLICY redeemable_items_select_all ON redeemable_items
    FOR SELECT USING (is_active = TRUE);

-- 只有管理员可管理可兑换物品
CREATE POLICY redeemable_items_insert_admin ON redeemable_items
    FOR INSERT WITH CHECK (
        auth.jwt() ->> 'role' = 'service_role' OR 
        auth.jwt() ->> 'role' = 'supabase_admin'
    );

-- checkin_records 表策略
CREATE POLICY checkin_records_select_own ON checkin_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY checkin_records_insert_own ON checkin_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- 【第十步】创建必要的索引优化
-- =====================================================

-- 积分流水的复合索引
CREATE INDEX IF NOT EXISTS idx_point_txn_user_time ON point_transactions(user_id, transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_point_txn_user_category ON point_transactions(user_id, points_category);

-- 积分账户的统计索引
CREATE INDEX IF NOT EXISTS idx_point_accounts_total_earned ON point_accounts(total_earned DESC);

-- 签到记录的复合索引
CREATE INDEX IF NOT EXISTS idx_checkin_user_date ON checkin_records(user_id, checkin_date DESC);

-- =====================================================
-- 【第十一步】导出初始化数据（示例兑换物品）
-- =====================================================

-- 示例：添加健康服务兑换项
INSERT INTO redeemable_items (item_type, category, name, description, points_required, is_active, is_featured, display_order) VALUES
    ('service', 'tongue_diagnosis', 'AI舌诊报告', '详细舌诊分析报告，含体质辨识和调理建议', 50, TRUE, TRUE, 1),
    ('service', 'constitution_analysis', '体质辨识报告', '基于舌诊的详细体质分析', 30, TRUE, TRUE, 2),
    ('service', 'diet_recommendation', '个性化饮食建议', '根据体质定制的饮食调理方案', 20, TRUE, FALSE, 3),
    ('product', 'health_food', '五谷杂粮礼包', '精选有机杂粮组合500g', 100, TRUE, FALSE, 10),
    ('product', 'herbal_tea', '养生花草茶', '根据体质定制的花草茶包', 80, TRUE, FALSE, 11),
    ('voucher', 'discount', '全场9折券', '订单满100元可用', 200, TRUE, FALSE, 20)
ON CONFLICT DO NOTHING;

-- =====================================================
-- 执行完成！
-- =====================================================

-- 验证脚本（可选执行）
-- SELECT 'point_accounts' as table_name, COUNT(*) as count FROM point_accounts;
-- SELECT 'point_transactions' as table_name, COUNT(*) as count FROM point_transactions;
-- SELECT 'point_rules' as table_name, COUNT(*) as count FROM point_rules;
-- SELECT 'redeemable_items' as table_name, COUNT(*) as count FROM redeemable_items;
