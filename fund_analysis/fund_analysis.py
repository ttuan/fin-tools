#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Phân tích dữ liệu giao dịch quỹ đầu tư tháng 8/2024
Tác giả: AI Analyst
Ngày: 10/01/2025
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Cấu hình hiển thị
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10
sns.set_style("whitegrid")

def load_and_clean_data(file_path):
    """Load và làm sạch dữ liệu"""
    print("🔄 Đang tải dữ liệu...")

    # Đọc file CSV, bỏ qua dòng đầu tiên (header trống)
    df = pd.read_csv(file_path, skiprows=1)

    # Làm sạch dữ liệu
    df = df.dropna(subset=['Fund Name', 'Stock Code'])  # Bỏ các dòng trống

    # Chuyển đổi kiểu dữ liệu
    df['Previous %'] = df['Previous %'].str.replace('%', '').astype(float)
    df['Current %'] = df['Current %'].str.replace('%', '').astype(float)
    df['Change %'] = df['Change %'].str.replace('%', '').astype(float)
    df['Change Points'] = df['Change Points'].astype(float)

    print(f"✅ Đã tải {len(df)} giao dịch từ {df['Fund Name'].nunique()} quỹ")
    return df

def basic_statistics(df):
    """Tạo thống kê cơ bản"""
    print("\n" + "="*60)
    print("📊 THỐNG KÊ CƠ BẢN")
    print("="*60)

    # Thống kê theo trạng thái
    status_counts = df['Status'].value_counts()
    print(f"\n📈 Phân bố theo trạng thái giao dịch:")
    for status, count in status_counts.items():
        percentage = (count / len(df)) * 100
        print(f"  {status}: {count:,} giao dịch ({percentage:.1f}%)")

    # Thống kê về thay đổi tỷ trọng
    print(f"\n📊 Thống kê thay đổi tỷ trọng (%):")
    print(f"  Trung bình: {df['Change %'].mean():.2f}%")
    print(f"  Trung vị: {df['Change %'].median():.2f}%")
    print(f"  Độ lệch chuẩn: {df['Change %'].std():.2f}%")
    print(f"  Min: {df['Change %'].min():.2f}%")
    print(f"  Max: {df['Change %'].max():.2f}%")

    # Thống kê theo quỹ
    fund_stats = df.groupby('Fund Name').agg({
        'Change %': ['count', 'mean', 'sum'],
        'Change Points': 'sum'
    }).round(2)
    fund_stats.columns = ['Số giao dịch', 'Thay đổi TB (%)', 'Tổng thay đổi (%)', 'Tổng điểm thay đổi']
    fund_stats = fund_stats.sort_values('Số giao dịch', ascending=False)

    print(f"\n🏆 Top 10 quỹ có nhiều giao dịch nhất:")
    print(fund_stats.head(10).to_string())

    return status_counts, fund_stats

def analyze_stock_movements(df):
    """Phân tích chuyển động cổ phiếu với phân biệt giao dịch thực và biến động giá"""
    print("\n" + "="*60)
    print("📈 PHÂN TÍCH CHUYỂN ĐỘNG CỔ PHIẾU (CẢI TIẾN)")
    print("="*60)

    # Phân loại giao dịch theo mức độ thay đổi
    significant_trades = df[abs(df['Change %']) > 1.0]  # Giao dịch thực (>1% hoặc <-1%)
    price_adjustments = df[abs(df['Change %']) <= 1.0]  # Điều chỉnh do biến động giá (-1% đến 1%)

    print(f"\n📊 PHÂN LOẠI GIAO DỊCH:")
    print(f"  • Giao dịch thực sự (|thay đổi| > 1%): {len(significant_trades):,} giao dịch ({len(significant_trades)/len(df)*100:.1f}%)")
    print(f"  • Điều chỉnh do biến động giá (|thay đổi| ≤ 1%): {len(price_adjustments):,} giao dịch ({len(price_adjustments)/len(df)*100:.1f}%)")

    # Phân tích giao dịch thực sự
    print(f"\n🎯 PHÂN TÍCH GIAO DỊCH THỰC SỰ (|thay đổi| > 1%):")
    if len(significant_trades) > 0:
        sig_stock_stats = significant_trades.groupby('Stock Code').agg({
            'Change %': ['count', 'mean', 'sum'],
            'Status': lambda x: (x == 'NEW').sum()
        }).round(2)
        sig_stock_stats.columns = ['Số giao dịch', 'Thay đổi TB (%)', 'Tổng thay đổi (%)', 'Số lần mới']
        sig_stock_stats = sig_stock_stats.sort_values('Số giao dịch', ascending=False)

        print(f"  Top 15 cổ phiếu có giao dịch thực nhiều nhất:")
        print(sig_stock_stats.head(15).to_string())

        # Phân tích mua/bán
        buy_trades = significant_trades[significant_trades['Change %'] > 1.0]
        sell_trades = significant_trades[significant_trades['Change %'] < -1.0]

        print(f"\n📈 CỔ PHIẾU ĐƯỢC MUA NHIỀU (tăng tỷ trọng > 1%):")
        if len(buy_trades) > 0:
            buy_stats = buy_trades.groupby('Stock Code').agg({
                'Change %': ['count', 'sum', 'mean']
            }).round(2)
            buy_stats.columns = ['Số lần mua', 'Tổng tăng (%)', 'TB tăng (%)']
            buy_stats = buy_stats.sort_values('Số lần mua', ascending=False)
            print(buy_stats.head(10).to_string())

        print(f"\n📉 CỔ PHIẾU ĐƯỢC BÁN NHIỀU (giảm tỷ trọng < -1%):")
        if len(sell_trades) > 0:
            sell_stats = sell_trades.groupby('Stock Code').agg({
                'Change %': ['count', 'sum', 'mean']
            }).round(2)
            sell_stats.columns = ['Số lần bán', 'Tổng giảm (%)', 'TB giảm (%)']
            sell_stats = sell_stats.sort_values('Số lần bán', ascending=False)
            print(sell_stats.head(10).to_string())
    else:
        sig_stock_stats = None
        buy_stats = None
        sell_stats = None

    # Phân tích điều chỉnh do biến động giá
    print(f"\n⚖️ PHÂN TÍCH ĐIỀU CHỈNH DO BIẾN ĐỘNG GIÁ (-1% ≤ thay đổi ≤ 1%):")
    if len(price_adjustments) > 0:
        price_stock_stats = price_adjustments['Stock Code'].value_counts()
        print(f"  Top 15 cổ phiếu xuất hiện nhiều trong điều chỉnh giá:")
        print(price_stock_stats.head(15).to_string())
        print(f"\n  💡 Insight: Các cổ phiếu này được các quỹ nắm giữ ổn định, chỉ thay đổi tỷ trọng do biến động giá")
    else:
        price_stock_stats = None

    # Thống kê tổng hợp
    all_stock_stats = df.groupby('Stock Code').agg({
        'Change %': ['count', 'mean', 'sum'],
        'Status': lambda x: (x == 'NEW').sum()
    }).round(2)
    all_stock_stats.columns = ['Tổng giao dịch', 'Thay đổi TB (%)', 'Tổng thay đổi (%)', 'Số lần mới']
    all_stock_stats = all_stock_stats.sort_values('Tổng giao dịch', ascending=False)

    print(f"\n📊 TỔNG HỢP TẤT CẢ GIAO DỊCH:")
    print(f"  Top 15 cổ phiếu có nhiều giao dịch nhất (bao gồm cả điều chỉnh giá):")
    print(all_stock_stats.head(15).to_string())

    # Cổ phiếu được thêm mới và loại bỏ
    new_stocks = df[df['Status'] == 'NEW']['Stock Code'].value_counts()
    removed_stocks = df[df['Status'] == 'REMOVED']['Stock Code'].value_counts()

    if len(new_stocks) > 0:
        print(f"\n🆕 Top 10 cổ phiếu được thêm mới nhiều nhất:")
        print(new_stocks.head(10).to_string())

    if len(removed_stocks) > 0:
        print(f"\n❌ Top 10 cổ phiếu bị loại bỏ nhiều nhất:")
        print(removed_stocks.head(10).to_string())

    return {
        'all_stats': all_stock_stats,
        'significant_stats': sig_stock_stats,
        'buy_stats': buy_stats if 'buy_stats' in locals() else None,
        'sell_stats': sell_stats if 'sell_stats' in locals() else None,
        'price_adjustment_stats': price_stock_stats,
        'new_stocks': new_stocks,
        'removed_stocks': removed_stocks,
        'significant_trades': significant_trades,
        'price_adjustments': price_adjustments
    }

def create_visualizations(df, status_counts, fund_stats, stock_analysis):
    """Tạo các biểu đồ trực quan cải tiến"""
    print("\n🔄 Đang tạo biểu đồ...")

    # Phân loại giao dịch
    significant_trades = stock_analysis['significant_trades']
    price_adjustments = stock_analysis['price_adjustments']

    # Tạo figure với subplots
    fig, axes = plt.subplots(3, 3, figsize=(20, 16))
    fig.suptitle('Phân tích giao dịch quỹ đầu tư tháng 8/2024 (Phiên bản cải tiến)', fontsize=16, fontweight='bold')

    # 1. Phân bố trạng thái giao dịch
    axes[0, 0].pie(status_counts.values, labels=status_counts.index, autopct='%1.1f%%', startangle=90)
    axes[0, 0].set_title('Phân bố trạng thái giao dịch')

    # 2. So sánh giao dịch thực vs điều chỉnh giá
    trade_types = ['Giao dịch thực\n(|Δ| > 1%)', 'Điều chỉnh giá\n(|Δ| ≤ 1%)']
    trade_counts = [len(significant_trades), len(price_adjustments)]
    axes[0, 1].bar(trade_types, trade_counts, color=['#ff6b6b', '#4ecdc4'])
    axes[0, 1].set_title('Phân loại giao dịch theo mức độ thay đổi')
    axes[0, 1].set_ylabel('Số giao dịch')

    # 3. Histogram thay đổi tỷ trọng - giao dịch thực
    if len(significant_trades) > 0:
        axes[0, 2].hist(significant_trades['Change %'], bins=20, alpha=0.7, color='red', edgecolor='black')
        axes[0, 2].axvline(significant_trades['Change %'].mean(), color='darkred', linestyle='--',
                          label=f'TB: {significant_trades["Change %"].mean():.2f}%')
        axes[0, 2].set_title('Phân bố giao dịch thực (|Δ| > 1%)')
        axes[0, 2].set_xlabel('Thay đổi tỷ trọng (%)')
        axes[0, 2].legend()

    # 4. Top 10 quỹ có nhiều giao dịch
    top_funds = fund_stats.head(10)
    axes[1, 0].barh(range(len(top_funds)), top_funds['Số giao dịch'])
    axes[1, 0].set_yticks(range(len(top_funds)))
    axes[1, 0].set_yticklabels([name[:25] + '...' if len(name) > 25 else name for name in top_funds.index])
    axes[1, 0].set_title('Top 10 quỹ có nhiều giao dịch')
    axes[1, 0].set_xlabel('Số giao dịch')

    # 5. Cổ phiếu được mua nhiều nhất
    if stock_analysis['buy_stats'] is not None and len(stock_analysis['buy_stats']) > 0:
        top_buys = stock_analysis['buy_stats'].head(10)
        axes[1, 1].barh(range(len(top_buys)), top_buys['Số lần mua'], color='green')
        axes[1, 1].set_yticks(range(len(top_buys)))
        axes[1, 1].set_yticklabels(top_buys.index)
        axes[1, 1].set_title('Top 10 cổ phiếu được mua nhiều')
        axes[1, 1].set_xlabel('Số lần mua')

    # 6. Cổ phiếu được bán nhiều nhất
    if stock_analysis['sell_stats'] is not None and len(stock_analysis['sell_stats']) > 0:
        top_sells = stock_analysis['sell_stats'].head(10)
        axes[1, 2].barh(range(len(top_sells)), top_sells['Số lần bán'], color='red')
        axes[1, 2].set_yticks(range(len(top_sells)))
        axes[1, 2].set_yticklabels(top_sells.index)
        axes[1, 2].set_title('Top 10 cổ phiếu được bán nhiều')
        axes[1, 2].set_xlabel('Số lần bán')

    # 7. Cổ phiếu trong điều chỉnh giá
    if stock_analysis['price_adjustment_stats'] is not None and len(stock_analysis['price_adjustment_stats']) > 0:
        top_stable = stock_analysis['price_adjustment_stats'].head(10)
        axes[2, 0].barh(range(len(top_stable)), top_stable.values, color='orange')
        axes[2, 0].set_yticks(range(len(top_stable)))
        axes[2, 0].set_yticklabels(top_stable.index)
        axes[2, 0].set_title('Top 10 cổ phiếu ổn định\n(chỉ điều chỉnh do giá)')
        axes[2, 0].set_xlabel('Số lần xuất hiện')

    # 8. So sánh mua vs bán
    if stock_analysis['buy_stats'] is not None and stock_analysis['sell_stats'] is not None:
        buy_total = stock_analysis['buy_stats']['Số lần mua'].sum() if len(stock_analysis['buy_stats']) > 0 else 0
        sell_total = stock_analysis['sell_stats']['Số lần bán'].sum() if len(stock_analysis['sell_stats']) > 0 else 0

        axes[2, 1].bar(['Mua', 'Bán'], [buy_total, sell_total], color=['green', 'red'])
        axes[2, 1].set_title('Tổng số lần mua vs bán\n(giao dịch thực)')
        axes[2, 1].set_ylabel('Số lần giao dịch')

    # 9. Histogram điều chỉnh giá
    if len(price_adjustments) > 0:
        axes[2, 2].hist(price_adjustments['Change %'], bins=20, alpha=0.7, color='orange', edgecolor='black')
        axes[2, 2].axvline(price_adjustments['Change %'].mean(), color='darkorange', linestyle='--',
                          label=f'TB: {price_adjustments["Change %"].mean():.2f}%')
        axes[2, 2].set_title('Phân bố điều chỉnh giá (|Δ| ≤ 1%)')
        axes[2, 2].set_xlabel('Thay đổi tỷ trọng (%)')
        axes[2, 2].legend()

    plt.tight_layout()
    plt.savefig('/Users/ttuan/Desktop/fund_analysis_charts_refined.png', dpi=300, bbox_inches='tight')
    plt.show()

    print("✅ Đã lưu biểu đồ cải tiến tại: fund_analysis_charts_refined.png")

def generate_insights(df, status_counts, fund_stats, stock_analysis):
    """Tạo các insight và quan điểm cải tiến"""
    print("\n" + "="*60)
    print("💡 INSIGHT VÀ QUAN ĐIỂM PHÂN TÍCH (CẢI TIẾN)")
    print("="*60)

    # Phân loại giao dịch
    significant_trades = stock_analysis['significant_trades']
    price_adjustments = stock_analysis['price_adjustments']

    # Tính toán các chỉ số quan trọng
    total_transactions = len(df)
    significant_pct = (len(significant_trades) / total_transactions) * 100
    price_adjustment_pct = (len(price_adjustments) / total_transactions) * 100

    removed_pct = (status_counts['REMOVED'] / total_transactions) * 100
    changed_pct = (status_counts['CHANGED'] / total_transactions) * 100
    new_pct = (status_counts['NEW'] / total_transactions) * 100

    print(f"\n🔍 PHÂN TÍCH TỔNG QUAN (CẢI TIẾN):")
    print(f"  • Tổng số giao dịch: {total_transactions:,}")
    print(f"  • Giao dịch thực sự (|Δ| > 1%): {len(significant_trades):,} ({significant_pct:.1f}%)")
    print(f"  • Điều chỉnh do biến động giá (|Δ| ≤ 1%): {len(price_adjustments):,} ({price_adjustment_pct:.1f}%)")
    print(f"  • Tỷ lệ loại bỏ: {removed_pct:.1f}% ({status_counts['REMOVED']:,} giao dịch)")
    print(f"  • Tỷ lệ thêm mới: {new_pct:.1f}% ({status_counts['NEW']:,} giao dịch)")

    # Phân tích giao dịch thực
    if len(significant_trades) > 0:
        sig_avg_change = significant_trades['Change %'].mean()
        sig_positive = len(significant_trades[significant_trades['Change %'] > 1])
        sig_negative = len(significant_trades[significant_trades['Change %'] < -1])

        print(f"\n📊 PHÂN TÍCH GIAO DỊCH THỰC SỰ:")
        print(f"  • Thay đổi tỷ trọng trung bình: {sig_avg_change:.2f}%")
        print(f"  • Giao dịch mua (tăng > 1%): {sig_positive:,} ({sig_positive/len(significant_trades)*100:.1f}%)")
        print(f"  • Giao dịch bán (giảm < -1%): {sig_negative:,} ({sig_negative/len(significant_trades)*100:.1f}%)")

    # Phân tích cổ phiếu ổn định
    if len(price_adjustments) > 0:
        stable_avg_change = price_adjustments['Change %'].mean()
        print(f"\n⚖️ PHÂN TÍCH CỔ PHIẾU ỔN ĐỊNH:")
        print(f"  • Thay đổi trung bình do biến động giá: {stable_avg_change:.3f}%")
        print(f"  • Số cổ phiếu được nắm giữ ổn định: {price_adjustments['Stock Code'].nunique()}")

    # Xu hướng mua/bán
    print(f"\n📈📉 XU HƯỚNG MUA/BÁN:")
    if stock_analysis['buy_stats'] is not None and len(stock_analysis['buy_stats']) > 0:
        top_buy = stock_analysis['buy_stats'].head(1)
        print(f"  • Cổ phiếu được mua nhiều nhất: {top_buy.index[0]} ({top_buy.iloc[0]['Số lần mua']} lần)")
        total_buys = stock_analysis['buy_stats']['Số lần mua'].sum()
        print(f"  • Tổng số lần mua: {total_buys}")

    if stock_analysis['sell_stats'] is not None and len(stock_analysis['sell_stats']) > 0:
        top_sell = stock_analysis['sell_stats'].head(1)
        print(f"  • Cổ phiếu được bán nhiều nhất: {top_sell.index[0]} ({top_sell.iloc[0]['Số lần bán']} lần)")
        total_sells = stock_analysis['sell_stats']['Số lần bán'].sum()
        print(f"  • Tổng số lần bán: {total_sells}")

    # Cổ phiếu ổn định
    if stock_analysis['price_adjustment_stats'] is not None:
        most_stable = stock_analysis['price_adjustment_stats'].head(3)
        print(f"\n🏦 TOP CỔ PHIẾU ỔN ĐỊNH (được nắm giữ lâu dài):")
        for i, (stock, count) in enumerate(most_stable.items(), 1):
            print(f"  {i}. {stock}: {count} lần xuất hiện trong điều chỉnh giá")

    # Top quỹ hoạt động
    top_3_funds = fund_stats.head(3)
    print(f"\n🏆 TOP QUỸ HOẠT ĐỘNG MẠNH NHẤT:")
    for i, (fund, stats) in enumerate(top_3_funds.iterrows(), 1):
        print(f"  {i}. {fund[:40]}...")
        print(f"     - Tổng giao dịch: {stats['Số giao dịch']}")
        print(f"     - Thay đổi TB: {stats['Thay đổi TB (%)']:.2f}%")

    # Khuyến nghị cải tiến
    print(f"\n💼 KHUYẾN NGHỊ ĐẦU TƯ (CẢI TIẾN):")

    if significant_pct < 50:
        print(f"  ✅ Thị trường ổn định: Chỉ {significant_pct:.1f}% là giao dịch thực")
        print(f"     → Các quỹ đang duy trì danh mục, ít thay đổi lớn")
    else:
        print(f"  ⚠️ Thị trường biến động: {significant_pct:.1f}% là giao dịch thực")
        print(f"     → Cần theo dõi sát sao xu hướng thị trường")

    if stock_analysis['buy_stats'] is not None and stock_analysis['sell_stats'] is not None:
        if len(stock_analysis['buy_stats']) > len(stock_analysis['sell_stats']):
            print(f"  🚀 Xu hướng tích cực: Nhiều cổ phiếu được mua hơn bán")
        elif len(stock_analysis['sell_stats']) > len(stock_analysis['buy_stats']):
            print(f"  📉 Xu hướng thận trọng: Nhiều cổ phiếu được bán hơn mua")
        else:
            print(f"  ⚖️ Xu hướng cân bằng: Số cổ phiếu mua/bán tương đương")

    print(f"  • Tập trung vào các cổ phiếu có giao dịch thực (tránh nhiễu do biến động giá)")
    print(f"  • Quan tâm cổ phiếu ổn định - thể hiện sự tin tưởng của quỹ")
    print(f"  • Phân tích kỹ các cổ phiếu có xu hướng mua/bán rõ ràng")

def main():
    """Hàm chính cải tiến"""
    print("🚀 BẮT ĐẦU PHÂN TÍCH DỮ LIỆU GIAO DỊCH QUỸ (PHIÊN BẢN CẢI TIẾN)")
    print("="*60)

    # Load dữ liệu
    file_path = '/Users/ttuan/Desktop/fund_transaction.csv'
    df = load_and_clean_data(file_path)

    # Thống kê cơ bản
    status_counts, fund_stats = basic_statistics(df)

    # Phân tích chuyển động cổ phiếu (cải tiến)
    stock_analysis = analyze_stock_movements(df)

    # Tạo biểu đồ cải tiến
    create_visualizations(df, status_counts, fund_stats, stock_analysis)

    # Tạo insight cải tiến
    generate_insights(df, status_counts, fund_stats, stock_analysis)

    # Lưu kết quả chi tiết
    print(f"\n💾 Đang lưu kết quả chi tiết...")

    # Lưu thống kê quỹ
    fund_stats.to_csv('/Users/ttuan/Desktop/fund_statistics_refined.csv', encoding='utf-8-sig')

    # Lưu các thống kê cổ phiếu mới
    if stock_analysis['all_stats'] is not None:
        stock_analysis['all_stats'].to_csv('/Users/ttuan/Desktop/stock_all_statistics.csv', encoding='utf-8-sig')

    if stock_analysis['significant_stats'] is not None:
        stock_analysis['significant_stats'].to_csv('/Users/ttuan/Desktop/stock_significant_trades.csv', encoding='utf-8-sig')

    if stock_analysis['buy_stats'] is not None:
        stock_analysis['buy_stats'].to_csv('/Users/ttuan/Desktop/stock_buy_trades.csv', encoding='utf-8-sig')

    if stock_analysis['sell_stats'] is not None:
        stock_analysis['sell_stats'].to_csv('/Users/ttuan/Desktop/stock_sell_trades.csv', encoding='utf-8-sig')

    if stock_analysis['price_adjustment_stats'] is not None:
        stock_analysis['price_adjustment_stats'].to_csv('/Users/ttuan/Desktop/stock_stable_holdings.csv', encoding='utf-8-sig')

    # Lưu dữ liệu phân loại
    stock_analysis['significant_trades'].to_csv('/Users/ttuan/Desktop/significant_trades_data.csv', encoding='utf-8-sig', index=False)
    stock_analysis['price_adjustments'].to_csv('/Users/ttuan/Desktop/price_adjustments_data.csv', encoding='utf-8-sig', index=False)

    print("✅ Hoàn thành phân tích cải tiến!")
    print("📁 Các file kết quả đã được lưu:")
    print("   - fund_analysis_charts_refined.png: Biểu đồ trực quan cải tiến (9 biểu đồ)")
    print("   - fund_statistics_refined.csv: Thống kê theo quỹ")
    print("   - stock_all_statistics.csv: Thống kê tổng hợp theo cổ phiếu")
    print("   - stock_significant_trades.csv: Thống kê giao dịch thực")
    print("   - stock_buy_trades.csv: Thống kê giao dịch mua")
    print("   - stock_sell_trades.csv: Thống kê giao dịch bán")
    print("   - stock_stable_holdings.csv: Cổ phiếu được nắm giữ ổn định")
    print("   - significant_trades_data.csv: Dữ liệu giao dịch thực")
    print("   - price_adjustments_data.csv: Dữ liệu điều chỉnh do biến động giá")

    return {
        'df': df,
        'status_counts': status_counts,
        'fund_stats': fund_stats,
        'stock_analysis': stock_analysis
    }

if __name__ == "__main__":
    main()
