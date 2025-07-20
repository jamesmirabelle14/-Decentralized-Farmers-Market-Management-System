# Decentralized Farmers Market Management System

A comprehensive blockchain-based solution for managing farmers markets using Clarity smart contracts on the Stacks blockchain.

## System Overview

This system consists of five interconnected smart contracts that manage all aspects of a farmers market:

### 1. Vendor Registration Contract (`vendor-registration.clar`)
- Manages seller applications and approvals
- Assigns booth numbers and locations
- Tracks vendor status and registration fees
- Handles vendor profile management

### 2. Product Certification Contract (`product-certification.clar`)
- Validates organic and local produce claims
- Issues certification tokens for verified products
- Manages certification expiry and renewal
- Tracks certification history

### 3. Payment Processing Contract (`payment-processing.clar`)
- Handles customer transactions
- Manages vendor payouts and escrow
- Processes refunds and disputes
- Tracks transaction history

### 4. Health Permit Contract (`health-permit.clar`)
- Ensures food safety compliance for prepared foods
- Issues and tracks health permits
- Manages permit renewals and inspections
- Handles violation reporting

### 5. Market Scheduling Contract (`market-scheduling.clar`)
- Coordinates seasonal market dates
- Manages special events and festivals
- Handles booth reservations for specific dates
- Tracks market capacity and availability

## Key Features

- **Decentralized Governance**: No single point of control
- **Transparent Operations**: All transactions and certifications on-chain
- **Automated Compliance**: Smart contract enforcement of rules
- **Vendor Empowerment**: Direct control over listings and sales
- **Customer Trust**: Verifiable certifications and reviews

## Contract Architecture

Each contract operates independently while maintaining data consistency through standardized interfaces. The system uses native Clarity data types and functions for optimal performance.

### Data Types Used
- \`uint\` for IDs, amounts, and timestamps
- \`principal\` for user addresses
- \`string-ascii\` for names and descriptions
- \`bool\` for status flags
- \`optional\` for nullable values

### Error Handling
All contracts implement comprehensive error codes starting from \`u100\` to avoid conflicts and provide clear debugging information.

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for deployment

### Installation
\`\`\`bash
git clone <repository-url>
cd farmers-market-dapp
npm install
clarinet check
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Register as a Vendor
\`\`\`clarity
(contract-call? .vendor-registration register-vendor "Farm Fresh Produce" "Organic vegetables and fruits")
\`\`\`

### Certify a Product
\`\`\`clarity
(contract-call? .product-certification certify-product u1 "organic" "Certified organic tomatoes")
\`\`\`

### Process a Payment
\`\`\`clarity
(contract-call? .payment-processing process-payment 'SP1VENDOR u1000000)
\`\`\`

## Security Considerations

- All functions include proper authorization checks
- Input validation prevents malicious data
- Reentrancy protection on financial operations
- Time-based validations for permits and certifications

## Contributing

Please read our contributing guidelines and submit pull requests for any improvements.

## License

MIT License - see LICENSE file for details.
