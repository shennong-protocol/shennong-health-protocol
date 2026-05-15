/**
 * 地球村健康小程序 - Supabase API 封装
 * 所有数据库操作统一走这里，方便联调
 */

import { SUPABASE_URL, SUPABASE_ANON_KEY, supabaseHeaders } from './api.config'

// ============================================
// 通用请求方法
// ============================================

async function supabaseRequest(
  path: string,
  options: {
    method?: 'GET' | 'POST' | 'PATCH' | 'DELETE'
    body?: any
    query?: Record<string, string>
    headers?: Record<string, string>
  } = {}
) {
  const { method = 'GET', body, query, headers = {} } = options
  
  let url = `${SUPABASE_URL}/rest/v1/${path}`
  if (query) {
    const params = new URLSearchParams(query)
    url += `?${params.toString()}`
  }

  const response = await wx.request({
    url,
    method,
    header: {
      ...supabaseHeaders,
      ...headers,
    },
    data: body ? JSON.stringify(body) : undefined,
  })

  if (response.statusCode >= 400) {
    throw new Error(`API Error: ${response.statusCode} ${JSON.stringify(response.data)}`)
  }

  return response.data
}

// ============================================
// 用户模块
// ============================================

/** 获取用户信息 */
export function getUserProfile(userId: string) {
  return supabaseRequest('users', {
    query: { id: `eq.${userId}`, select: '*' },
  })
}

/** 更新用户信息 */
export function updateUserProfile(userId: string, data: Record<string, any>) {
  return supabaseRequest('users', {
    method: 'PATCH',
    query: { id: `eq.${userId}` },
    body: data,
    headers: { Prefer: 'return=representation' },
  })
}

/** 更新用户体质类型 */
export function updateConstitution(userId: string, constitutionType: string) {
  return updateUserProfile(userId, {
    constitution_type: constitutionType,
    last_diagnosis_time: new Date().toISOString(),
  })
}

// ============================================
// 积分模块
// ============================================

/** 查询积分账户 */
export function getPointAccount(userId: string) {
  return supabaseRequest('point_accounts', {
    query: { user_id: `eq.${userId}`, select: '*' },
  })
}

/** 添加积分（签到/贡献/消费等） */
export function addPoints(params: {
  userId: string
  actionCode: string
  sourceType: string
  sourceId: string
  description?: string
  descriptionZh?: string
}) {
  return supabaseRequest('rpc/add_points', {
    method: 'POST',
    body: {
      p_user_id: params.userId,
      p_action_code: params.actionCode,
      p_source_type: params.sourceType,
      p_source_id: params.sourceId,
      p_description: params.description || '',
      p_description_zh: params.descriptionZh || '',
    },
  })
}

/** 每日签到 */
export function dailyCheckin(userId: string) {
  return addPoints({
    userId,
    actionCode: 'daily_checkin',
    sourceType: 'activity',
    sourceId: crypto.randomUUID(),
    description: 'Daily check-in',
    descriptionZh: '每日签到',
  })
}

/** 消费积分 */
export function consumePoints(params: {
  userId: string
  actionCode: string
  sourceType: string
  sourceId: string
  points: number
  description?: string
}) {
  return supabaseRequest('rpc/consume_points', {
    method: 'POST',
    body: {
      p_user_id: params.userId,
      p_action_code: params.actionCode,
      p_source_type: params.sourceType,
      p_source_id: params.sourceId,
      p_points: params.points,
      p_description: params.description || '',
    },
  })
}

/** 查询积分流水 */
export function getPointTransactions(userId: string, limit = 20, offset = 0) {
  return supabaseRequest('point_transactions', {
    query: {
      user_id: `eq.${userId}`,
      order: 'transaction_time.desc',
      limit: String(limit),
      offset: String(offset),
      select: '*',
    },
  })
}

/** 查询可兑换物品 */
export function getRedeemableItems() {
  return supabaseRequest('redeemable_items', {
    query: {
      is_active: 'eq.true',
      order: 'display_order.asc',
      select: '*',
    },
  })
}

/** 兑换物品 */
export function redeemItem(params: {
  userId: string
  itemId: string
}) {
  return supabaseRequest('rpc/redeem_item', {
    method: 'POST',
    body: {
      p_user_id: params.userId,
      p_item_id: params.itemId,
    },
  })
}

// ============================================
// 保障模块
// ============================================

/** 查询保障状态 */
export function getGuaranteeStatus(userId: string) {
  return supabaseRequest('guarantee_status', {
    query: { user_id: `eq.${userId}`, select: '*' },
  })
}

/** 计算保障比例 */
export function calcGuaranteeRatio(years: number) {
  return supabaseRequest('rpc/calculate_guarantee_ratio', {
    method: 'POST',
    body: { p_years: years },
  })
}

/** 计算消费年数 */
export function calcConsumptionYears(userId: string) {
  return supabaseRequest('rpc/calculate_consumption_years', {
    method: 'POST',
    body: { p_user_id: userId },
  })
}

/** 查询消费记录 */
export function getConsumptionRecords(userId: string, limit = 20) {
  return supabaseRequest('consumption_records', {
    query: {
      user_id: `eq.${userId}`,
      order: 'consumption_time.desc',
      limit: String(limit),
      select: '*',
    },
  })
}

/** 查询贡献记录 */
export function getContributionRecords(userId: string, limit = 20) {
  return supabaseRequest('contribution_records', {
    query: {
      user_id: `eq.${userId}`,
      order: 'contribution_time.desc',
      limit: String(limit),
      select: '*',
    },
  })
}

// ============================================
// 舌诊模块
// ============================================

/** 查询舌诊记录 */
export function getTongueRecords(userId: string, limit = 10) {
  return supabaseRequest('tongue_diagnosis_records', {
    query: {
      user_id: `eq.${userId}`,
      order: 'diagnosis_time.desc',
      limit: String(limit),
      select: '*',
    },
  })
}

/** 保存舌诊记录 */
export function saveTongueRecord(data: {
  userId: string
  tongueImageUrl: string
  constitutionType: string
  confidence: number
  diagnosisSummary: string
  adviceDetail: any
  tongueColor?: string
  coatingColor?: string
  coatingThickness?: string
  hasToothMark?: boolean
  crack?: string
  sublingualVein?: string
}) {
  return supabaseRequest('tongue_diagnosis_records', {
    method: 'POST',
    body: {
      user_id: data.userId,
      tongue_image_url: data.tongueImageUrl,
      constitution_type: data.constitutionType,
      constitution_confidence: data.confidence,
      diagnosis_summary: data.diagnosisSummary,
      advice_detail: data.adviceDetail,
      tongue_color: data.tongueColor,
      coating_color: data.coatingColor,
      coating_thickness: data.coatingThickness,
      tooth_mark: data.hasToothMark || false,
      crack: data.crack,
      sublingual_vein: data.sublingualVein,
    },
    headers: { Prefer: 'return=representation' },
  })
}

// ============================================
// 信用模块
// ============================================

/** 查询信用分 */
export function getCreditScore(userId: string) {
  return supabaseRequest('user_credit_scores', {
    query: { user_id: `eq.${userId}`, select: '*' },
  })
}

/** 查询信用变动记录 */
export function getCreditRecords(userId: string, limit = 20) {
  return supabaseRequest('credit_records', {
    query: {
      user_id: `eq.${userId}`,
      order: 'change_time.desc',
      limit: String(limit),
      select: '*',
    },
  })
}

// ============================================
// 九种体质字典
// ============================================

/** 查询所有体质类型 */
export function getConstitutionTypes() {
  return supabaseRequest('constitution_types', {
    query: { select: 'code,name,description' },
  })
}

// ============================================
// 积分规则
// ============================================

/** 查询积分规则 */
export function getPointRules() {
  return supabaseRequest('point_rules', {
    query: { is_active: 'eq.true', select: '*' },
  })
}
