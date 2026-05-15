const api = require('../../services/supabase.js')

Page({
  data: {
    guaranteeRatio: 0,
    contributions: []
  },

  onLoad() {
    this.loadData()
  },

  onShow() {
    this.loadData()
  },

  async loadData() {
    const userId = tt.getStorageSync('userId') || '7711c554-18e5-4e15-baab-81441711b39d'
    try {
      // 保障状态 - 查询personal_funds表获取保障信息
      const funds = await api.getPersonalFunds(userId)
      if (funds && funds.length > 0) {
        this.setData({ guaranteeRatio: funds[0].guarantee_ratio || 0 })
      }

      // 贡献记录
      const contributions = await api.getContributionRecords(userId, 20)
      this.setData({ contributions: contributions || [] })
    } catch (err) {
      console.log('保障数据加载失败:', err)
    }
  }
})
