-- =====================================================
-- 生命延续基金 - RLS策略脚本（可重复执行）
-- 复制本文件全部内容到Supabase SQL Editor执行即可
-- =====================================================

-- 开启行级安全
ALTER TABLE personal_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_inheritance_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_epitaph_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE death_certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_continuation_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE fund_annual_settlements ENABLE ROW LEVEL SECURITY;

-- personal_funds 策略
DROP POLICY IF EXISTS "users_select_own_funds" ON personal_funds;
CREATE POLICY "users_select_own_funds" ON personal_funds
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "users_insert_own_funds" ON personal_funds;
CREATE POLICY "users_insert_own_funds" ON personal_funds
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "users_update_own_funds" ON personal_funds;
CREATE POLICY "users_update_own_funds" ON personal_funds
    FOR UPDATE USING (user_id = auth.uid());

-- fund_transactions 策略
DROP POLICY IF EXISTS "users_select_own_transactions" ON fund_transactions;
CREATE POLICY "users_select_own_transactions" ON fund_transactions
    FOR SELECT USING (user_id = auth.uid());

-- fund_inheritance_rules 策略
DROP POLICY IF EXISTS "users_manage_own_rules" ON fund_inheritance_rules;
CREATE POLICY "users_manage_own_rules" ON fund_inheritance_rules
    FOR ALL USING (
        fund_id IN (SELECT id FROM personal_funds WHERE user_id = auth.uid())
    );

-- fund_epitaph_records 策略
DROP POLICY IF EXISTS "users_select_own_records" ON fund_epitaph_records;
CREATE POLICY "users_select_own_records" ON fund_epitaph_records
    FOR SELECT USING (user_id = auth.uid());

-- death_certifications 策略
DROP POLICY IF EXISTS "admins_or_owner_view_certifications" ON death_certifications;
CREATE POLICY "admins_or_owner_view_certifications" ON death_certifications
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_app_meta_data->>'role' = 'admin')
        OR user_id = auth.uid()
    );

-- merchant_funds 策略
DROP POLICY IF EXISTS "merchants_manage_own_funds" ON merchant_funds;
CREATE POLICY "merchants_manage_own_funds" ON merchant_funds
    FOR ALL USING (merchant_id = auth.uid());

-- life_continuation_pool 策略（只读）
DROP POLICY IF EXISTS "all_view_pool" ON life_continuation_pool;
CREATE POLICY "all_view_pool" ON life_continuation_pool
    FOR SELECT USING (TRUE);

-- fund_annual_settlements 策略
DROP POLICY IF EXISTS "users_view_own_settlements" ON fund_annual_settlements;
CREATE POLICY "users_view_own_settlements" ON fund_annual_settlements
    FOR SELECT USING (
        fund_id IN (SELECT id FROM personal_funds WHERE user_id = auth.uid())
    );

-- 执行完成
SELECT '生命延续基金RLS策略创建完成！' as status;
