App({
  onLaunch() {
    // 检查登录状态
    const userInfo = tt.getStorageSync('userInfo')
    if (!userInfo) {
      this.login()
    }
  },

  globalData: {
    userInfo: null,
    userId: 'YOUR_USER_ID_HERE',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseKey: 'YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE',
    apiBaseUrl: 'https://your-api-server.com'
  },

  login() {
    tt.login({
      success: (res) => {
        if (res.code) {
          console.log('登录成功:', res.code)
        }
      }
    })
  }
})
