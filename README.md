# CreditSphere: Social Credit Protocol

CreditSphere is a decentralized lending protocol built on Stacks blockchain that enables credit-based lending through social reputation and community governance.

## Features

### Credit System
- Social credit scoring based on loan repayment history
- Community participation metrics
- Staking history consideration
- Maximum credit score of 1000
- Initial credit score of 500 for new users

### Lending Mechanism
- Credit-based loans without collateral
- Maximum loan amount: 1,000,000 microSTX
- 10-day loan duration
- Automatic credit adjustments based on repayment behavior
- Credit penalty of 100 points for defaults

### DAO Governance
- Community-driven credit appeals system
- Minimum credit threshold (700) for governance participation
- 10-day voting period for proposals
- Quorum requirement of 10 votes
- Majority voting system for proposal execution

### Credit Components
- Loan completion history (100 points per successful loan)
- Community activity score (max 100 points)
- Staking duration score (max 100 points)

## Technical Details

### Smart Contract Functions

#### Core Functions
- `create-credit-profile`: Initialize user credit profile
- `borrow`: Request a loan based on credit score
- `settle-loan`: Repay an active loan
- `verify-loan`: Check loan status and apply penalties

#### Governance Functions
- `submit-appeal`: Create credit score appeal
- `cast-vote`: Vote on credit appeals
- `finalize-appeal`: Execute approved appeals

#### Helper Functions
- `get-credit`: Retrieve user credit profile
- `get-active-loan`: Check active loan status
- `get-appeal`: View appeal details
- `get-appeal-vote`: Check vote status

## Installation

1. Install Clarinet
```bash
curl -L https://install.clarinet.co | sh
```

2. Initialize project
```bash
clarinet new creditsphere
cd creditsphere
```

3. Deploy contract
```bash
clarinet contract new creditsphere
```

## Testing

Run the test suite:
```bash
clarinet test
```

## Security Considerations

- Credit score manipulation protection
- Governance threshold requirements
- Vote duplication prevention
- Loan cap enforcement
- Credit score bounds validation

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Submit pull request
