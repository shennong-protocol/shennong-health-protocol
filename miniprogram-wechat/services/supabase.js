// Supabase API 封装
const app = getApp()

// ============================================
// ⚠️ MVP临时方案：使用service_role key绕过RLS
// 上线前必须替换为正式认证方案！
// ============================================
const SUPABASE_URL = 'https://lretoiyxmdyzlffufrgc.supabase.co'
const SUPABASE_SERVICE_KEY = 'YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE'

function supabaseRequest(path, options = {}) {
  const { method = 'GET', data, query } = options
  
  let url = `${SUPABASE_URL}/rest/v1/${path}`
  if (query) {
    const params = Object.entries(query).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&')
    url += `?${params}`
  }

  return new Promise((resolve, reject) => {
    wx.request({
      url,
      method,
      header: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': method === 'POST' ? 'return=representation' : undefined
      },
      data: method !== 'GET' ? data : undefined,
      success: (res) => {
        if (res.statusCode >= 400) {
          reject(new Error(`API Error: ${res.statusCode} ${JSON.stringify(res.data)}`))
        } else {
          resolve(res.data)
        }
      },
      fail: (err) => reject(err)
    })
  })
}

// 用户模块
function getUserProfile(userId) {
  return supabaseRequest('users', { query: { id: `eq.${userId}`, select: '*' } })
}

// 积分模块
function getPointAccount(userId) {
  return supabaseRequest('point_accounts', { query: { user_id: `eq.${userId}`, select: '*' } })
}

function addPoints(params) {
  return supabaseRequest('rpc/add_points', {
    method: 'POST',
    data: {
      p_user_id: params.userId,
      p_action_code: params.actionCode,
      p_source_type: params.sourceType,
      p_source_id: params.sourceId || crypto.randomUUID(),
      p_description: params.description || '',
      p_description_zh: params.descriptionZh || ''
    }
  })
}

function dailyCheckin(userId) {
  return addPoints({
    userId,
    actionCode: 'daily_checkin',
    sourceType: 'activity',
    description: 'Daily check-in',
    descriptionZh: '每日签到'
  })
}

function getPointTransactions(userId, limit = 20) {
  return supabaseRequest('point_transactions', {
    query: {
      user_id: `eq.${userId}`,
      order: 'transaction_time.desc',
      limit: String(limit),
      select: '*'
    }
  })
}

function getRedeemableItems() {
  return supabaseRequest('redeemable_items', {
    query: { is_active: 'eq.true', order: 'display_order.asc', select: '*' }
  })
}

// 保障模块
function getGuaranteeStatus(userId) {
  return supabaseRequest('guarantee_status', { query: { user_id: `eq.${userId}`, select: '*' } })
}

// 保障专户查询
function getPersonalFunds(userId) {
  return supabaseRequest('personal_funds', { query: { user_id: `eq.${userId}`, select: '*' } })
}

function calcGuaranteeRatio(years) {
  return supabaseRequest('rpc/calculate_guarantee_ratio', {
    method: 'POST',
    data: { p_years: years }
  })
}

function getConsumptionRecords(userId, limit = 20) {
  return supabaseRequest('consumption_records', {
    query: { user_id: `eq.${userId}`, order: 'consumption_time.desc', limit: String(limit), select: '*' }
  })
}

function getContributionRecords(userId, limit = 20) {
  return supabaseRequest('contribution_records', {
    query: { user_id: `eq.${userId}`, order: 'contribution_time.desc', limit: String(limit), select: '*' }
  })
}

// 舌象模块
function getTongueRecords(userId, limit = 10) {
  return supabaseRequest('tongue_diagnosis_records', {
    query: { user_id: `eq.${userId}`, order: 'diagnosis_time.desc', limit: String(limit), select: '*' }
  })
}

function getConstitutionTypes() {
  return supabaseRequest('constitution_types', { query: { select: 'code,name,description' } })
}

// 积分规则
function getPointRules() {
  return supabaseRequest('point_rules', { query: { is_active: 'eq.true', select: '*' } })
}

// 信用模块
function getCreditScore(userId) {
  return supabaseRequest('user_credit_scores', { query: { user_id: `eq.${userId}`, select: '*' } })
}

module.exports = {
  supabaseRequest,
  getUserProfile,
  getPointAccount,
  addPoints,
  dailyCheckin,
  getPointTransactions,
  getRedeemableItems,
  getGuaranteeStatus,
  getPersonalFunds,
  calcGuaranteeRatio,
  getConsumptionRecords,
  getContributionRecords,
  getTongueRecords,
  getConstitutionTypes,
  getPointRules,
  getCreditScore
}
