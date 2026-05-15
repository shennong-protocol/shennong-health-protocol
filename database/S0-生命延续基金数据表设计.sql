-- =====================================================
-- 神农地球村·生命延续基金数据表设计
-- S0-生命延续基金数据表设计
-- 版本：v1.0
-- 日期：2026年5月15日
-- 核心亮点：1元即可创建"活着的印记"
-- =====================================================

-- =====================================================
-- 一、核心表结构
-- =====================================================

-- -----------------------------------------------------
-- 1. 个人子基金表（personal_funds）- 活着的印记
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS personal_funds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 基金基本信息
    fund_name VARCHAR(20) NOT NULL,  -- 印记名称，用户自命名（2-20字符）
    fund_type VARCHAR(20) NOT NULL DEFAULT 'personal' CHECK (fund_type IN ('personal', 'career', 'spirit')),
    fund_code VARCHAR(20) UNIQUE NOT NULL,  -- 基金唯一代码
    
    -- 活着的印记核心字段（全部由用户自己书写，非系统模板）
    fund_epitaph VARCHAR(100),  -- 印记箴言：用户的一句话/心愿/感悟（最多100字符）
    fund_description TEXT,      -- 印记简介：用户自己书写的基金简介（个人叙事空间，最多2000字符）
    fund_motto VARCHAR(200),    -- 印记座右铭：扩展箴言（最多200字符）
    fund_image_url TEXT,        -- 印记图片URL：代表性图片（可选，JPG/PNG，最大5MB）
    
    -- 资金相关
    balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,  -- 当前余额
    total_contributed DECIMAL(12,2) NOT NULL DEFAULT 0.00,  -- 累计注入
    total_distributed DECIMAL(12,2) NOT NULL DEFAULT 0.00,  -- 累计分配
    total_inheritance DECIMAL(12,2) NOT NULL DEFAULT 0.00,  -- 累计继承支出
    
    -- 1元基金标识
    is_one_yuan_fund BOOLEAN NOT NULL DEFAULT FALSE,  -- 是否为1元基金（活着的印记）
    initial_amount DECIMAL(6,2) NOT NULL DEFAULT 1.00,  -- 创建时基础金额（最低1元）
    
    -- 继承相关
    inheritance_type VARCHAR(20) CHECK (inheritance_type IN ('material', 'career', 'spirit', 'mixed')),
    has_heir BOOLEAN NOT NULL DEFAULT FALSE,  -- 是否有继承人
    
    -- 状态与时间
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen', 'inherited', 'dissolved', 'no_heir')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    frozen_at TIMESTAMPTZ,  -- 冻结时间（死亡后）
    inherited_at TIMESTAMPTZ,  -- 继承完成时间
    
    -- 合规标记
    name_approved BOOLEAN NOT NULL DEFAULT FALSE,  -- 名称审核是否通过
    name_reject_reason VARCHAR(200),  -- 名称驳回原因
    
    -- 约束
    CONSTRAINT balance_non_negative CHECK (balance >= 0),
    CONSTRAINT initial_amount_min CHECK (initial_amount >= 1.00)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_personal_funds_user_id ON personal_funds(user_id);
CREATE INDEX IF NOT EXISTS idx_personal_funds_status ON personal_funds(status);
CREATE INDEX IF NOT EXISTS idx_personal_funds_fund_code ON personal_funds(fund_code);
CREATE INDEX IF NOT EXISTS idx_personal_funds_created_at ON personal_funds(created_at DESC);

-- -----------------------------------------------------
-- 2. 基金流水表（fund_transactions）- 资金变动记录
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS fund_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES personal_funds(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    
    -- 交易类型
    transaction_type VARCHAR(30) NOT NULL CHECK (
        transaction_type IN (
            'contribution',       -- 注入：消费/贡献/捐赠
            'distribution',        -- 分配：使用/提取
            'inheritance',         -- 继承：转给继承人
            'no_heir_transfer',    -- 无继承人：转入总基金
            'pool_injection',     -- 总基金注入：1元基础
            'adjustment'          -- 调整：系统调整
        )
    ),
    
    -- 金额
    amount DECIMAL(12,2) NOT NULL,  -- 正数表示增加，负数表示减少
    balance_before DECIMAL(12,2) NOT NULL,  -- 变动前余额
    balance_after DECIMAL(12,2) NOT NULL,  -- 变动后余额
    
    -- 来源信息
    source_type VARCHAR(30) CHECK (
        source_type IN (
            'consumption',     -- 消费注入
            'merchant',        -- 商家交易注入
            'donation',        -- 捐赠
            'spread',          -- 传播收益
            'points_conversion',  -- 积分兑换回流
            'pool_transfer',   -- 总基金池转入
            'system',          -- 系统调整
            'inheritance_receive' -- 继承获得
        )
    ),
    source_id UUID,  -- 关联业务ID（如消费记录ID）
    
    -- 描述
    description VARCHAR(200),  -- 变动描述
    description_zh VARCHAR(200),  -- 中文描述
    
    -- 合规与审计
    compliance_verified BOOLEAN NOT NULL DEFAULT TRUE,
    operator_id UUID,  -- 操作者
    operator_type VARCHAR(20) CHECK (operator_type IN ('system', 'user', 'admin')),
    
    -- 时间
    transaction_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_fund_transactions_fund_id ON fund_transactions(fund_id);
CREATE INDEX IF NOT EXISTS idx_fund_transactions_user_id ON fund_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_fund_transactions_type ON fund_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_fund_transactions_time ON fund_transactions(transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_fund_transactions_source ON fund_transactions(source_type, source_id);

-- -----------------------------------------------------
-- 3. 继承规则表（fund_inheritance_rules）- 继承安排
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS fund_inheritance_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES personal_funds(id) ON DELETE CASCADE,
    
    -- 继承人信息
    heir_user_id UUID REFERENCES users(id),  -- 继承人用户ID（可为NULL表示法定继承）
    heir_type VARCHAR(20) NOT NULL CHECK (
        heir_type IN ('designated', 'legal', 'default_pool')
    ),  -- designated=指定继承人, legal=法定继承人, default_pool=转入总基金
    
    -- 继承分配
    priority INTEGER NOT NULL DEFAULT 1,  -- 优先级（数字越小优先级越高）
    percentage DECIMAL(5,2) NOT NULL DEFAULT 100.00 CHECK (
        percentage >= 0 AND percentage <= 100
    ),  -- 继承比例%
    
    -- 继承条件
    conditions JSONB,  -- 继承条件（如：年龄限制、身份要求等）
    
    -- 继承类型
    inheritance_type VARCHAR(20) CHECK (
        inheritance_type IN ('material', 'career', 'spirit', 'all')
    ),  -- 物质/事业/精神/全部
    
    -- 状态
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_activated BOOLEAN NOT NULL DEFAULT FALSE,  -- 是否已激活（死亡后）
    
    -- 时间
    effective_date TIMESTAMPTZ,  -- 生效日期
    activated_at TIMESTAMPTZ,  -- 激活时间（死亡后触发）
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_inheritance_rules_fund_id ON fund_inheritance_rules(fund_id);
CREATE INDEX IF NOT EXISTS idx_inheritance_rules_heir_id ON fund_inheritance_rules(heir_user_id);
CREATE INDEX IF NOT EXISTS idx_inheritance_rules_active ON fund_inheritance_rules(is_active);

-- -----------------------------------------------------
-- 4. 商家品牌子基金表（merchant_funds）
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_funds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    
    -- 基金信息
    fund_name VARCHAR(50) NOT NULL,
    fund_code VARCHAR(20) UNIQUE NOT NULL,
    fund_description TEXT,
    
    -- 注入配置
    contribution_rate DECIMAL(5,4) NOT NULL CHECK (
        contribution_rate >= 0.01 AND contribution_rate <= 0.15
    ),  -- 注入比例：1%-15%
    
    -- 曝光权重
    brand_exposure_weight DECIMAL(3,2) NOT NULL DEFAULT 1.00,
    
    -- 资金
    balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    total_contributed DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    total_distributed DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    
    -- 商家等级
    merchant_level VARCHAR(20) CHECK (
        merchant_level IN ('bronze', 'silver', 'gold', 'diamond')
    ),  -- 青铜/白银/黄金/钻石
    
    -- 状态
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (
        status IN ('active', 'frozen', 'closed', 'transferred')
    ),
    
    -- 时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_merchant_funds_merchant_id ON merchant_funds(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_funds_status ON merchant_funds(status);
CREATE INDEX IF NOT EXISTS idx_merchant_funds_level ON merchant_funds(merchant_level);

-- -----------------------------------------------------
-- 5. 总基金池表（life_continuation_pool）- 公共保障池
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS life_continuation_pool (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pool_type VARCHAR(30) NOT NULL DEFAULT 'main' CHECK (
        pool_type IN ('main', 'no_heir', 'charity', 'emergency')
    ),  -- main=主池, no_heir=无继承人池, charity=慈善池, emergency=应急池
    
    -- 资金
    balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    total_inflow DECIMAL(14,2) NOT NULL DEFAULT 0.00,  -- 累计流入
    total_outflow DECIMAL(14,2) NOT NULL DEFAULT 0.00,  -- 累计流出
    
    -- 统计
    total_no_heir_funds_count INTEGER NOT NULL DEFAULT 0,  -- 无继承人基金数量
    total_charity_donations DECIMAL(14,2) NOT NULL DEFAULT 0.00,  -- 累计慈善捐赠
    
    -- 分配规则
    distribution_priority INTEGER NOT NULL DEFAULT 1,  -- 分配优先级
    max_single_distribution DECIMAL(12,2),  -- 单次最大分配
    
    -- 状态
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT balance_non_negative CHECK (balance >= 0)
);

-- 初始化主池记录
INSERT INTO life_continuation_pool (pool_type, balance, total_inflow, total_outflow)
VALUES ('main', 0.00, 0.00, 0.00)
ON CONFLICT (pool_type) DO NOTHING;

-- -----------------------------------------------------
-- 6. 印记记录表（fund_epitaph_records）- 印记变更历史
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS fund_epitaph_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES personal_funds(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    
    -- 变更内容
    change_type VARCHAR(30) NOT NULL CHECK (
        change_type IN ('create', 'update_epitaph', 'update_image', 'update_motto', 'inherit')
    ),
    old_value TEXT,  -- 变更前的值
    new_value TEXT,  -- 变更后的值
    
    -- 审核
    approved BOOLEAN NOT NULL DEFAULT TRUE,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    reject_reason VARCHAR(200),
    
    -- 时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_epitaph_records_fund_id ON fund_epitaph_records(fund_id);
CREATE INDEX IF NOT EXISTS idx_epitaph_records_time ON fund_epitaph_records(created_at DESC);

-- -----------------------------------------------------
-- 7. 死亡认证表（death_certifications）- 死亡认证记录
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS death_certifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    
    -- 认证信息
    certification_type VARCHAR(20) NOT NULL CHECK (
        certification_type IN ('family_report', 'police', 'hospital', 'system_auto')
    ),  -- 家属申报/公安/医院/系统自动
    
    -- 证明材料
    certificate_url TEXT,  -- 证明材料URL
    certificate_number VARCHAR(50),  -- 证明编号
    
    -- 认证状态
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'approved', 'rejected', 'cancelled')
    ),
    
    -- 认证结果
    approved_by UUID,  -- 审核人
    approved_at TIMESTAMPTZ,
    reject_reason VARCHAR(200),
    
    -- 关联基金
    related_funds_processed BOOLEAN NOT NULL DEFAULT FALSE,  -- 关联基金是否已处理
    inheritance_completed BOOLEAN NOT NULL DEFAULT FALSE,  -- 继承是否完成
    
    -- 时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_death_certifications_user_id ON death_certifications(user_id);
CREATE INDEX IF NOT EXISTS idx_death_certifications_status ON death_certifications(status);

-- -----------------------------------------------------
-- 8. 基金年度结算表（fund_annual_settlements）
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS fund_annual_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES personal_funds(id),
    
    -- 结算年度
    settlement_year INTEGER NOT NULL,
    settlement_period VARCHAR(20),  -- 结算期间描述
    
    -- 期初/期末
    opening_balance DECIMAL(12,2) NOT NULL,
    closing_balance DECIMAL(12,2) NOT NULL,
    
    -- 变动明细
    total_inflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_outflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    inflow_count INTEGER NOT NULL DEFAULT 0,
    outflow_count INTEGER NOT NULL DEFAULT 0,
    
    -- 分类统计
    consumption_inflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    merchant_inflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    donation_inflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    spread_inflow DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    
    -- 继承情况
    inheritance_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    
    -- 审计
    auditor_id UUID,
    audit_status VARCHAR(20) CHECK (audit_status IN ('pending', 'approved', 'flagged')),
    audit_notes TEXT,
    audit_at TIMESTAMPTZ,
    
    -- 时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_annual_settlements_fund_id ON fund_annual_settlements(fund_id);
CREATE INDEX IF NOT EXISTS idx_annual_settlements_year ON fund_annual_settlements(settlement_year DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_annual_settlements_unique ON fund_annual_settlements(fund_id, settlement_year);

-- =====================================================
-- 二、核心函数
-- =====================================================

-- -----------------------------------------------------
-- 函数1：创建个人子基金（1元即可创建活着的印记）
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_create_personal_fund(
    p_user_id UUID,
    p_fund_name VARCHAR,
    p_fund_type VARCHAR DEFAULT 'personal',
    p_fund_epitaph VARCHAR DEFAULT NULL,
    p_fund_motto VARCHAR DEFAULT NULL,
    p_fund_image_url TEXT DEFAULT NULL,
    p_initial_amount DECIMAL DEFAULT 1.00
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_fund_id UUID;
    v_fund_code VARCHAR(20);
    v_pool_id UUID;
BEGIN
    -- 验证最低金额
    IF p_initial_amount < 1.00 THEN
        RAISE EXCEPTION '创建基金最低金额为1元';
    END IF;
    
    -- 生成唯一基金代码
    v_fund_code := 'PF-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 6));
    
    -- 检查用户是否已有该类型的子基金
    IF EXISTS (SELECT 1 FROM personal_funds WHERE user_id = p_user_id AND fund_type = p_fund_type AND status = 'active') THEN
        RAISE EXCEPTION '该类型子基金已存在，不可重复创建';
    END IF;
    
    -- 创建个人子基金
    INSERT INTO personal_funds (
        user_id,
        fund_name,
        fund_type,
        fund_code,
        fund_epitaph,
        fund_motto,
        fund_image_url,
        balance,
        total_contributed,
        is_one_yuan_fund,
        initial_amount,
        name_approved,
        status
    ) VALUES (
        p_user_id,
        p_fund_name,
        p_fund_type,
        v_fund_code,
        p_fund_epitaph,
        p_fund_motto,
        p_fund_image_url,
        0.00,  -- 初始余额为0，资金注入总基金池
        p_initial_amount,
        CASE WHEN p_initial_amount = 1.00 THEN TRUE ELSE FALSE END,
        p_initial_amount,
        TRUE,  -- 默认审核通过（实际应走审核流程）
        'active'
    ) RETURNING id INTO v_fund_id;
    
    -- 1元基础金额注入总基金池
    SELECT id INTO v_pool_id FROM life_continuation_pool WHERE pool_type = 'main';
    
    UPDATE life_continuation_pool SET
        balance = balance + p_initial_amount,
        total_inflow = total_inflow + p_initial_amount,
        updated_at = NOW()
    WHERE id = v_pool_id;
    
    -- 记录流水（基金创建）
    INSERT INTO fund_transactions (
        fund_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        source_type,
        description,
        description_zh,
        operator_type
    ) VALUES (
        v_fund_id,
        p_user_id,
        'pool_injection',
        p_initial_amount,
        0.00,
        0.00,
        'pool_transfer',
        '1元基础注入总基金池，创建活着的印记',
        '1元基础注入总基金池，创建活着的印记',
        'system'
    );
    
    -- 记录印记创建历史
    INSERT INTO fund_epitaph_records (
        fund_id,
        user_id,
        change_type,
        new_value
    ) VALUES (
        v_fund_id,
        p_user_id,
        'create',
        json_build_object(
            'fund_name', p_fund_name,
            'fund_epitaph', p_fund_epitaph,
            'fund_motto', p_fund_motto,
            'initial_amount', p_initial_amount
        )::TEXT
    );
    
    RETURN v_fund_id;
END;
$$;

-- -----------------------------------------------------
-- 函数2：消费注入基金
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_inject_to_fund(
    p_user_id UUID,
    p_amount DECIMAL,
    p_source_type VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description VARCHAR DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_fund_id UUID;
    v_balance_before DECIMAL(12,2);
    v_balance_after DECIMAL(12,2);
    v_injection_rate DECIMAL(5,4) := 0.10;  -- 默认10%注入比例
    v_injection_amount DECIMAL(12,2);
    v_consumption_years INTEGER;
BEGIN
    -- 查找用户活跃的个人子基金
    SELECT id, balance INTO v_fund_id, v_balance_before
    FROM personal_funds
    WHERE user_id = p_user_id AND status = 'active'
    ORDER BY created_at ASC
    LIMIT 1;
    
    -- 如果用户没有子基金，自动创建一个1元印记基金
    IF v_fund_id IS NULL THEN
        SELECT fn_create_personal_fund(
            p_user_id,
            '我的活着的印记',  -- 默认名称
            'personal',
            '用消费为生命留下印记',  -- 默认箴言
            NULL,
            NULL,
            0.00  -- 0元创建，不额外注入
        ) INTO v_fund_id;
        
        SELECT balance INTO v_balance_before FROM personal_funds WHERE id = v_fund_id;
    END IF;
    
    -- 计算注入金额（按比例）
    v_injection_amount := p_amount * v_injection_rate;
    
    -- 更新基金余额
    UPDATE personal_funds SET
        balance = balance + v_injection_amount,
        total_contributed = total_contributed + v_injection_amount,
        updated_at = NOW()
    WHERE id = v_fund_id
    RETURNING balance INTO v_balance_after;
    
    -- 记录流水
    INSERT INTO fund_transactions (
        fund_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        source_type,
        source_id,
        description,
        description_zh,
        operator_type
    ) VALUES (
        v_fund_id,
        p_user_id,
        'contribution',
        v_injection_amount,
        v_balance_before,
        v_balance_after,
        p_source_type,
        p_source_id,
        COALESCE(p_description, '消费注入基金'),
        COALESCE(p_description, '消费注入基金'),
        'system'
    );
END;
$$;

-- -----------------------------------------------------
-- 函数3：执行继承
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_execute_inheritance(
    p_fund_id UUID,
    p_death_certification_id UUID
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_fund RECORD;
    v_rules RECORD;
    v_heir_id UUID;
    v_percentage DECIMAL(5,2);
    v_inheritance_amount DECIMAL(12,2);
    v_balance_before DECIMAL(12,2);
    v_balance_after DECIMAL(12,2);
    v_inherited BOOLEAN := FALSE;
BEGIN
    -- 获取基金信息
    SELECT * INTO v_fund FROM personal_funds WHERE id = p_fund_id;
    
    IF v_fund.status != 'active' THEN
        RAISE EXCEPTION '基金状态不允许继承';
    END IF;
    
    -- 冻结基金
    UPDATE personal_funds SET
        status = 'frozen',
        frozen_at = NOW(),
        updated_at = NOW()
    WHERE id = p_fund_id;
    
    -- 检查是否有指定继承人
    SELECT * INTO v_rules
    FROM fund_inheritance_rules
    WHERE fund_id = p_fund_id AND is_active = TRUE
    ORDER BY priority ASC
    LIMIT 1;
    
    IF v_rules.heir_user_id IS NOT NULL THEN
        -- 有指定继承人，执行继承
        v_heir_id := v_rules.heir_user_id;
        v_percentage := v_rules.percentage;
        v_inheritance_amount := v_fund.balance * (v_percentage / 100.00);
        
        v_balance_before := v_fund.balance;
        v_balance_after := 0.00;
        
        -- 更新基金状态
        UPDATE personal_funds SET
            balance = 0.00,
            total_inheritance = total_inheritance + v_inheritance_amount,
            status = 'inherited',
            inherited_at = NOW(),
            updated_at = NOW()
        WHERE id = p_fund_id;
        
        -- 记录继承流水
        INSERT INTO fund_transactions (
            fund_id,
            user_id,
            transaction_type,
            amount,
            balance_before,
            balance_after,
            source_type,
            description,
            description_zh,
            operator_type
        ) VALUES (
            p_fund_id,
            v_heir_id,
            'inheritance',
            -v_inheritance_amount,
            v_balance_before,
            v_balance_after,
            'inheritance_receive',
            '继承获得：' || v_fund.fund_name,
            '继承获得：' || v_fund.fund_name,
            'system'
        );
        
        -- 更新继承规则状态
        UPDATE fund_inheritance_rules SET
            is_activated = TRUE,
            activated_at = NOW()
        WHERE id = v_rules.id;
        
        v_inherited := TRUE;
        
    ELSE
        -- 无继承人，转入总基金池
        UPDATE personal_funds SET
            balance = 0.00,
            total_inheritance = total_inheritance + v_fund.balance,
            status = 'no_heir',
            inherited_at = NOW(),
            updated_at = NOW()
        WHERE id = p_fund_id;
        
        -- 转入总基金池
        UPDATE life_continuation_pool SET
            balance = balance + v_fund.balance,
            total_inflow = total_inflow + v_fund.balance,
            total_no_heir_funds_count = total_no_heir_funds_count + 1,
            updated_at = NOW()
        WHERE pool_type = 'no_heir';
        
        -- 记录流水
        INSERT INTO fund_transactions (
            fund_id,
            user_id,
            transaction_type,
            amount,
            balance_before,
            balance_after,
            source_type,
            description,
            description_zh,
            operator_type
        ) VALUES (
            p_fund_id,
            v_fund.user_id,
            'no_heir_transfer',
            -v_fund.balance,
            v_fund.balance,
            0.00,
            'pool_transfer',
            '无继承人转入总基金池',
            '无继承人转入总基金池',
            'system'
        );
    END IF;
    
    -- 更新死亡认证记录
    UPDATE death_certifications SET
        related_funds_processed = TRUE,
        inheritance_completed = v_inherited,
        completed_at = NOW()
    WHERE id = p_death_certification_id;
    
END;
$$;

-- -----------------------------------------------------
-- 函数4：无继承人注入总基金
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_inject_no_heir_to_pool(
    p_fund_id UUID
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_fund RECORD;
    v_pool_id UUID;
BEGIN
    SELECT * INTO v_fund FROM personal_funds WHERE id = p_fund_id;
    
    IF v_fund.status != 'frozen' THEN
        RAISE EXCEPTION '只有冻结状态的基金才能转入总基金池';
    END IF;
    
    IF v_fund.balance <= 0 THEN
        RAISE EXCEPTION '基金余额为0，无需转入';
    END IF;
    
    -- 获取总基金池
    SELECT id INTO v_pool_id FROM life_continuation_pool WHERE pool_type = 'no_heir';
    
    -- 转入总基金池
    UPDATE life_continuation_pool SET
        balance = balance + v_fund.balance,
        total_inflow = total_inflow + v_fund.balance,
        total_no_heir_funds_count = total_no_heir_funds_count + 1,
        updated_at = NOW()
    WHERE id = v_pool_id;
    
    -- 更新基金状态
    UPDATE personal_funds SET
        balance = 0.00,
        status = 'no_heir',
        inherited_at = NOW(),
        updated_at = NOW()
    WHERE id = p_fund_id;
    
    -- 记录流水
    INSERT INTO fund_transactions (
        fund_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        source_type,
        description,
        description_zh,
        operator_type
    ) VALUES (
        p_fund_id,
        v_fund.user_id,
        'no_heir_transfer',
        -v_fund.balance,
        v_fund.balance,
        0.00,
        'pool_transfer',
        '无继承人基金转入总基金池',
        '无继承人基金转入总基金池',
        'system'
    );
END;
$$;

-- -----------------------------------------------------
-- 函数5：更新印记信息
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_fund_epitaph(
    p_fund_id UUID,
    p_user_id UUID,
    p_fund_epitaph VARCHAR DEFAULT NULL,
    p_fund_motto VARCHAR DEFAULT NULL,
    p_fund_image_url TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_fund RECORD;
    v_change_type VARCHAR(30);
    v_old_value TEXT;
    v_new_value TEXT;
    v_image_change_count INTEGER;
BEGIN
    SELECT * INTO v_fund FROM personal_funds WHERE id = p_fund_id AND user_id = p_user_id;
    
    IF v_fund IS NULL THEN
        RAISE EXCEPTION '基金不存在或无权修改';
    END IF;
    
    IF v_fund.status != 'active' THEN
        RAISE EXCEPTION '非活跃状态的基金不能修改印记';
    END IF;
    
    -- 记录变更
    IF p_fund_epitaph IS DISTINCT FROM v_fund.fund_epitaph THEN
        INSERT INTO fund_epitaph_records (fund_id, user_id, change_type, old_value, new_value)
        VALUES (p_fund_id, p_user_id, 'update_epitaph', v_fund.fund_epitaph, p_fund_epitaph);
    END IF;
    
    IF p_fund_motto IS DISTINCT FROM v_fund.fund_motto THEN
        INSERT INTO fund_epitaph_records (fund_id, user_id, change_type, old_value, new_value)
        VALUES (p_fund_id, p_user_id, 'update_motto', v_fund.fund_motto, p_fund_motto);
    END IF;
    
    IF p_fund_image_url IS DISTINCT FROM v_fund.fund_image_url THEN
        -- 检查图片更换频率（每年限12次）
        SELECT COUNT(*) INTO v_image_change_count
        FROM fund_epitaph_records
        WHERE fund_id = p_fund_id AND change_type = 'update_image'
        AND created_at > NOW() - INTERVAL '1 year';
        
        IF v_image_change_count >= 12 THEN
            RAISE EXCEPTION '印记图片每年最多更换12次';
        END IF;
        
        INSERT INTO fund_epitaph_records (fund_id, user_id, change_type, old_value, new_value)
        VALUES (p_fund_id, p_user_id, 'update_image', v_fund.fund_image_url, p_fund_image_url);
    END IF;
    
    -- 更新基金
    UPDATE personal_funds SET
        fund_epitaph = COALESCE(p_fund_epitaph, fund_epitaph),
        fund_motto = COALESCE(p_fund_motto, fund_motto),
        fund_image_url = COALESCE(p_fund_image_url, fund_image_url),
        updated_at = NOW()
    WHERE id = p_fund_id;
    
END;
$$;

-- -----------------------------------------------------
-- 函数6：商家交易注入品牌基金
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_merchant_transaction_inject(
    p_merchant_id UUID,
    p_transaction_amount DECIMAL,
    p_source_id UUID DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_merchant_fund RECORD;
    v_contribution_amount DECIMAL(12,2);
    v_balance_before DECIMAL(14,2);
    v_balance_after DECIMAL(14,2);
BEGIN
    -- 获取商家品牌基金
    SELECT * INTO v_merchant_fund
    FROM merchant_funds
    WHERE merchant_id = p_merchant_id AND status = 'active';
    
    IF v_merchant_fund IS NULL THEN
        RETURN;  -- 商家没有品牌基金，直接返回
    END IF;
    
    -- 计算注入金额
    v_contribution_amount := p_transaction_amount * v_merchant_fund.contribution_rate;
    
    IF v_contribution_amount <= 0 THEN
        RETURN;
    END IF;
    
    v_balance_before := v_merchant_fund.balance;
    
    -- 更新基金余额
    UPDATE merchant_funds SET
        balance = balance + v_contribution_amount,
        total_contributed = total_contributed + v_contribution_amount,
        updated_at = NOW()
    WHERE id = v_merchant_fund.id
    RETURNING balance INTO v_balance_after;
    
    -- 记录流水
    INSERT INTO fund_transactions (
        fund_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        source_type,
        source_id,
        description,
        description_zh,
        operator_type
    ) VALUES (
        v_merchant_fund.id,
        p_merchant_id,
        'contribution',
        v_contribution_amount,
        v_balance_before,
        v_balance_after,
        'merchant',
        p_source_id,
        '商家交易注入品牌基金',
        '商家交易注入品牌基金',
        'system'
    );
    
END;
$$;

-- =====================================================
-- 三、触发器
-- =====================================================

-- -----------------------------------------------------
-- 触发器1：消费成功后自动注入基金
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION trg_after_consumption_inject()
RETURNS TRIGGER AS $$
BEGIN
    -- 当消费记录状态变为已完成时，自动注入基金
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        PERFORM fn_inject_to_fund(
            NEW.user_id,
            NEW.amount,
            'consumption',
            NEW.id,
            '消费注入基金'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_consumption_inject ON consumption_records;
CREATE TRIGGER trg_consumption_inject
    AFTER UPDATE OF status ON consumption_records
    FOR EACH ROW
    EXECUTE FUNCTION trg_after_consumption_inject();

-- -----------------------------------------------------
-- 触发器2：创建用户时自动创建1元印记基金（可选）
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION trg_after_user_create_fund()
RETURNS TRIGGER AS $$
BEGIN
    -- 可选：用户注册时自动创建1元印记基金
    -- 如需启用，取消下面注释
    -- PERFORM fn_create_personal_fund(
    --     NEW.id,
    --     '我的活着的印记',
    --     'personal',
    --     '从今天起，为生命留下印记',
    --     NULL,
    --     NULL,
    --     1.00
    -- );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_create_fund ON users;
CREATE TRIGGER trg_user_create_fund
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION trg_after_user_create_fund();

-- -----------------------------------------------------
-- 触发器3：自动更新updated_at
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION trg_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_personal_funds_timestamp ON personal_funds;
CREATE TRIGGER trg_personal_funds_timestamp
    BEFORE UPDATE ON personal_funds
    FOR EACH ROW
    EXECUTE FUNCTION trg_update_timestamp();

DROP TRIGGER IF EXISTS trg_merchant_funds_timestamp ON merchant_funds;
CREATE TRIGGER trg_merchant_funds_timestamp
    BEFORE UPDATE ON merchant_funds
    FOR EACH ROW
    EXECUTE FUNCTION trg_update_timestamp();

DROP TRIGGER IF EXISTS trg_pool_timestamp ON life_continuation_pool;
CREATE TRIGGER trg_pool_timestamp
    BEFORE UPDATE ON life_continuation_pool
    FOR EACH ROW
    EXECUTE FUNCTION trg_update_timestamp();

DROP TRIGGER IF EXISTS trg_inheritance_rules_timestamp ON fund_inheritance_rules;
CREATE TRIGGER trg_inheritance_rules_timestamp
    BEFORE UPDATE ON fund_inheritance_rules
    FOR EACH ROW
    EXECUTE FUNCTION trg_update_timestamp();

-- =====================================================
-- 四、视图定义
-- =====================================================

-- -----------------------------------------------------
-- 视图1：用户印记基金总览
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_user_fund_summary AS
SELECT 
    pf.id,
    pf.user_id,
    pf.fund_name,
    pf.fund_type,
    pf.fund_code,
    pf.fund_epitaph,
    pf.fund_motto,
    pf.fund_image_url,
    pf.balance,
    pf.total_contributed,
    pf.total_distributed,
    pf.total_inheritance,
    pf.is_one_yuan_fund,
    pf.initial_amount,
    pf.inheritance_type,
    pf.has_heir,
    pf.status,
    pf.created_at,
    pf.updated_at,
    pf.name_approved,
    -- 继承统计
    (SELECT COUNT(*) FROM fund_inheritance_rules WHERE fund_id = pf.id AND is_active = TRUE) as heir_count,
    -- 印记更新次数
    (SELECT COUNT(*) FROM fund_epitaph_records WHERE fund_id = pf.id) as epitaph_changes,
    -- 最近一次注入
    (SELECT transaction_time FROM fund_transactions 
     WHERE fund_id = pf.id AND transaction_type = 'contribution'
     ORDER BY transaction_time DESC LIMIT 1) as last_contribution_at
FROM personal_funds pf;

-- -----------------------------------------------------
-- 视图2：总基金池状态
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_pool_status AS
SELECT 
    pool_type,
    balance,
    total_inflow,
    total_outflow,
    CASE 
        WHEN pool_type = 'no_heir' THEN total_no_heir_funds_count 
        ELSE 0 
    END as transferred_funds_count,
    CASE 
        WHEN pool_type = 'charity' THEN total_charity_donations 
        ELSE 0 
    END as charity_amount,
    status,
    updated_at
FROM life_continuation_pool;

-- -----------------------------------------------------
-- 视图3：商家品牌基金排行
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_merchant_fund_ranking AS
SELECT 
    mf.id,
    mf.merchant_id,
    mf.fund_name,
    mf.fund_code,
    mf.contribution_rate,
    mf.brand_exposure_weight,
    mf.balance,
    mf.total_contributed,
    mf.merchant_level,
    mf.status,
    -- 计算曝光权重调整后的值
    mf.balance * mf.brand_exposure_weight as effective_weight
FROM merchant_funds mf
WHERE mf.status = 'active'
ORDER BY effective_weight DESC;

-- -----------------------------------------------------
-- 视图4：继承统计
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_inheritance_summary AS
SELECT 
    fir.fund_id,
    pf.fund_name,
    pf.user_id,
    pf.inheritance_type,
    fir.heir_user_id,
    u.heir_name,
    fir.heir_type,
    fir.percentage,
    fir.is_activated,
    fir.activated_at,
    pf.total_inheritance
FROM fund_inheritance_rules fir
LEFT JOIN personal_funds pf ON pf.id = fir.fund_id
LEFT JOIN users u ON u.id = fir.heir_user_id
WHERE fir.is_active = TRUE;

-- =====================================================
-- 五、RLS 行级安全策略
-- =====================================================

-- 开启RLS
ALTER TABLE personal_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_inheritance_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_epitaph_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE death_certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_continuation_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_annual_settlements ENABLE ROW LEVEL SECURITY;

-- personal_funds 策略
CREATE POLICY "用户只能查看自己的印记基金" ON personal_funds
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "用户只能创建自己的印记基金" ON personal_funds
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "用户只能更新自己的印记基金" ON personal_funds
    FOR UPDATE USING (user_id = auth.uid());

-- fund_transactions 策略
CREATE POLICY "用户只能查看自己的基金流水" ON fund_transactions
    FOR SELECT USING (user_id = auth.uid());

-- fund_inheritance_rules 策略
CREATE POLICY "用户只能管理自己的继承规则" ON fund_inheritance_rules
    FOR ALL USING (
        fund_id IN (SELECT id FROM personal_funds WHERE user_id = auth.uid())
    );

-- fund_epitaph_records 策略
CREATE POLICY "用户只能查看自己的印记记录" ON fund_epitaph_records
    FOR SELECT USING (user_id = auth.uid());

-- death_certifications 策略（管理员可查看所有）
CREATE POLICY "管理员可查看所有死亡认证" ON death_certifications
    FOR SELECT USING (
        auth.uid() IN (SELECT id FROM users WHERE role = 'admin')
        OR user_id = auth.uid()
    );

-- merchant_funds 策略
CREATE POLICY "商家只能管理自己的品牌基金" ON merchant_funds
    FOR ALL USING (merchant_id = auth.uid());

-- life_continuation_pool 策略（只读）
CREATE POLICY "所有人可查看总基金池" ON life_continuation_pool
    FOR SELECT USING (TRUE);

-- fund_annual_settlements 策略
CREATE POLICY "用户只能查看自己的年度结算" ON fund_annual_settlements
    FOR SELECT USING (
        fund_id IN (SELECT id FROM personal_funds WHERE user_id = auth.uid())
    );

-- =====================================================
-- 六、默认数据
-- =====================================================

-- 插入总基金池初始记录
INSERT INTO life_continuation_pool (pool_type, balance, total_inflow, total_outflow, status)
VALUES 
    ('main', 0.00, 0.00, 0.00, 'active'),
    ('no_heir', 0.00, 0.00, 0.00, 'active'),
    ('charity', 0.00, 0.00, 0.00, 'active'),
    ('emergency', 0.00, 0.00, 0.00, 'active')
ON CONFLICT (pool_type) DO NOTHING;

-- =====================================================
-- 七、注释说明
-- =====================================================

COMMENT ON TABLE personal_funds IS '个人子基金表 - 活着的印记';
COMMENT ON COLUMN personal_funds.fund_epitaph IS '印记箴言：用户的一句话/心愿/感悟';
COMMENT ON COLUMN personal_funds.fund_motto IS '印记座右铭：扩展箴言';
COMMENT ON COLUMN personal_funds.fund_image_url IS '印记图片：代表性图片（可选）';
COMMENT ON COLUMN personal_funds.is_one_yuan_fund IS '是否为1元基金（活着的印记）';
COMMENT ON COLUMN personal_funds.initial_amount IS '创建时基础金额（最低1元）';

COMMENT ON TABLE fund_transactions IS '基金流水表 - 资金变动记录';
COMMENT ON TABLE fund_inheritance_rules IS '继承规则表 - 继承安排';
COMMENT ON TABLE merchant_funds IS '商家品牌子基金表';
COMMENT ON TABLE life_continuation_pool IS '总基金池表 - 公共保障池';
COMMENT ON TABLE fund_epitaph_records IS '印记记录表 - 印记变更历史';
COMMENT ON TABLE death_certifications IS '死亡认证表';
COMMENT ON TABLE fund_annual_settlements IS '基金年度结算表';

-- =====================================================
-- 执行完成
-- =====================================================
