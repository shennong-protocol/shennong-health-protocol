const api = require('../../services/supabase.js')

const wisdomQuotes = [
  '价值感是最好的药',
  '健康是价值的外显，财富是健康的外显',
  '认真吃饭，好好睡觉，对人善良，对己克制',
  '自己的汗养自己的人',
  '有肌肉的人接得住机会',
  '醒来不是病，焦虑才是病'
]

const dailyTips = [
  '今天喝够水了吗？',
  '按时吃饭，认真吃饭',
  '睡得好，才能活得好',
  '动一动，十年少',
  '心宽体健，百病不侵'
]

Page({
  data: {
    checkedIn: false,
    pointsBalance: 0,
    guaranteeRatio: 0,
    wisdomQuote: '',
    dailyTip: '',
    userId: ''
  },

  onLoad() {
    const app = getApp()
    const userId = wx.getStorageSync('userId') || '7711c554-18e5-4e15-baab-81441711b39d'
    this.setData({ userId })

    // 随机每日一句
    const today = new Date().getDate()
    this.setData({
      wisdomQuote: wisdomQuotes[today % wisdomQuotes.length],
      dailyTip: dailyTips[today % dailyTips.length]
    })

    this.loadData()
  },

  onShow() {
    this.loadData()
  },

  async loadData() {
    try {
      // 加载积分
      const accounts = await api.getPointAccount(this.data.userId)
      if (accounts && accounts.length > 0) {
        this.setData({ pointsBalance: accounts[0].current_balance })
      }

      // 加载保障
      const guarantees = await api.getGuaranteeStatus(this.data.userId)
      if (guarantees && guarantees.length > 0) {
        this.setData({ guaranteeRatio: guarantees[0].guarantee_ratio || 0 })
      }

      // 检查今日签到
      const today = new Date().toISOString().split('T')[0]
      const records = await api.getPointTransactions(this.data.userId, 5)
      const checkedIn = records && records.some(r => 
        r.action_code === 'daily_checkin' && 
        r.transaction_time && r.transaction_time.startsWith(today)
      )
      this.setData({ checkedIn })
    } catch (err) {
      console.log('数据加载失败:', err)
    }
  },

  async handleCheckin() {
    if (this.data.checkedIn) {
      wx.showToast({ title: '今日已签到', icon: 'none' })
      return
    }

    try {
      const result = await api.dailyCheckin(this.data.userId)
      if (result && result.success) {
        this.setData({ checkedIn: true })
        wx.showToast({ title: `签到成功 +${result.points_added}积分`, icon: 'success' })
        this.loadData()
      }
    } catch (err) {
      wx.showToast({ title: '签到失败，请重试', icon: 'none' })
    }
  },

  goTongue() {
    wx.switchTab({ url: '/pages/tongue/tongue' })
  },

  goPoints() {
    wx.switchTab({ url: '/pages/points/points' })
  },

  goGuarantee() {
    wx.navigateTo({ url: '/pages/guarantee/guarantee' })
  }
})
