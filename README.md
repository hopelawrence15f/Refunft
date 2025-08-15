# 🆔 Refunft - Refugee Identity NFTs

> 🌍 Portable and verifiable digital identity for displaced people worldwide

## 📋 Overview

Refunft is a Clarity smart contract that creates non-transferable NFTs representing digital identity documents for refugees and displaced persons. These NFTs provide a secure, portable, and verifiable way to maintain identity records across borders and jurisdictions.

## ✨ Features

- 🎫 **Non-transferable NFTs** - Identity tokens that cannot be traded or sold
- 🔐 **Authorized Issuers** - Only verified organizations can mint identity NFTs  
- 📝 **Comprehensive Profiles** - Store essential identity and emergency information
- ✅ **Verification System** - Track verification status of identity documents
- 🔄 **Self-Updates** - Token owners can update emergency contacts and medical info
- ⏸️ **Emergency Controls** - Contract can be paused by owner if needed
- 📊 **Update Tracking** - Monitor profile modification history

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd refunft
clarinet check
```

## 📖 Usage

### For Authorized Organizations

#### 1️⃣ Mint a Refugee ID

```clarity
(contract-call? .Refunft mint-refugee-id
  'SP1234...  ;; recipient address
  "John Doe"  ;; name
  u1990       ;; birth year
  "Syria"     ;; country of origin
  u1640995200 ;; displacement date (unix timestamp)
  "UNHCR"     ;; issuing authority
  "jane@email.com +1234567890"  ;; emergency contact
  "Type A blood, no allergies"  ;; medical info
  (some u"https://ipfs.io/...")  ;; optional token URI
)
```

#### 2️⃣ Update Verification Status

```clarity
(contract-call? .Refunft update-verification-status u1 "verified")
```

### For Token Holders

#### 🆘 Update Emergency Contact

```clarity
(contract-call? .Refunft update-emergency-contact 
  u1 
  "new-contact@email.com +9876543210"
)
```

#### 🏥 Update Medical Information

```clarity
(contract-call? .Refunft update-medical-info 
  u1 
  "Type O blood, allergic to penicillin"
)
```

### For Everyone

#### 🔍 View Profile Information

```clarity
(contract-call? .Refunft get-refugee-profile u1)
```

#### 👤 Check Token Owner

```clarity
(contract-call? .Refunft get-owner u1)
```

## 🏗️ Contract Structure

### Data Storage

- **refugee-profiles**: Core identity information
- **authorized-issuers**: Verified organizations that can mint NFTs
- **token-metadata**: NFT metadata and URIs
- **profile-updates**: Update history tracking

### Key Functions

| Function | Purpose | Who Can Call |
|----------|---------|--------------|
| `mint-refugee-id` | Create new identity NFT | Authorized issuers |
| `update-verification-status` | Change verification status | Authorized issuers |
| `update-emergency-contact` | Update emergency info | Token owner |
| `update-medical-info` | Update medical info | Token owner |
| `add-authorized-issuer` | Add new issuer | Contract owner |

## 🔒 Security Features

- ❌ **Transfer Prevention**: NFTs cannot be transferred to prevent identity theft
- 🛡️ **Access Control**: Only authorized entities can mint new identities
- 🔐 **Owner-only Updates**: Sensitive info can only be updated by token owner
- ⏸️ **Emergency Pause**: Contract can be halted if security issues arise

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🌟 Impact

Refunft aims to provide displaced persons with:
- 📱 **Digital Identity Preservation** across borders
- 🏥 **Emergency Medical Access** through stored health information  
- 🔗 **Institutional Trust** via blockchain verification
- 🌐 **Global Portability** independent of physical documents

---

*Built for humanitarian impact*

