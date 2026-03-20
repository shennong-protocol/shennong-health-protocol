# shennong_cao.py - 神农转腰双效操自动化记录脚本
# 协议：AGPL v3 - 规则属于社区，代码即法律
import datetime
import json

def calculate_limp(before_bp, after_bp, duration_min):
    """
    简易LIMP积分算法：
    基础分：10分
    血压改善奖励：(收缩压下降值) * 2
    时长奖励：每分钟 0.5分
    """
    base_score = 10
    bp_drop = (before_bp[0] - after_bp[0]) if before_bp[0] > after_bp[0] else 0
    time_score = duration_min * 0.5
    total_limp = base_score + (bp_drop * 2) + time_score
    return max(total_limp, 0) # 确保不为负

def main():
    print("=== 神农地球村 · 转腰双效操打卡系统 ===")
    user_id = input("请输入您的用户ID (或昵称): ")
    
    try:
        b_before = int(input("运动前收缩压 (mmHg): "))
        b_after = int(input("运动后收缩压 (mmHg): "))
        duration = float(input("运动时长 (分钟): "))
        
        limp_score = calculate_limp((b_before, 0), (b_after, 0), duration)
        
        record = {
            "user_id": user_id,
            "timestamp": datetime.datetime.now().isoformat(),
            "before_bp": b_before,
            "after_bp": b_after,
            "duration": duration,
            "limp_earned": limp_score,
            "status": "verified_auto"
        }
        
        # 模拟写入数据库 (实际生产环境请对接飞书API或Coze)
        print("\n--- ✅ 打卡成功 ---")
        print(f"用户: {user_id}")
        print(f"获得 LIMP 积分: {limp_score:.2f}")
        print(f"凭证哈希: {hash(json.dumps(record)) % 1000000}")
        print("数据已上链 (模拟)，不可篡改。")
        
        with open("health_log.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
            
    except Exception as e:
        print(f"❌ 记录失败: {e}")

if __name__ == "__main__":
    main()