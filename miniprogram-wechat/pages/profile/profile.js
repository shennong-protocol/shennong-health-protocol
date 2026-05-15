const api = require('../../services/supabase.js')

Page({
  data: {
    constitutionType: '',
    creditScore: 0,
    creditLevel: '未评定'
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
      // 用户信息
      const users = await api.getUserProfile(userId)
      if (users && users.length > 0) {
        const user = users[0]
        this.setData({ constitutionType: user.constitution_type || '' })
      }

      // 信用分
      const scores = await api.getCreditScore(userId)
      if (scores && scores.length > 0) {
        const score = scores[0]
        this.setData({
          creditScore: score.credit_score || 0,
          creditLevel: score.credit_level || '未评定'
        })
      }
    } catch (err) {
      console.log('用户数据加载失败:', err)
    }
  },

  goGuarantee() {
    wx.navigateTo({ url: '/pages/guarantee/guarantee' })
  },

  goContribution() {
    wx.showToast({ title: '贡献记录开发中', icon: 'none' })
  },

  goConsumption() {
    wx.showToast({ title: '消费记录开发中', icon: 'none' })
  },

  goTongueHistory() {
    wx.switchTab({ url: '/pages/tongue/tongue' })
  },

  showAbout() {
    wx.showModal({
      title: '关于地球村健康',
      content: '地球村健康——神农地球村·全球健康保障共同体\n\n让每个人有价值地活着\n\n三大核心：神农保障、神农积分、神农消费\n\n本服务仅提供健康信息参考，不构成医疗诊断建议\n\n代码即规则，自动执行，去人治\n\n保障为实物和服务，非现金\n积分不可提现，仅用于兑换平台服务',
      showCancel: false
    })
  },

  showPrivacy() {
    wx.showModal({
      title: '隐私政策',
      content: '1. 我们重视您的隐私保护\n2. 健康数据加密存储，不对外售卖\n3. 积分和信用数据仅用于平台服务\n4. 您可随时要求删除个人数据\n5. 代码即规则，数据操作自动执行',
      showCancel: false
    })
  }
})
