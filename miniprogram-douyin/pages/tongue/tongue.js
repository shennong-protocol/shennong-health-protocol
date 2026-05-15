const api = require('../../services/supabase.js')

Page({
  data: {
    constitutionTypes: [],
    records: []
  },

  onLoad() {
    this.loadConstitutions()
  },

  onShow() {
    this.loadRecords()
  },

  async loadConstitutions() {
    try {
      const types = await api.getConstitutionTypes()
      if (types && types.length > 0) {
        this.setData({ constitutionTypes: types })
      }
    } catch (err) {
      console.log('体质类型加载失败:', err)
    }
  },

  async loadRecords() {
    const userId = tt.getStorageSync('userId') || '7711c554-18e5-4e15-baab-81441711b39d'
    try {
      const records = await api.getTongueRecords(userId, 10)
      this.setData({ records: records || [] })
    } catch (err) {
      console.log('舌象记录加载失败:', err)
    }
  },

  takePhoto() {
    tt.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['camera'],
      success: (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath
        this.analyzeTongue(tempFilePath)
      }
    })
  },

  chooseImage() {
    tt.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album'],
      success: (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath
        this.analyzeTongue(tempFilePath)
      }
    })
  },

  analyzeTongue(imagePath) {
    tt.showLoading({ title: '分析中...' })
    // TODO: 调用神农舌象分析API
    // 目前模拟结果
    setTimeout(() => {
      tt.hideLoading()
      tt.showModal({
        title: '舌象记录',
        content: '您的体质特征为：平和质\n参考度：85%\n\n建议：保持良好的生活习惯，注意饮食均衡。\n\n⚠️ 本服务仅提供健康信息参考，不构成医疗诊断建议。',
        showCancel: false
      })
    }, 2000)
  }
})
