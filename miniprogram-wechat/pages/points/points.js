const api = require('../../services/supabase.js')

Page({
  data: {
    pointsBalance: 0,
    consumptionPts: 0,
    contributionPts: 0,
    activityPts: 0,
    checkedIn: false,
    redeemItems: [],
    transactions: []
  },

  onLoad() {
    this.loadData()
  },

  onShow() {
    this.loadData()
  },

  async loadData() {
    const userId = wx.getStorageSync('userId') || '7711c554-18e5-4e15-baab-81441711b39d'
    try {
      // 积分账户
      const accounts = await api.getPointAccount(userId)
      if (accounts && accounts.length > 0) {
        const acc = accounts[0]
        this.setData({
          pointsBalance: acc.current_balance,
          consumptionPts: acc.consumption_points,
          contributionPts: acc.contribution_points,
          activityPts: acc.activity_points
        })
      }

      // 签到状态
      const today = new Date().toISOString().split('T')[0]
      const records = await api.getPointTransactions(userId, 5)
      const checkedIn = records && records.some(r =>
        r.action_code === 'daily_checkin' &&
        r.transaction_time && r.transaction_time.startsWith(today)
      )
      this.setData({ checkedIn })

      // 可兑换物品
      const items = await api.getRedeemableItems()
      this.setData({ redeemItems: items || [] })

      // 积分明细
      const txs = await api.getPointTransactions(userId, 20)
      this.setData({ transactions: txs || [] })
    } catch (err) {
      console.log('积分数据加载失败:', err)
    }
  },

  async handleCheckin() {
    if (this.data.checkedIn) {
      wx.showToast({ title: '今日已签到', icon: 'none' })
      return
    }
    const userId = wx.getStorageSync('userId') || '7711c554-18e5-4e15-baab-81441711b39d'
    try {
      const result = await api.dailyCheckin(userId)
      if (result && result.success) {
        wx.showToast({ title: `签到成功 +${result.points_added}积分`, icon: 'success' })
        this.loadData()
      }
    } catch (err) {
      wx.showToast({ title: '签到失败', icon: 'none' })
    }
  },

  redeemItem(e) {
    const item = e.currentTarget.dataset.item
    wx.showModal({
      title: '确认兑换',
      content: `使用 ${item.points_required} 积分兑换「${item.name}」？`,
      success: (res) => {
        if (res.confirm) {
          wx.showToast({ title: '兑换功能开发中', icon: 'none' })
        }
      }
    })
  }
})
