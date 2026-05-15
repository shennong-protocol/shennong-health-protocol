-- =====================================================
-- 神农地球村数据库修复脚本
-- 执行时间: 2026-05-15
-- 用途: 修复签到功能（添加积分规则）
-- =====================================================

-- 1. 创建每日签到积分规则
INSERT INTO point_rules (
  id, 
  rule_code, 
  rule_name, 
  action_code, 
  points_type, 
  points_value, 
  max_daily_count,
  is_active, 
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'daily_checkin',
  '每日签到',
  'daily_checkin',
  'activity',
  2,
  1,
  true,
  NOW(),
  NOW()
) ON CONFLICT (rule_code) DO UPDATE SET
  rule_name = EXCLUDED.rule_name,
  points_value = EXCLUDED.points_value,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- 2. 创建首次注册积分奖励规则
INSERT INTO point_rules (
  id, 
  rule_code, 
  rule_name, 
  action_code, 
  points_type, 
  points_value, 
  max_daily_count,
  is_active, 
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'first_register',
  '首次注册',
  'first_register',
  'activity',
  10,
  1,
  true,
  NOW(),
  NOW()
) ON CONFLICT (rule_code) DO UPDATE SET
  rule_name = EXCLUDED.rule_name,
  points_value = EXCLUDED.points_value,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- 3. 创建完善资料积分规则
INSERT INTO point_rules (
  id, 
  rule_code, 
  rule_name, 
  action_code, 
  points_type, 
  points_value, 
  max_daily_count,
  is_active, 
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'complete_profile',
  '完善个人资料',
  'complete_profile',
  'activity',
  5,
  1,
  true,
  NOW(),
  NOW()
) ON CONFLICT (rule_code) DO UPDATE SET
  rule_name = EXCLUDED.rule_name,
  points_value = EXCLUDED.points_value,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- 验证插入
SELECT * FROM point_rules WHERE is_active = true ORDER BY created_at DESC;
