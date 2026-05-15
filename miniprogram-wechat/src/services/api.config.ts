/**
 * 地球村健康小程序 - 接口配置模板
 * 
 * 使用方法：将 API_BASE_URL 替换为线上域名即可
 * 示例：https://api.junlanhealth.com
 * 
 * 所有接口按功能模块分类，统一走 Supabase REST API
 */

// ============================================
// 🔧 核心配置（拿到域名后只需改这一处）
// ============================================

// TODO: 替换为线上域名
export const API_BASE_URL = 'https://singular-gelato-96a14a.netlify.app'

// Supabase 直连（小程序可直接调用，不经过自建后端）
export const SUPABASE_URL = 'https://lretoiyxmdyzlffufrgc.supabase.co'
export const SUPABASE_ANON_KEY = 'sb_publishable_X_GL1TD0lykftEtDRBD2Rg_DoS3Fypv'

// ============================================
// 📡 接口地址映射
// ============================================

export const API = {
  // ---- 用户模块 ----
  // 微信登录（需自建后端，用线上域名）
  AUTH_WECHAT_LOGIN: `${API_BASE_URL}/api/v1/auth/wechat`,
  
  // Supabase 直连（无需自建后端）
  USER_PROFILE: `${SUPABASE_URL}/rest/v1/users`,
  USER_CREDIT_SCORE: `${SUPABASE_URL}/rest/v1/user_credit_scores`,
  
  // ---- 舌诊模块 ----
  // 舌诊记录（Supabase 直连）
  TONGUE_RECORDS: `${SUPABASE_URL}/rest/v1/tongue_diagnosis_records`,
  CONSTITUTION_TYPES: `${SUPABASE_URL}/rest/v1/constitution_types`,
  
  // 舌诊AI分析（扣子Bot，后续接入）
  TONGUE_AI_ANALYZE: `${API_BASE_URL}/api/v1/tongue-diagnosis`,
  
  // ---- 积分模块 ----
  // 积分账户（Supabase 直连）
  POINT_ACCOUNT: `${SUPABASE_URL}/rest/v1/point_accounts`,
  POINT_TRANSACTIONS: `${SUPABASE_URL}/rest/v1/point_transactions`,
  POINT_RULES: `${SUPABASE_URL}/rest/v1/point_rules`,
  POINT_REDEMPTIONS: `${SUPABASE_URL}/rest/v1/point_redemptions`,
  REDEEMABLE_ITEMS: `${SUPABASE_URL}/rest/v1/redeemable_items`,
  CHECKIN_RECORDS: `${SUPABASE_URL}/rest/v1/checkin_records`,
  
  // 积分操作（Supabase RPC函数）
  ADD_POINTS: `${SUPABASE_URL}/rest/v1/rpc/add_points`,
  CONSUME_POINTS: `${SUPABASE_URL}/rest/v1/rpc/consume_points`,
  REDEEM_ITEM: `${SUPABASE_URL}/rest/v1/rpc/redeem_item`,
  
  // ---- 保障模块 ----
  GUARANTEE_STATUS: `${SUPABASE_URL}/rest/v1/guarantee_status`,
  CONSUMPTION_RECORDS: `${SUPABASE_URL}/rest/v1/consumption_records`,
  CONTRIBUTION_RECORDS: `${SUPABASE_URL}/rest/v1/contribution_records`,
  CONTRIBUTION_POINT_RULES: `${SUPABASE_URL}/rest/v1/contribution_point_rules`,
  
  // 保障计算（Supabase RPC函数）
  CALC_GUARANTEE_RATIO: `${SUPABASE_URL}/rest/v1/rpc/calculate_guarantee_ratio`,
  CALC_CONSUMPTION_YEARS: `${SUPABASE_URL}/rest/v1/rpc/calculate_consumption_years`,
  
  // ---- 信用模块 ----
  CREDIT_RECORDS: `${SUPABASE_URL}/rest/v1/credit_records`,
  CREDIT_CHANGE_RULES: `${SUPABASE_URL}/rest/v1/credit_change_rules`,
}

// ============================================
// 🔑 请求头模板
// ============================================

/** Supabase 请求头（anon权限，RLS保护） */
export const supabaseHeaders = {
  'apikey': SUPABASE_ANON_KEY,
  'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
  'Content-Type': 'application/json',
}

/** 自建后端请求头（带JWT Token） */
export function getAuthHeaders(token: string) {
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  }
}

// ============================================
// 📋 接口调用示例（拿到域名后参照使用）
// ============================================

/**
 * 1. 微信登录
 * POST /api/v1/auth/wechat
 * Body: { code: '微信登录码' }
 * Response: { user_id, token, is_new_user, profile }
 */

/**
 * 2. 查询积分余额
 * GET /rest/v1/point_accounts?user_id=eq.{userId}
 * Headers: supabaseHeaders
 * Response: [{ current_balance, total_earned, ... }]
 */

/**
 * 3. 每日签到
 * POST /rest/v1/rpc/add_points
 * Headers: supabaseHeaders
 * Body: { p_user_id, p_action_code: 'daily_checkin', p_source_type: 'activity', ... }
 * Response: { success: true, points_added: 2 }
 */

/**
 * 4. 查询保障状态
 * GET /rest/v1/guarantee_status?user_id=eq.{userId}
 * Headers: supabaseHeaders
 * Response: [{ guarantee_ratio, consumption_years, status, ... }]
 */

/**
 * 5. 查询可兑换物品
 * GET /rest/v1/redeemable_items?is_active=eq.true&order=display_order.asc
 * Headers: supabaseHeaders
 * Response: [{ name, points_required, ... }]
 */

/**
 * 6. 计算保障比例
 * POST /rest/v1/rpc/calculate_guarantee_ratio
 * Headers: supabaseHeaders
 * Body: { p_years: 5 }
 * Response: 10.00
 */

// ============================================
// ⚙️ 微信小程序域名配置（需在mp.weixin.qq.com配置）
// ============================================

/**
 * 拿到线上域名后，在微信小程序后台配置：
 * 
 * 登录 mp.weixin.qq.com → 开发管理 → 开发设置 → 服务器域名
 * 
 * request合法域名：
 *   - https://lretoiyxmdyzlffufrgc.supabase.co  （Supabase）
 *   - https://{{YOUR_DOMAIN}}                     （自建后端）
 * 
 * uploadFile合法域名（舌诊图片上传）：
 *   - https://lretoiyxmdyzlffufrgc.supabase.co
 *   - https://{{YOUR_DOMAIN}}
 */
