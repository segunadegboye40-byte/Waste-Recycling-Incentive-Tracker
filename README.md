# ♻️ Waste Recycling Incentive Tracker

A Stacks blockchain smart contract that incentivizes waste recycling by rewarding users with tokens for verified recycling submissions.

## 🌟 Features

- **User Registration**: Users can register to participate in the recycling program
- **Recycling Submissions**: Submit different types of waste with weight measurements
- **Token Rewards**: Earn tokens based on waste type and weight recycled
- **Verification System**: Authorized verifiers validate recycling submissions
- **Token Management**: Transfer and redeem tokens earned from recycling
- **Multi-Waste Support**: Support for plastic, paper, glass, metal, and organic waste

## 🗂️ Waste Types & Rates

| Waste Type | Rate per KG |
|------------|-------------|
| 🥤 Plastic | 15 tokens   |
| 📄 Paper   | 10 tokens   |
| 🍃 Glass   | 20 tokens   |
| 🔗 Metal   | 25 tokens   |
| 🥬 Organic | 5 tokens    |

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for interaction

### Contract Deployment

1. Clone this repository
2. Navigate to project directory
3. Run contract checks:
```bash
clarinet check
```

4. Deploy to testnet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

## 📋 Contract Functions

### Public Functions

#### `initialize-contract`
Initializes the contract with default waste type rates (owner only).

#### `register-user`
Register as a new user in the recycling program.

#### `submit-recycling (waste-type weight)`
Submit a recycling entry with waste type and weight in kg.
- `waste-type`: String (plastic, paper, glass, metal, organic)  
- `weight`: Weight in kg (uint)

#### `verify-submission (submission-id)`
Verify a recycling submission (verifiers/owner only).

#### `add-verifier (verifier)`
Add an authorized verifier (owner only).

#### `remove-verifier (verifier)`  
Remove verifier authorization (owner only).

#### `redeem-tokens (amount recipient)`
Redeem tokens to external recipient.

#### `transfer-tokens (amount recipient)`
Transfer tokens to another user.

#### `update-waste-type-rate (waste-type new-rate)`
Update token rate for waste type (owner only).

### Read-Only Functions

#### `get-user-profile (user)`
Get user's profile information and statistics.

#### `get-user-balance (user)`  
Get user's token balance.

#### `get-submission (submission-id)`
Get details of a specific submission.

#### `get-waste-type-rate (waste-type)`
Get current token rate for waste type.

#### `get-total-recycled`
Get total weight of waste recycled.

#### `get-token-balance (user)`
Get user's fungible token balance.

## 💡 Usage Example

```clarity
;; Register as user
(contract-call? .waste-recycling-incentive-tracker register-user)

;; Submit recycling
(contract-call? .waste-recycling-incentive-tracker submit-recycling "plastic" u5)

;; Verify submission (as verifier)
(contract-call? .waste-recycling-incentive-tracker verify-submission u1)

;; Check balance
(contract-call? .waste-recycling-incentive-tracker get-user-balance tx-sender)
```

## 🏗️ Architecture

The contract uses several data structures:
- **user-profiles**: Track user statistics and verification status
- **recycling-submissions**: Store all recycling submissions  
- **waste-type-rates**: Define token rates per waste type
- **verifiers**: Manage authorized verifiers
- **user-balances**: Track user token balances

## 🔒 Security Features

- Owner-only administrative functions
- Verifier authorization system
- Input validation for all parameters
- Prevention of duplicate submissions
- Balance checks before transfers

## 📊 Token Economics

- Fungible token (waste-token) minted upon verification
- Dynamic rates per waste type
- Token transferability between users
- Redemption system for external use

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes and test with `clarinet check`
4. Submit pull request

## 📄 License

This project is open source and available under the MIT License.
