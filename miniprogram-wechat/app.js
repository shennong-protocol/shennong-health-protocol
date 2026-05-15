App({
  onLaunch() {
    // 检查登录状态
    const userInfo = wx.getStorageSync('userInfo')
    if (!userInfo) {
      this.login()
    }
  },

  globalData: {
    userInfo: null,
    // ⚠️ MVP临时方案：使用真实测试用户ID
    // 正式上线前必须接入微信登录获取真实用户
    userId: 'YOUR_USER_ID_HERE',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    // ⚠️ 重要：正式上线前必须使用 anon key
    // service_role key 仅用于服务端，不应暴露在客户端代码中
    supabaseKey: 'YOUR_ANON_KEY_HERE',
    apiBaseUrl: 'https://your-api-server.com'
  },

  login() {
    wx.login({
      success: (res) => {
        if (res.code) {
          console.log('登录code:', res.code)
          // TODO: 发送code到后端换取openid和token
          // 目前先使用本地模拟的测试用户ID
          const testUserId = this.globalData.userId
          wx.setStorageSync('userId', testUserId)
          this.globalData.userId = testUserId
        }
      }
    })
  }
})
