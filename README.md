# 🍽️ Dynamic Tipping Pools

A smart contract system for performance-based tip distribution among kitchen staff on the Stacks blockchain.

## 🎯 Overview

The Dynamic Tipping Pools contract allows restaurants to fairly distribute tips among kitchen staff based on their performance metrics. Tips are collected in a shared pool and distributed periodically based on individual performance scores across multiple criteria.

## ✨ Features

- 👥 **Staff Management**: Register and manage kitchen staff members
- 📊 **Performance Tracking**: Track multiple performance metrics per staff member
- 💰 **Tip Pool Management**: Collect and manage customer tips
- 🏆 **Performance-Based Distribution**: Distribute tips based on performance scores
- ⏰ **Automated Periods**: Configurable distribution periods
- 💎 **Fair Compensation**: Base share plus performance bonuses

## 🔧 Performance Metrics

Each staff member is evaluated on:
- **Quality Score** (0-100): Food quality and presentation
- **Punctuality Score** (0-100): Timeliness and reliability  
- **Teamwork Score** (0-100): Collaboration and communication
- **Efficiency Score** (0-100): Speed and productivity
- **Orders Completed**: Number of orders handled

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/Dynamic-Tipping-Pools.git
cd Dynamic-Tipping-Pools
```

2. Install dependencies:
```bash
npm install
```

3. Check contract compilation:
```bash
clarinet check
```

## 📖 Usage

### 1. Register Staff Members 👨‍🍳

```clarity
(contract-call? .Dynamic-Tipping-pools register-staff 'SP1234... "John Doe" "Chef")
```

### 2. Add Tips to Pool 💵

```clarity
(contract-call? .Dynamic-Tipping-pools add-tip u1000000) ;; 1 STX in microSTX
```

### 3. Record Performance Metrics 📈

```clarity
(contract-call? .Dynamic-Tipping-pools record-performance 
  'SP1234...      ;; staff-id
  u25             ;; orders-completed
  u85             ;; quality-score
  u90             ;; punctuality-score  
  u88             ;; teamwork-score
  u92             ;; efficiency-score
)
```

### 4. Distribute Tips 🎁

```clarity
(contract-call? .Dynamic-Tipping-pools distribute-tips)
```

### 5. Calculate Individual Share 🧮

```clarity
(contract-call? .Dynamic-Tipping-pools calculate-staff-share 'SP1234... u1)
```

### 6. Claim Earnings 💰

```clarity
(contract-call? .Dynamic-Tipping-pools claim-earnings u1)
```

## 📊 Performance Bonus System

Performance bonuses are calculated based on total performance score:

| Total Score | Bonus Multiplier |
|-------------|------------------|
| 350+ | 50% 🏆 |
| 300-349 | 30% 🥈 |
| 250-299 | 20% 🥉 |
| 200-249 | 10% 📈 |
| <200 | 0% |

## 🔍 Read-Only Functions

### Get Staff Information
```clarity
(contract-call? .Dynamic-Tipping-pools get-staff-info 'SP1234...)
```

### Get Performance Metrics
```clarity
(contract-call? .Dynamic-Tipping-pools get-performance-metrics 'SP1234... u1)
```

### Get Contract Statistics
```clarity
(contract-call? .Dynamic-Tipping-pools get-contract-stats)
```

### Get Earnings Information
```clarity
(contract-call? .Dynamic-Tipping-pools get-staff-earnings 'SP1234... u1)
```

## ⚙️ Configuration

### Set Distribution Period
```clarity
(contract-call? .Dynamic-Tipping-pools set-distribution-period u144) ;; ~24 hours
```

### Toggle Contract
```clarity
(contract-call? .Dynamic-Tipping-pools toggle-contract)
```

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Run specific tests:
```bash
npm test
```

## 🔐 Security Features

- **Owner-only functions**: Critical operations restricted to contract owner
- **Input validation**: All inputs are validated for correctness
- **Staff verification**: Only active staff can earn and claim tips
- **Period validation**: Prevents duplicate distributions
- **Balance checks**: Ensures sufficient funds before transfers

## 📝 Error Codes

- `u100`: Owner-only operation
- `u101`: Record not found  
- `u102`: Record already exists
- `u103`: Insufficient balance
- `u104`: Invalid amount
- `u105`: Not an active staff member
- `u106`: Invalid metric value
- `u107`: No tips available for distribution

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on the [Stacks](https://www.stacks.co/) blockchain
- Powered by [Clarity](https://clarity-lang.org/) smart contracts
- Testing framework: [Clarinet](https://github.com/hirosystems/clarinet)

---

Made with ❤️ for fair tip distribution in the food service industry
